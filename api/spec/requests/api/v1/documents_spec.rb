require 'rails_helper'

RSpec.describe 'Api::V1::Documents', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  describe 'GET /api/v1/knowledge_bases/:knowledge_base_id/documents' do
    let!(:documents) { create_list(:document, 3, knowledge_base: knowledge_base) }
    let!(:other_kb_doc) { create(:document) }

    it 'returns all documents for the knowledge base' do
      get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['documents'].length).to eq(3)
    end

    it 'includes meta information with status counts' do
      create(:document, knowledge_base: knowledge_base, status: 'indexed')
      create(:document, knowledge_base: knowledge_base, status: 'failed')

      get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers

      meta = json_response['meta']
      expect(meta['total']).to eq(5)
      expect(meta).to have_key('pending')
      expect(meta).to have_key('processing')
      expect(meta).to have_key('indexed')
      expect(meta).to have_key('failed')
    end

    it 'includes content_preview in response' do
      get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers

      doc = json_response['documents'].first
      expect(doc['content_preview']).to be_present
      expect(doc['content_preview'].length).to be <= 200
    end

    it 'does not include full content in list view' do
      get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers

      doc = json_response['documents'].first
      expect(doc).not_to have_key('content')
    end

    it 'returns documents in descending order by created_at' do
      get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers

      dates = json_response['documents'].map { |d| d['created_at'] }
      expect(dates).to eq(dates.sort.reverse)
    end

    it 'returns 404 for non-existent knowledge base' do
      get '/api/v1/knowledge_bases/99999/documents', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for another user knowledge base' do
      other_kb = create(:knowledge_base)
      get "/api/v1/knowledge_bases/#{other_kb.id}/documents", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /api/v1/documents/:id' do
    let(:document) { create(:document, knowledge_base: knowledge_base) }

    it 'returns the document with details' do
      get "/api/v1/documents/#{document.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['document']['id']).to eq(document.id)
      expect(json_response['document']['content']).to be_present
      expect(json_response['document']['metadata']).to be_present
    end

    it 'includes chunks_count' do
      create_list(:chunk, 3, document: document)

      get "/api/v1/documents/#{document.id}", headers: headers

      expect(json_response['document']['chunks_count']).to eq(3)
    end

    it 'returns 404 for non-existent document' do
      get '/api/v1/documents/99999', headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to eq('Document not found')
    end

    it 'returns 404 for another user document' do
      other_doc = create(:document)
      get "/api/v1/documents/#{other_doc.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/knowledge_bases/:knowledge_base_id/documents' do
    let(:valid_params) do
      {
        title: 'Test Document',
        content: 'This is the document content for testing purposes. It should be long enough.'
      }
    end

    it 'creates a new document' do
      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: valid_params,
             headers: headers
      }.to change(Document, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['document']['title']).to eq('Test Document')
      expect(json_response['document']['status']).to eq('pending')
      expect(json_response['message']).to include('Processing will begin shortly')
    end

    it 'associates document with knowledge base' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: valid_params,
           headers: headers

      doc = Document.last
      expect(doc.knowledge_base_id).to eq(knowledge_base.id)
    end

    it 'accepts metadata' do
      params_with_metadata = valid_params.merge(metadata: { source: 'upload', tags: [ 'test' ] })

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: params_with_metadata,
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'returns errors for missing title' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { content: 'Some content' },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include("Title can't be blank")
    end

    it 'returns errors for missing content' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test' },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include("Content can't be blank")
    end

    it 'returns 404 for non-existent knowledge base' do
      post '/api/v1/knowledge_bases/99999/documents',
           params: valid_params,
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for another user knowledge base' do
      other_kb = create(:knowledge_base)
      post "/api/v1/knowledge_bases/#{other_kb.id}/documents",
           params: valid_params,
           headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /api/v1/documents/:id' do
    let!(:document) { create(:document, knowledge_base: knowledge_base) }

    it 'deletes the document' do
      expect {
        delete "/api/v1/documents/#{document.id}", headers: headers
      }.to change(Document, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to eq('Document deleted successfully')
    end

    it 'deletes associated chunks' do
      create_list(:chunk, 3, document: document)

      expect {
        delete "/api/v1/documents/#{document.id}", headers: headers
      }.to change(Chunk, :count).by(-3)
    end

    it 'returns 404 for another user document' do
      other_doc = create(:document)
      delete "/api/v1/documents/#{other_doc.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'prevents deletion of processing documents' do
      document.update!(status: 'processing')

      expect {
        delete "/api/v1/documents/#{document.id}", headers: headers
      }.not_to change(Document, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Cannot delete document while it is being processed')
    end
  end

  describe 'GET /api/v1/documents/:id/status' do
    let(:document) { create(:document, knowledge_base: knowledge_base, status: 'pending') }

    it 'returns the document status' do
      get "/api/v1/documents/#{document.id}/status", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['id']).to eq(document.id)
      expect(json_response['status']).to eq('pending')
      expect(json_response['chunks_count']).to eq(0)
      expect(json_response['updated_at']).to be_present
    end

    it 'includes error message for failed documents' do
      document.mark_failed!('Processing error occurred')

      get "/api/v1/documents/#{document.id}/status", headers: headers

      expect(json_response['status']).to eq('failed')
      expect(json_response['error']).to include('Processing error')
    end

    it 'includes chunks count for indexed documents' do
      create_list(:chunk, 5, document: document)
      document.update!(status: 'indexed')

      get "/api/v1/documents/#{document.id}/status", headers: headers

      expect(json_response['chunks_count']).to eq(5)
    end

    it 'returns 404 for another user document' do
      other_doc = create(:document)
      get "/api/v1/documents/#{other_doc.id}/status", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/documents/:id/reprocess' do
    include ActiveJob::TestHelper

    let(:document) { create(:document, :failed, knowledge_base: knowledge_base) }

    it 'queues the document for reprocessing' do
      expect {
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
      }.to have_enqueued_job(ProcessDocumentJob).with(document.id, force: true)

      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to include('reprocessing')
    end

    it 'resets document status to pending' do
      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(document.reload.status).to eq('pending')
    end

    it 'clears previous error from metadata' do
      document.update!(metadata: { 'error' => 'Previous error' })

      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(document.reload.metadata['error']).to be_nil
    end

    it 'returns the updated document' do
      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(json_response['document']['status']).to eq('pending')
    end

    it 'prevents reprocessing of currently processing documents' do
      document.update!(status: 'processing')

      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Document is already being processed')
    end

    it 'allows reprocessing of indexed documents' do
      document.update!(status: 'indexed')

      expect {
        post "/api/v1/documents/#{document.id}/reprocess", headers: headers
      }.to have_enqueued_job(ProcessDocumentJob)

      expect(response).to have_http_status(:ok)
    end

    it 'returns 404 for another user document' do
      other_doc = create(:document)
      post "/api/v1/documents/#{other_doc.id}/reprocess", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/knowledge_bases/:knowledge_base_id/documents/batch_reprocess' do
    include ActiveJob::TestHelper

    let!(:pending_doc) { create(:document, knowledge_base: knowledge_base, status: 'pending') }
    let!(:failed_doc) { create(:document, :failed, knowledge_base: knowledge_base) }
    let!(:indexed_doc) { create(:document, :indexed, knowledge_base: knowledge_base) }

    it 'queues batch processing job' do
      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents/batch_reprocess", headers: headers
      }.to have_enqueued_job(BatchProcessDocumentsJob)

      expect(response).to have_http_status(:ok)
    end

    it 'returns the count of documents to be processed' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents/batch_reprocess", headers: headers

      expect(json_response['documents_count']).to eq(2) # pending + failed
      expect(json_response['knowledge_base_id']).to eq(knowledge_base.id)
    end

    it 'accepts custom statuses parameter' do
      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents/batch_reprocess",
             params: { statuses: [ 'failed' ] },
             headers: headers
      }.to have_enqueued_job(BatchProcessDocumentsJob)
        .with(knowledge_base.id, hash_including(statuses: [ 'failed' ]))

      expect(json_response['documents_count']).to eq(1)
    end

    it 'accepts force parameter' do
      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents/batch_reprocess",
             params: { force: true },
             headers: headers
      }.to have_enqueued_job(BatchProcessDocumentsJob)
        .with(knowledge_base.id, hash_including(force: true))
    end

    it 'returns 404 for another user knowledge base' do
      other_kb = create(:knowledge_base)

      post "/api/v1/knowledge_bases/#{other_kb.id}/documents/batch_reprocess", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/knowledge_bases/:knowledge_base_id/documents queues processing job' do
    include ActiveJob::TestHelper

    let(:valid_params) do
      {
        title: 'Test Document',
        content: 'This is the document content for testing purposes. It should be long enough.'
      }
    end

    it 'enqueues ProcessDocumentJob after creation' do
      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: valid_params,
             headers: headers
      }.to have_enqueued_job(ProcessDocumentJob)
    end

    it 'passes the correct document ID to the job' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: valid_params,
           headers: headers

      created_doc = Document.last
      expect(ProcessDocumentJob).to have_been_enqueued.with(created_doc.id)
    end
  end
end

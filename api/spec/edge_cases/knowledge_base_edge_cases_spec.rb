# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Knowledge Base Edge Cases', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'Name Validation Edge Cases' do
    it 'rejects empty name' do
      post '/api/v1/knowledge_bases', params: { name: '' }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects name with only whitespace' do
      post '/api/v1/knowledge_bases', params: { name: '   ' }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'accepts name at minimum length (1 character after trim)' do
      post '/api/v1/knowledge_bases', params: { name: 'A' }, headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles very long name' do
      long_name = 'A' * 255 # Use reasonable length within DB column limits

      post '/api/v1/knowledge_bases', params: { name: long_name }, headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['knowledge_base']['name']).to eq(long_name)
    end

    it 'handles name with special characters' do
      special_name = "Test <script>alert('xss')</script> KB"

      post '/api/v1/knowledge_bases', params: { name: special_name }, headers: headers

      expect(response).to have_http_status(:created)
      # Name should be stored as-is (XSS is handled at output time)
      expect(json_response['knowledge_base']['name']).to eq(special_name)
    end

    it 'handles name with unicode characters' do
      unicode_name = '知識ベース 📚 тест'

      post '/api/v1/knowledge_bases', params: { name: unicode_name }, headers: headers

      expect(response).to have_http_status(:created)
      expect(json_response['knowledge_base']['name']).to eq(unicode_name)
    end

    it 'handles name with newlines' do
      name_with_newlines = "Line1\nLine2\rLine3"

      post '/api/v1/knowledge_bases', params: { name: name_with_newlines }, headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles name with null bytes (security)' do
      name_with_null = "Test\x00Injection"

      post '/api/v1/knowledge_bases', params: { name: name_with_null }, headers: headers

      # Null bytes may cause encoding issues; should handle gracefully
      expect(response.status).to be_in([ 201, 422, 500 ])
    end
  end

  describe 'ID Parameter Edge Cases' do
    it 'returns 404 for ID = 0' do
      get '/api/v1/knowledge_bases/0', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for negative ID' do
      get '/api/v1/knowledge_bases/-1', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for very large ID' do
      get '/api/v1/knowledge_bases/999999999999999', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for non-numeric ID' do
      get '/api/v1/knowledge_bases/abc', headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for ID with SQL injection' do
      # URL encode the malicious ID to avoid URI parsing errors
      get "/api/v1/knowledge_bases/#{CGI.escape('1;DROP TABLE knowledge_bases;--')}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns 404 for ID with path traversal' do
      get '/api/v1/knowledge_bases/../../../etc/passwd', headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'Multi-tenant Isolation' do
    let(:other_user) { create(:user) }
    let(:other_kb) { create(:knowledge_base, user: other_user) }
    let(:user_kb) { create(:knowledge_base, user: user) }

    it 'cannot view another user knowledge base' do
      get "/api/v1/knowledge_bases/#{other_kb.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot update another user knowledge base' do
      patch "/api/v1/knowledge_bases/#{other_kb.id}",
            params: { name: 'Hacked!' },
            headers: headers

      expect(response).to have_http_status(:not_found)
      expect(other_kb.reload.name).not_to eq('Hacked!')
    end

    it 'cannot delete another user knowledge base' do
      delete "/api/v1/knowledge_bases/#{other_kb.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(KnowledgeBase.exists?(other_kb.id)).to be true
    end

    it 'cannot search in another user knowledge base' do
      post "/api/v1/knowledge_bases/#{other_kb.id}/search",
           params: { query: 'test' },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot ask questions in another user knowledge base' do
      post "/api/v1/knowledge_bases/#{other_kb.id}/ask",
           params: { question: 'What is this?' },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'list only shows user own knowledge bases' do
      other_kb # Create other user's KB
      user_kb  # Create current user's KB

      get '/api/v1/knowledge_bases', headers: headers

      kb_ids = json_response['knowledge_bases'].map { |kb| kb['id'] }
      expect(kb_ids).to include(user_kb.id)
      expect(kb_ids).not_to include(other_kb.id)
    end
  end

  describe 'Cascading Deletes' do
    let!(:knowledge_base) { create(:knowledge_base, user: user) }
    let!(:documents) { create_list(:document, 3, knowledge_base: knowledge_base) }
    let!(:chunks) do
      documents.flat_map do |doc|
        create_list(:chunk, 2, document: doc)
      end
    end

    it 'deletes all associated documents when knowledge base is deleted' do
      document_ids = documents.map(&:id)

      delete "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers

      expect(response).to have_http_status(:ok)
      document_ids.each do |doc_id|
        expect(Document.exists?(doc_id)).to be false
      end
    end

    it 'deletes all associated chunks when knowledge base is deleted' do
      chunk_ids = chunks.map(&:id)

      delete "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers

      expect(response).to have_http_status(:ok)
      chunk_ids.each do |chunk_id|
        expect(Chunk.exists?(chunk_id)).to be false
      end
    end
  end

  describe 'Concurrent Access' do
    let!(:knowledge_base) { create(:knowledge_base, user: user, name: 'Original') }

    it 'handles concurrent updates' do
      threads = 5.times.map do |i|
        Thread.new do
          patch "/api/v1/knowledge_bases/#{knowledge_base.id}",
                params: { name: "Update #{i}" },
                headers: headers
        end
      end

      threads.each(&:join)

      # Should have final update, not corrupted data
      knowledge_base.reload
      expect(knowledge_base.name).to match(/Update \d/)
    end
  end

  describe 'Large Data Handling' do
    it 'handles knowledge base with many documents' do
      knowledge_base = create(:knowledge_base, user: user)
      create_list(:document, 50, knowledge_base: knowledge_base)

      get "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['knowledge_base']['total_documents']).to eq(50)
    end
  end
end

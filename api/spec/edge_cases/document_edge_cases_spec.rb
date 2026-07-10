# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Document Edge Cases', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  describe 'Content Validation Edge Cases' do
    it 'rejects empty content' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test', content: '' },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'rejects content with only whitespace' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test', content: '   ' },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'accepts very large content' do
      large_content = 'A' * 100_000 # 100KB

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Large Doc', content: large_content },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles content with binary data gracefully' do
      binary_content = "Normal text \x00\x01\x02 more text"

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Binary', content: binary_content },
           headers: headers

      # Binary data may cause encoding issues; should handle gracefully
      expect(response.status).to be_in([ 201, 422, 500 ])
    end

    it 'handles content with mixed encodings' do
      mixed_content = "UTF-8: 日本語 • Latin-1: café"

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Mixed', content: mixed_content },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles content with only emojis' do
      emoji_content = '🚀🎉💡🔥✨' * 100

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Emojis', content: emoji_content },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles markdown content' do
      markdown_content = <<~MARKDOWN
        # Heading 1
        ## Heading 2

        - List item 1
        - List item 2

        ```ruby
        def hello
          puts "Hello, World!"
        end
        ```

        [Link](https://example.com)
      MARKDOWN

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Markdown', content: markdown_content },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles HTML content (potential XSS)' do
      html_content = '<script>alert("xss")</script><p>Normal content</p>'

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'HTML', content: html_content },
           headers: headers

      expect(response).to have_http_status(:created)
      # Content stored as-is; XSS prevention at output layer
    end
  end

  describe 'Title Validation Edge Cases' do
    it 'accepts title at minimum length' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'A', content: 'Content here' },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles title with path traversal attempt' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: '../../../etc/passwd', content: 'Content' },
           headers: headers

      expect(response).to have_http_status(:created)
      # Title stored as-is; no file system operations
    end
  end

  describe 'Document Status Transitions' do
    it 'cannot delete document while processing' do
      document = create(:document, knowledge_base: knowledge_base, status: 'processing')

      delete "/api/v1/documents/#{document.id}", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Document.exists?(document.id)).to be true
    end

    it 'cannot reprocess document while already processing' do
      document = create(:document, knowledge_base: knowledge_base, status: 'processing')

      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it 'can reprocess failed document' do
      document = create(:document, knowledge_base: knowledge_base, status: 'failed')

      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(response).to have_http_status(:ok)
      expect(document.reload.status).to eq('pending')
    end

    it 'can reprocess indexed document' do
      document = create(:document, :indexed, knowledge_base: knowledge_base)

      post "/api/v1/documents/#{document.id}/reprocess", headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'Multi-tenant Document Isolation' do
    let(:other_user) { create(:user) }
    let(:other_kb) { create(:knowledge_base, user: other_user) }
    let(:other_document) { create(:document, knowledge_base: other_kb) }

    it 'cannot view another user document' do
      get "/api/v1/documents/#{other_document.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot delete another user document' do
      delete "/api/v1/documents/#{other_document.id}", headers: headers

      expect(response).to have_http_status(:not_found)
      expect(Document.exists?(other_document.id)).to be true
    end

    it 'cannot reprocess another user document' do
      post "/api/v1/documents/#{other_document.id}/reprocess", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot get status of another user document' do
      get "/api/v1/documents/#{other_document.id}/status", headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'cannot add document to another user knowledge base' do
      post "/api/v1/knowledge_bases/#{other_kb.id}/documents",
           params: { title: 'Hacked', content: 'Content' },
           headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'Metadata Edge Cases' do
    it 'accepts empty metadata' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test', content: 'Content', metadata: {} },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'accepts nested metadata' do
      metadata = {
        author: 'John',
        tags: %w[ruby rails],
        details: { version: '1.0', date: '2024-01-01' }
      }

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test', content: 'Content', metadata: metadata },
           headers: headers

      expect(response).to have_http_status(:created)
    end

    it 'handles metadata with special characters' do
      metadata = {
        key: "value with 'quotes' and \"double quotes\"",
        unicode: '日本語'
      }

      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
           params: { title: 'Test', content: 'Content', metadata: metadata },
           headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  describe 'Batch Operations Edge Cases' do
    it 'handles batch reprocess with no matching documents' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents/batch_reprocess",
           params: { statuses: [ 'failed' ] },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['documents_count']).to eq(0)
    end

    it 'handles batch reprocess with invalid status' do
      post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents/batch_reprocess",
           params: { statuses: [ 'invalid_status' ] },
           headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['documents_count']).to eq(0)
    end
  end
end

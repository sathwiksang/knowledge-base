# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Documents API', type: :request do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{JwtService.encode(user_id: user.id)}" }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  path '/api/v1/knowledge_bases/{knowledge_base_id}/documents' do
    parameter name: :knowledge_base_id, in: :path, type: :integer, description: 'Knowledge base ID'

    get 'List documents' do
      tags 'Documents'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Documents retrieved' do
        schema type: :object,
               properties: {
                 documents: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/Document' }
                 },
                 meta: {
                   type: :object,
                   properties: {
                     total: { type: :integer },
                     pending: { type: :integer },
                     processing: { type: :integer },
                     indexed: { type: :integer },
                     failed: { type: :integer }
                   }
                 },
                 request_id: { type: :string, format: :uuid }
               }

        let(:knowledge_base_id) { knowledge_base.id }
        let!(:document) { create(:document, knowledge_base: knowledge_base) }

        run_test!
      end
    end

    post 'Upload document' do
      tags 'Documents'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      description 'Upload a document for processing. Document will be chunked and embeddings generated asynchronously.'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string, example: 'Getting Started Guide' },
          content: { type: :string, example: 'This guide covers the basics of...' },
          metadata: {
            type: :object,
            description: 'Optional metadata',
            additionalProperties: true
          }
        },
        required: %w[title content]
      }

      response '201', 'Document uploaded' do
        schema type: :object,
               properties: {
                 document: { '$ref' => '#/components/schemas/Document' },
                 message: { type: :string, example: 'Document uploaded successfully. Processing will begin shortly.' },
                 request_id: { type: :string, format: :uuid }
               }

        let(:knowledge_base_id) { knowledge_base.id }
        let(:body) { { title: 'Test Doc', content: 'Test content for the document.' } }

        run_test!
      end

      response '422', 'Validation failed' do
        schema '$ref' => '#/components/schemas/Error'

        let(:knowledge_base_id) { knowledge_base.id }
        let(:body) { { title: '', content: '' } }

        run_test!
      end
    end
  end

  path '/api/v1/documents/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Document ID'

    get 'Get document' do
      tags 'Documents'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Document retrieved' do
        schema type: :object,
               properties: {
                 document: {
                   allOf: [
                     { '$ref' => '#/components/schemas/Document' },
                     {
                       type: :object,
                       properties: {
                         content: { type: :string },
                         metadata: { type: :object },
                         chunks_count: { type: :integer }
                       }
                     }
                   ]
                 },
                 request_id: { type: :string, format: :uuid }
               }

        let(:document) { create(:document, knowledge_base: knowledge_base) }
        let(:id) { document.id }

        run_test!
      end

      response '404', 'Document not found' do
        let(:id) { 99999 }

        run_test!
      end
    end

    delete 'Delete document' do
      tags 'Documents'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Document deleted' do
        schema type: :object,
               properties: {
                 message: { type: :string, example: 'Document deleted successfully' },
                 request_id: { type: :string, format: :uuid }
               }

        let(:document) { create(:document, knowledge_base: knowledge_base) }
        let(:id) { document.id }

        run_test!
      end
    end
  end

  path '/api/v1/documents/{id}/status' do
    parameter name: :id, in: :path, type: :integer, description: 'Document ID'

    get 'Get document processing status' do
      tags 'Documents'
      produces 'application/json'
      security [ bearerAuth: [] ]
      description 'Check the processing status of a document'

      response '200', 'Status retrieved' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 status: { type: :string, enum: %w[pending processing indexed failed] },
                 chunks_count: { type: :integer },
                 error: { type: :string, nullable: true },
                 updated_at: { type: :string, format: 'date-time' },
                 request_id: { type: :string, format: :uuid }
               }

        let(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
        let(:id) { document.id }

        run_test!
      end
    end
  end

  path '/api/v1/documents/{id}/reprocess' do
    parameter name: :id, in: :path, type: :integer, description: 'Document ID'

    post 'Reprocess document' do
      tags 'Documents'
      produces 'application/json'
      security [ bearerAuth: [] ]
      description 'Queue a document for reprocessing (regenerate chunks and embeddings)'

      response '200', 'Document queued for reprocessing' do
        schema type: :object,
               properties: {
                 document: { '$ref' => '#/components/schemas/Document' },
                 message: { type: :string, example: 'Document queued for reprocessing' },
                 request_id: { type: :string, format: :uuid }
               }

        let(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
        let(:id) { document.id }

        run_test!
      end

      response '422', 'Document is currently processing' do
        schema '$ref' => '#/components/schemas/Error'

        let(:document) { create(:document, knowledge_base: knowledge_base, status: 'processing') }
        let(:id) { document.id }

        run_test!
      end
    end
  end

  path '/api/v1/knowledge_bases/{knowledge_base_id}/documents/batch_reprocess' do
    parameter name: :knowledge_base_id, in: :path, type: :integer, description: 'Knowledge base ID'

    post 'Batch reprocess documents' do
      tags 'Documents'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      description 'Queue multiple documents for reprocessing based on status filter'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          statuses: {
            type: :array,
            items: { type: :string, enum: %w[pending processing indexed failed] },
            default: %w[pending failed],
            description: 'Document statuses to include'
          },
          force: {
            type: :boolean,
            default: false,
            description: 'Force reprocessing even for indexed documents'
          }
        }
      }

      response '200', 'Batch reprocessing queued' do
        schema type: :object,
               properties: {
                 message: { type: :string },
                 knowledge_base_id: { type: :integer },
                 statuses: { type: :array, items: { type: :string } },
                 documents_count: { type: :integer },
                 request_id: { type: :string, format: :uuid }
               }

        let(:knowledge_base_id) { knowledge_base.id }
        let(:body) { { statuses: %w[pending failed] } }

        run_test!
      end
    end
  end
end

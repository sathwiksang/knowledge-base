# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Knowledge Bases API', type: :request do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{JwtService.encode(user_id: user.id)}" }

  path '/api/v1/knowledge_bases' do
    get 'List knowledge bases' do
      tags 'Knowledge Bases'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Knowledge bases retrieved' do
        schema type: :object,
               properties: {
                 knowledge_bases: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/KnowledgeBase' }
                 },
                 request_id: { type: :string, format: :uuid }
               }

        let!(:knowledge_base) { create(:knowledge_base, user: user) }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }

        run_test!
      end
    end

    post 'Create knowledge base' do
      tags 'Knowledge Bases'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'My Knowledge Base' },
          description: { type: :string, example: 'Documentation for my project' }
        },
        required: %w[name]
      }

      response '201', 'Knowledge base created' do
        schema type: :object,
               properties: {
                 knowledge_base: { '$ref' => '#/components/schemas/KnowledgeBase' },
                 request_id: { type: :string, format: :uuid }
               }

        let(:body) { { name: 'Test KB', description: 'Test description' } }

        run_test!
      end

      response '422', 'Validation failed' do
        schema '$ref' => '#/components/schemas/Error'

        let(:body) { { name: '' } }

        run_test!
      end
    end
  end

  path '/api/v1/knowledge_bases/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Knowledge base ID'

    get 'Get knowledge base' do
      tags 'Knowledge Bases'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Knowledge base retrieved' do
        schema type: :object,
               properties: {
                 knowledge_base: { '$ref' => '#/components/schemas/KnowledgeBase' },
                 request_id: { type: :string, format: :uuid }
               }

        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }

        run_test!
      end

      response '404', 'Not found' do
        let(:id) { 99999 }

        run_test!
      end
    end

    patch 'Update knowledge base' do
      tags 'Knowledge Bases'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string }
        }
      }

      response '200', 'Knowledge base updated' do
        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }
        let(:body) { { name: 'Updated Name' } }

        run_test!
      end
    end

    delete 'Delete knowledge base' do
      tags 'Knowledge Bases'
      produces 'application/json'
      security [ bearerAuth: [] ]

      response '200', 'Knowledge base deleted' do
        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }

        run_test!
      end
    end
  end

  path '/api/v1/knowledge_bases/{id}/search' do
    parameter name: :id, in: :path, type: :integer, description: 'Knowledge base ID'

    post 'Semantic search' do
      tags 'Search'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      description 'Perform semantic search across documents in the knowledge base using vector similarity'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          query: { type: :string, example: 'How do I configure authentication?' },
          limit: { type: :integer, default: 5, maximum: 20, description: 'Max results to return' },
          min_similarity: { type: :number, format: :float, description: 'Minimum similarity threshold (0-1)' }
        },
        required: %w[query]
      }

      response '200', 'Search results' do
        schema type: :object,
               properties: {
                 results: {
                   type: :array,
                   items: { '$ref' => '#/components/schemas/SearchResult' }
                 },
                 query: { type: :string },
                 total_chunks_searched: { type: :integer },
                 knowledge_base_id: { type: :integer },
                 search_time_ms: { type: :number },
                 request_id: { type: :string, format: :uuid }
               }

        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }
        let(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
        let!(:chunk) { create(:chunk, document: document, content: 'Test content about authentication') }
        let(:body) { { query: 'authentication' } }

        before do
          mock_embedding = Array.new(768) { |i| Math.sin(i * 0.1) }
          chunk.update!(embedding: mock_embedding)
          allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(mock_embedding)
        end

        run_test!
      end

      response '422', 'No indexed documents' do
        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }
        let(:body) { { query: 'test' } }

        run_test!
      end
    end
  end

  path '/api/v1/knowledge_bases/{id}/ask' do
    parameter name: :id, in: :path, type: :integer, description: 'Knowledge base ID'

    post 'RAG Question Answering' do
      tags 'Search'
      consumes 'application/json'
      produces 'application/json'
      security [ bearerAuth: [] ]
      description 'Ask a question and get an AI-generated answer based on knowledge base content (RAG)'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          question: { type: :string, example: 'What is the recommended way to handle errors?' },
          num_chunks: { type: :integer, default: 5, maximum: 10, description: 'Context chunks to use' },
          include_sources: { type: :boolean, default: true, description: 'Include source citations' }
        },
        required: %w[question]
      }

      response '200', 'Answer generated' do
        schema '$ref' => '#/components/schemas/RagResponse'

        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }
        let(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
        let!(:chunk) { create(:chunk, document: document, content: 'Error handling is done with try-catch blocks') }
        let(:body) { { question: 'How to handle errors?' } }

        before do
          mock_embedding = Array.new(768) { |i| Math.sin(i * 0.1) }
          chunk.update!(embedding: mock_embedding)
          allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(mock_embedding)
          allow_any_instance_of(LlmService).to receive(:answer_question).and_return({
            answer: 'Errors can be handled using try-catch blocks as mentioned in the documentation.',
            model: 'llama3.2:3b'
          })
        end

        run_test!
      end

      response '422', 'No indexed documents or question validation failed' do
        let(:knowledge_base) { create(:knowledge_base, user: user) }
        let(:id) { knowledge_base.id }
        let(:body) { { question: 'test' } }

        run_test!
      end
    end
  end
end

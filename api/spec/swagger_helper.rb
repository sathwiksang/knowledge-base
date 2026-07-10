# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  config.openapi_root = Rails.root.join('swagger').to_s

  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.3',
      info: {
        title: 'Knowledge Base API',
        version: 'v1.0.0',
        description: <<~DESC,
          AI-powered Knowledge Base API with semantic search and RAG capabilities.

          ## Features
          - **JWT Authentication**: Secure token-based authentication
          - **Knowledge Base Management**: Create and manage knowledge bases
          - **Document Processing**: Upload documents with automatic chunking and embedding generation
          - **Semantic Search**: Vector similarity search using pgvector
          - **RAG Q&A**: Retrieval-Augmented Generation for intelligent question answering

          ## Authentication
          All API endpoints (except auth and health) require a valid JWT token.
          Include the token in the Authorization header: `Bearer <token>`

          ## Rate Limiting
          - General API: 100 requests/minute
          - Authentication: 5 requests/20 seconds
          - Search: 30 requests/minute
          - RAG Q&A: 20 requests/minute
        DESC
        contact: {
          name: 'API Support',
          email: 'support@example.com'
        },
        license: {
          name: 'MIT',
          url: 'https://opensource.org/licenses/MIT'
        }
      },
      paths: {},
      servers: [
        {
          url: 'http://localhost:3000',
          description: 'Development server'
        },
        {
          url: 'https://api.example.com',
          description: 'Production server'
        }
      ],
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'JWT',
            description: 'JWT token obtained from /api/v1/auth/login'
          }
        },
        schemas: {
          User: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              email: { type: :string, format: :email, example: 'user@example.com' },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id email]
          },
          KnowledgeBase: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              name: { type: :string, example: 'Technical Documentation' },
              description: { type: :string, example: 'Documentation for our tech stack' },
              total_documents: { type: :integer, example: 10 },
              indexed_documents: { type: :integer, example: 8 },
              total_chunks: { type: :integer, example: 150 },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id name]
          },
          Document: {
            type: :object,
            properties: {
              id: { type: :integer, example: 1 },
              title: { type: :string, example: 'Getting Started Guide' },
              status: {
                type: :string,
                enum: %w[pending processing indexed failed],
                example: 'indexed'
              },
              content_preview: { type: :string, example: 'This guide covers...' },
              created_at: { type: :string, format: 'date-time' },
              updated_at: { type: :string, format: 'date-time' }
            },
            required: %w[id title status]
          },
          SearchResult: {
            type: :object,
            properties: {
              rank: { type: :integer, example: 1 },
              chunk_id: { type: :integer, example: 42 },
              content: { type: :string, example: 'Ruby is a programming language...' },
              similarity_score: { type: :number, format: :float, example: 0.85 },
              document_id: { type: :integer, example: 5 },
              document_title: { type: :string, example: 'Ruby Guide' },
              chunk_index: { type: :integer, example: 0 }
            },
            required: %w[rank chunk_id content similarity_score document_id]
          },
          RagResponse: {
            type: :object,
            properties: {
              answer: { type: :string, example: 'Ruby is a dynamic programming language...' },
              question: { type: :string, example: 'What is Ruby?' },
              sources: {
                type: :array,
                items: { '$ref': '#/components/schemas/SourceCitation' }
              },
              knowledge_base_id: { type: :integer, example: 1 },
              model: { type: :string, example: 'llama3.2:3b' },
              chunks_used: { type: :integer, example: 3 },
              total_chunks_searched: { type: :integer, example: 50 },
              processing_time_ms: { type: :number, example: 250.5 }
            },
            required: %w[answer question sources knowledge_base_id]
          },
          SourceCitation: {
            type: :object,
            properties: {
              document_id: { type: :integer, example: 5 },
              document_title: { type: :string, example: 'Ruby Guide' },
              chunk_id: { type: :integer, example: 42 },
              chunk_index: { type: :integer, example: 0 },
              content_preview: { type: :string, example: 'Ruby is a dynamic...' },
              similarity_score: { type: :number, format: :float, example: 0.85 }
            },
            required: %w[document_id document_title chunk_id similarity_score]
          },
          Error: {
            type: :object,
            properties: {
              error: { type: :string, example: 'Validation failed' },
              errors: {
                type: :array,
                items: { type: :string },
                example: [ "Email can't be blank" ]
              },
              request_id: { type: :string, format: :uuid },
              timestamp: { type: :string, format: 'date-time' }
            },
            required: %w[error]
          },
          HealthStatus: {
            type: :object,
            properties: {
              status: { type: :string, enum: %w[ok degraded], example: 'ok' },
              timestamp: { type: :string, format: 'date-time' },
              services: {
                type: :object,
                properties: {
                  api: { type: :object },
                  database: { type: :object },
                  ollama: { type: :object }
                }
              },
              version: {
                type: :object,
                properties: {
                  ruby: { type: :string, example: '3.4.8' },
                  rails: { type: :string, example: '8.0.0' }
                }
              }
            }
          }
        }
      },
      security: [ { bearerAuth: [] } ],
      tags: [
        { name: 'Authentication', description: 'User authentication endpoints' },
        { name: 'Health', description: 'Health check endpoints' },
        { name: 'Knowledge Bases', description: 'Knowledge base management' },
        { name: 'Documents', description: 'Document management and processing' },
        { name: 'Search', description: 'Semantic search and RAG Q&A' }
      ]
    }
  }

  config.openapi_format = :yaml
end

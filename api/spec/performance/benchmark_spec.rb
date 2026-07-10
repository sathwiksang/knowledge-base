# frozen_string_literal: true

require 'rails_helper'
require 'rspec-benchmark'

RSpec.describe 'Performance Benchmarks', type: :request do
  include RSpec::Benchmark::Matchers

  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  describe 'API Response Time' do
    describe 'Authentication endpoints' do
      it 'login performs within acceptable time' do
        create(:user, email: 'perf@test.com', password: 'password123')

        expect {
          post '/api/v1/auth/login', params: { email: 'perf@test.com', password: 'password123' }
        }.to perform_under(500).ms
      end

      it 'register performs within acceptable time' do
        expect {
          post '/api/v1/auth/register', params: {
            email: "perf#{SecureRandom.hex(4)}@test.com",
            password: 'password123',
            password_confirmation: 'password123'
          }
        }.to perform_under(500).ms
      end
    end

    describe 'Knowledge Base endpoints' do
      before { create_list(:knowledge_base, 10, user: user) }

      it 'list knowledge bases performs under 200ms' do
        expect {
          get '/api/v1/knowledge_bases', headers: headers
        }.to perform_under(200).ms
      end

      it 'get single knowledge base performs under 100ms' do
        expect {
          get "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers
        }.to perform_under(100).ms
      end

      it 'create knowledge base performs under 200ms' do
        expect {
          post '/api/v1/knowledge_bases',
               params: { name: 'Performance Test' },
               headers: headers
        }.to perform_under(200).ms
      end
    end

    describe 'Document endpoints' do
      let!(:documents) { create_list(:document, 20, knowledge_base: knowledge_base) }

      it 'list documents performs under 200ms' do
        expect {
          get "/api/v1/knowledge_bases/#{knowledge_base.id}/documents", headers: headers
        }.to perform_under(200).ms
      end

      it 'create document performs under 300ms' do
        expect {
          post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
               params: { title: 'Perf Test', content: 'Content ' * 100 },
               headers: headers
        }.to perform_under(300).ms
      end
    end

    describe 'Search endpoint' do
      let!(:document) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:chunks) do
        create_list(:chunk, 50, document: document).each do |chunk|
          chunk.update!(embedding: Array.new(768) { rand })
        end
      end

      before do
        allow_any_instance_of(EmbeddingService).to receive(:generate)
          .and_return(Array.new(768) { rand })
      end

      it 'search performs under 500ms' do
        expect {
          post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
               params: { query: 'test query' },
               headers: headers
        }.to perform_under(500).ms
      end
    end
  end

  describe 'Iteration Performance' do
    describe 'bulk operations' do
      it 'handles 100 knowledge base creates efficiently' do
        expect {
          100.times do |i|
            post '/api/v1/knowledge_bases',
                 params: { name: "KB #{i}" },
                 headers: headers
          end
        }.to perform_under(30).sec
      end

      it 'handles 100 document creates efficiently' do
        expect {
          100.times do |i|
            post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
                 params: { title: "Doc #{i}", content: "Content #{i}" },
                 headers: headers
          end
        }.to perform_under(30).sec
      end
    end
  end

  describe 'Memory Usage' do
    it 'does not leak memory on repeated requests' do
      initial_memory = GetProcessMem.new.mb rescue nil
      skip 'get_process_mem not available' unless initial_memory

      100.times do
        get '/api/v1/knowledge_bases', headers: headers
      end

      GC.start
      final_memory = GetProcessMem.new.mb

      # Memory growth should be minimal (less than 50MB)
      expect(final_memory - initial_memory).to be < 50
    end
  end

  describe 'Concurrent Request Handling' do
    it 'handles concurrent requests without errors' do
      create_list(:knowledge_base, 5, user: user)
      errors = []

      threads = 10.times.map do
        Thread.new do
          begin
            get '/api/v1/knowledge_bases', headers: headers
            errors << response.status unless response.status == 200
          rescue => e
            errors << e.message
          end
        end
      end

      threads.each(&:join)

      expect(errors).to be_empty
    end
  end

  describe 'Large Payload Handling' do
    it 'handles large document content' do
      large_content = 'A' * 500_000 # 500KB

      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/documents",
             params: { title: 'Large Doc', content: large_content },
             headers: headers
      }.to perform_under(5).sec

      expect(response).to have_http_status(:created)
    end

    it 'handles many chunks in search' do
      document = create(:document, :indexed, knowledge_base: knowledge_base)
      embedding = Array.new(768) { rand }

      100.times do |i|
        create(:chunk, document: document, content: "Chunk #{i}", embedding: embedding)
      end

      allow_any_instance_of(EmbeddingService).to receive(:generate).and_return(embedding)

      expect {
        post "/api/v1/knowledge_bases/#{knowledge_base.id}/search",
             params: { query: 'test' },
             headers: headers
      }.to perform_under(2).sec
    end
  end
end

# Helper to get process memory (if gem is available)
class GetProcessMem
  def mb
    `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
  rescue
    nil
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RagService do
  let(:user) { create(:user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }
  let(:document) { create(:document, :indexed, knowledge_base: knowledge_base, title: 'Ruby Programming Guide') }

  let(:mock_search_service) { instance_double(SearchService) }
  let(:mock_llm_service) { instance_double(LlmService) }

  let(:service) do
    described_class.new(
      knowledge_base: knowledge_base,
      search_service: mock_search_service,
      llm_service: mock_llm_service
    )
  end

  # Sample search results
  let(:search_results) do
    [
      SearchService::SearchResult.new(
        rank: 1,
        chunk_id: 1,
        content: 'Ruby is a dynamic programming language focusing on simplicity.',
        similarity_score: 0.85,
        document_id: document.id,
        document_title: document.title,
        chunk_index: 0
      ),
      SearchService::SearchResult.new(
        rank: 2,
        chunk_id: 2,
        content: 'Ruby on Rails is a web framework written in Ruby.',
        similarity_score: 0.75,
        document_id: document.id,
        document_title: document.title,
        chunk_index: 1
      )
    ]
  end

  let(:successful_search_response) do
    SearchService::SearchResponse.new(
      results: search_results,
      query: 'What is Ruby?',
      total_chunks_searched: 10,
      knowledge_base_id: knowledge_base.id,
      search_time_ms: 15.5,
      error: nil
    )
  end

  let(:empty_search_response) do
    SearchService::SearchResponse.new(
      results: [],
      query: 'What is Ruby?',
      total_chunks_searched: 10,
      knowledge_base_id: knowledge_base.id,
      search_time_ms: 5.0,
      error: nil
    )
  end

  let(:failed_search_response) do
    SearchService::SearchResponse.new(
      results: [],
      query: 'What is Ruby?',
      total_chunks_searched: 0,
      knowledge_base_id: knowledge_base.id,
      search_time_ms: 1.0,
      error: 'Embedding generation failed'
    )
  end

  let(:llm_answer) do
    {
      answer: 'Ruby is a dynamic programming language known for its simplicity and elegance.',
      model: 'llama3.2:3b'
    }
  end

  describe '#ask' do
    before do
      allow(mock_search_service).to receive(:search).and_return(successful_search_response)
      allow(mock_llm_service).to receive(:answer_question).and_return(llm_answer)
    end

    context 'with valid question and context' do
      it 'returns a successful RagResponse' do
        response = service.ask(question: 'What is Ruby?')

        expect(response).to be_a(RagService::RagResponse)
        expect(response.success?).to be true
        expect(response.answer).to eq(llm_answer[:answer])
        expect(response.question).to eq('What is Ruby?')
        expect(response.model).to eq('llama3.2:3b')
      end

      it 'includes source citations' do
        response = service.ask(question: 'What is Ruby?')

        expect(response.sources).to be_an(Array)
        expect(response.sources.length).to eq(2)

        first_source = response.sources.first
        expect(first_source.document_id).to eq(document.id)
        expect(first_source.document_title).to eq('Ruby Programming Guide')
        expect(first_source.similarity_score).to eq(0.85)
      end

      it 'includes metadata' do
        response = service.ask(question: 'What is Ruby?')

        expect(response.knowledge_base_id).to eq(knowledge_base.id)
        expect(response.chunks_used).to eq(2)
        expect(response.total_chunks_searched).to eq(10)
        expect(response.processing_time_ms).to be_a(Numeric)
      end

      it 'performs semantic search with the question' do
        service.ask(question: 'What is Ruby?')

        expect(mock_search_service).to have_received(:search).with(
          query: 'What is Ruby?',
          limit: RagService::DEFAULT_CONTEXT_CHUNKS,
          min_similarity: RagService::MIN_SIMILARITY_THRESHOLD
        )
      end

      it 'passes context to LLM service' do
        service.ask(question: 'What is Ruby?')

        expect(mock_llm_service).to have_received(:answer_question) do |args|
          expect(args[:question]).to eq('What is Ruby?')
          expect(args[:context]).to include('Ruby is a dynamic programming language')
          expect(args[:context]).to include('[Source 1: Ruby Programming Guide]')
        end
      end
    end

    context 'with custom parameters' do
      it 'respects num_chunks parameter' do
        service.ask(question: 'What is Ruby?', num_chunks: 3)

        expect(mock_search_service).to have_received(:search).with(
          hash_including(limit: 3)
        )
      end

      it 'respects min_similarity parameter' do
        service.ask(question: 'What is Ruby?', min_similarity: 0.5)

        expect(mock_search_service).to have_received(:search).with(
          hash_including(min_similarity: 0.5)
        )
      end

      it 'excludes sources when include_sources is false' do
        response = service.ask(question: 'What is Ruby?', include_sources: false)

        expect(response.sources).to be_empty
      end

      it 'caps num_chunks at MAX_CONTEXT_CHUNKS' do
        service.ask(question: 'What is Ruby?', num_chunks: 100)

        expect(mock_search_service).to have_received(:search).with(
          hash_including(limit: RagService::MAX_CONTEXT_CHUNKS)
        )
      end
    end

    context 'with invalid question' do
      it 'returns error for blank question' do
        response = service.ask(question: '')

        expect(response.success?).to be false
        expect(response.error).to include('required')
      end

      it 'returns error for nil question' do
        response = service.ask(question: nil)

        expect(response.success?).to be false
        expect(response.error).to include('required')
      end

      it 'returns error for too short question' do
        response = service.ask(question: 'Hi')

        expect(response.success?).to be false
        expect(response.error).to include('at least 3 characters')
      end

      it 'returns error for too long question' do
        response = service.ask(question: 'a' * 1001)

        expect(response.success?).to be false
        expect(response.error).to include('exceed')
      end
    end

    context 'when search fails' do
      before do
        allow(mock_search_service).to receive(:search).and_return(failed_search_response)
      end

      it 'returns error response' do
        response = service.ask(question: 'What is Ruby?')

        expect(response.success?).to be false
        expect(response.error).to include('Search failed')
        expect(response.answer).to be_nil
      end
    end

    context 'when no relevant context is found' do
      before do
        allow(mock_search_service).to receive(:search).and_return(empty_search_response)
      end

      it 'returns error response' do
        response = service.ask(question: 'What is Ruby?')

        expect(response.success?).to be false
        expect(response.error).to include('No relevant information')
        expect(response.total_chunks_searched).to eq(10)
      end

      it 'does not call LLM service' do
        service.ask(question: 'What is Ruby?')

        expect(mock_llm_service).not_to have_received(:answer_question)
      end
    end

    context 'when LLM generation fails' do
      before do
        allow(mock_llm_service).to receive(:answer_question)
          .and_raise(LlmService::LlmError, 'Connection refused')
      end

      it 'returns error response' do
        response = service.ask(question: 'What is Ruby?')

        expect(response.success?).to be false
        expect(response.error).to include('Failed to generate answer')
        expect(response.error).to include('Connection refused')
      end
    end
  end

  describe '#ask_with_history' do
    let(:history) do
      [
        { question: 'What is Ruby?', answer: 'Ruby is a programming language.' }
      ]
    end

    before do
      allow(mock_search_service).to receive(:search).and_return(successful_search_response)
      allow(mock_llm_service).to receive(:chat).and_return({ response: 'Yes, Ruby supports OOP.', model: 'llama3.2:3b' })
    end

    it 'returns a successful response' do
      response = service.ask_with_history(
        question: 'Does it support OOP?',
        history: history
      )

      expect(response.success?).to be true
      expect(response.answer).to eq('Yes, Ruby supports OOP.')
    end

    it 'passes conversation history to LLM' do
      service.ask_with_history(
        question: 'Does it support OOP?',
        history: history
      )

      expect(mock_llm_service).to have_received(:chat) do |args|
        messages = args[:messages]

        expect(messages.length).to eq(3) # 1 historical Q + 1 historical A + 1 current Q
        expect(messages[0][:role]).to eq('user')
        expect(messages[0][:content]).to eq('What is Ruby?')
        expect(messages[1][:role]).to eq('assistant')
        expect(messages[1][:content]).to eq('Ruby is a programming language.')
        expect(messages[2][:role]).to eq('user')
        expect(messages[2][:content]).to include('Does it support OOP?')
      end
    end

    it 'includes sources in response' do
      response = service.ask_with_history(
        question: 'Does it support OOP?',
        history: history
      )

      expect(response.sources).not_to be_empty
    end
  end

  describe '#available?' do
    it 'delegates to LLM service' do
      allow(mock_llm_service).to receive(:available?).and_return(true)

      expect(service.available?).to be true
      expect(mock_llm_service).to have_received(:available?)
    end

    it 'returns false when LLM is unavailable' do
      allow(mock_llm_service).to receive(:available?).and_return(false)

      expect(service.available?).to be false
    end
  end

  describe 'RagResponse' do
    let(:response) do
      RagService::RagResponse.new(
        answer: 'Test answer',
        question: 'Test question',
        sources: [],
        knowledge_base_id: 1,
        model: 'llama3.2:3b',
        chunks_used: 3,
        total_chunks_searched: 10,
        processing_time_ms: 100.5,
        error: nil
      )
    end

    it 'success? returns true when no error' do
      expect(response.success?).to be true
    end

    it 'success? returns false when error present' do
      response.error = 'Something went wrong'
      expect(response.success?).to be false
    end

    it 'to_h returns hash representation' do
      hash = response.to_h

      expect(hash[:answer]).to eq('Test answer')
      expect(hash[:question]).to eq('Test question')
      expect(hash[:model]).to eq('llama3.2:3b')
      expect(hash[:chunks_used]).to eq(3)
      expect(hash[:total_chunks_searched]).to eq(10)
      expect(hash[:processing_time_ms]).to eq(100.5)
    end

    it 'to_h includes error only when present' do
      expect(response.to_h).not_to have_key(:error)

      response.error = 'Error message'
      expect(response.to_h[:error]).to eq('Error message')
    end
  end

  describe 'SourceCitation' do
    let(:citation) do
      RagService::SourceCitation.new(
        document_id: 1,
        document_title: 'Test Doc',
        chunk_id: 10,
        chunk_index: 2,
        content_preview: 'Some content...',
        similarity_score: 0.85
      )
    end

    it 'has all expected attributes' do
      expect(citation.document_id).to eq(1)
      expect(citation.document_title).to eq('Test Doc')
      expect(citation.chunk_id).to eq(10)
      expect(citation.chunk_index).to eq(2)
      expect(citation.content_preview).to eq('Some content...')
      expect(citation.similarity_score).to eq(0.85)
    end

    it 'converts to hash' do
      hash = citation.to_h

      expect(hash[:document_id]).to eq(1)
      expect(hash[:document_title]).to eq('Test Doc')
      expect(hash[:similarity_score]).to eq(0.85)
    end
  end

  describe 'context building' do
    before do
      allow(mock_search_service).to receive(:search).and_return(successful_search_response)
      allow(mock_llm_service).to receive(:answer_question).and_return(llm_answer)
    end

    it 'builds context with source headers' do
      service.ask(question: 'What is Ruby?')

      expect(mock_llm_service).to have_received(:answer_question) do |args|
        context = args[:context]

        expect(context).to include('[Source 1:')
        expect(context).to include('[Source 2:')
        expect(context).to include('Ruby is a dynamic programming language')
        expect(context).to include('Ruby on Rails is a web framework')
      end
    end

    it 'truncates content preview in sources' do
      long_content = 'A' * 200
      search_results.first.content = long_content

      response = service.ask(question: 'What is Ruby?')

      expect(response.sources.first.content_preview.length).to be <= 153 # 150 + '...'
    end
  end
end

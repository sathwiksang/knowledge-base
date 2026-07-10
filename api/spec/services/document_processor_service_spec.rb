# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DocumentProcessorService do
  let(:knowledge_base) { create(:knowledge_base) }
  let(:document) { create(:document, knowledge_base: knowledge_base, content: long_content, status: 'pending') }
  let(:long_content) { 'This is a test sentence for document processing. ' * 50 }
  let(:mock_chunker) { instance_double(TextChunkerService) }
  let(:mock_embedding_service) { instance_double(EmbeddingService) }
  let(:mock_embedding) { Array.new(768) { rand(-1.0..1.0) } }
  let(:mock_chunks) do
    [
      { content: 'Chunk 1 content here', index: 0 },
      { content: 'Chunk 2 content here', index: 1 },
      { content: 'Chunk 3 content here', index: 2 }
    ]
  end

  let(:service) do
    described_class.new(
      document: document,
      chunker: mock_chunker,
      embedding_service: mock_embedding_service
    )
  end

  before do
    allow(mock_chunker).to receive(:chunk).and_return(mock_chunks)
    allow(mock_embedding_service).to receive(:generate).and_return(mock_embedding)
    allow(mock_embedding_service).to receive(:available?).and_return(true)
  end

  describe '#process' do
    context 'successful processing' do
      it 'returns a successful ProcessingResult' do
        result = service.process

        expect(result).to be_success
        expect(result.document).to eq(document)
        expect(result.chunks_created).to eq(3)
        expect(result.processing_time).to be >= 0
        expect(result.error_message).to be_nil
      end

      it 'marks document as processing initially' do
        expect(document).to receive(:mark_processing!).and_call_original
        service.process
      end

      it 'marks document as indexed on completion' do
        service.process
        expect(document.reload).to be_indexed
      end

      it 'creates chunks with embeddings' do
        expect { service.process }.to change { document.chunks.count }.by(3)
      end

      it 'generates embeddings for each chunk' do
        service.process
        expect(mock_embedding_service).to have_received(:generate).exactly(3).times
      end

      it 'stores correct chunk indices' do
        service.process
        indices = document.chunks.pluck(:chunk_index).sort
        expect(indices).to eq([ 0, 1, 2 ])
      end

      it 'stores embeddings in chunks' do
        service.process
        document.chunks.each do |chunk|
          expect(chunk.embedding).to be_an(Array)
          expect(chunk.embedding.length).to eq(768)
        end
      end
    end

    context 'when document is nil' do
      let(:service) do
        described_class.new(
          document: nil,
          chunker: mock_chunker,
          embedding_service: mock_embedding_service
        )
      end

      it 'returns a failed result with validation error' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('nil')
      end
    end

    context 'when document has no content' do
      let(:document) do
        doc = create(:document, knowledge_base: knowledge_base, content: long_content, status: 'pending')
        # Bypass validation for testing
        doc.update_column(:content, '')
        doc.reload
      end

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('no content')
      end
    end

    context 'when document content is too short' do
      let(:document) { create(:document, knowledge_base: knowledge_base, content: 'Short', status: 'pending') }

      before do
        document.update_column(:content, 'Short')
      end

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('too short')
      end
    end

    context 'when document is already indexed' do
      let(:document) { create(:document, :indexed, knowledge_base: knowledge_base, content: long_content) }

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('already indexed')
      end
    end

    context 'when document is currently processing' do
      let(:document) { create(:document, :processing, knowledge_base: knowledge_base, content: long_content) }

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('being processed')
      end
    end

    context 'when embedding service is unavailable' do
      before do
        allow(mock_embedding_service).to receive(:available?).and_return(false)
      end

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('not available')
      end
    end

    context 'when chunking returns empty array' do
      before do
        allow(mock_chunker).to receive(:chunk).and_return([])
      end

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('could not be chunked')
      end

      it 'marks document as failed' do
        service.process
        expect(document.reload).to be_failed
      end
    end

    context 'when chunker raises error' do
      before do
        allow(mock_chunker).to receive(:chunk)
          .and_raise(TextChunkerService::ChunkerError, 'Chunking failed')
      end

      it 'returns a failed result' do
        result = service.process

        expect(result).to be_failed
        expect(result.error_message).to include('Chunking failed')
      end
    end

    context 'when embedding service raises connection error' do
      before do
        allow(mock_embedding_service).to receive(:generate)
          .and_raise(Clients::OllamaClient::ConnectionError, 'Connection refused')
      end

      it 'raises the error for job retry' do
        expect { service.process }
          .to raise_error(Clients::OllamaClient::ConnectionError)
      end

      it 'marks document as failed before raising' do
        expect { service.process }.to raise_error(Clients::OllamaClient::ConnectionError)
        expect(document.reload).to be_failed
      end
    end

    context 'when embedding service raises model error' do
      before do
        allow(mock_embedding_service).to receive(:generate)
          .and_raise(Clients::OllamaClient::ModelError, 'Model not found')
      end

      it 'raises the error for job retry' do
        expect { service.process }
          .to raise_error(Clients::OllamaClient::ModelError)
      end
    end

    context 'when embedding returns nil' do
      before do
        allow(mock_embedding_service).to receive(:generate).and_return(nil)
      end

      it 'raises EmbeddingError after retries' do
        expect { service.process }
          .to raise_error(DocumentProcessorService::EmbeddingError)
      end
    end

    context 'when reprocessing a document with existing chunks' do
      before do
        create_list(:chunk, 5, document: document)
      end

      it 'removes existing chunks before reprocessing' do
        expect(document.chunks.count).to eq(5)

        # Reset status to pending for reprocessing
        document.update!(status: 'pending')

        service.process

        expect(document.chunks.count).to eq(3)
      end
    end
  end

  describe '.process' do
    it 'provides convenient class method for processing' do
      allow(mock_embedding_service).to receive(:available?).and_return(true)

      result = described_class.process(
        document,
        chunker: mock_chunker,
        embedding_service: mock_embedding_service
      )

      expect(result).to be_success
    end
  end

  describe '.process_batch' do
    let(:documents) do
      3.times.map { create(:document, knowledge_base: knowledge_base, content: long_content, status: 'pending') }
    end

    it 'processes multiple documents' do
      results = described_class.process_batch(
        documents,
        chunker: mock_chunker,
        embedding_service: mock_embedding_service
      )

      expect(results.length).to eq(3)
      expect(results).to all(be_success)
    end
  end

  describe 'ProcessingResult' do
    let(:result) do
      DocumentProcessorService::ProcessingResult.new(
        success: true,
        document: document,
        chunks_created: 5,
        processing_time: 1.5,
        error_message: nil
      )
    end

    it 'responds to success?' do
      expect(result.success?).to be true
    end

    it 'responds to failed?' do
      expect(result.failed?).to be false
    end

    it 'has all expected attributes' do
      expect(result.document).to eq(document)
      expect(result.chunks_created).to eq(5)
      expect(result.processing_time).to eq(1.5)
      expect(result.error_message).to be_nil
    end
  end
end

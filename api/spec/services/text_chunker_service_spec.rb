# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TextChunkerService do
  let(:service) { described_class.new(chunk_size: 100, overlap: 20) }

  describe '#initialize' do
    it 'accepts custom chunk_size and overlap' do
      custom_service = described_class.new(chunk_size: 200, overlap: 50)
      expect(custom_service.instance_variable_get(:@chunk_size)).to eq(200)
      expect(custom_service.instance_variable_get(:@overlap)).to eq(50)
    end

    it 'raises error for chunk_size below minimum' do
      expect { described_class.new(chunk_size: 10) }
        .to raise_error(TextChunkerService::InvalidConfigError, /at least 50/)
    end

    it 'raises error for chunk_size above maximum' do
      expect { described_class.new(chunk_size: 3000) }
        .to raise_error(TextChunkerService::InvalidConfigError, /not exceed 2000/)
    end

    it 'raises error when overlap >= chunk_size' do
      expect { described_class.new(chunk_size: 100, overlap: 100) }
        .to raise_error(TextChunkerService::InvalidConfigError, /less than chunk size/)
    end

    it 'raises error for negative overlap' do
      expect { described_class.new(overlap: -10) }
        .to raise_error(TextChunkerService::InvalidConfigError, /non-negative/)
    end
  end

  describe '#chunk' do
    it 'returns empty array for blank text' do
      expect(service.chunk('')).to eq([])
      expect(service.chunk(nil)).to eq([])
      expect(service.chunk('   ')).to eq([])
    end

    it 'returns single chunk for short text' do
      short_text = 'This is a short piece of text that fits in one chunk.'
      chunks = service.chunk(short_text)

      expect(chunks.length).to eq(1)
      expect(chunks.first[:content]).to eq(short_text)
      expect(chunks.first[:index]).to eq(0)
    end

    it 'chunks text into smaller pieces' do
      long_text = 'This is a sentence. ' * 20
      chunks = service.chunk(long_text)

      expect(chunks).to be_an(Array)
      expect(chunks.length).to be > 1
    end

    it 'includes required fields in each chunk' do
      long_text = 'This is a test sentence. ' * 15
      chunks = service.chunk(long_text)

      chunks.each do |chunk|
        expect(chunk).to have_key(:content)
        expect(chunk).to have_key(:index)
        expect(chunk).to have_key(:char_start)
        expect(chunk).to have_key(:char_end)
      end
    end

    it 'assigns sequential indices' do
      long_text = 'This is a test sentence. ' * 30
      chunks = service.chunk(long_text)

      indices = chunks.map { |c| c[:index] }
      expect(indices).to eq((0...chunks.length).to_a)
    end

    it 'normalizes whitespace' do
      # Use longer text to ensure it passes minimum chunk size
      text_with_whitespace = "Text   with\n\nmultiple   spaces. This is additional content to make the chunk long enough to pass the minimum size threshold for chunking."
      chunks = service.chunk(text_with_whitespace)

      expect(chunks).not_to be_empty
      expect(chunks.first[:content]).not_to include('  ')
    end

    it 'respects minimum chunk size' do
      # Very short final chunk should be appended to previous
      text = 'A' * 80 + '. ' + 'B' * 80 + '. ' + 'C' * 10 + '.'
      chunks = service.chunk(text)

      chunks.each do |chunk|
        expect(chunk[:content].length).to be >= TextChunkerService::MIN_CHUNK_SIZE
      end
    end

    context 'with paragraph breaks' do
      let(:text_with_paragraphs) do
        "First paragraph with some content here.\n\n" \
          "Second paragraph with different content.\n\n" \
          "Third paragraph to add more text for chunking purposes."
      end

      it 'handles paragraph breaks gracefully' do
        chunks = service.chunk(text_with_paragraphs)

        expect(chunks).to be_an(Array)
        expect(chunks).not_to be_empty
      end
    end
  end

  describe '#chunk_with_metadata' do
    let(:text) { 'This is a sample text for testing. ' * 10 }
    let(:metadata) { { document_id: 123, source: 'test' } }

    it 'includes provided metadata in each chunk' do
      chunks = service.chunk_with_metadata(text, metadata)

      chunks.each do |chunk|
        expect(chunk[:metadata][:document_id]).to eq(123)
        expect(chunk[:metadata][:source]).to eq('test')
      end
    end

    it 'adds chunk_index and total_chunks to metadata' do
      chunks = service.chunk_with_metadata(text, metadata)

      chunks.each_with_index do |chunk, idx|
        expect(chunk[:metadata][:chunk_index]).to eq(idx)
        expect(chunk[:metadata][:total_chunks]).to eq(chunks.length)
      end
    end
  end

  describe '#chunk_documents' do
    let(:documents) do
      [
        'First document content. ' * 10,
        'Second document content. ' * 10
      ]
    end

    it 'chunks multiple documents' do
      chunks = service.chunk_documents(documents)

      expect(chunks).to be_an(Array)
      expect(chunks).not_to be_empty
    end

    it 'includes document_index for each chunk' do
      chunks = service.chunk_documents(documents)

      doc_indices = chunks.map { |c| c[:document_index] }.uniq.sort
      expect(doc_indices).to include(0, 1)
    end

    it 'includes index and document_index for each chunk' do
      chunks = service.chunk_documents(documents)

      chunks.each do |chunk|
        expect(chunk).to have_key(:index)
        expect(chunk).to have_key(:document_index)
      end
    end
  end

  describe '.optimal_chunk_size' do
    it 'returns default for zero or negative length' do
      expect(described_class.optimal_chunk_size(0)).to eq(500)
      expect(described_class.optimal_chunk_size(-100)).to eq(500)
    end

    it 'calculates based on target chunks' do
      result = described_class.optimal_chunk_size(5000, target_chunks: 10)
      expect(result).to eq(500)
    end

    it 'clamps to minimum chunk size' do
      result = described_class.optimal_chunk_size(100, target_chunks: 10)
      expect(result).to eq(50)
    end

    it 'clamps to maximum chunk size' do
      result = described_class.optimal_chunk_size(100_000, target_chunks: 10)
      expect(result).to eq(2000)
    end
  end

  describe '#estimate_chunks' do
    it 'returns 0 for blank text' do
      expect(service.estimate_chunks('')).to eq(0)
      expect(service.estimate_chunks(nil)).to eq(0)
    end

    it 'returns 1 for text shorter than chunk size' do
      short_text = 'Short text.'
      expect(service.estimate_chunks(short_text)).to eq(1)
    end

    it 'estimates multiple chunks for long text' do
      long_text = 'a' * 500 # 500 characters
      estimate = service.estimate_chunks(long_text)

      expect(estimate).to be > 1
    end
  end
end

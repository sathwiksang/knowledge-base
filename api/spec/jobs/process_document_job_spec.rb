# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProcessDocumentJob, type: :job do
  include ActiveJob::TestHelper

  let(:knowledge_base) { create(:knowledge_base) }
  let(:document) { create(:document, knowledge_base: knowledge_base, status: 'pending') }
  let(:mock_result) do
    DocumentProcessorService::ProcessingResult.new(
      success: true,
      document: document,
      chunks_created: 5,
      processing_time: 1.5,
      error_message: nil
    )
  end

  before do
    allow(DocumentProcessorService).to receive(:process).and_return(mock_result)
  end

  describe '#perform' do
    it 'processes the document' do
      perform_enqueued_jobs do
        described_class.perform_later(document.id)
      end

      expect(DocumentProcessorService).to have_received(:process).with(document)
    end

    it 'skips already indexed documents' do
      document.update!(status: 'indexed')

      perform_enqueued_jobs do
        described_class.perform_later(document.id)
      end

      expect(DocumentProcessorService).not_to have_received(:process)
    end

    it 'skips documents currently processing' do
      document.update!(status: 'processing')

      perform_enqueued_jobs do
        described_class.perform_later(document.id)
      end

      expect(DocumentProcessorService).not_to have_received(:process)
    end

    it 'processes indexed documents when force flag is set' do
      document.update!(status: 'indexed')

      perform_enqueued_jobs do
        described_class.perform_later(document.id, force: true)
      end

      expect(DocumentProcessorService).to have_received(:process)
    end

    it 'returns the processing result' do
      result = described_class.new.perform(document.id)

      expect(result).to eq(mock_result)
    end

    context 'when document does not exist' do
      it 'discards the job without error' do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(-1)
          end
        }.not_to raise_error
      end
    end

    context 'when processing fails with connection error' do
      before do
        allow(DocumentProcessorService).to receive(:process)
          .and_raise(Clients::OllamaClient::ConnectionError, 'Connection refused')
      end

      it 'retries the job' do
        assert_enqueued_with(job: described_class, args: [ document.id ]) do
          described_class.perform_later(document.id)
        end

        expect {
          perform_enqueued_jobs
        }.to have_enqueued_job(described_class).at_least(1).times
      end
    end

    context 'when processing fails with validation error' do
      before do
        allow(DocumentProcessorService).to receive(:process)
          .and_raise(DocumentProcessorService::ValidationError, 'Invalid document')
      end

      it 'discards the job (no retry)' do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(document.id)
          end
        }.not_to raise_error
      end
    end
  end

  describe 'job queuing' do
    it 'queues the job' do
      expect {
        described_class.perform_later(document.id)
      }.to have_enqueued_job(described_class).with(document.id)
    end

    it 'queues on default queue' do
      expect {
        described_class.perform_later(document.id)
      }.to have_enqueued_job.on_queue('default')
    end
  end

  describe '.perform_with_priority' do
    it 'queues job with specified priority' do
      expect {
        described_class.perform_with_priority(document.id, priority: 5)
      }.to have_enqueued_job(described_class)
    end
  end

  describe '.perform_urgent' do
    it 'queues job with high priority' do
      expect {
        described_class.perform_urgent(document.id)
      }.to have_enqueued_job(described_class)
    end
  end

  describe 'retry configuration' do
    it 'is an ActiveJob' do
      expect(described_class.ancestors).to include(ActiveJob::Base)
    end

    it 'handles ConnectionError gracefully in perform_later' do
      allow(DocumentProcessorService).to receive(:process)
        .and_raise(Clients::OllamaClient::ConnectionError, 'Test error')

      # The job should enqueue retry jobs when ConnectionError occurs
      expect {
        described_class.perform_later(document.id)
        perform_enqueued_jobs
      }.to have_enqueued_job(described_class).at_least(1).times
    end

    it 'handles TimeoutError gracefully in perform_later' do
      allow(DocumentProcessorService).to receive(:process)
        .and_raise(Clients::OllamaClient::TimeoutError, 'Timeout')

      # The job should enqueue retry jobs when TimeoutError occurs
      expect {
        described_class.perform_later(document.id)
        perform_enqueued_jobs
      }.to have_enqueued_job(described_class).at_least(1).times
    end

    it 'handles ValidationError by discarding without retry' do
      allow(DocumentProcessorService).to receive(:process)
        .and_raise(DocumentProcessorService::ValidationError, 'Invalid')

      # ValidationError should be discarded (no retry, no raise)
      expect {
        perform_enqueued_jobs do
          described_class.perform_later(document.id)
        end
      }.not_to raise_error

      # Should not have enqueued retry jobs
      expect(described_class).not_to have_been_enqueued.with(document.id)
    end

    it 'handles RecordNotFound by discarding without retry' do
      expect {
        perform_enqueued_jobs do
          described_class.perform_later(-999)
        end
      }.not_to raise_error
    end
  end
end

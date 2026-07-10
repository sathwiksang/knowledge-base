# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BatchProcessDocumentsJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:knowledge_base) { create(:knowledge_base, user: user) }

  describe '#perform' do
    context 'with pending and failed documents' do
      let!(:pending_doc) { create(:document, knowledge_base: knowledge_base, status: 'pending') }
      let!(:failed_doc) { create(:document, :failed, knowledge_base: knowledge_base) }
      let!(:indexed_doc) { create(:document, :indexed, knowledge_base: knowledge_base) }
      let!(:processing_doc) { create(:document, :processing, knowledge_base: knowledge_base) }

      it 'queues jobs for pending documents' do
        expect {
          described_class.new.perform(knowledge_base.id)
        }.to have_enqueued_job(ProcessDocumentJob).with(pending_doc.id, force: false)
      end

      it 'queues jobs for failed documents' do
        expect {
          described_class.new.perform(knowledge_base.id)
        }.to have_enqueued_job(ProcessDocumentJob).with(failed_doc.id, force: false)
      end

      it 'does not queue jobs for indexed documents' do
        expect {
          described_class.new.perform(knowledge_base.id)
        }.not_to have_enqueued_job(ProcessDocumentJob).with(indexed_doc.id, anything)
      end

      it 'does not queue jobs for processing documents' do
        expect {
          described_class.new.perform(knowledge_base.id)
        }.not_to have_enqueued_job(ProcessDocumentJob).with(processing_doc.id, anything)
      end

      it 'returns a BatchResult with correct counts' do
        result = described_class.new.perform(knowledge_base.id)

        expect(result.knowledge_base_id).to eq(knowledge_base.id)
        expect(result.total_documents).to eq(2) # pending + failed
        expect(result.queued_count).to eq(2)
        expect(result.skipped_count).to eq(0)
        expect(result.errors).to be_empty
      end
    end

    context 'with custom statuses' do
      let!(:pending_doc) { create(:document, knowledge_base: knowledge_base, status: 'pending') }
      let!(:failed_doc) { create(:document, :failed, knowledge_base: knowledge_base) }

      it 'only processes documents with specified statuses' do
        described_class.new.perform(knowledge_base.id, statuses: [ 'failed' ])

        # Check that only failed_doc was enqueued
        expect(ProcessDocumentJob).to have_been_enqueued.with(failed_doc.id, hash_including(force: false))
        expect(ProcessDocumentJob).not_to have_been_enqueued.with(pending_doc.id, anything)
      end
    end

    context 'with force flag' do
      let!(:failed_doc) { create(:document, :failed, knowledge_base: knowledge_base) }

      it 'resets failed documents to pending when force is true' do
        described_class.new.perform(knowledge_base.id, force: true)

        expect(failed_doc.reload.status).to eq('pending')
      end

      it 'queues jobs with force flag' do
        expect {
          described_class.new.perform(knowledge_base.id, force: true)
        }.to have_enqueued_job(ProcessDocumentJob).with(failed_doc.id, force: true)
      end
    end

    context 'with limit option' do
      let!(:docs) do
        5.times.map { create(:document, knowledge_base: knowledge_base, status: 'pending') }
      end

      it 'limits the number of documents processed' do
        result = described_class.new.perform(knowledge_base.id, limit: 2)

        expect(result.total_documents).to eq(2)
        expect(result.queued_count).to eq(2)
      end
    end

    context 'when knowledge base does not exist' do
      it 'is discarded without error' do
        expect {
          perform_enqueued_jobs do
            described_class.perform_later(-1)
          end
        }.not_to raise_error
      end
    end

    context 'when enqueueing fails for some documents' do
      let!(:pending_doc) { create(:document, knowledge_base: knowledge_base, status: 'pending') }

      before do
        # Simulate a failure during enqueue
        allow(ProcessDocumentJob).to receive(:perform_later)
          .and_raise(StandardError, 'Queue error')
      end

      it 'captures errors and continues' do
        result = described_class.new.perform(knowledge_base.id)

        expect(result.errors).not_to be_empty
        expect(result.errors.first[:error]).to include('Queue error')
      end
    end
  end

  describe 'job queuing' do
    it 'queues the job' do
      expect {
        described_class.perform_later(knowledge_base.id)
      }.to have_enqueued_job(described_class).with(knowledge_base.id)
    end

    it 'queues on default queue' do
      expect {
        described_class.perform_later(knowledge_base.id)
      }.to have_enqueued_job.on_queue('default')
    end
  end

  describe '.process_all_pending' do
    let!(:kb1) { create(:knowledge_base) }
    let!(:kb2) { create(:knowledge_base) }

    it 'queues jobs for all knowledge bases' do
      described_class.process_all_pending

      expect(described_class).to have_been_enqueued.with(kb1.id, anything)
      expect(described_class).to have_been_enqueued.with(kb2.id, anything)
    end
  end

  describe '.retry_failed' do
    let!(:kb) { create(:knowledge_base) }

    context 'with specific knowledge base' do
      it 'queues job with failed status and force flag' do
        expect {
          described_class.retry_failed(kb.id)
        }.to have_enqueued_job(described_class)
          .with(kb.id, hash_including(statuses: [ 'failed' ], force: true))
      end
    end

    context 'without specific knowledge base' do
      let!(:kb2) { create(:knowledge_base) }

      it 'queues jobs for all knowledge bases' do
        expect {
          described_class.retry_failed
        }.to have_enqueued_job(described_class).at_least(2).times
      end
    end
  end

  describe 'BatchResult' do
    let(:result) do
      described_class::BatchResult.new(
        knowledge_base_id: 1,
        total_documents: 10,
        queued_count: 8,
        skipped_count: 2,
        errors: []
      )
    end

    it 'has all expected attributes' do
      expect(result.knowledge_base_id).to eq(1)
      expect(result.total_documents).to eq(10)
      expect(result.queued_count).to eq(8)
      expect(result.skipped_count).to eq(2)
      expect(result.errors).to eq([])
    end
  end
end

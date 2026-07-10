require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:content) }
    it { should validate_presence_of(:status) }
    it { should validate_length_of(:title).is_at_most(255) }
    it { should validate_inclusion_of(:status).in_array(Document::STATUSES) }
  end

  describe 'associations' do
    it { should belong_to(:knowledge_base) }
    it { should have_many(:chunks).dependent(:destroy) }
  end

  describe 'default values' do
    it 'sets default status to pending' do
      kb = create(:knowledge_base)
      doc = Document.create!(knowledge_base: kb, title: 'Test', content: 'Content')
      expect(doc.status).to eq('pending')
    end

    it 'sets default metadata to empty hash' do
      kb = create(:knowledge_base)
      doc = Document.create!(knowledge_base: kb, title: 'Test', content: 'Content')
      expect(doc.metadata).to eq({})
    end
  end

  describe 'scopes' do
    let!(:pending_doc) { create(:document, status: 'pending') }
    let!(:processing_doc) { create(:document, status: 'processing') }
    let!(:indexed_doc) { create(:document, status: 'indexed') }
    let!(:failed_doc) { create(:document, status: 'failed') }

    it { expect(Document.pending).to include(pending_doc) }
    it { expect(Document.processing).to include(processing_doc) }
    it { expect(Document.indexed).to include(indexed_doc) }
    it { expect(Document.failed).to include(failed_doc) }
  end

  describe 'status methods' do
    let(:document) { build(:document, status: 'pending') }

    it 'returns correct status predicates' do
      expect(document.pending?).to be true
      expect(document.processing?).to be false
      expect(document.indexed?).to be false
      expect(document.failed?).to be false
    end
  end

  describe 'status transition methods' do
    let(:document) { create(:document, status: 'pending') }

    describe '#mark_processing!' do
      it 'updates status to processing' do
        document.mark_processing!
        expect(document.reload.status).to eq('processing')
      end
    end

    describe '#mark_indexed!' do
      it 'updates status to indexed' do
        document.mark_indexed!
        expect(document.reload.status).to eq('indexed')
      end
    end

    describe '#mark_failed!' do
      it 'updates status to failed' do
        document.mark_failed!
        expect(document.reload.status).to eq('failed')
      end

      it 'stores error message in metadata' do
        document.mark_failed!('Something went wrong')
        expect(document.reload.metadata['error']).to eq('Something went wrong')
      end
    end
  end
end

require 'rails_helper'

RSpec.describe UserBlueprint do
  let(:user) { create(:user) }

  describe 'default view' do
    subject { described_class.render_as_hash(user) }

    it 'includes id' do
      expect(subject[:id]).to eq(user.id)
    end

    it 'includes email' do
      expect(subject[:email]).to eq(user.email)
    end

    it 'includes created_at' do
      expect(subject[:created_at]).to be_present
    end

    it 'does not include password_digest' do
      expect(subject).not_to have_key(:password_digest)
    end

    it 'does not include password' do
      expect(subject).not_to have_key(:password)
    end
  end

  describe 'with_stats view' do
    subject { described_class.render_as_hash(user, view: :with_stats) }

    before do
      create_list(:knowledge_base, 3, user: user)
    end

    it 'includes knowledge_bases_count' do
      expect(subject[:knowledge_bases_count]).to eq(3)
    end
  end
end

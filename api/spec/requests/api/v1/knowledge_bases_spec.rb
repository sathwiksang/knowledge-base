require 'rails_helper'

RSpec.describe 'Api::V1::KnowledgeBases', type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }

  describe 'GET /api/v1/knowledge_bases' do
    let!(:knowledge_bases) { create_list(:knowledge_base, 3, user: user) }
    let!(:other_user_kb) { create(:knowledge_base) }

    it 'returns all knowledge bases for the user' do
      get '/api/v1/knowledge_bases', headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['knowledge_bases'].length).to eq(3)
    end

    it 'includes stats in response' do
      kb = knowledge_bases.first
      create_list(:document, 2, knowledge_base: kb, status: 'indexed')

      get '/api/v1/knowledge_bases', headers: headers

      kb_response = json_response['knowledge_bases'].find { |k| k['id'] == kb.id }
      expect(kb_response['total_documents']).to eq(2)
      expect(kb_response['indexed_documents']).to eq(2)
    end

    it 'does not return other users knowledge bases' do
      get '/api/v1/knowledge_bases', headers: headers

      ids = json_response['knowledge_bases'].map { |kb| kb['id'] }
      expect(ids).not_to include(other_user_kb.id)
    end

    it 'returns 401 without authentication' do
      get '/api/v1/knowledge_bases'

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns knowledge bases in descending order by created_at' do
      get '/api/v1/knowledge_bases', headers: headers

      dates = json_response['knowledge_bases'].map { |kb| kb['created_at'] }
      expect(dates).to eq(dates.sort.reverse)
    end
  end

  describe 'GET /api/v1/knowledge_bases/:id' do
    let(:knowledge_base) { create(:knowledge_base, user: user) }

    it 'returns the knowledge base' do
      get "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['knowledge_base']['id']).to eq(knowledge_base.id)
      expect(json_response['knowledge_base']['name']).to eq(knowledge_base.name)
    end

    it 'includes stats in response' do
      create_list(:document, 2, knowledge_base: knowledge_base)

      get "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers

      expect(json_response['knowledge_base']['total_documents']).to eq(2)
    end

    it 'returns 404 for non-existent knowledge base' do
      get '/api/v1/knowledge_bases/99999', headers: headers

      expect(response).to have_http_status(:not_found)
      expect(json_response['error']).to eq('Knowledge base not found')
    end

    it 'returns 404 for another user knowledge base' do
      other_kb = create(:knowledge_base)
      get "/api/v1/knowledge_bases/#{other_kb.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /api/v1/knowledge_bases' do
    let(:valid_params) { { name: 'My Knowledge Base', description: 'Test description' } }

    it 'creates a new knowledge base' do
      expect {
        post '/api/v1/knowledge_bases', params: valid_params, headers: headers
      }.to change(KnowledgeBase, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response['knowledge_base']['name']).to eq('My Knowledge Base')
      expect(json_response['knowledge_base']['description']).to eq('Test description')
    end

    it 'associates knowledge base with current user' do
      post '/api/v1/knowledge_bases', params: valid_params, headers: headers

      kb = KnowledgeBase.last
      expect(kb.user_id).to eq(user.id)
    end

    it 'returns errors for missing name' do
      post '/api/v1/knowledge_bases', params: { description: 'test' }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include("Name can't be blank")
    end

    it 'returns errors for duplicate name for same user' do
      create(:knowledge_base, user: user, name: 'My Knowledge Base')
      post '/api/v1/knowledge_bases', params: valid_params, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response['errors']).to include('Name already exists for this user')
    end

    it 'allows same name for different users' do
      create(:knowledge_base, name: 'My Knowledge Base')
      post '/api/v1/knowledge_bases', params: valid_params, headers: headers

      expect(response).to have_http_status(:created)
    end
  end

  describe 'PATCH /api/v1/knowledge_bases/:id' do
    let(:knowledge_base) { create(:knowledge_base, user: user) }

    it 'updates the knowledge base' do
      patch "/api/v1/knowledge_bases/#{knowledge_base.id}",
            params: { name: 'Updated Name', description: 'Updated desc' },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response['knowledge_base']['name']).to eq('Updated Name')
      expect(json_response['knowledge_base']['description']).to eq('Updated desc')
    end

    it 'returns 404 for another user knowledge base' do
      other_kb = create(:knowledge_base)
      patch "/api/v1/knowledge_bases/#{other_kb.id}",
            params: { name: 'Hacked' },
            headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'returns errors for invalid params' do
      patch "/api/v1/knowledge_bases/#{knowledge_base.id}",
            params: { name: '' },
            headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'DELETE /api/v1/knowledge_bases/:id' do
    let!(:knowledge_base) { create(:knowledge_base, user: user) }

    it 'deletes the knowledge base' do
      expect {
        delete "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers
      }.to change(KnowledgeBase, :count).by(-1)

      expect(response).to have_http_status(:ok)
      expect(json_response['message']).to eq('Knowledge base deleted successfully')
    end

    it 'deletes associated documents' do
      create_list(:document, 2, knowledge_base: knowledge_base)

      expect {
        delete "/api/v1/knowledge_bases/#{knowledge_base.id}", headers: headers
      }.to change(Document, :count).by(-2)
    end

    it 'returns 404 for another user knowledge base' do
      other_kb = create(:knowledge_base)
      delete "/api/v1/knowledge_bases/#{other_kb.id}", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end

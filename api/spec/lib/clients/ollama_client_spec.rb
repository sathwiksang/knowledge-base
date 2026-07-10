# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Clients::OllamaClient do
  let(:client) { described_class.new }
  let(:base_url) { 'http://localhost:11434' }

  describe '#initialize' do
    it 'uses default base URL' do
      expect(client.instance_variable_get(:@base_url)).to eq(base_url)
    end

    it 'accepts custom base URL' do
      custom_client = described_class.new(base_url: 'http://custom:8080')
      expect(custom_client.instance_variable_get(:@base_url)).to eq('http://custom:8080')
    end
  end

  describe '#embed' do
    let(:mock_embedding) { Array.new(768) { rand(-1.0..1.0) } }

    before do
      stub_request(:post, "#{base_url}/api/embeddings")
        .with(
          body: hash_including(model: 'nomic-embed-text', prompt: 'Test text'),
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(
          status: 200,
          body: { embedding: mock_embedding }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'generates embeddings for text' do
      result = client.embed('Test text')

      expect(result).to be_an(Array)
      expect(result.length).to eq(768)
    end

    it 'uses custom model when specified' do
      stub_request(:post, "#{base_url}/api/embeddings")
        .with(body: hash_including(model: 'custom-model'))
        .to_return(
          status: 200,
          body: { embedding: mock_embedding }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      client.embed('Test text', model: 'custom-model')
    end

    context 'when Ollama is unavailable' do
      before do
        stub_request(:post, "#{base_url}/api/embeddings")
          .to_raise(Errno::ECONNREFUSED)
      end

      it 'raises ConnectionError' do
        expect { client.embed('Test text') }
          .to raise_error(Clients::OllamaClient::ConnectionError, /Cannot connect to Ollama/)
      end
    end

    context 'when request times out' do
      before do
        stub_request(:post, "#{base_url}/api/embeddings")
          .to_timeout
      end

      it 'raises TimeoutError' do
        expect { client.embed('Test text') }
          .to raise_error(Clients::OllamaClient::TimeoutError)
      end
    end

    context 'when model returns error' do
      before do
        stub_request(:post, "#{base_url}/api/embeddings")
          .to_return(
            status: 400,
            body: { error: 'Model not found' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises ModelError' do
        expect { client.embed('Test text') }
          .to raise_error(Clients::OllamaClient::ModelError, /Model not found/)
      end
    end
  end

  describe '#generate' do
    let(:response_text) { 'This is a generated response.' }

    before do
      stub_request(:post, "#{base_url}/api/generate")
        .with(
          body: hash_including(model: 'llama3.2:3b', prompt: 'Test prompt', stream: false),
          headers: { 'Content-Type' => 'application/json' }
        )
        .to_return(
          status: 200,
          body: { response: response_text }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'generates text completion' do
      result = client.generate('Test prompt')
      expect(result).to eq(response_text)
    end

    it 'includes system prompt when provided' do
      stub_request(:post, "#{base_url}/api/generate")
        .with(body: hash_including(system: 'You are helpful'))
        .to_return(
          status: 200,
          body: { response: response_text }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      client.generate('Test prompt', system: 'You are helpful')
    end
  end

  describe '#chat' do
    let(:messages) do
      [
        { role: 'user', content: 'Hello' },
        { role: 'assistant', content: 'Hi!' },
        { role: 'user', content: 'How are you?' }
      ]
    end
    let(:response_content) { "I'm doing well, thank you!" }

    before do
      stub_request(:post, "#{base_url}/api/chat")
        .to_return(
          status: 200,
          body: { message: { role: 'assistant', content: response_content } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'handles chat completion' do
      result = client.chat(messages)
      expect(result).to eq(response_content)
    end

    it 'includes system message when provided' do
      stub_request(:post, "#{base_url}/api/chat")
        .with(body: hash_including(messages: array_including(hash_including(role: 'system'))))
        .to_return(
          status: 200,
          body: { message: { role: 'assistant', content: response_content } }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      client.chat(messages, system: 'Be helpful')
    end
  end

  describe '#health_check' do
    context 'when Ollama is running' do
      before do
        stub_request(:get, "#{base_url}/api/tags")
          .to_return(status: 200, body: { models: [] }.to_json)
      end

      it 'returns true' do
        expect(client.health_check).to be true
      end
    end

    context 'when Ollama is not running' do
      before do
        stub_request(:get, "#{base_url}/api/tags")
          .to_raise(Errno::ECONNREFUSED)
      end

      it 'returns false' do
        expect(client.health_check).to be false
      end
    end
  end

  describe '#list_models' do
    let(:models_response) do
      {
        models: [
          { name: 'nomic-embed-text', size: 274000000 },
          { name: 'llama3.2:3b', size: 2000000000 }
        ]
      }
    end

    before do
      stub_request(:get, "#{base_url}/api/tags")
        .to_return(
          status: 200,
          body: models_response.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns list of model names' do
      result = client.list_models
      expect(result).to eq([ 'nomic-embed-text', 'llama3.2:3b' ])
    end

    context 'when request fails' do
      before do
        stub_request(:get, "#{base_url}/api/tags")
          .to_raise(Errno::ECONNREFUSED)
      end

      it 'returns empty array' do
        expect(client.list_models).to eq([])
      end
    end
  end

  describe '#model_available?' do
    before do
      stub_request(:get, "#{base_url}/api/tags")
        .to_return(
          status: 200,
          body: { models: [ { name: 'nomic-embed-text' } ] }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns true when model exists' do
      expect(client.model_available?('nomic-embed-text')).to be true
    end

    it 'returns false when model does not exist' do
      expect(client.model_available?('non-existent-model')).to be false
    end
  end
end

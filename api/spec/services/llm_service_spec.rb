# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LlmService do
  let(:mock_client) { instance_double(Clients::OllamaClient) }
  let(:service) { described_class.new(client: mock_client) }

  describe '#answer_question' do
    let(:response_text) { 'This is the answer based on the context.' }

    before do
      allow(mock_client).to receive(:generate).and_return(response_text)
    end

    it 'generates an answer based on context' do
      result = service.answer_question(
        question: 'What is Ruby?',
        context: 'Ruby is a dynamic, open source programming language.'
      )

      expect(result[:answer]).to eq(response_text)
      expect(result[:model]).to eq('llama3.2:3b')
    end

    it 'uses custom system prompt when provided' do
      service.answer_question(
        question: 'What is Ruby?',
        context: 'Ruby is a programming language.',
        system_prompt: 'Custom system prompt'
      )

      expect(mock_client).to have_received(:generate) do |_prompt, **options|
        expect(options[:system]).to eq('Custom system prompt')
      end
    end

    it 'includes context in the prompt' do
      service.answer_question(
        question: 'What is Ruby?',
        context: 'Ruby was created by Matz.'
      )

      expect(mock_client).to have_received(:generate) do |prompt, **_options|
        expect(prompt).to include('Ruby was created by Matz')
        expect(prompt).to include('What is Ruby?')
      end
    end

    context 'when client raises error' do
      before do
        allow(mock_client).to receive(:generate)
          .and_raise(Clients::OllamaClient::ConnectionError, 'Connection failed')
      end

      it 'raises LlmError' do
        expect do
          service.answer_question(question: 'Test?', context: 'Context')
        end.to raise_error(LlmService::LlmError, /Connection failed/)
      end
    end
  end

  describe '#chat' do
    let(:messages) do
      [
        { role: 'user', content: 'Hello' },
        { role: 'assistant', content: 'Hi there!' },
        { role: 'user', content: 'How are you?' }
      ]
    end
    let(:response_text) { "I'm doing great!" }

    before do
      allow(mock_client).to receive(:chat).and_return(response_text)
    end

    it 'handles chat with message history' do
      result = service.chat(messages: messages)

      expect(result[:response]).to eq(response_text)
      expect(result[:model]).to eq('llama3.2:3b')
    end

    it 'passes system prompt to client' do
      service.chat(messages: messages, system_prompt: 'Be helpful')

      expect(mock_client).to have_received(:chat) do |_msgs, **options|
        expect(options[:system]).to eq('Be helpful')
      end
    end
  end

  describe '#generate' do
    let(:response_text) { 'Generated response' }

    before do
      allow(mock_client).to receive(:generate).and_return(response_text)
    end

    it 'generates text from prompt' do
      result = service.generate('Test prompt')
      expect(result).to eq(response_text)
    end

    it 'passes system prompt when provided' do
      service.generate('Test prompt', system_prompt: 'Be concise')

      expect(mock_client).to have_received(:generate).with('Test prompt', system: 'Be concise')
    end
  end

  describe '#summarize' do
    let(:summary_text) { 'This is the summary.' }

    before do
      allow(mock_client).to receive(:generate).and_return(summary_text)
    end

    it 'summarizes text' do
      result = service.summarize('Long text to summarize...')

      expect(result[:summary]).to eq(summary_text)
      expect(result[:model]).to eq('llama3.2:3b')
    end

    it 'includes max_length in prompt when specified' do
      service.summarize('Text to summarize', max_length: 100)

      expect(mock_client).to have_received(:generate) do |prompt, **_options|
        expect(prompt).to include('100 words')
      end
    end
  end

  describe '#extract_keywords' do
    let(:keywords_text) { "Ruby\nRails\nProgramming\nWeb Development\nAPI" }

    before do
      allow(mock_client).to receive(:generate).and_return(keywords_text)
    end

    it 'extracts keywords from text' do
      result = service.extract_keywords('Text about Ruby on Rails development')

      expect(result[:keywords]).to be_an(Array)
      expect(result[:keywords].length).to be <= 5
      expect(result[:keywords]).to include('Ruby', 'Rails')
    end

    it 'limits keywords to specified count' do
      result = service.extract_keywords('Some text', count: 3)

      expect(result[:keywords].length).to be <= 3
    end
  end

  describe '#available?' do
    it 'returns true when client health check passes' do
      allow(mock_client).to receive(:health_check).and_return(true)
      expect(service.available?).to be true
    end

    it 'returns false when client health check fails' do
      allow(mock_client).to receive(:health_check).and_return(false)
      expect(service.available?).to be false
    end
  end

  describe '#llm_model_name' do
    it 'returns configured model name' do
      expect(service.llm_model_name).to eq('llama3.2:3b')
    end
  end
end

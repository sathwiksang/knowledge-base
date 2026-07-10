# frozen_string_literal: true

# Provides a high-level interface to the local LLM (Ollama / llama3.2:3b)
# for text generation tasks: question answering, chat, summarization,
# and keyword extraction.
#
# This service is the "generation" half of the RAG pipeline — it takes
# context retrieved by {SearchService} and produces a natural-language
# answer. It also supports standalone generation tasks that don't require
# retrieved context.
#
# @note Requires a running Ollama instance with the configured model
#   pulled. Use {#available?} to verify before calling generation methods.
# @note All generation methods wrap Ollama errors in {LlmError} for
#   consistent error handling upstream.
#
# @example Answer a question with retrieved context (RAG)
#   llm = LlmService.new
#   result = llm.answer_question(
#     question: "What is Ruby?",
#     context:  "Ruby is a dynamic programming language..."
#   )
#   result[:answer] # => "Ruby is a dynamic programming language..."
#
# @example Multi-turn chat conversation
#   llm.chat(messages: [
#     { role: "user", content: "What is Rails?" },
#     { role: "assistant", content: "Rails is a web framework..." },
#     { role: "user", content: "How does it compare to Django?" }
#   ])
#
# @example Summarize a long document
#   llm.summarize(long_text, max_length: 100)
#   # => { summary: "...", model: "llama3.2:3b" }
#
# @see RagService Orchestrates retrieval + generation
# @see Clients::OllamaClient Low-level HTTP client for Ollama
class LlmService
  # @return [String] default system prompt for general assistant behaviour
  DEFAULT_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a helpful AI assistant that answers questions based on the provided context.
    Always base your answers on the context provided.
    If the context doesn't contain enough information to answer the question, say so clearly.
    Be concise, accurate, and helpful in your responses.
    When referencing information from the context, be specific about what you're citing.
  PROMPT

  # @return [String] system prompt for RAG question-answering — instructs the
  #   model to answer strictly from provided context
  RAG_SYSTEM_PROMPT = <<~PROMPT.freeze
    You are a knowledgeable AI assistant for a knowledge base system.
    Your role is to answer questions based ONLY on the provided context documents.

    Guidelines:
    1. Base your answers strictly on the provided context
    2. If the context doesn't contain relevant information, say "I don't have enough information to answer this question based on the available documents."
    3. Be concise but thorough
    4. If multiple sources contain relevant information, synthesize them coherently
    5. Do not make up or infer information not present in the context
    6. When appropriate, indicate which parts of your answer come from which sources
  PROMPT

  # @return [String] system prompt for text summarization tasks
  SUMMARIZATION_PROMPT = <<~PROMPT.freeze
    You are a skilled summarizer. Create a concise but comprehensive summary of the provided text.
    Maintain the key points and important details while reducing length.
    Use clear, professional language.
  PROMPT

  # Raised when any LLM generation call fails.
  class LlmError < StandardError; end

  # @param client [Clients::OllamaClient, nil] Ollama HTTP client;
  #   defaults to a new {Clients::OllamaClient}
  def initialize(client: nil)
    @client = client || Clients::OllamaClient.new
  end

  # Generate an answer to a question using provided context (RAG pattern).
  #
  # Builds a structured prompt that presents the context first, then the
  # question, and instructs the model to answer only from the context.
  #
  # @param question [String] the user's question
  # @param context [String] concatenated context text from retrieved chunks
  # @param system_prompt [String, nil] override the default {RAG_SYSTEM_PROMPT}
  # @param options [Hash] additional options forwarded to the Ollama client
  # @return [Hash] with keys +:answer+ (String), +:model+ (String),
  #   +:prompt_tokens+ (nil), +:completion_tokens+ (nil)
  # @raise [LlmError] if the Ollama API call fails
  #
  # @example
  #   llm.answer_question(question: "What is TDD?", context: "TDD stands for...")
  #   # => { answer: "TDD stands for...", model: "llama3.2:3b", ... }
  def answer_question(question:, context:, system_prompt: nil, **options)
    system = system_prompt || RAG_SYSTEM_PROMPT

    prompt = build_qa_prompt(question: question, context: context)

    response = @client.generate(prompt, system: system, **options)

    {
      answer: response&.strip || "",
      model: llm_model_name,
      prompt_tokens: nil, # Ollama doesn't return token counts by default
      completion_tokens: nil
    }
  rescue Clients::OllamaClient::OllamaError => e
    Rails.logger.error("LLM generation failed: #{e.message}")
    raise LlmError, "Failed to generate answer: #{e.message}"
  end

  # Generate a response using multi-turn chat format with message history.
  #
  # Supports conversational follow-ups by passing the full message history.
  # Each message is a Hash with +:role+ (+\"user\"+ or +\"assistant\"+)
  # and +:content+ keys.
  #
  # @param messages [Array<Hash>] conversation history
  #   (e.g. +[{ role: "user", content: "Hi" }]+)
  # @param system_prompt [String, nil] override the default system prompt
  # @param options [Hash] additional options forwarded to the Ollama client
  # @return [Hash] with keys +:response+ (String) and +:model+ (String)
  # @raise [LlmError] if the Ollama API call fails
  #
  # @example
  #   llm.chat(messages: [{ role: "user", content: "Hello!" }])
  #   # => { response: "Hello! How can I help?", model: "llama3.2:3b" }
  def chat(messages:, system_prompt: nil, **options)
    system = system_prompt || DEFAULT_SYSTEM_PROMPT

    response = @client.chat(messages, system: system, **options)

    {
      response: response&.strip || "",
      model: llm_model_name
    }
  rescue Clients::OllamaClient::OllamaError => e
    Rails.logger.error("LLM chat failed: #{e.message}")
    raise LlmError, "Failed to generate chat response: #{e.message}"
  end

  # Generate text from a raw prompt without structured context.
  #
  # This is the lowest-level generation method — useful for ad-hoc
  # prompts that don't fit the Q&A or chat patterns.
  #
  # @param prompt [String] the generation prompt
  # @param system_prompt [String, nil] optional system-level instructions
  # @param options [Hash] additional options forwarded to the Ollama client
  # @return [String] the generated text
  # @raise [LlmError] if the Ollama API call fails
  #
  # @example
  #   llm.generate("Explain polymorphism in one sentence.")
  #   # => "Polymorphism allows objects of different types to..."
  def generate(prompt, system_prompt: nil, **options)
    @client.generate(prompt, system: system_prompt, **options)
  rescue Clients::OllamaClient::OllamaError => e
    Rails.logger.error("LLM generation failed: #{e.message}")
    raise LlmError, "Failed to generate text: #{e.message}"
  end

  # Summarize a piece of text, optionally targeting a word count.
  #
  # @param text [String] the text to summarize
  # @param max_length [Integer, nil] approximate target word count for the
  #   summary; if nil, the model decides the length
  # @param options [Hash] additional options forwarded to the Ollama client
  # @return [Hash] with keys +:summary+ (String) and +:model+ (String)
  # @raise [LlmError] if the Ollama API call fails
  #
  # @example
  #   llm.summarize(article_text, max_length: 50)
  #   # => { summary: "The article discusses...", model: "llama3.2:3b" }
  def summarize(text, max_length: nil, **options)
    prompt = if max_length
               "Summarize the following text in approximately #{max_length} words:\n\n#{text}"
    else
               "Summarize the following text:\n\n#{text}"
    end

    response = @client.generate(prompt, system: SUMMARIZATION_PROMPT, **options)

    {
      summary: response&.strip || "",
      model: llm_model_name
    }
  rescue Clients::OllamaClient::OllamaError => e
    Rails.logger.error("LLM summarization failed: #{e.message}")
    raise LlmError, "Failed to summarize text: #{e.message}"
  end

  # Extract the most important keywords or key phrases from text.
  #
  # Prompts the LLM to return one keyword per line, then parses and
  # trims the output.
  #
  # @param text [String] the text to extract keywords from
  # @param count [Integer] maximum number of keywords to return (default: 5)
  # @param options [Hash] additional options forwarded to the Ollama client
  # @return [Hash] with keys +:keywords+ (Array<String>) and +:model+ (String)
  # @raise [LlmError] if the Ollama API call fails
  #
  # @example
  #   llm.extract_keywords("Ruby on Rails is a web framework...", count: 3)
  #   # => { keywords: ["Ruby on Rails", "web framework", "MVC"], model: "llama3.2:3b" }
  def extract_keywords(text, count: 5, **options)
    prompt = <<~PROMPT
      Extract the #{count} most important keywords or key phrases from the following text.
      Return only the keywords, one per line, without numbering or bullet points.

      Text:
      #{text}
    PROMPT

    response = @client.generate(prompt, **options)

    keywords = response&.strip&.split("\n")&.map(&:strip)&.reject(&:blank?) || []

    {
      keywords: keywords.first(count),
      model: llm_model_name
    }
  rescue Clients::OllamaClient::OllamaError => e
    Rails.logger.error("LLM keyword extraction failed: #{e.message}")
    raise LlmError, "Failed to extract keywords: #{e.message}"
  end

  # Check whether the Ollama LLM service is reachable.
  #
  # @return [Boolean] +true+ if the health check passes
  def available?
    @client.health_check
  end

  # Return the configured LLM model name from environment or default.
  #
  # @return [String] model name (e.g. +"llama3.2:3b"+)
  def llm_model_name
    ENV.fetch("OLLAMA_LLM_MODEL", "llama3.2:3b")
  end

  private

  # Build the structured prompt that presents context followed by the question.
  #
  # @param question [String] the user's question
  # @param context [String] concatenated context from retrieved chunks
  # @return [String] the formatted prompt
  def build_qa_prompt(question:, context:)
    <<~PROMPT
      Context information is provided below:
      ---
      #{context}
      ---

      Based on the context above, please answer the following question:
      #{question}

      If the context doesn't contain relevant information to answer the question, respond with:
      "I don't have enough information to answer this question based on the provided documents."
    PROMPT
  end
end

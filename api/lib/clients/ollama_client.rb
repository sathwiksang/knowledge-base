# frozen_string_literal: true

module Clients
  # Low-level HTTP client for communicating with a local Ollama server.
  #
  # == What is Ollama?
  #
  # Ollama (https://ollama.ai) is an open-source tool that lets you run
  # large language models locally. It exposes a REST API on port 11434 that
  # accepts JSON requests and returns JSON responses. Think of it as a
  # local, self-hosted alternative to the OpenAI API.
  #
  # We use Ollama for two things:
  #
  # 1. **Embeddings** — converting text into 768-dimensional float vectors
  #    using the +nomic-embed-text+ model. These vectors power semantic
  #    search via pgvector.
  # 2. **Text generation** — answering questions using the +llama3.2:3b+
  #    model in the RAG pipeline.
  #
  # == Required Ollama models
  #
  # Before the app can function, these models must be pulled into Ollama:
  #
  #   ollama pull nomic-embed-text   # ~274 MB — embedding model (768 dims)
  #   ollama pull llama3.2:3b        # ~2 GB  — language model for Q&A
  #
  # You can verify they're available with:
  #
  #   curl http://localhost:11434/api/tags
  #
  # == How this client communicates with Ollama
  #
  # All communication happens over HTTP using the +httparty+ gem:
  #
  #   ┌──────────────┐       HTTP POST (JSON)       ┌──────────────────┐
  #   │  Rails App   │  ──────────────────────────>  │  Ollama Server   │
  #   │ OllamaClient │  <──────────────────────────  │  localhost:11434 │
  #   └──────────────┘       JSON Response           └──────────────────┘
  #
  # - Embedding requests go to  +POST /api/embeddings+
  # - Generation requests go to +POST /api/generate+
  # - Chat requests go to       +POST /api/chat+
  # - Health/model listing uses +GET  /api/tags+
  #
  # All POST requests send a JSON body with +Content-Type: application/json+
  # and receive a JSON response. Streaming is disabled by default (the client
  # waits for the complete response).
  #
  # == Environment variables
  #
  # | Variable                | Default                 | Description                              |
  # |------------------------|-------------------------|------------------------------------------|
  # | +OLLAMA_BASE_URL+       | +http://localhost:11434+ | Ollama server URL                        |
  # | +OLLAMA_EMBEDDING_MODEL+| +nomic-embed-text+       | Model used for embedding generation      |
  # | +OLLAMA_LLM_MODEL+      | +llama3.2:3b+            | Model used for text generation and chat  |
  #
  # == Error handling strategy
  #
  # This client converts all possible failure modes into a small hierarchy
  # of custom exceptions so that callers can handle errors consistently:
  #
  #   OllamaError (base — catch this to handle ANY Ollama failure)
  #   ├── ConnectionError  — Ollama server is not running or unreachable
  #   ├── ModelError       — Ollama returned an error (wrong model name, etc.)
  #   └── TimeoutError     — request took too long (connection or read timeout)
  #
  # Callers like {EmbeddingService} and {LlmService} rescue these exceptions
  # and either retry (for transient errors) or wrap them in their own error
  # classes for the controller layer.
  #
  # Non-critical methods ({#health_check}, {#list_models}, {#pull_model},
  # {#model_info}) rescue all errors and return safe fallback values
  # (+false+, +[]+, +nil+) so they never crash the app.
  #
  # == Timeout strategy
  #
  # Different operations have different timeout budgets:
  #
  # - **Health checks** (5s) — should be instant; fail fast if Ollama is down
  # - **Embeddings** (60s) — typically completes in <5s, but the first request
  #   after model load can be slow
  # - **Generation/Chat** (120s) — LLM inference can take 10–60s depending on
  #   prompt length and hardware
  # - **Model pull** (3600s) — downloading a multi-GB model can take a while
  #
  # @example Basic usage
  #   client = Clients::OllamaClient.new
  #
  #   # Check if Ollama is running
  #   client.health_check # => true
  #
  #   # Generate an embedding
  #   vector = client.embed("What is Ruby?")
  #   vector.length # => 768
  #
  #   # Generate text
  #   answer = client.generate("Explain Ruby in one sentence.")
  #   # => "Ruby is a dynamic, object-oriented programming language..."
  #
  # @example Connecting to a remote Ollama instance
  #   client = Clients::OllamaClient.new(base_url: "http://gpu-server:11434")
  #
  # @example Error handling
  #   begin
  #     client.generate("Hello")
  #   rescue Clients::OllamaClient::ConnectionError
  #     puts "Ollama is not running — start it with: ollama serve"
  #   rescue Clients::OllamaClient::TimeoutError
  #     puts "Request took too long — the model may be loading"
  #   rescue Clients::OllamaClient::OllamaError => e
  #     puts "Something else went wrong: #{e.message}"
  #   end
  #
  # @see EmbeddingService Higher-level embedding interface (uses #embed)
  # @see LlmService Higher-level generation interface (uses #generate, #chat)
  # @see Api::V1::HealthController Uses #health_check and #list_models
  class OllamaClient
    # @return [String] base URL of the Ollama REST API.
    #   Override with the +OLLAMA_BASE_URL+ environment variable for
    #   remote Ollama instances (e.g. a GPU server on your network).
    BASE_URL = ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")

    # @return [Integer] timeout in seconds for LLM generation and chat
    #   requests. Set high because inference on CPU can be slow,
    #   especially for long prompts.
    DEFAULT_TIMEOUT = 120

    # @return [Integer] timeout in seconds for embedding requests.
    #   Embeddings are much faster than generation, but the first
    #   request after model load may be slow due to model warm-up.
    EMBEDDING_TIMEOUT = 60

    # @return [Integer] timeout in seconds for health checks and model
    #   listing. These should return almost instantly when Ollama is
    #   healthy, so we fail fast.
    HEALTH_TIMEOUT = 5

    # Base error class for all Ollama-related failures.
    # Catch this to handle ANY Ollama error regardless of cause.
    #
    # @example Catch-all error handling
    #   rescue Clients::OllamaClient::OllamaError => e
    #     Rails.logger.error("Ollama failed: #{e.message}")
    class OllamaError < StandardError; end

    # Raised when the Ollama server cannot be reached at all.
    #
    # Common causes:
    # - Ollama is not running (fix: +ollama serve+)
    # - Wrong +OLLAMA_BASE_URL+ (e.g. wrong port or host)
    # - Network/firewall blocking the connection
    #
    # This error is always safe to retry after the underlying issue is
    # fixed. {DocumentProcessorService} re-raises it so Solid Queue
    # can retry with exponential backoff.
    class ConnectionError < OllamaError; end

    # Raised when Ollama returns an HTTP error response (non-2xx status).
    #
    # Common causes:
    # - Requested model is not pulled (fix: +ollama pull <model>+)
    # - Malformed request payload
    # - Ollama internal error during inference
    #
    # The error message includes Ollama's error description when available.
    class ModelError < OllamaError; end

    # Raised when the HTTP request to Ollama exceeds its timeout.
    #
    # Two variants:
    # - **Connection timeout** (+Net::OpenTimeout+) — Ollama accepted the
    #   TCP connection but didn't respond in time. Often means the server
    #   is overloaded.
    # - **Read timeout** (+Net::ReadTimeout+) — Ollama started processing
    #   but didn't finish within the timeout. Common with long prompts
    #   or slow hardware.
    #
    # Safe to retry — the model may have been loading or the server may
    # have been busy with another request.
    class TimeoutError < OllamaError; end

    # Create a new Ollama client.
    #
    # @param base_url [String] the Ollama server URL
    #   (default: +OLLAMA_BASE_URL+ env var, or +http://localhost:11434+)
    #
    # @example Default (local Ollama)
    #   client = Clients::OllamaClient.new
    #
    # @example Remote server
    #   client = Clients::OllamaClient.new(base_url: "http://192.168.1.50:11434")
    def initialize(base_url: BASE_URL)
      @base_url = base_url
    end

    # Generate a vector embedding for a piece of text.
    #
    # Sends the text to Ollama's +/api/embeddings+ endpoint, which runs
    # it through the embedding model and returns a fixed-length float
    # array representing the text's semantic meaning.
    #
    # == Ollama API details
    #
    # Request:
    #   POST /api/embeddings
    #   { "model": "nomic-embed-text", "prompt": "your text here" }
    #
    # Response:
    #   { "embedding": [0.123, -0.456, ..., 0.789] }  # 768 floats
    #
    # @param text [String] the text to embed (will be sent as-is — caller
    #   is responsible for normalisation/truncation)
    # @param model [String, nil] embedding model name. Defaults to the
    #   +OLLAMA_EMBEDDING_MODEL+ env var, or +"nomic-embed-text"+.
    # @return [Array<Float>] a 768-dimensional vector. Each float
    #   represents one dimension of the text's semantic meaning.
    # @raise [ConnectionError] if Ollama is not reachable
    # @raise [ModelError] if the model is not available or Ollama returns an error
    # @raise [TimeoutError] if the request exceeds {EMBEDDING_TIMEOUT} seconds
    #
    # @example
    #   client = Clients::OllamaClient.new
    #   vector = client.embed("Ruby is a programming language")
    #   vector.length # => 768
    #   vector.first  # => 0.0234 (a float)
    def embed(text, model: nil)
      model ||= ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text")

      response = make_request(
        "/api/embeddings",
        { model: model, prompt: text },
        timeout: EMBEDDING_TIMEOUT
      )

      # Ollama returns the vector under the "embedding" key
      response["embedding"]
    end

    # Generate a text completion from a prompt.
    #
    # Sends the prompt to Ollama's +/api/generate+ endpoint for single-turn
    # text generation. This is the simpler of the two generation methods —
    # use {#chat} when you need multi-turn conversation history.
    #
    # == Ollama API details
    #
    # Request:
    #   POST /api/generate
    #   {
    #     "model": "llama3.2:3b",
    #     "prompt": "Explain Ruby in one sentence.",
    #     "system": "You are a helpful assistant.",  // optional
    #     "stream": false,                           // wait for full response
    #     "options": { "temperature": 0.7 }          // optional model params
    #   }
    #
    # Response:
    #   { "response": "Ruby is a dynamic...", "model": "llama3.2:3b", ... }
    #
    # @param prompt [String] the user prompt / question
    # @param model [String, nil] LLM model name. Defaults to the
    #   +OLLAMA_LLM_MODEL+ env var, or +"llama3.2:3b"+.
    # @param system [String, nil] optional system prompt that sets the
    #   assistant's behaviour (e.g. "Answer only from the provided context")
    # @param stream [Boolean] whether to stream the response token-by-token.
    #   Always +false+ in this app — we wait for the complete response.
    # @param options [Hash] additional Ollama model parameters (e.g.
    #   +temperature+, +top_p+, +num_predict+). Passed through as-is.
    # @return [String] the generated text response
    # @raise [ConnectionError] if Ollama is not reachable
    # @raise [ModelError] if the model is not available or generation fails
    # @raise [TimeoutError] if the request exceeds {DEFAULT_TIMEOUT} seconds
    #
    # @example Simple generation
    #   client.generate("What is 2 + 2?")
    #   # => "2 + 2 equals 4."
    #
    # @example With system prompt and options
    #   client.generate(
    #     "Explain Ruby",
    #     system: "Be extremely concise.",
    #     temperature: 0.3
    #   )
    #   # => "Dynamic OOP language focused on developer happiness."
    def generate(prompt, model: nil, system: nil, stream: false, **options)
      model ||= ENV.fetch("OLLAMA_LLM_MODEL", "llama3.2:3b")

      payload = {
        model: model,
        prompt: prompt,
        stream: stream  # false = Ollama buffers the full response before replying
      }
      payload[:system] = system if system.present?
      payload[:options] = options if options.present?

      response = make_request("/api/generate", payload)

      # Ollama returns the generated text under the "response" key
      response["response"]
    end

    # Generate a response in a multi-turn conversation.
    #
    # Unlike {#generate} which takes a single prompt, this method accepts
    # a list of messages (user/assistant turns) for conversational context.
    # The LLM sees the full conversation history and can reference earlier
    # exchanges.
    #
    # Used by {RagService#ask_with_history} for follow-up questions.
    #
    # == Ollama API details
    #
    # Request:
    #   POST /api/chat
    #   {
    #     "model": "llama3.2:3b",
    #     "messages": [
    #       { "role": "system", "content": "You are helpful." },
    #       { "role": "user", "content": "What is Ruby?" },
    #       { "role": "assistant", "content": "Ruby is a language..." },
    #       { "role": "user", "content": "How does it compare to Python?" }
    #     ],
    #     "stream": false
    #   }
    #
    # Response:
    #   { "message": { "role": "assistant", "content": "Compared to Python..." }, ... }
    #
    # @param messages [Array<Hash>] conversation history. Each hash must
    #   have +:role+ (+"user"+, +"assistant"+, or +"system"+) and
    #   +:content+ (String) keys.
    # @param model [String, nil] LLM model name (defaults to env/llama3.2:3b)
    # @param system [String, nil] system prompt. If provided, it is
    #   prepended as the first message with +role: "system"+.
    # @param stream [Boolean] always +false+ in this app
    # @param options [Hash] additional Ollama model parameters
    # @return [String] the assistant's response text
    # @raise [ConnectionError] if Ollama is not reachable
    # @raise [ModelError] if the model is not available or generation fails
    # @raise [TimeoutError] if the request exceeds {DEFAULT_TIMEOUT} seconds
    #
    # @example Single-turn chat
    #   client.chat([{ role: "user", content: "Hello!" }])
    #   # => "Hello! How can I help you today?"
    #
    # @example Multi-turn conversation with system prompt
    #   client.chat(
    #     [
    #       { role: "user", content: "What is Rails?" },
    #       { role: "assistant", content: "Rails is a web framework..." },
    #       { role: "user", content: "Who created it?" }
    #     ],
    #     system: "Be concise."
    #   )
    #   # => "David Heinemeier Hansson (DHH) created Rails in 2004."
    def chat(messages, model: nil, system: nil, stream: false, **options)
      model ||= ENV.fetch("OLLAMA_LLM_MODEL", "llama3.2:3b")

      # Prepend the system prompt as a "system" role message so Ollama
      # treats it as top-level instructions for the conversation
      all_messages = if system.present?
                       [ { role: "system", content: system } ] + messages
      else
                       messages
      end

      payload = {
        model: model,
        messages: all_messages,
        stream: stream
      }
      payload[:options] = options if options.present?

      response = make_request("/api/chat", payload)

      # Chat responses nest the content inside a "message" object
      response.dig("message", "content")
    end

    # Check whether the Ollama server is running and responding.
    #
    # Uses the +GET /api/tags+ endpoint (which lists models) as a
    # lightweight health probe. Returns a boolean — never raises.
    #
    # @return [Boolean] +true+ if Ollama responds with 2xx, +false+ otherwise
    #
    # @example
    #   if client.health_check
    #     puts "Ollama is running"
    #   else
    #     puts "Ollama is down — start it with: ollama serve"
    #   end
    def health_check
      response = HTTParty.get(
        "#{@base_url}/api/tags",
        timeout: HEALTH_TIMEOUT
      )
      response.success?
    rescue StandardError
      # Swallow all errors — health checks should never crash the caller
      false
    end

    # List all models that have been pulled into Ollama.
    #
    # == Ollama API details
    #
    # Request:
    #   GET /api/tags
    #
    # Response:
    #   { "models": [{ "name": "llama3.2:3b", ... }, { "name": "nomic-embed-text", ... }] }
    #
    # @return [Array<String>] model names (e.g. +["llama3.2:3b", "nomic-embed-text"]+).
    #   Returns an empty array if Ollama is unreachable or returns an error.
    #
    # @example
    #   client.list_models
    #   # => ["llama3.2:3b", "nomic-embed-text"]
    def list_models
      response = HTTParty.get(
        "#{@base_url}/api/tags",
        timeout: HEALTH_TIMEOUT * 2  # slightly more generous than health check
      )

      if response.success?
        # Each model object has "name", "size", "digest", etc. — we only need the name.
        response.parsed_response["models"]&.map { |m| m["name"] } || []
      else
        []
      end
    rescue StandardError => e
      Rails.logger.error("Failed to list Ollama models: #{e.message}")
      []
    end

    # Check whether a specific model has been pulled and is ready to use.
    #
    # Uses +start_with?+ matching so that +"llama3.2:3b"+ matches a
    # model listed as +"llama3.2:3b-fp16"+ (Ollama sometimes appends
    # quantisation suffixes).
    #
    # @param model_name [String] the model name to check
    #   (e.g. +"nomic-embed-text"+)
    # @return [Boolean] +true+ if the model is available
    #
    # @example
    #   client.model_available?("nomic-embed-text") # => true
    #   client.model_available?("gpt-4")            # => false
    def model_available?(model_name)
      list_models.any? { |m| m.start_with?(model_name) }
    end

    # Download (pull) a model into Ollama.
    #
    # This is a long-running operation — a 3B parameter model is ~2 GB.
    # The timeout is set to 1 hour to accommodate slow connections.
    #
    # == Ollama API details
    #
    # Request:
    #   POST /api/pull
    #   { "name": "llama3.2:3b" }
    #
    # Response (streamed progress, but we wait for completion):
    #   { "status": "success" }
    #
    # @param model_name [String] the model to pull (e.g. +"llama3.2:3b"+)
    # @return [Boolean] +true+ if the pull succeeded, +false+ on any error
    #
    # @example Pull the embedding model
    #   client.pull_model("nomic-embed-text") # => true (after download)
    def pull_model(model_name)
      response = HTTParty.post(
        "#{@base_url}/api/pull",
        body: { name: model_name }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: 3600  # 1 hour — model downloads can be very slow
      )

      response.success?
    rescue StandardError => e
      Rails.logger.error("Failed to pull Ollama model #{model_name}: #{e.message}")
      false
    end

    # Retrieve detailed information about a specific model.
    #
    # Returns model metadata including parameter count, quantisation,
    # template format, and license information.
    #
    # == Ollama API details
    #
    # Request:
    #   POST /api/show
    #   { "name": "llama3.2:3b" }
    #
    # Response:
    #   { "modelfile": "...", "parameters": "...", "template": "...", ... }
    #
    # @param model_name [String] the model to inspect
    # @return [Hash, nil] parsed JSON response with model details,
    #   or +nil+ if the model is not found or Ollama is unreachable
    #
    # @example
    #   info = client.model_info("llama3.2:3b")
    #   info["parameters"] # => "num_params 3.2B\n..."
    def model_info(model_name)
      response = HTTParty.post(
        "#{@base_url}/api/show",
        body: { name: model_name }.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: HEALTH_TIMEOUT * 2
      )

      response.parsed_response if response.success?
    rescue StandardError => e
      Rails.logger.error("Failed to get model info for #{model_name}: #{e.message}")
      nil
    end

    private

    # Central method for all POST requests to Ollama.
    #
    # Handles the full request lifecycle:
    # 1. Serialise the payload to JSON
    # 2. Send the HTTP POST with appropriate headers and timeout
    # 3. Check the HTTP status code
    # 4. Parse the JSON response
    # 5. Convert any network/parsing error into our custom exception hierarchy
    #
    # == Error mapping
    #
    # | Ruby exception            | Our exception    | Meaning                            |
    # |--------------------------|------------------|------------------------------------|
    # | +Errno::ECONNREFUSED+     | ConnectionError  | Ollama server is not running       |
    # | +Net::OpenTimeout+        | TimeoutError     | TCP connection timed out           |
    # | +Net::ReadTimeout+        | TimeoutError     | Response not received in time      |
    # | +JSON::ParserError+       | OllamaError      | Ollama returned non-JSON response  |
    # | +HTTParty::Error+         | OllamaError      | Other HTTP-level failure           |
    # | HTTP non-2xx status       | ModelError       | Ollama returned an error response  |
    #
    # @param endpoint [String] the API path (e.g. +"/api/generate"+)
    # @param payload [Hash] the request body (will be serialised to JSON)
    # @param timeout [Integer] request timeout in seconds
    # @return [Hash] the parsed JSON response
    # @raise [ConnectionError] if Ollama is unreachable
    # @raise [TimeoutError] if the request exceeds the timeout
    # @raise [ModelError] if Ollama returns a non-2xx HTTP status
    # @raise [OllamaError] if the response cannot be parsed or another HTTP error occurs
    def make_request(endpoint, payload, timeout: DEFAULT_TIMEOUT)
      # Send the POST request. HTTParty handles JSON serialisation of the
      # response body automatically via parsed_response.
      response = HTTParty.post(
        "#{@base_url}#{endpoint}",
        body: payload.to_json,
        headers: { "Content-Type" => "application/json" },
        timeout: timeout  # applies to both connection and read phases
      )

      # Check for HTTP errors (4xx, 5xx). Ollama typically returns a JSON
      # body with an "error" key explaining what went wrong.
      unless response.success?
        error_message = response.parsed_response&.dig("error") || response.body
        raise ModelError, "Ollama request failed: #{error_message}"
      end

      # Return the parsed JSON hash (HTTParty auto-parses JSON responses)
      response.parsed_response

    # --- Error mapping: convert Ruby network exceptions to our hierarchy ---

    rescue Errno::ECONNREFUSED => e
      # Ollama is not running or not listening on the expected port
      raise ConnectionError, "Cannot connect to Ollama at #{@base_url}: Connection refused. Is Ollama running?"

    rescue Net::OpenTimeout => e
      # TCP connection could not be established within the timeout.
      # The server may be overloaded or the host may be unreachable.
      raise TimeoutError, "Connection to Ollama at #{@base_url} timed out: #{e.message}"

    rescue Net::ReadTimeout => e
      # The connection was established but Ollama didn't send a response
      # in time. Common with long prompts on slow hardware.
      raise TimeoutError, "Ollama request timed out after #{timeout}s: #{e.message}"

    rescue JSON::ParserError => e
      # Ollama returned something that isn't valid JSON. This is rare
      # but can happen if Ollama crashes mid-response.
      raise OllamaError, "Invalid response from Ollama: #{e.message}"

    rescue HTTParty::Error => e
      # Catch-all for any other HTTP-level issues (redirect loops,
      # SSL errors, etc.)
      raise OllamaError, "HTTP error communicating with Ollama: #{e.message}"
    end
  end
end

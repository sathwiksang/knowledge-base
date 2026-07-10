# frozen_string_literal: true

module Api
  module V1
    # Provides health-check endpoints for monitoring the API and its
    # dependencies (database, Solid Queue, Ollama).
    #
    # All endpoints in this controller are **public** — no JWT token is
    # required. They are designed to be called by load balancers,
    # Kubernetes probes, or uptime monitors.
    #
    # == Endpoints overview
    #
    # | Endpoint                       | Purpose                                       |
    # |-------------------------------|-----------------------------------------------|
    # | GET /api/v1/health            | Full status of all services                   |
    # | GET /api/v1/health/liveness   | Lightweight "is the process alive?" check     |
    # | GET /api/v1/health/readiness  | Can the app serve traffic? (checks database)  |
    #
    # == Authentication
    # None — all endpoints are publicly accessible.
    #
    # == Rate limiting
    # None currently applied. Consider rate-limiting in production to
    # prevent abuse.
    class HealthController < BaseController
      skip_before_action :authenticate_request

      # ----------------------------------------------------------------
      # GET /api/v1/health
      # ----------------------------------------------------------------
      # Returns a comprehensive status report for all backend services:
      # API, PostgreSQL database, Solid Queue, and Ollama (LLM/embeddings).
      #
      # The top-level +status+ is +"ok"+ only when ALL services are healthy.
      # If any service is down, +status+ becomes +"degraded"+ and the HTTP
      # status code changes to 503.
      #
      # == Parameters
      # None.
      #
      # == Success response (200 OK) — all services healthy
      #   {
      #     "status": "ok",
      #     "timestamp": "2026-01-01T00:00:00Z",
      #     "services": {
      #       "api":      { "status": "ok", "message": "API is running" },
      #       "database": { "status": "ok", "adapter": "PostgreSQL", "database": "knowledge_base_development" },
      #       "queue":    { "status": "ok", "adapter": "solid_queue" },
      #       "ollama":   { "status": "ok", "base_url": "http://localhost:11434", "embedding_model": "nomic-embed-text", "llm_model": "llama3.2:3b" }
      #     },
      #     "ollama_models": ["llama3.2:3b", "nomic-embed-text"],
      #     "version": { "ruby": "3.4.8", "rails": "8.1.2" }
      #   }
      #
      # == Degraded response (503 Service Unavailable) — one or more services down
      #   {
      #     "status": "degraded",
      #     "services": {
      #       "ollama": { "status": "error", "message": "Cannot connect to Ollama", ... },
      #       ...
      #     },
      #     ...
      #   }
      #
      # == Example curl
      #   curl http://localhost:3000/api/v1/health
      def show
        ollama_client = Clients::OllamaClient.new

        status = {
          status: "ok",
          timestamp: Time.current.iso8601,
          services: {
            api: api_status,
            database: database_status,
            queue: queue_status,
            ollama: ollama_status(ollama_client)
          },
          ollama_models: ollama_models(ollama_client),
          version: {
            ruby: RUBY_VERSION,
            rails: Rails.version
          }
        }

        overall_healthy = status[:services].values.all? { |s| s[:status] == "ok" }
        status[:status] = overall_healthy ? "ok" : "degraded"

        render json: status, status: overall_healthy ? :ok : :service_unavailable
      end

      # ----------------------------------------------------------------
      # GET /api/v1/health/liveness
      # ----------------------------------------------------------------
      # Lightweight liveness probe — confirms the Rails process is running
      # and can handle HTTP requests. Does NOT check any external dependencies.
      #
      # Use this for Kubernetes liveness probes (restart the pod if this fails).
      #
      # == Parameters
      # None.
      #
      # == Success response (200 OK)
      #   { "status": "ok", "timestamp": "2026-01-01T00:00:00Z" }
      #
      # == Example curl
      #   curl http://localhost:3000/api/v1/health/liveness
      def liveness
        render json: { status: "ok", timestamp: Time.current.iso8601 }, status: :ok
      end

      # ----------------------------------------------------------------
      # GET /api/v1/health/readiness
      # ----------------------------------------------------------------
      # Readiness probe — confirms the app can serve real traffic by
      # verifying the database connection. If the database is down the
      # app is "not ready" and should be removed from the load balancer.
      #
      # Use this for Kubernetes readiness probes.
      #
      # == Parameters
      # None.
      #
      # == Success response (200 OK) — database is reachable
      #   { "status": "ready", "timestamp": "2026-01-01T00:00:00Z" }
      #
      # == Failure response (503 Service Unavailable) — database is down
      #   { "status": "not_ready", "reason": "database_unavailable" }
      #
      # == Example curl
      #   curl http://localhost:3000/api/v1/health/readiness
      def readiness
        db_ok = database_ready?

        if db_ok
          render json: { status: "ready", timestamp: Time.current.iso8601 }, status: :ok
        else
          render json: { status: "not_ready", reason: "database_unavailable" }, status: :service_unavailable
        end
      end

      private

      # @return [Hash] always reports "ok" — if the code is executing, the API is up
      def api_status
        { status: "ok", message: "API is running" }
      end

      # Check PostgreSQL connectivity and return adapter/database info.
      #
      # @return [Hash] status hash with +:status+ of "ok" or "error"
      def database_status
        if database_ready?
          {
            status: "ok",
            adapter: ActiveRecord::Base.connection.adapter_name,
            database: ActiveRecord::Base.connection.current_database
          }
        else
          { status: "error", message: "Database connection failed" }
        end
      rescue StandardError => e
        { status: "error", message: e.message }
      end

      # Execute a trivial query to verify the database connection is alive.
      # +active?+ alone can return false on idle connections, so we use
      # +SELECT 1+ for a definitive check.
      #
      # @return [Boolean]
      def database_ready?
        ActiveRecord::Base.connection.execute("SELECT 1")
        true
      rescue StandardError
        false
      end

      # Check Solid Queue's database connection.
      #
      # @return [Hash] status hash with +:status+ of "ok" or "error"
      def queue_status
        SolidQueue::Job.connection.execute("SELECT 1")
        { status: "ok", adapter: "solid_queue" }
      rescue StandardError => e
        { status: "error", message: "Queue database unavailable: #{e.message}" }
      end

      # Check Ollama connectivity and report configured models.
      #
      # @param client [Clients::OllamaClient]
      # @return [Hash] status hash with model and URL info
      def ollama_status(client)
        if client.health_check
          embedding_model = ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text")
          llm_model = ENV.fetch("OLLAMA_LLM_MODEL", "llama3.2:3b")

          {
            status: "ok",
            base_url: ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434"),
            embedding_model: embedding_model,
            llm_model: llm_model
          }
        else
          {
            status: "error",
            message: "Cannot connect to Ollama",
            base_url: ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
          }
        end
      rescue StandardError => e
        { status: "error", message: e.message }
      end

      # Fetch the list of models currently pulled in Ollama.
      #
      # @param client [Clients::OllamaClient]
      # @return [Array<String>] model names, or empty array on failure
      def ollama_models(client)
        models = client.list_models
        models.presence || []
      rescue StandardError
        []
      end
    end
  end
end

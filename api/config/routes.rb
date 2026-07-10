Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  namespace :api do
    namespace :v1 do
      # Health checks
      get "health", to: "health#show"
      get "health/liveness", to: "health#liveness"
      get "health/readiness", to: "health#readiness"

      # Authentication
      post "auth/register", to: "auth#register"
      post "auth/login", to: "auth#login"
      get "auth/profile", to: "auth#profile"
      delete "auth/logout", to: "auth#logout"

      # Knowledge Bases
      resources :knowledge_bases, only: [ :index, :show, :create, :update, :destroy ] do
        # Nested documents
        resources :documents, only: [ :index, :create ] do
          collection do
            post "batch_reprocess"
          end
        end

        # Search and Q&A endpoints (to be implemented in Phase 7 & 8)
        member do
          post "search"
          post "ask"
        end
      end

      # Shallow document routes (access without knowledge_base_id)
      resources :documents, only: [ :show, :destroy ] do
        member do
          post "reprocess"
          get "status"
        end
      end
    end
  end

  # Health check
  get "health", to: proc { [ 200, {}, [ "OK" ] ] }

  # Rails default health check
  get "up" => "rails/health#show", as: :rails_health_check
end

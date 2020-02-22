Rails.application.routes.draw do
  # AUTH STARTS
  match 'auth/:provider/callback', to: 'home#callback', via: [:get, :post]
  mount_devise_token_auth_for 'User', at: 'auth', controllers: {
    confirmations: 'devise_overrides/confirmations',
    passwords: 'devise_overrides/passwords',
    sessions: 'devise_overrides/sessions',
    token_validations: 'devise_overrides/token_validations'
  }, via: [:get, :post]

  root to: 'dashboard#index'

  get '/app', to: 'dashboard#index'
  get '/app/*params', to: 'dashboard#index'
  get '/app/settings/inboxes/new/twitter', to: 'dashboard#index', as: 'app_new_twitter_inbox'
  get '/app/settings/inboxes/new/:inbox_id/agents', to: 'dashboard#index', as: 'app_twitter_inbox_agents'

  resource :widget, only: [:show]

  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :callbacks, only: [] do
        collection do
          post :register_facebook_page
          get :register_facebook_page
          post :get_facebook_pages
          post :reauthorize_page
        end
      end

      namespace :widget do
        resources :messages, only: [:index, :create, :update]
        resources :inboxes, only: [:create, :update]
        resources :inbox_members, only: [:index]
      end

      namespace :actions do
        resource :contact_merge, only: [:create]
      end

      namespace :inbox do
        resources :webhooks, except: [:show]
      end

      resource :profile, only: [:show, :update]
      resources :accounts, only: [:create]
      resources :inboxes, only: [:index, :destroy, :update]
      resources :agents, except: [:show, :edit, :new]
      resources :labels, only: [:index] do
        collection do
          get :most_used
        end
      end
      resources :canned_responses, except: [:show, :edit, :new]
      resources :inbox_members, only: [:create, :show], param: :inbox_id
      resources :facebook_indicators, only: [] do
        collection do
          post :mark_seen
          post :typing_on
          post :typing_off
        end
      end

      resources :reports, only: [] do
        collection do
          get :account
          get :agent
        end
        member do
          get :account_summary
          get :agent_summary
        end
      end

      resources :conversations, only: [:index, :show] do
        scope module: :conversations do # for nested controller
          resources :messages, only: [:create]
          resources :assignments, only: [:create]
          resources :labels, only: [:create, :index]
        end
        member do
          post :toggle_status
          post :update_last_seen
        end
      end

      resources :contacts, only: [:index, :show, :update, :create] do
        scope module: :contacts do
          resources :conversations, only: [:index]
        end
      end

      # this block is only required if subscription via chargebee is enabled
      resources :subscriptions, only: [:index] do
        collection do
          get :summary
        end
      end

      resources :webhooks, only: [] do
        collection do
          post :chargebee
        end
      end
    end
  end

  namespace :twitter do
    resource :authorization, only: [:create]
    resource :callback, only: [:show]
  end

  # Used in mailer templates
  resource :app, only: [:index] do
    resources :conversations, only: [:show]
  end

  mount Facebook::Messenger::Server, at: 'bot'
  get 'webhooks/twitter', to: 'api/v1/webhooks#twitter_crc'
  post 'webhooks/twitter', to: 'api/v1/webhooks#twitter_events'

  post '/webhooks/telegram/:account_id/:inbox_id' => 'home#telegram'

  # Routes for testing
  resources :widget_tests, only: [:index] unless Rails.env.production?

  # ----------------------------------------------------------------------
  # Internal Monitoring Routes
  require 'sidekiq/web'

  scope :monitoring do
    # Sidekiq should use basic auth in production environment
    if Rails.env.production?
      Sidekiq::Web.use Rack::Auth::Basic do |username, password|
        ENV['SIDEKIQ_AUTH_USERNAME'] &&
          ENV['SIDEKIQ_AUTH_PASSWORD'] &&
          ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(username),
                                                      ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_AUTH_USERNAME'])) &&
          ActiveSupport::SecurityUtils.secure_compare(::Digest::SHA256.hexdigest(password),
                                                      ::Digest::SHA256.hexdigest(ENV['SIDEKIQ_AUTH_PASSWORD']))
      end
    end

    mount Sidekiq::Web, at: '/sidekiq'
  end
  # ----------------------------------------------------------------------

  # Routes for swagger docs
  get '/swagger/*path', to: 'swagger#respond'
  get '/swagger', to: 'swagger#respond'
end

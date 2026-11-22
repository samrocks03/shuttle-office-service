# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'

  get 'up', to: proc { [200, {}, ['OK']] }

  namespace 'api' do
    namespace 'v1' do
      # Authentication
      post '/login', to: 'auth#login'
      post '/register', to: 'auth#register'
      delete '/logout', to: 'auth#logout'

      # Resources
      resources :roles, constraints: { format: :json }
      resources :companies, constraints: { format: :json }
      resources :buses, constraints: { format: :json }
      resources :users, constraints: { format: :json }
      resources :schedules, constraints: { format: :json }
      resources :reservations, only: %i[index show create destroy], constraints: { format: :json }
      get '/reservations/:id/payment', to: 'reservations#payment_status', constraints: { format: :json }
      post '/reservations/:id/payment', to: 'reservations#retry_payment', constraints: { format: :json }

      # Routing admin: cities and stops (employees read, admins write), distances and fares (admins)
      resources :cities, only: %i[index show], constraints: { format: :json } do
        resources :stops, constraints: { format: :json }
      end
      resources :stop_distances, only: %i[index update], constraints: { format: :json }
      resources :fare_tables, only: %i[index show], constraints: { format: :json }

      # Payment gateway webhooks (signature-checked, no JWT)
      post '/webhooks/hyperswitch', to: 'webhooks#hyperswitch'
    end
  end
end

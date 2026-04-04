# frozen_string_literal: true

Rails.application.routes.draw do
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  get 'up' => 'rails/health#show', as: :rails_health_check

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
    end
  end
end

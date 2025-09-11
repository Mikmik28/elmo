Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    sessions: "users/sessions",
    confirmations: "users/confirmations",
    passwords: "users/passwords",
    unlocks: "users/unlocks"
  }

  # Two-Factor Authentication routes
  resource :two_factor, only: [ :show, :create, :destroy ], controller: "two_factor" do
    get :backup_codes
    post :regenerate_backup_codes
  end

  # Admin routes
  namespace :admin do
    root "dashboard#index"
    get "dashboard", to: "dashboard#index"

    resources :kyc_reviews, only: [ :index, :show ] do
      member do
        patch :approve
        patch :reject
      end
    end
  end

  # KYC routes
  resource :kyc, only: [ :show, :new, :create ], controller: "kyc/submissions" do
    post :simulate_decision, on: :member
  end

  # Credit scoring preview routes
  get "scoring/preview", to: "scoring/previews#show", as: :scoring_preview
  post "scoring/recompute", to: "scoring/previews#create", as: :scoring_recompute

  # Letter Opener routes (development only)
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "leads#index"

  get "gmail/oauth/connect", to: "gmail_oauth#connect", as: :gmail_oauth_connect
  get "gmail/oauth/callback", to: "gmail_oauth#callback", as: :gmail_oauth_callback

  resources :leads, only: [ :index, :show ] do
    collection do
      post :discover
      delete :bulk_destroy
      post :bulk_send_pitch
    end
    member do
      post :generate_pitch
      post :find_email
      patch :update_email
      post :retry
    end
  end
end

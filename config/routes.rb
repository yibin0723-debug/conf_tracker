Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token, only: %i[new create edit update]
  resource :registration, only: %i[new create]

  # 固定路径必须放在 /conferences/:id 前
  get "conferences/hub",
      to: "frontend#conferences_hub",
      as: :conferences_hub

  get "admin/spa",
      to: "frontend#admin_spa",
      as: :admin_spa

  resources :conferences do
    resource :bookmark, only: :create
  end

  resources :bookmarks, only: %i[index destroy]

  namespace :api do
    resources :conferences, only: :index

    namespace :admin do
      resources :conferences, only: %i[index create update destroy]
    end
  end

  root "conferences#index"
end
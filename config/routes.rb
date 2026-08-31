Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :passwords, param: :token

  get "up" => "health#show", as: :rails_health_check

  resources :assets, only: %i[index show]
  resources :backtest_runs, only: %i[index new create show destroy]

  namespace :market_data do
    resources :imports, only: %i[create]
  end

  root "dashboard#index"
end

# frozen_string_literal: true

Rails.application.routes.draw do
  root "home#index"

  resources :products, only: %i[index show]
  resources :categories, only: :show
  resource :cart, only: :show do
    post :add
    patch :update
    delete :remove
    post :checkout
  end

  resource :session, only: %i[new create destroy]
  resources :users, only: %i[new create]

  get "ofertas", to: "products#index", defaults: { offer: "true" }
  get "vender", to: "home#sell"
  get "ajuda", to: "home#help"
end

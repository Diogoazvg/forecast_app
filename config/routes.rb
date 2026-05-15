Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html
  resources :forecasts, only: %i[index create]

  root "forecasts#index"
end

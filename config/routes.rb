Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  # get '/init', to: 'auto_test#system_initializer'
  post '/create_auto_test_point', to: 'auto_test#create_auto_test_point'
  post '/start_auto_test', to: 'auto_test#start_auto_test'
end

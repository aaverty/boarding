Rails.application.routes.draw do
  root 'invite#index'

  post '/submit' => 'invite#submit'

  post '/addTester' => 'api#addTester'
end

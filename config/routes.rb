Rails.application.routes.draw do
  devise_for :users
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  # root 'welcome#index'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'
  root :to => "application#tweets"
  post '/gmail_inbound' => 'application#gmail_inbound'
  post '/new_tweet' => 'application#new_tweet'
  post '/send_to_telegram' => 'application#send_to_telegram'
  get '/create_event' => 'application#create_event'
  post '/flock_events' => 'application#flock_events'
  get '/flock_events' => 'application#flock_events'
  get '/flock_landing' => 'application#flock_landing'
  get '/file' => 'application#file'
  get '/drive' => 'application#drive'
  get '/change_visibility' => 'application#change_visibility'
  get '/trends' => 'application#trends'
  post '/save_reaction' => 'application#save_reaction'
  get '/tweets' => 'application#tweets'
  get '/live_feed' => 'application#live_feed'
  get '/archive' => 'application#archive'
  get '/go_live' => 'application#go_live'
  post '/go_live_submit' => 'application#go_live_submit'
  get '/my_tweets' => 'application#my_tweets'
  get '/replyModal' => 'application#replyModal'
  get '/submit_reply' => 'application#submit_reply'
  get '/agenda' => 'application#agenda'
  get '/attach' => 'application#attach'
  get '/download' => 'application#download'
  get '/connect/goodreads' => 'application#connect_goodreads'
  get '/connect/google' => 'application#connect_google'
  get '/oauth/callback/goodreads' => 'application#oauth_callback_goodreads'
  get '/oauth2/callback/google' => 'application#oauth2_callback_google'
  get '/oauth2callback' => 'application#oauth2_callback_google'
  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products
  post 'youtube/liked' => 'application#youtube_liked'
  # Example resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end

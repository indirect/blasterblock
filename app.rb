require "dotenv"
require "omniauth-twitter"
require "sinatra"
require "dotenv/load"

configure do
  enable :sessions

  use OmniAuth::Builder do
    provider :twitter, ENV.fetch("CONSUMER_KEY"), ENV.fetch("CONSUMER_SECRET")
  end
end

helpers do
  # define a current_user method, so we can be sure if an user is authenticated
  def current_user
    !session[:uid].nil?
  end
end

before do
  # we do not want to redirect to twitter when the path info starts
  # with /auth/
  pass if request.path_info =~ /^\/auth\//

  # /auth/twitter is captured by omniauth:
  # when the path info matches /auth/twitter, omniauth will redirect to twitter
  redirect to("/auth/twitter") unless current_user
end

get "/auth/twitter/callback" do
  # probably you will need to create a user in the database too...
  session[:uid] = env["omniauth.auth"]["uid"]
  # this is the main endpoint to your application
  redirect to("/")
end

get "/auth/failure" do
  # omniauth redirects to /auth/failure when it encounters a problem
  # so you can implement this as you please
end

get "/" do
  "Hello #{env.inspect}"
end

post "/user/:name" do
  params[:name]
end

post "/tweet/:id" do
  params[:id]
end

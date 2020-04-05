require "bundler/setup"

environment = ENV.fetch("RACK_ENV", "development")
Bundler.require(:default, environment)

configure do
  enable :sessions
  set :sessions, expire_after: 2592000
  set :session_secret, ENV.fetch("SESSION_SECRET")

  use OmniAuth::Builder do
    provider :twitter, ENV.fetch("CONSUMER_KEY"), ENV.fetch("CONSUMER_SECRET")
  end
end

helpers do

  def current_user
    !session[:uid].nil?
  end

  def h(text)
    Rack::Utils.escape_html(text)
  end

  def twitter
    @twitter ||= Twitter::REST::Client.new do |config|
      config.consumer_key        = ENV.fetch("CONSUMER_KEY")
      config.consumer_secret     = ENV.fetch("CONSUMER_SECRET")
      config.access_token        = session.fetch(:twitter).fetch(:token)
      config.access_token_secret = session.fetch(:twitter).fetch(:secret)
    end
  end

  def block_ids(ids)
    results = []

    ids.each_slice(100) do |slice|
      results << twitter.block(slice).map(&:id)
    end

    results.flatten
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
  auth = env["omniauth.auth"]
  session[:uid] = auth["uid"]
  session[:twitter] = {
    username: auth.dig("info", "nickname"),
    token: auth.dig("credentials", "token"),
    secret: auth.dig("credentials", "secret"),
  }
  logger.info env["omniauth.auth"].to_h.inspect
  redirect to("/")
end

get "/auth/failure" do
  # omniauth redirects to /auth/failure when it encounters a problem
  # so you can implement this as you please
  "oh no"
end

get "/" do
  @user = twitter.user.attrs
  erb :index
end

post "/user" do
  username = params.fetch(:name)

  ids = twitter.follower_ids(username, count: 5000)
  count = block_ids(ids).size

  flash[:notice] = "#{count} followers of @#{username} blocked"
  redirect to("/")
end

post "/tweet" do
  tweet_id = params.fetch(:id)

  ids = twitter.retweeters_ids(tweet_id, count: 5000)
  count = block_ids(ids).size

  flash[:notice] = "#{count} retweeters of tweet #{tweet_id} blocked (unfortunately the Twitter API only lets you see < 100 retweeters)"
  redirect to("/")
end

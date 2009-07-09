class HyvesController < ApplicationController

  # Put your key here (get it via http://www.hyves.nl/api/apply/)
  @@key     = 'key'
  @@secret  = 'secret'

  # This action redirects to the hyves 'authentication' page.
  def index
    methods = [
      'albums.get',
      'albums.getByUser',
      'auth.accesstoken',
      'auth.requesttoken',
      'auth.revoke',
      'auth.revokeAll',
      'auth.revokeSelf',
      'blogs.create',
      'blogs.createRespect',
      'blogs.get',
      'blogs.getByTag',
      'blogs.getByUser',
      'blogs.getComments',
      'blogs.getForFriends',
      'blogs.getRespects',
      'cities.get',
      'countries.get',
      'fancylayout.parse',
      'friends.get',
      'friends.getDistance',
      'friends.getIncomingInvitations',
      'friends.getOutgoingInvitations',
      'gadgets.create',
      'gadgets.createRespect',
      'gadgets.get',
      'gadgets.getByUser',
      'gadgets.getComments',
      'gadgets.getRespects',
      'listeners.create',
      'listeners.delete',
      'listeners.get',
      'listeners.getAll',
      'listeners.getByType',
      'media.createRespect',
      'media.get',
      'media.getAlbums',
      'media.getByAlbum',
      'media.getByTag',
      'media.getComments',
      'media.getRespects',
      'pings.get',
      'pings.getByTargetUser',
      'pings.getByUser',
      'regions.get',
      'tips.createRespect',
      'tips.get',
      'tips.getByUser',
      'tips.getCategories',
      'tips.getComments',
      'tips.getForFriends',
      'tips.getRespects',
      'users.createRespect',
      'users.get',
      'users.getByUsername',
      'users.getLoggedin',
      'users.getRespects',
      'users.getScraps',
      'users.getTestimonials',
      'users.search',
      'users.searchInFriends',
      'wwws.create',
      'wwws.get',
      'wwws.getByUser',
      'wwws.getForFriends'
      ]
    hyves = Hyves.new(@@key, @@secret, :methods => methods, :expirationtype => 'infinite')
    # Go and login on the following URL
    redirect_url = hyves.authorize_url('http://localhost:3000/hyves/return')
    session[:request_token_secret] = hyves.request_token.secret
    redirect_to redirect_url
  end

  # This action checks the authentication.
  def return
    request_token = params[:oauth_token]
    request_token_secret = session[:request_token_secret]

    # sleep(0.5) # Short sleep to make sure Hyves is ready.. (FIXME: needed?)

    begin
      hyves = Hyves.new(@@key, @@secret)
      hyves.set_request_token(request_token, request_token_secret)
      hyves.get_access_token

      if hyves.has_default_expiration?
        render :text => "Please use the checkbox! We need longer access to your Hyves account!"
        return
      end

      session[:request_token_secret] = nil # Clear the request_token_secret, we don't need it any more
      session[:access_token] = hyves.access_token.token
      session[:access_token_secret] = hyves.access_token.secret

      @response = hyves.users_get(:userid => hyves.userid)
      render :text => "Got API response: #{@response.inspect}"
    rescue HyvesException => e
      render :text => "Sorry, HyvesException occured: #{e}"
    end
  end

  # When you want this to work even when somebody has closed his
  # browser, make sure you set :session_expires => 1.year.from_now in 
  # your environment.rb
  def do_things # This can be accessed when we have returned :)
    access_token = session[:access_token]
    access_token_secret = session[:access_token_secret]
    
    begin
      hyves = Hyves.new(@@key, @@secret)
      hyves.set_access_token(access_token, access_token_secret)
      @response =  hyves.cities_get(:cityid => ['9647a30b487650e3'].join(','))
      render :text => "Got API response: #{@response.inspect}"
    rescue HyvesException => e
      render :text => "Sorry, HyvesException occured: #{e}"
    end
  end

end

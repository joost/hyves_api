class HyvesException < StandardError;end

class Hyves
  
  API_METHODS = methods = [
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

  attr_accessor :access_token, :consumer, :api_methods, :ha_fancylayout
  attr_reader :request_token
  attr_reader :ha_version, :ha_format, :key, :secret
  attr_reader :oauth_options
  
  attr_reader :userid, :expiredate
  
  # Hyves.new(consumer_key, secret)
  # A third (optional) parameter is a Hash of options:
  # * <tt>:methods</tt> - [array of methods like 'users.get'], defaults to ['users.get', 'users.getByUsername'].
  # * <tt>:ha_fancylayout</tt> - true/false, defaults to false.
  # * <tt>:expirationtype</tt> -  see hyves, defaults to 'default'.
  # * <tt>:mobile</tt> - true or false depending if you want to use the mobile Hyves pages, defaults to false.
  # * <tt>:ha_version</tt> - version of the Hyves API to connect to. Defaults to 1.0.
  # You can also re-init a session which already has a request token:
  # Hyves.new(consumer_key, secret, {:request_token => 'blbla', :request_token_secret => 'blibli'})
  def initialize(key, secret, options = {})
    options = {
        :methods => ['users.get', 'users.getByUsername'],
        :ha_fancylayout => false,
        :expirationtype => 'default' # 'infinite'
      }.merge(options) # Set defaults

    @key = key
    @secret = secret
    
    @ha_version = options.delete(:ha_version) || '1.2.1'
    @ha_format = 'xml'
    @ha_fancylayout = options.delete(:ha_fancylayout)

    default_options = '&'+serialize_options(default_request_options)

    options[:methods] = API_METHODS if options[:methods] == :all
    options[:methods] = options[:methods].join(',')
    request_token_options = '&'+serialize_options(options)

    request_token_path = '/?ha_method=auth.requesttoken'+default_options+request_token_options
    authorize_url = 'http://www.hyves.nl/api/authorize/'
    authorize_url = 'http://www.hyves.nl/mobile/api/authorize/' if options[:mobile]
    access_token_path = '/?ha_method=auth.accesstoken'+default_options
    @oauth_options = {
      :site => "http://data.hyves-api.nl",
      :request_token_path => request_token_path,
      :authorize_url => authorize_url,
      :access_token_path => access_token_path,
      :scheme => :query_string
    }

    # Set the api_methods to the ones we initialized the consumer for
    api_methods = options[:methods]

  end

  # The OAuth::Consumer for this Hyves object. Might you want to do some
  # fancy things with it.
  def consumer
    @consumer ||= OAuth::ConsumerWithHyvesExtension.new(key, secret, oauth_options)
  end

  def request_token
    @request_token ||= consumer.get_request_token
  end
  
  def set_request_token(token, secret)
    raise HyvesException, "Expected a valid token and secret, got #{token.inspect} and '#{secret.inspect}." if token.blank? || secret.blank?
    @request_token = OAuth::RequestToken.new(consumer, token, secret)
  end

  def set_access_token(token, secret)
    raise HyvesException, "Expected a valid token and secret, got #{token.inspect} and #{secret.inspect}." if token.blank? || secret.blank?
    @access_token = OAuth::AccessToken.new(consumer, token, secret)
  end

  # Gets an access token with an available request token (that is authorized).
  def get_access_token
    raise HyvesException, 'You need an request token to make get an access token' if request_token.nil?
    @access_token = request_token.get_access_token

    @userid = request_token.response["userid"]
    @expiredate = Time.at(request_token.response["expiredate"].to_i) if not request_token.response["expiredate"].nil?

    @access_token
  end
  
  # Returns if the session is infinite.
  # It checks if the expiredate is > 1 hour from now.
  # Since infite means: "Infinite token, if User accepts valid for 2 years." (see: http://trac.hyves-api.nl/hyves-api/wiki/APIMethods#methods-1.0-auth.requesttoken)
  def has_infinite_expiration?
    expiredate > Time.now+60*60
  end
  
  # Returns true if the session has default expiration.
  def has_default_expiration?
    expiredate < Time.now+60*60+60 # The last 60seconds are for safety
  end

  # Sends a default request to the API.
  def request(options)
    raise HyvesException, 'You need an access token to make requests' if access_token.nil?
    options = default_request_options.merge(options)
    access_token.post('/', options)
  end
  
  # Go to this URL to authorize a request token and receive an access token.
  # Supply the url to return to: h.authorize_url('http://www.returnhere.com/hyves')
  def authorize_url(callback_url)
    request_token.authorize_url+'&oauth_callback='+CGI.escape(callback_url)
  end

private

  # This are the options that are needed for every request to Hyves.
  # They are returned as a Hash.
  def default_request_options
    {'ha_version' => ha_version, 'ha_format' => ha_format, 'ha_fancylayout' => ha_fancylayout}
  end

  # This method defines all api calls. Use it as follows:
  # hyves.users_get(:userid => 'someuserid')
  # hyves.cities_get(:cityid => ['b809b7cb9e452a6b', 'b4d2e84c967f0ed0'].join(','))
  # For all methods see: http://trac.hyves-api.nl/hyves-api/wiki/APIMethods
  def method_missing(meth, *args)
    hyves_method = meth.to_s.gsub('_', '.')
    options = {:ha_method => hyves_method}
    options.merge!(args.first) if args.first.is_a?(Hash)
    hyves_log('Hyves', "Sent request: #{options.inspect}")
    response = request(options)
    hyves_log('Hyves', "Got response: #{response.inspect}")
    return response
  end

  # Serializes a Hash to become URL options.
  def serialize_options(options)
    options.collect {|k,v| "#{k}=#{CGI.escape(v.to_s)}"}.join('&')
  end

  def hyves_log(message, dump = nil, loglevel = Logger::DEBUG)
    message_color, dump_color = "4;31;1", "0" # 0;1 = Bold
    info = "  \e[#{message_color}m#{message}\e[0m   "
    info << "\e[#{dump_color}m#{dump}\e[0m" if dump
    RAILS_DEFAULT_LOGGER.add(loglevel, info)
  end

end
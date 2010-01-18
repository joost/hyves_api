require 'xmlsimple' # gem install xml-simple
# We need to mod the oAuth gem (at least v0.2.2) a bit to use it with the Hyves API v1.0

module OAuth
  
  class RequestToken<ConsumerToken
    # This makes we can actually access the response included with the Access Token.
    # Since Hyves puts the userid in there.. and we want to grab that!
    attr_accessor :response
    
    def get_access_token(options={})
      @response=consumer.token_request(consumer.http_method,consumer.access_token_path,self,options)
      OAuth::AccessToken.new(consumer,@response[:oauth_token],@response[:oauth_token_secret])
    end
    
  end

end

module OAuth::Client
  class Helper

    # The following hack makes sure we DO NOT send a 'token' parameter
    # to Hyves when it it empty. Otherwise we get 401 "Unauthorized" (error 17, OAuth token is invalid)
    alias :oauth_parameters_before_hyves_hack :oauth_parameters
    def oauth_parameters
      params = oauth_parameters_before_hyves_hack
      token = params.delete('oauth_token')
      params.merge!('oauth_token' => options[:token].token) unless token.nil? || token.empty?
      return params
    end

  end
end

module OAuth
  class ConsumerWithHyvesExtension < Consumer

    def get_request_token(request_options = {}, *arguments)
      # if oauth_callback wasn't provided, it is assumed that oauth_verifiers
      # will be exchanged out of band
      request_options.delete(:oauth_callback) # No callback expected

      response = token_request(http_method, (request_token_url? ? request_token_url : request_token_path), nil, request_options, *arguments)
      # raise response.to_yaml
      OAuth::RequestToken.from_hash(self, response)
    end
    # We use XMLSimple to parse the response of Hyves. oAuth did not work out-of-the-box.
    # This is because Hyves uses some own kind of format (see: https://trac.hyves-api.nl/hyves-api/wiki/APIoAuth).
    # This can be overcome by using stric_oauth_spec_response=true in the request.
    def token_request(http_method,path,token=nil,request_options={},*arguments)
      response=request(http_method,path,token,request_options,*arguments)
    end

    def request(http_method,path, token=nil,request_options={},*arguments)
      request = create_signed_request(http_method,path,token,request_options,*arguments)
      response = http.request(request)
      if response.code=="200"
        HashWithIndifferentAccess.new(XmlSimple.xml_in(response.body, { 'ForceArray' => false }))
        # FIXME: Should the following correctly parse JSON?
        # CGI.parse(response.body).inject({}){|h,(k,v)| h[k.to_sym]=v.first;h}
      else
        # We've got an Error. Try to see if we can show something usefull or raise the Http error.
        parsed_response = HashWithIndifferentAccess.new(XmlSimple.xml_in(response.body, { 'ForceArray' => false }))
        if parsed_response && parsed_response['error_code']
          raise HyvesException, "#{parsed_response['error_message']} (error_code: #{parsed_response['error_code']})"
        else
          response.error!
        end
      end
    end

  end
end


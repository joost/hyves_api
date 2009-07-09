# The HyvesApi module extends ActiveRecord::Base with some class methods to make
# a model a Hyves User or Hyves bloggable.
#
# For example:
#  class HyvesUser < User
#    acts_as_hyves_user
#  end
#
# This requires the following columns in your database:
# - hyves_id
# - hyves_access_token
# - hyves_access_token_secret
module HyvesRailsExtensions

  module ClassMethods
    
    def acts_as_hyves_user
      include ActsAsHyvesUser
      validates_uniqueness_of   :hyves_id, :case_sensitive => false
    end
    
    def acts_as_hyves_bloggable(options = {})
      include ActsAsHyvesBloggable
      options.reverse_merge!({:put_on_hyves_blog => '1'})
      
      write_inheritable_attribute(:acts_as_hyves_bloggable_options, options)
      class_inheritable_reader :acts_as_hyves_bloggable_options
      # after_create :post_on_hyves_blog
    end
    
  end

  module ActsAsHyvesUser

    # Updates this user object with the values coming from Hyves.
    # Eg. {"mediaid"=>"66b2ae87ce0c6282", "nickname"=>"Joost", "friendscount"=>"18", "url"=>"http://joostmenso.hyves.nl/", "firstname"=>"Joost", "lastname"=>"Hietbrink", "gender"=>"male", "userid"=>"c26fbee3459914f0", "countryid"=>"74670144e53fffcb", "birthday"=>{"month"=>"9", "day"=>"2", "year"=>"1980", "age"=>"27"}, "created"=>"1122984883", "profilevisible"=>"true", "cityid"=>"9647a30b487650e3"}
    def update_from_hyves(hyves_user)
      # FIXME: Make this better
      hyves_nickname = hyves_user[:nickname]
      hyves_nickname = hyves_user[:firstname] if hyves_nickname.blank?
      hyves_nickname = hyves_user[:lastname] if hyves_nickname.blank?
      hyves_nickname = $1 if hyves_nickname.blank? || hyves_user[:url] =~ /https?\:\/\/([\w-]+)\./
      self.nickname = hyves_nickname
      # Do not set_avatar here since it will give a stack overflow. self -> avatar -> creator -> self ..
    end

    # Sets the users avatar to match the one on Hyves.
    # FIXME: Make avatars work with weird user nicknames.
    def set_avatar(mediaid)
      response = hyves_api.media_get(:mediaid => [mediaid].join(','))
      if response[:media] && response[:media][:image_fullscreen] && response[:media][:image_fullscreen][:src]
        self.build_avatar(:image_file_url => response[:media][:image_fullscreen][:src], :imageable => self)
        self.save # Calling self.avatar.save won't save a correct avatar_id
      end
    end

    # Returns true if the Hyves authentication / authorization
    # token of this user is expired.
    def authentication_expired?
      Time.now > (self.hyves_expires_at || 0)
    end

    # Checks (by sending an API request) if this
    # user is authenticated.
    def authenticated?
      hyves_api.users_get(:userid => hyves_id)
      true
    rescue HyvesException => e
      false
    end

    def password_required?
      false
    end

  private
    def hyves_api
      @hyves ||= Hyves.new(Hyves::HYVES_KEY, Hyves::HYVES_SECRET)
      @hyves.set_access_token(self.hyves_access_token, self.hyves_access_token_secret)
      @hyves
    end
  
  end

  module ControllerExtensions
    
    def self.included(base)
      base.helper_method :hyves_logged_in?
    end

    # Returns true if a user is logged_in and is a HyvesUser.
    def hyves_logged_in?
      logged_in? && User.is_a?(HyvesUser)
    end

  # Before Filter methods:

    def hyves_login_required
      hyves_logged_in? || hyves_access_denied
    end
    
    def non_expired_hyves_login_required
      hyves_logged_in? && !current_user.authentication_expired? || hyves_access_denied
    end
    
    def non_expired_hyves_login_required_if_logged_in
      if hyves_logged_in?
        non_expired_hyves_login_required
      end
    end
    
  private
    # This is called when the user is denied access.
    # It uses the AuthenticatedSystem access_denied method.
    def hyves_access_denied
      access_denied
    end
    
  end

  # Usage:
  # In your model use 'acts_as_hyves_bloggable'.
  # You can now use a checkbox named 'put_on_hyves_blog'.
  # When the model is saved a Blog entry is created (after_create filter).
  # This uses the method
  # - hyves_blog_title
  # - hyves_blog_body
  # to create the blog item.
  #
  # acts_as_hyves_bloggable methods
  # 
  #   def hyves_blog_title
  #     self.title
  #   end
  # 
  #   def hyves_blog_body
  #     ("My review of %s on [url=http://www.yelloyello.com]YelloYello[/url]:\n")+ # / link_to(self.reviewable))+
  #     self.text.auto_hyves_link_urls
  #   end
  module ActsAsHyvesBloggable
  
    attr_writer :put_on_hyves_blog
    def put_on_hyves_blog
      @put_on_hyves_blog || acts_as_hyves_bloggable_options[:put_on_hyves_blog]
    end
    
    def put_on_hyves_blog?
      @put_on_hyves_blog == '1' 
    end

    # TODO: This 'in Model' way is impossible since we can't create links.
    #
    # def hyves_blog_title
    #   raise 'Overwrite this method in your Model class'
    # end
    # 
    # def hyves_blog_body
    #   raise 'Overwrite this method in your Model class'
    # end
    # 
    # def post_on_hyves_blog
    #   if (put_on_hyves_blog? && self.creator.is_a?(HyvesUser))
    #     begin
    #       @response = self.creator.hyves_api.blogs_create(:title => self.hyves_blog_title, :body => self.hyves_blog_body, :visibility => 'superpublic')
    #        # "Got API response: #{@response.inspect}"
    #     rescue HyvesException => e
    #        # "Sorry, HyvesException occured: #{e}"
    #     end
    #   end
    # end
  
  end

end
ActiveRecord::Base.send :extend, HyvesRailsExtensions::ClassMethods
ActionController::Base.send :include, HyvesRailsExtensions::ControllerExtensions
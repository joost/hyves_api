require 'rubygems'

puts "WARNING: We're going to f*ck up OAuth to be compatible with the Hyves API. Other things might NOT work anymore." if defined? OAuth
require 'oauth'
require 'oauth/consumer'

$LOAD_PATH << File.expand_path(File.dirname(__FILE__) + "/lib")
require 'hyves'
require 'oauth_hacks'
# HashWithIndifferentAccess is not needed when is used as a Rails plugin
require 'indifferent_access' if not defined? HashWithIndifferentAccess

require 'hyves_rails_extensions'
require 'hyves_base_extensions'
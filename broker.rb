require 'sinatra'
require 'json'
require 'yaml'

class ServiceBroker < Sinatra::Base
  use Rack::Auth::Basic do |username, password|
    username == self.app_settings["basic_auth"]["username"] and password == self.app_settings["basic_auth"]["password"]
  end

  get "/v2/catalog" do
    content_type :json

    self.class.app_settings["catalog"].to_json
  end

  def self.app_settings
    @app_settings ||= YAML.load_file('settings.yml')
  end

end

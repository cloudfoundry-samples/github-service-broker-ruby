require 'sinatra'
require 'json'
require 'yaml'

class ServiceBroker < Sinatra::Base

  use Rack::Auth::Basic do |username, password|
    username == self.app_settings["basic_auth"]["username"] and password == self.app_settings["basic_auth"]["password"]
  end

  get "/v2/catalog" do
    content_type :json

    description = {
      "services" => [{
        "id" => "github-repo",
        "name"=> " GitHub repository service",
        "description"=> "An instance of this service provides a repository which an app can write to and read from.",
        "bindable" => true,
        "plans"=> [{
          "id"=> "public-repo",
          "name"=> "free",
          "description"=> "All repositories are public."
        }]
      }]
    }

    description.to_json
  end

  def self.app_settings
    YAML.load_file('settings.yml')
  end
end

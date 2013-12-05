require 'sinatra'
require 'json'

class ServiceBroker < Sinatra::Base
  use Rack::Auth::Basic do |username, password|
    username == 'admin' and password == 'password'
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
end

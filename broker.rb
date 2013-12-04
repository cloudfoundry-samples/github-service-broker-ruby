require 'sinatra'
require 'json'

class ServiceBroker < Sinatra::Base
  get "/v2/catalog" do
    content_type :json

    description = {
      "services" => [{
        "id" => "github-repo",
        "name"=> " GitHub repository service",
        "description"=> "An instance of this service provides a repository which an app write to and read from",
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

require 'sinatra'
require 'json'

class ServiceBroker < Sinatra::Base
  get "/v2/catalog" do
    content_type :json

    description = {
      "services" => [{
        "id" => "echo-service",
        "name"=> "Echo Service",
        "description"=> "A service that echoes back the body of each web request it receives",
        "plans"=> [{
          "id"=> "free-plan",
          "name"=> "free",
          "description"=> "Echoing does not cost money."
        },{
          "id"=> "expensive-plan",
          "name"=> "expensive",
          "description"=> "Echoing costs lots of money."
        }]
      }]
    }

    description.to_json
  end
end

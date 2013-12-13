require 'sinatra'
require 'json'

class ServiceConsumerApp < Sinatra::Base

  #declare the routes used by the app

  get "/" do
    content_type "text/plain"
    messages
  end

  get "/env" do
    content_type "text/plain"

    #TODO: do we need to check if VCAP_SERVICES does not exist?
    response_body = "VCAP_SERVICES = \n#{ENV["VCAP_SERVICES"]}"
    response_body << messages
    response_body
  end

  # helper methods
  private

  def messages
    result = ""
    result << "#{no_bindings_exist_message}" unless bindings_exist
    result << "\n\nAfter binding or unbinding any service instances, restart this application with 'cf restart <appname>'."
    result
  end

  def bindings_exist
    JSON.parse(ENV["VCAP_SERVICES"]).keys.any? { |key|
      key.match service_name
    }
  end

  def no_bindings_exist_message
    "\n\nYou haven't bound any instances of the #{service_name} service."
  end

  def service_name
    "github-repo"
  end
end

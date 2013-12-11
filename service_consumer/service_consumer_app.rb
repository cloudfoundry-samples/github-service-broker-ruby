require 'sinatra'

class ServiceConsumerApp < Sinatra::Base

  #declare the routes used by the app

  get "/" do
    content_type "text/plain"
    no_bindings_exist_message
  end

  get "/env" do
    content_type "text/plain"

    if ENV["VCAP_SERVICES"].nil?
      response_body = "The environment variable VCAP_SERVICES is not found."
    else
      response_body = "VCAP_SERVICES = \n#{ENV["VCAP_SERVICES"]}"
      response_body << "\n\n#{no_bindings_exist_message}"
    end
    response_body
  end

  # helper methods
  private

  def no_bindings_exist_message
    "You haven't bound any instances of the Github Repo service.\n\nAfter binding a service instance, restart this application with 'cf restart <appname>'."
  end
end

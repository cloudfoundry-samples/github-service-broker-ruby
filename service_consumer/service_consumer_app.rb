require 'sinatra'

class ServiceConsumerApp < Sinatra::Base

  #declare the routes used by the app

  get "/" do
    content_type "text/plain"

    "You haven't bound any instances of the Github Repo service.\n\nAfter binding a service instance, restart this application with 'cf restart <appname>'"
  end
end

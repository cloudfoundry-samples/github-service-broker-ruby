require 'sinatra'
require 'json'
require 'yaml'
require_relative 'github_service'

class ServiceBroker < Sinatra::Base
  use Rack::Auth::Basic do |username, password|
    username == self.app_settings["basic_auth"]["username"] and password == self.app_settings["basic_auth"]["password"]
  end

  get "/v2/catalog" do
    content_type :json

    self.class.app_settings["catalog"].to_json
  end

  get "/v2/service_instances/:id" do
    status 201

    {"dashboard_url" => github_service.create_repo(params[:id])}.to_json
  end

  def self.app_settings
    @app_settings ||= YAML.load_file('settings.yml')
  end

  def github_service
    GithubService.new(self.class.app_settings["github"]["username"], self.class.app_settings["github"]["password"])
  end
end

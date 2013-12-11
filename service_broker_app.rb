require 'sinatra'
require 'json'
require 'yaml'
require_relative 'models/github_service'

class ServiceBrokerApp < Sinatra::Base
  #configure the Sinatra app
  use Rack::Auth::Basic do |username, password|
    credentials = self.app_settings.fetch("basic_auth")
    username == credentials.fetch("username") and password == credentials.fetch("password")
  end

  #declare the routes used by the app
  get "/v2/catalog" do
    content_type :json

    self.class.app_settings.fetch("catalog").to_json
  end

  put "/v2/service_instances/:id" do
    content_type :json

    repo_name = params[:id]

    begin
      repo_url = github_service.create_repo(repo_name)
      status 201
      {"dashboard_url" => repo_url}.to_json
    rescue GithubService::RepoAlreadyExistsError
      status 409
      {"description" => "The repo #{repo_name} already exists in the GitHub account"}.to_json
    rescue GithubService::GithubUnreachableError
      status 504
      {"description" => "GitHub is not reachable"}.to_json
    rescue GithubService::GithubError => e
      status 502
      {"description" => e.message}.to_json
    end
  end

  #helper methods
  private

  def self.app_settings
    settings_filename = SETTINGS_FILENAME || 'config/settings.yml'
    @app_settings ||= YAML.load_file(settings_filename)
  end

  def github_service
    github_credentials = self.class.app_settings.fetch("github")
    GithubService.new(github_credentials.fetch("username"), github_credentials.fetch("password"))
  end
end

require 'sinatra'
require 'json'
require 'yaml'
require_relative 'models/github_service_helper'

class ServiceBrokerApp < Sinatra::Base
  #configure the Sinatra app
  use Rack::Auth::Basic do |username, password|
    credentials = self.app_settings.fetch("basic_auth")
    username == credentials.fetch("username") and password == credentials.fetch("password")
  end

  #declare the routes used by the app

  # CATALOG
  get "/v2/catalog" do
    content_type :json

    self.class.app_settings.fetch("catalog").to_json
  end

  # PROVISION
  put "/v2/service_instances/:id" do |id|
    content_type :json

    repo_name = id

    begin
      repo_url = github_service.create_repo(repo_name)
      status 201
      {"dashboard_url" => repo_url}.to_json
    rescue GithubServiceHelper::RepoAlreadyExistsError
      status 409
      {"description" => "The repo #{repo_name} already exists in the GitHub account"}.to_json
    rescue GithubServiceHelper::GithubUnreachableError
      status 504
      {"description" => "GitHub is not reachable"}.to_json
    rescue GithubServiceHelper::GithubError => e
      status 502
      {"description" => e.message}.to_json
    end
  end

  # BIND
  put '/v2/service_instances/:instance_id/service_bindings/:id' do |instance_id, id|
    content_type :json

    begin
      credentials = github_service.create_github_deploy_key(repo_name: instance_id, deploy_key_title: id)
      status 201
      {"credentials" => credentials}.to_json
    rescue GithubServiceHelper::BindingAlreadyExistsError
      status 409
      {"description" => "The binding #{id} already exists"}.to_json
    rescue GithubServiceHelper::GithubUnreachableError
      status 504
      {"description" => "GitHub is not reachable"}.to_json
    rescue GithubServiceHelper::GithubError => e
      status 502
      {"description" => e.message}.to_json
    end
  end

  # UNBIND
  delete '/v2/service_instances/:instance_id/service_bindings/:id' do |instance_id, id|
    content_type :json

    begin
      if github_service.remove_github_deploy_key(repo_name: instance_id, deploy_key_title: id)
        status 200
      else
        status 410
      end
      {}.to_json
    rescue GithubServiceHelper::GithubUnreachableError
      status 504
      {"description" => "GitHub is not reachable"}.to_json
    rescue GithubServiceHelper::GithubError => e
      status 502
      {"description" => e.message}.to_json
    end
  end

  #helper methods
  private

  def self.app_settings
    settings_filename = defined?(SETTINGS_FILENAME) ? SETTINGS_FILENAME : 'config/settings.yml'
    @app_settings ||= YAML.load_file(settings_filename)
  end

  def github_service
    github_credentials = self.class.app_settings.fetch("github")
    GithubServiceHelper.new(github_credentials.fetch("username"), github_credentials.fetch("password"))
  end
end

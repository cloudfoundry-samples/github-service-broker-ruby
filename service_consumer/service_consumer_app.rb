require 'sinatra'
require 'json'
require 'rack-flash'
require_relative 'models/github_repo_helper'

class ServiceConsumerApp < Sinatra::Base

  # app configuration
  enable :sessions
  use Rack::Flash, :sweep => true

  #declare the routes used by the app
  get "/" do
    credentials_list = credentials_of_all_repos
    repo_uris = credentials_list.map { |c| c["uri"]} unless credentials_list.nil?

    erb :index, locals: { repo_uris: repo_uris, messages: messages }
  end

  get "/env" do
    content_type "text/plain"

    response_body = "VCAP_SERVICES = \n#{ENV["VCAP_SERVICES"]}"
    response_body << messages
    response_body
  end

  post "/create_commit" do
    github_repo_helper = GithubRepoHelper.new(credentials_of_all_repos)
    repo_uri = params[:repo_uri]

    begin
      github_repo_helper.create_commit(repo_uri)
      flash[:notice] = "Successfully pushed commit to #{repo_uri}"
    rescue GithubRepoHelper::RepoCredentialsMissingError
      flash[:notice] = "Unable to create the commit, repo credentials in VCAP_SERVICES are invalid for: #{repo_uri}"
    rescue GithubRepoHelper::RepoUriNotFoundError
      flash[:notice] =  "Unable to create the commit, repo not found: #{repo_uri}"
    rescue GithubRepoHelper::CreateCommitError
      flash[:notice] = "Creating the commit failed. Please see the logs for details."
    end

    redirect "/"
  end

  # helper methods
  private

  def messages
    result = ""
    result << "#{no_bindings_exist_message}" unless bindings_exist
    result << "\n\nAfter binding or unbinding any service instances, restart this application with 'cf restart [appname]'."
    result
  end

  def vcap_services
    ENV["VCAP_SERVICES"]
  end

  def bindings_exist
    JSON.parse(vcap_services).keys.any? { |key|
      key == service_name
    }
  end

  def no_bindings_exist_message
    "\n\nYou haven't bound any instances of the #{service_name} service."
  end

  def service_name
    "github-repo"
  end

  def credentials_of_all_repos
    if bindings_exist
      JSON.parse(vcap_services)[service_name].map do |service_instance|
        service_instance["credentials"]
      end
    end
  end
end
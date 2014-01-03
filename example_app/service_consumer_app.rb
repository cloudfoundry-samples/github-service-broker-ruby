require 'sinatra'
require 'json'
require 'rack-flash'
require 'cf-app-utils'
require_relative 'github_repo_helper'

class ServiceConsumerApp < Sinatra::Base

  # app configuration
  enable :sessions
  use Rack::Flash, :sweep => true

  #declare the routes used by the app
  get "/" do
    repo_uris = credentials_of_all_repos.map { |c| c["uri"] } if bindings_exist

    erb :index, locals: {repo_uris: repo_uris, messages: messages}
  end

  get "/env" do
    content_type "text/plain"

    response_body = "VCAP_SERVICES = \n#{vcap_services}\n\n"
    response_body << "VCAP_APPLICATION = \n#{vcap_application}\n\n"
    response_body << messages
    response_body
  end

  post "/create_commit" do
    github_repo_helper = GithubRepoHelper.new(credentials_of_all_repos)
    repo_uri = params[:repo_uri]

    begin
      github_repo_helper.create_commit(repo_uri, application_name)
      flash[:notice] = "Successfully pushed commit to #{repo_uri}"
    rescue GithubRepoHelper::RepoCredentialsMissingError
      flash[:notice] = "Unable to create the commit, repo credentials in VCAP_SERVICES are missing or invalid for: #{repo_uri}"
    rescue GithubRepoHelper::CreateCommitError => e
      flash[:notice] = "Creating the commit failed. Log contents:\n#{e.message}"
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

  def vcap_application
    ENV["VCAP_APPLICATION"]
  end

  def application_name
    JSON.parse(vcap_application).fetch("application_name")
  end

  def bindings_exist
    !(credentials_of_all_repos.empty?)
  end

  def no_bindings_exist_message
    "\n\nYou haven't bound any instances of the #{service_name} service."
  end

  def service_name
    "github-repo"
  end

  def credentials_of_all_repos
    CF::App::Credentials.find_all_by_service_label(service_name)
  end
end
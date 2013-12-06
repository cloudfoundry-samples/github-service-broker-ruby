require 'octokit'

class GithubService

  def initialize(username, password)
    @login = username
    @password = password
  end

  def create_repo(name)
    response = github_client.create_repository(name)
    "https://github.com/#{response.full_name}"
  end

  private

  def github_client
    ::Octokit::Client.new(login: @login, password: @password)
  end
end


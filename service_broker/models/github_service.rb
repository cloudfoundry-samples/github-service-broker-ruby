require 'octokit'

class GithubService
  class GithubUnreachableError < StandardError
  end
  class RepoAlreadyExistsError < StandardError
  end
  class GithubError < StandardError
  end

  def initialize(username, password)
    @login = username
    @password = password
  end

  def create_repo(name)
    begin
      response = github_client.create_repository(name)
      "https://github.com/#{response.full_name}"

    rescue Octokit::Error => e
      if e.is_a?(Octokit::UnprocessableEntity) && (e.message.match /name already exists on this account/)
        raise GithubService::RepoAlreadyExistsError
      else
        # error due to unknown reason, pass the original error message upstream
        raise GithubService::GithubError.new("GitHub returned an error - #{e.message}")
      end
    rescue Faraday::Error::TimeoutError
      raise GithubService::GithubUnreachableError
    end
  end

  private

  def github_client
    ::Octokit::Client.new(login: @login, password: @password)
  end
end


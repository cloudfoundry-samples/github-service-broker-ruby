require 'octokit'
require 'sshkey'

class GithubService
  class RepoAlreadyExistsError < StandardError
  end
  class BindingAlreadyExistsError < StandardError
  end
  class GithubUnreachableError < StandardError
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

    repo_url(response.full_name)
  end

  def create_deploy_key(options)
    repo_name = options.fetch(:repo_name)
    full_repo_name = full_repo_name(repo_name)
    deploy_key_title = options.fetch(:deploy_key_title)

    deploy_key_list = get_deploy_keys(full_repo_name)

    raise GithubService::BindingAlreadyExistsError if deploy_key_list.map(&:title).include? deploy_key_title

    key_pair = SSHKey.generate
    public_key = key_pair.ssh_public_key # get the public key in OpenSSH format

    add_deploy_key(deploy_key_title, full_repo_name, public_key)

    {
        name: repo_name,
        uri: repo_url(full_repo_name),
        private_key: key_pair.private_key
    }
  end

  private

  def add_deploy_key(deploy_key_title, full_repo_name, public_key)
    begin
      github_client.add_deploy_key(full_repo_name, deploy_key_title, public_key)
    rescue Octokit::Error => e
      raise GithubService::GithubError.new("GitHub returned an error - #{e.message}")
    rescue Faraday::Error::TimeoutError
      raise GithubService::GithubUnreachableError
    end
  end

  def get_deploy_keys(full_repo_name)
    begin
      deploy_key_list = github_client.list_deploy_keys(full_repo_name)
    rescue Octokit::Error => e
      raise GithubService::GithubError.new("GitHub returned an error - #{e.message}")
    rescue Faraday::Error::TimeoutError
      raise GithubService::GithubUnreachableError
    end
    deploy_key_list
  end

  def full_repo_name(repo_name)
    "#{@login}/#{repo_name}"
  end

  def repo_url(full_repo_name)
    "https://github.com/#{full_repo_name}"
  end

  def github_client
    ::Octokit::Client.new(login: @login, password: @password)
  end
end


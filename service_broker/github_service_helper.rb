require 'octokit'
require 'sshkey'

class GithubServiceHelper
  class RepoAlreadyExistsError < StandardError
  end
  class BindingAlreadyExistsError < StandardError
  end
  class GithubResourceNotFoundError < StandardError
  end
  class GithubUnreachableError < StandardError
  end
  class GithubError < StandardError
  end

  def initialize(login, access_token)
    @login = login
    @access_token = access_token
  end

  def create_github_repo(name)
    begin
      response = octokit_client.create_repository(name, auto_init: true)
    rescue Octokit::Error => e
      if e.is_a?(Octokit::UnprocessableEntity) && (e.message.match /name already exists on this account/)
        raise GithubServiceHelper::RepoAlreadyExistsError
      else
        # error due to unknown reason, pass the original error message upstream
        raise GithubServiceHelper::GithubError.new("GitHub returned an error - #{e.message}")
      end
    rescue Faraday::Error::TimeoutError, Faraday::ConnectionFailed
      raise GithubServiceHelper::GithubUnreachableError
    end

    repo_https_url(response.full_name)
  end

  def delete_github_repo(name)
    begin
      octokit_client.delete_repository(full_repo_name(name))
    rescue Octokit::Error => e
      raise GithubServiceHelper::GithubError.new("GitHub returned an error - #{e.message}")
    rescue Faraday::Error::TimeoutError, Faraday::ConnectionFailed
      raise GithubServiceHelper::GithubUnreachableError
    end
  end

  def create_github_deploy_key(options)
    repo_name = options.fetch(:repo_name)
    full_repo_name = full_repo_name(repo_name)
    deploy_key_title = options.fetch(:deploy_key_title)

    deploy_key_list = get_deploy_keys(full_repo_name)

    raise GithubServiceHelper::BindingAlreadyExistsError if deploy_key_list.map(&:title).include? deploy_key_title

    key_pair = SSHKey.generate
    public_key = key_pair.ssh_public_key # get the public key in OpenSSH format

    add_deploy_key(deploy_key_title, full_repo_name, public_key)

    {
        name: repo_name,
        uri: repo_https_url(full_repo_name),
        ssh_url: repo_ssh_url(full_repo_name),
        private_key: key_pair.private_key
    }
  end

  def remove_github_deploy_key(options)
    repo_name = options.fetch(:repo_name)
    full_repo_name = full_repo_name(repo_name)
    deploy_key_title = options.fetch(:deploy_key_title)

    deploy_key_list = get_deploy_keys(full_repo_name)
    deploy_key = deploy_key_list.detect { |key| key.title == deploy_key_title }

    return false if deploy_key.nil?
    remove_deploy_key(full_repo_name, deploy_key.id)
  end

  private

  def get_deploy_keys(full_repo_name)
    begin
      octokit_client.list_deploy_keys(full_repo_name)
    rescue Octokit::NotFound
      raise GithubServiceHelper::GithubResourceNotFoundError
    rescue Octokit::Error => e
      raise GithubServiceHelper::GithubError.new("GitHub returned an error - #{e.message}")
    rescue Faraday::Error::TimeoutError, Faraday::ConnectionFailed
      raise GithubServiceHelper::GithubUnreachableError
    end
  end

  def add_deploy_key(deploy_key_title, full_repo_name, public_key)
    begin
      octokit_client.add_deploy_key(full_repo_name, deploy_key_title, public_key)
    rescue Octokit::Error => e
      raise GithubServiceHelper::GithubError.new("GitHub returned an error - #{e.message}")
    rescue Faraday::Error::TimeoutError, Faraday::ConnectionFailed
      raise GithubServiceHelper::GithubUnreachableError
    end
  end

  def remove_deploy_key(full_repo_name, deploy_key_id)
    begin
      octokit_client.remove_deploy_key(full_repo_name, deploy_key_id)
    rescue Octokit::Error => e
      raise GithubServiceHelper::GithubError.new("GitHub returned an error - #{e.message}")
    rescue Faraday::Error::TimeoutError, Faraday::ConnectionFailed
      raise GithubServiceHelper::GithubUnreachableError
    end
  end

  def full_repo_name(repo_name)
    "#{@login}/#{repo_name}"
  end

  def repo_ssh_url(full_repo_name)
    "git@github.com:#{full_repo_name}.git"
  end

  def repo_https_url(full_repo_name)
    "https://github.com/#{full_repo_name}"
  end

  def octokit_client
    ::Octokit::Client.new(access_token: @access_token)
  end
end

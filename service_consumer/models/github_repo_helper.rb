class GithubRepoHelper
  class CreateCommitError < StandardError
  end
  class RepoUriNotFoundError < StandardError
  end
  class RepoCredentialsInvalidError < StandardError
  end

  def initialize(all_repo_credentials)
    @all_repo_credentials = all_repo_credentials
  end

  def create_commit(repo_uri)
    repo_credentials = credentials_for_repo_uri(repo_uri)
    raise RepoUriNotFoundError if repo_credentials.nil?
    raise RepoCredentialsInvalidError unless credentials_are_present?(repo_credentials)

    create_and_push_result = shell_create_and_push_commit(repo_credentials)

    raise CreateCommitError.new(create_and_push_result[:command_output]) unless 0 == create_and_push_result[:command_status]
  end

  private

  def credentials_for_repo_uri(uri)
    # NOTE - per Cloud Controller behavior, there should only be 1 binding,
    # hence 1 set of credentials for a service instance
    @all_repo_credentials.detect do |credentials|
      credentials["uri"] == uri
    end
  end


  # This function shells out to issue commands that do the following:
  #
  # - write ssh private key to file
  # - configure git ssh (known hosts, and private key file)
  # - clone the repo
  # - set git author
  # - check out master
  # - create empty commit
  # - print the commit log
  # - push commit to master
  # - delete private key
  # - delete ssh script
  # - delete cloned directory
  #
  # returns a hash: {
  #   command_status: <status code>,
  #   command_output: <stdio and stderr output of all commands>
  # }
  # command_status is 0 if all commands succeed
  # command_status is status code of the failing command if any command fails
  def shell_create_and_push_commit(repo_credentials)
    private_key = repo_credentials["private_key"]
    repo_name = repo_credentials["name"]
    repo_ssh_url = repo_credentials["ssh_url"]
    keys_dir = "/tmp/github_keys"
    key_file_name = "#{keys_dir}/#{repo_name}.key"
    git_ssh_script = "/tmp/#{repo_name}_ssh_script.sh"
    known_hosts_file = "/tmp/github_known_hosts"

    # Create directory for storing key file, and set permissions
    `if [ ! -d #{keys_dir} ]; then mkdir #{keys_dir}; fi`
    `chmod 0700 #{keys_dir}`

    # Store the private key in a file
    File.open(key_file_name, "w", 0600) do |f|
      f.puts private_key
    end

    # Create a unique known hosts file with github's public key, for these purposes:
    # 1) since SSH StrictHostKeyChecking is "on" by default, this file prevents SSH from asking the user to
    # confirm the github.com host upon the first connection.
    # 2) not relying on the default ~/.ssh/known_hosts file
    File.open(known_hosts_file, "w", 0700) do |f|
      f.puts <<TEXT
github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==
TEXT
    end

    # Configure git to use this custom ssh script instead of the default "ssh" command
    File.open(git_ssh_script, "w", 0700) do |f|
      f.puts <<BASH
#!/bin/sh
exec `which ssh` -o UserKnownHostsFile=#{known_hosts_file} -o HashKnownHosts=no -i #{key_file_name} "$@"
BASH
    end

    commands = [
        "cd /tmp; GIT_SSH=#{git_ssh_script} git clone #{repo_ssh_url} 2>&1",
        "cd /tmp/#{repo_name} && git config user.name 'Demo App' 2>&1",
        "cd /tmp/#{repo_name} && git commit --allow-empty -m 'auto generated empty commit' 2>&1",
        "cd /tmp/#{repo_name} && git log --pretty=format:\"%h%x09%ad%x09%s\" 2>&1",
        "cd /tmp/#{repo_name}; GIT_SSH=#{git_ssh_script} git push origin master 2>&1"
    ]


    return_code = 0
    output = ""

    commands.each do |command|
      output << "\n\n> #{command}\n"
      output << `#{command}`
      return_code = $?
      break if return_code != 0
    end

    # Remove the temp files regardless of success or failure
    cleanup_commands = [
        "rm #{key_file_name}",
        "rm #{git_ssh_script}",
        "rm -rf /tmp/#{repo_name}"
    ]

    cleanup_commands.each do |command|
      output << "\n> #{command}\n"
      output << `#{command}`
    end

    puts output
    {command_status: return_code, command_output: output}
  end

  def blank?(value)
    value.nil? || value.empty?
  end

  def credentials_are_present?(credentials)
    !(blank?(credentials["name"]) ||
        blank?(credentials["uri"]) ||
        blank?(credentials["ssh_url"]) ||
        blank?(credentials["private_key"]))
  end
end
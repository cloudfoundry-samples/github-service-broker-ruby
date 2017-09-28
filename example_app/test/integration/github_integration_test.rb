require File.expand_path '../../test_helper.rb', __FILE__
require File.expand_path '../integration_test_helper.rb', __FILE__

describe "/" do
  before do
    ensure_env_vars_exist

    @vcap_services_value = <<~JSON
      {
        "github-repo": [
          {
            "name": "github-repo-1",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "name": "#{repo_name}",
              "uri": "#{repo_uri}",
              "ssh_url": "#{repo_ssh_url}",
              "private_key": #{repo_private_key.to_json}
            }
          }
        ]
      }
    JSON

    @vcap_application_value = <<~JSON
      {
        "application_name": "#{File.basename(__FILE__, '.rb')}"
      }
    JSON

    ServiceConsumerApp.any_instance.stubs(:vcap_services).returns(@vcap_services_value)
    ServiceConsumerApp.any_instance.stubs(:vcap_application).returns(@vcap_application_value)

    visit "/"
  end

  it "has links to the repos" do
    page.must_have_link(repo_uri)
  end

  it "creates a commit when the commit button is clicked" do
    initial_commit_count = count_commits_in_repo
    click_on "Create a commit"
    sleep(2)
    final_commit_count = count_commits_in_repo

    assert_equal initial_commit_count + 1, final_commit_count
  end
end

private

def ensure_env_vars_exist
   if [github_username, github_access_token, repo_name, repo_private_key].any?(&:nil?)
     raise "PLEASE DEFINE THE REQUIRED ENV VARS FOR THE INTEGRATION TEST"
   end
end

def count_commits_in_repo
  github_client.commits(repo_fullname).length
end

def github_username
  ENV["GITHUB_USERNAME"]
end

# You can create an access token for your integration test GitHub account by running:
# curl -u <github-username-of-test-account> -d '{"scopes": ["repo"], "note": "integration-test-token"}' https://api.github.com/authorizations
def github_access_token
  ENV["GITHUB_ACCESS_TOKEN"]
end

def repo_name
  ENV["GITHUB_REPO_NAME"]
end

def repo_private_key
  # the corresponding public key must be present as a deploy key in "#{github_username}/#{repo_name}"
  ENV["GITHUB_REPO_PRIVATE_KEY"]
end

def repo_ssh_url
  "git@github.com:#{github_username}/#{repo_name}.git"
end

def repo_uri
  "https://github.com/#{github_username}/#{repo_name}"
end

def repo_fullname
  "#{github_username}/#{repo_name}"
end

def github_client
  ::Octokit::Client.new(access_token: github_access_token)
end

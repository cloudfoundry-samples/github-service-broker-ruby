require File.expand_path '../../test_helper.rb', __FILE__

include Rack::Test::Methods

describe GithubRepoHelper do
  describe "#create_commit" do
    before do
      @repo_name = "some-repo"
      @repo_uri = "http://fake.github.com/some-user/#{@repo_name}"
      @desired_repo_credentials = {
          "uri" => @repo_uri,
          "name" => @repo_name,
          "ssh_url" => "dont-care",
          "private_key" => "dont-care"
      }
      @all_repo_credentials =
          [
              @desired_repo_credentials,
              {
                  "uri" => "other-repo-uri",
                  "name" => "other-repo-name",
                  "ssh_url" => "dont-care",
                  "private_key" => "dont-care"
              }
          ]

      @github_repo_helper = GithubRepoHelper.new(@all_repo_credentials)
      @github_repo_helper.stubs(:shell_create_and_push_commit)
    end

    describe "when no repo credentials for the uri exist" do
      it "raises an error" do
        proc {
          @github_repo_helper.create_commit("http://uri-not-present-in-list-of-credentials")
        }.must_raise GithubRepoHelper::RepoCredentialsMissingError
      end
    end

    describe "when the repo credentials for the uri are found" do
      it "creates and pushes the commit to GitHub" do
        @github_repo_helper.expects(:shell_create_and_push_commit).with(@desired_repo_credentials).returns({command_status: 0, command_output: "all is well"})

        @github_repo_helper.create_commit(@repo_uri)
      end
    end

    describe "when any of the fields inside the repo credentials for the uri are missing" do
      %w|uri name ssh_url private_key|.each do |key|
        it "raises an error when #{key} in credentials is empty" do
          @desired_repo_credentials[key] = nil

          proc {
            @github_repo_helper.create_commit(@repo_uri)
          }.must_raise GithubRepoHelper::RepoCredentialsMissingError
        end
      end
    end

    describe "when any shell command fails" do
      it "raises an exception with the failure log in the exception message" do
        @github_repo_helper.expects(:shell_create_and_push_commit).with(@desired_repo_credentials).
            returns({command_status: 1, command_output: "some error messages"})

        exception = proc {
          @github_repo_helper.create_commit(@repo_uri)
        }.must_raise GithubRepoHelper::CreateCommitError

        exception.message.must_equal "some error messages"
      end
    end
  end
end
require File.expand_path '../../test_helper.rb', __FILE__
require 'sshkey'

include Rack::Test::Methods

describe GithubService do
  describe "#create_repo" do
    before do
      @repo_name = "Hello-World"
    end

    describe "when GitHub successfully creates the repo" do
      before do
        # stubbing the http request/response to GitHub API
        @expected_request = stub_request(:post, "https://octocat:github-password@api.github.com/user/repos").
            with(:body => "{\"name\":\"#{@repo_name}\"}").
            to_return(status: 201,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/create_github_repo_success_response.json")
        )
      end

      it "makes request to github" do
        GithubService.new('octocat', 'github-password').create_repo(@repo_name)
        assert_requested @expected_request
      end

      it "returns a repo url" do
        response = GithubService.new('octocat', 'github-password').create_repo(@repo_name)
        response.must_equal "https://github.com/octocat/#{@repo_name}"
      end
    end

    describe "when the repo already exists" do
      before do
        stub_request(:post, "https://octocat:github-password@api.github.com/user/repos").
            with(:body => "{\"name\":\"#{@repo_name}\"}").
            to_return(status: 422,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/create_github_repo_failure_already_exists_response.json")
        )
      end

      it "raises RepoAlreadyExistsError" do
        proc {
          GithubService.new('octocat', 'github-password').create_repo("Hello-World")
        }.must_raise GithubService::RepoAlreadyExistsError
      end
    end

    describe "when GitHub returns 422 for any reason other than a repo already existing" do
      before do
        stub_request(:post, "https://octocat:github-password@api.github.com/user/repos").
            with(:body => "{\"name\":\"#{@repo_name}\"}").
            to_return(status: 422,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: {
                          "message" => "Semantically Invalid"
                      }.to_json
        )
      end

      it "raises CreateRepoError with a message" do
        expected_exception = proc {
          GithubService.new('octocat', 'github-password').create_repo("Hello-World")
        }.must_raise GithubService::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /Semantically Invalid/
      end
    end

    describe "when GitHub returns any other error" do
      before do
        stub_request(:post, "https://octocat:github-password@api.github.com/user/repos").
            with(:body => "{\"name\":\"#{@repo_name}\"}").
            to_return(status: 404,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: {
                          "message" => "Validation Failed"
                      }.to_json
        )
      end

      it "raises CreateRepoError with a message" do
        expected_exception = proc {
          GithubService.new('octocat', 'github-password').create_repo("Hello-World")
        }.must_raise GithubService::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /Validation Failed/
      end
    end

    describe "when GitHub is not reachable" do
      before do
        stub_request(:post, "https://octocat:github-password@api.github.com/user/repos").
            with(:body => "{\"name\":\"#{@repo_name}\"}").
            to_timeout
      end

      it "raises GitHubUnreachableError" do
        proc {
          GithubService.new('octocat', 'github-password').create_repo("Hello-World")
        }.must_raise GithubService::GithubUnreachableError
      end
    end
  end

  describe "#create_deploy_key" do
    def stub_deploy_key_list_request(repo_name)
      stub_request(:get, "https://octocat:github-password@api.github.com/repos/octocat/#{repo_name}/keys").
          to_return(status: 200,
                    headers: {
                        "content-type" => "application/json; charset=utf-8"
                    },
                    body: File.read("test/fixtures/list_github_deploy_keys.json")
      )
    end

    def stub_key_pair_generation
      fake_ssh_key_pair = mock

      SSHKey.stubs(:generate).returns(fake_ssh_key_pair)
      fake_ssh_key_pair.stubs(:ssh_public_key).returns(@public_key)
      fake_ssh_key_pair.stubs(:private_key).returns(@private_key)
    end

    before do
      @repo_name = "repo-name-same-as-service-instance-id"
      @key_title = "key-uuid-same-as-service-binding-id"
      @public_key = "ssh-rsa AAA..."
      @private_key = "-----BEGIN RSA PRIVATE KEY-----\nZZZ\n-----END RSA PRIVATE KEY-----\n"
    end

    describe "when the key is created and added successfully" do
      before do
        stub_deploy_key_list_request(@repo_name)

        stub_key_pair_generation

        @expected_request = stub_request(:post, "https://octocat:github-password@api.github.com/repos/octocat/#{@repo_name}/keys").
            with(:body => {
            "title" => @key_title,
            "key" => @public_key
        }.to_json).
            to_return(status: 201,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: {
                          "id" => 1234,
                          "key" => @public_key,
                          "url" => "https://api.github.com/user/keys/1234",
                          "title" => @key_title
                      }.to_json
        )
      end

      it "makes a deploy key creation request to github" do
        GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
        assert_requested @expected_request
      end

      it "returns credentials, with repo URI and private key" do
        response = GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
        response.must_equal({
                                uri: "https://github.com/octocat/#{@repo_name}",
                                private_key: @private_key
                            })
      end
    end

    describe "when GitHub returns an error" do
      before do
        stub_deploy_key_list_request(@repo_name)

        stub_key_pair_generation

        # stub create deploy key request
        @expected_request = stub_request(:post, "https://octocat:github-password@api.github.com/repos/octocat/#{@repo_name}/keys").
            with(:body => {
            "title" => @key_title,
            "key" => @public_key
        }.to_json).
            to_return(status: 422,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/create_github_deploy_key_failure.json")
        )
      end

      it "raises a GithubError" do
        expected_exception = proc {
          GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
        }.must_raise GithubService::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /key is invalid. Ensure you've copied the file correctly/
      end
    end

    describe "when GitHub is not reachable" do
      before do
        stub_deploy_key_list_request(@repo_name)

        stub_key_pair_generation

        # stub create deploy key request
        stub_request(:post, "https://octocat:github-password@api.github.com/repos/octocat/#{@repo_name}/keys").
            with(:body => {
            "title" => @key_title,
            "key" => @public_key
        }.to_json).
            to_timeout
      end

      it "raises a GithubUnreachableError" do
        proc {
          GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
        }.must_raise GithubService::GithubUnreachableError
      end

    end

    describe "when a deploy key with a title equal to the requested binding already exists" do
      before do
        stub_deploy_key_list_request(@repo_name)
      end

      it "raises a BindingAlreadyExistsError" do
        proc {
          GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: "second-key")
        }.must_raise GithubService::BindingAlreadyExistsError
      end
    end

    describe "when fetching the deploy key list gets an error from GitHub" do
      before do
        stub_request(:get, "https://octocat:github-password@api.github.com/repos/octocat/#{@repo_name}/keys").
            to_return(
            status: 422,
            headers: {
                "content-type" => "application/json; charset=utf-8"
            },
            body: {"message" => "really informative message"}.to_json
        )
      end

      it "raises a GithubError" do
        expected_exception = proc {
          GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
        }.must_raise GithubService::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /really informative message/
      end
    end

    describe "when fetching the deploy key list from GitHub times out" do
      before do
        stub_request(:get, "https://octocat:github-password@api.github.com/repos/octocat/#{@repo_name}/keys").to_timeout
      end

      it "raises a GithubUnreachableError" do
        proc {
          GithubService.new('octocat', 'github-password').create_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
        }.must_raise GithubService::GithubUnreachableError
      end
    end
  end
end

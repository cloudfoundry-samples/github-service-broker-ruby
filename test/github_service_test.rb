require File.expand_path '../test_helper.rb', __FILE__

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
end

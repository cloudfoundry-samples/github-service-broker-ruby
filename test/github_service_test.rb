require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

describe GithubService do
  describe "#create_repo" do
    describe "when GitHub successfully creates the repo" do
      before do
        @repo_name = "Hello-World"

        # stubbing the http request/response to GitHub API
        @expected_request = stub_request(:post, "https://octocat:github-password@api.github.com/user/repos").
            with(:body => "{\"name\":\"#{@repo_name}\"}").
            to_return(status: 201,
                      headers: {
                          "content-type"=>"application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/create_github_repo.json")
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
  end
end

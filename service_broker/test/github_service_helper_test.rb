require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

describe GithubServiceHelper do
  def stub_successful_deploy_key_list_request(repo_name, empty = false)
    response_body = empty ? "[]" : File.read("test/fixtures/list_github_deploy_keys.json")
    stub_request(:get, "https://api.github.com/repos/octocat/#{repo_name}/keys").
        with(headers: {"Authorization" => "token access-token"}).
        to_return(status: 200,
                  headers: {
                      "content-type" => "application/json; charset=utf-8"
                  },
                  body: response_body
    )
  end

  describe "#create_repo" do
    before do
      @repo_name = "Hello-World"
    end

    describe "when GitHub successfully creates the repo" do
      before do
        # stubbing the http request/response to GitHub API
        @expected_request = stub_request(:post, "https://api.github.com/user/repos").
            with(headers: {"Authorization" => "token access-token"},
                 body: {"auto_init" => true, "name" => @repo_name}.to_json).
            to_return(status: 201,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/create_github_repo_success_response.json")
        )
      end

      it "123 makes a request to github" do
        GithubServiceHelper.new('octocat', 'access-token').create_github_repo(@repo_name)
        assert_requested @expected_request
      end

      it "123 returns a repo url" do
        response = GithubServiceHelper.new('octocat', 'access-token').create_github_repo(@repo_name)
        response.must_equal "https://github.com/octocat/#{@repo_name}"
      end
    end

    describe "when the repo already exists" do
      before do
        stub_request(:post, "https://api.github.com/user/repos").
            with(headers: {"Authorization" => "token access-token"},
                 :body => {"auto_init" => true, "name" => @repo_name}.to_json).
            to_return(status: 422,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/create_github_repo_failure_already_exists_response.json")
        )
      end

      it "raises RepoAlreadyExistsError" do
        proc {
          GithubServiceHelper.new('octocat', 'access-token').create_github_repo("Hello-World")
        }.must_raise GithubServiceHelper::RepoAlreadyExistsError
      end
    end

    describe "when GitHub returns 422 for any reason other than a repo already existing" do
      before do
        stub_request(:post, "https://api.github.com/user/repos").
            with(headers: {"Authorization" => "token access-token"},
                 :body => {"auto_init" => true, "name" => @repo_name}.to_json).
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
          GithubServiceHelper.new('octocat', 'access-token').create_github_repo("Hello-World")
        }.must_raise GithubServiceHelper::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /Semantically Invalid/
      end
    end

    describe "when GitHub returns any other error" do
      before do
        stub_request(:post, "https://api.github.com/user/repos").
            with(headers: {"Authorization" => "token access-token"},
                 :body => {"auto_init" => true, "name" => @repo_name}.to_json).
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
          GithubServiceHelper.new('octocat', 'access-token').create_github_repo("Hello-World")
        }.must_raise GithubServiceHelper::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /Validation Failed/
      end
    end

    describe "when GitHub is not reachable" do
      before do
        stub_request(:post, "https://api.github.com/user/repos").
            with(headers: {"Authorization" => "token access-token"},
                 :body => {"auto_init" => true, "name" => @repo_name}.to_json).
            to_timeout
      end

      it "raises GitHubUnreachableError" do
        proc {
          GithubServiceHelper.new('octocat', 'access-token').create_github_repo("Hello-World")
        }.must_raise GithubServiceHelper::GithubUnreachableError
      end
    end
  end

  describe "#create_deploy_key" do
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

    describe "when fetching the list of keys fails" do
      describe "because GitHub resource (repo or account) is not found" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 404,
                        headers: {
                            "content-type" => "application/json; charset=utf-8"
                        },
                        body: File.read("test/fixtures/github_resource_not_found_response.json")
          )
        end

        it "raises a GithubResourceNotFound" do
          proc {
            GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubResourceNotFoundError
        end
      end

      describe "because GitHub returns any other error" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 422,
                        headers: {
                            "content-type" => "application/json; charset=utf-8"
                        },
                        body: File.read("test/fixtures/github_general_error_response.json")
          )
        end

        it "raises a GithubError" do
          expected_exception = proc {
            GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubError

          expected_exception.message.must_match /GitHub returned an error/
          expected_exception.message.must_match /some error message/
        end
      end

      describe "because GitHub is not reachable" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_timeout
        end

        it "raises a GithubUnreachableError" do
          proc {
            GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubUnreachableError
        end
      end
    end

    describe "when fetching the list of keys succeeds" do
      describe "when the key is created and added successfully" do
        before do
          stub_successful_deploy_key_list_request(@repo_name)

          stub_key_pair_generation

          @expected_request = stub_request(:post, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"},
                   :body => {
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
          GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          assert_requested @expected_request
        end

        it "returns credentials, with repo URI and private key" do
          response = GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          response.must_equal({
                                  name: @repo_name,
                                  uri: "https://github.com/octocat/#{@repo_name}",
                                  ssh_url: "git@github.com:octocat/#{@repo_name}.git",
                                  private_key: @private_key
                              })
        end

        describe "when there are no keys on github" do
          it "still succeeds" do
            stub_successful_deploy_key_list_request(@repo_name, true)

            response = GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
            response.must_equal({
                                    name: @repo_name,
                                    uri: "https://github.com/octocat/#{@repo_name}",
                                    ssh_url: "git@github.com:octocat/#{@repo_name}.git",
                                    private_key: @private_key
                                })
          end
        end
      end

      describe "when GitHub returns an error" do
        before do
          stub_successful_deploy_key_list_request(@repo_name)

          stub_key_pair_generation

          @expected_request = stub_request(:post, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"},
                   :body => {
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
            GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubError

          expected_exception.message.must_match /GitHub returned an error/
          expected_exception.message.must_match /key is invalid. Ensure you've copied the file correctly/
        end
      end

      describe "when GitHub is not reachable" do
        before do
          stub_successful_deploy_key_list_request(@repo_name)

          stub_key_pair_generation

          stub_request(:post, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(:body => {
              "title" => @key_title,
              "key" => @public_key
          }.to_json).
              to_timeout
        end

        it "raises a GithubUnreachableError" do
          proc {
            GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubUnreachableError
        end

      end

      describe "when a deploy key with a title equal to the requested binding already exists" do
        before do
          stub_successful_deploy_key_list_request(@repo_name)
        end

        it "raises a BindingAlreadyExistsError" do
          proc {
            GithubServiceHelper.new('octocat', 'access-token').create_github_deploy_key(repo_name: @repo_name, deploy_key_title: "second-key")
          }.must_raise GithubServiceHelper::BindingAlreadyExistsError
        end
      end
    end
  end

  describe "#remove_deploy_key" do
    before do
      @repo_name = "whatever-repo"
      @key_title = "second-key"
      @key_id = 2
    end
    #
    it "requests a list of keys from github" do
      @expected_get_keys_request = stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
          with(headers: {"Authorization" => "token access-token"}).
          to_return(status: 200,
                    headers: {
                        "content-type" => "application/json; charset=utf-8"
                    },
                    body: File.read("test/fixtures/list_github_deploy_keys.json"))

      stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}/keys/#{@key_id}").
          with(headers: {"Authorization" => "token access-token"}).
          to_return(status: 204)

      GithubServiceHelper.new('octocat', 'access-token').remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
      assert_requested @expected_get_keys_request
    end

    describe "when fetching the list of keys fails" do
      describe "because github resource not found" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 404,
                        headers: {
                            "content-type" => "application/json; charset=utf-8"
                        },
                        body: File.read("test/fixtures/github_resource_not_found_response.json")
          )
        end

        it "raises a GithubResourceNotFoundError" do
          proc {
            GithubServiceHelper.new('octocat', 'access-token').
                remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubResourceNotFoundError
        end
      end

      describe "because GitHub is not reachable" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_timeout
        end

        it "raises a GithubUnreachableError" do
          proc {
            GithubServiceHelper.new('octocat', 'access-token').
                remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubUnreachableError
        end
      end

      describe "because GitHub responds with an error" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 422,
                        headers: {
                            "content-type" => "application/json; charset=utf-8"
                        },
                        body: File.read("test/fixtures/github_general_error_response.json"))
        end

        it "raises a GithubError" do
          expected_exception = proc {
            GithubServiceHelper.new('octocat', 'access-token').
                remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          }.must_raise GithubServiceHelper::GithubError

          expected_exception.message.must_match /GitHub returned an error/
          expected_exception.message.must_match /some error message/
        end
      end
    end

    describe "when fetching the list of keys succeeds" do
      describe "when there are no keys in the list" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 200,
                        headers: {
                            "content-type" => "application/json; charset=utf-8"
                        },
                        body: "[]")
        end

        it "returns false" do
          result = GithubServiceHelper.new('octocat', 'access-token').
              remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: "does-not-exist")

          assert_equal false, result
        end
      end

      describe "when the key is not found on github" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 200,
                        headers: {
                            "content-type" => "application/json; charset=utf-8",
                            'Authorization' => 'token access-token'
                        },
                        body: File.read("test/fixtures/list_github_deploy_keys.json")
          )
        end

        it "returns false" do
          result = GithubServiceHelper.new('octocat', 'access-token').
              remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: "does-not-exist")
          assert_equal false, result
        end
      end

      describe "when the requested key exists on github" do
        before do
          stub_request(:get, "https://api.github.com/repos/octocat/#{@repo_name}/keys").
              with(headers: {"Authorization" => "token access-token"}).
              to_return(status: 200,
                        headers: {
                            "content-type" => "application/json; charset=utf-8"
                        },
                        body: File.read("test/fixtures/list_github_deploy_keys.json")
          )

          @expected_request = stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}/keys/#{@key_id}").
              with(headers: {"Authorization" => "token access-token"})
        end

        it "requests github to remove the deploy key" do
          GithubServiceHelper.new('octocat', 'access-token').remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
          assert_requested @expected_request
        end

        describe "when removal succeeds" do
          before do
            stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}/keys/#{@key_id}").
                with(headers: {"Authorization" => "token access-token"}).
                to_return(status: 204)
          end

          it "returns true" do
            result = GithubServiceHelper.new('octocat', 'access-token').
                remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
            assert_equal true, result
          end
        end

        describe "when removal fails" do
          describe "because GitHub cannot find the resource" do
            before do
              stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}/keys/#{@key_id}").
                  with(headers: {"Authorization" => "token access-token"}).
                  to_return(status: 404)
            end

            it "returns false" do
              result = GithubServiceHelper.new('octocat', 'access-token').
                  remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
              assert_equal false, result
            end
          end

          describe "because GitHub returns an error" do
            before do
              stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}/keys/#{@key_id}").
                  with(headers: {"Authorization" => "token access-token"}).
                  to_return(status: 422,
                            headers: {
                                "content-type" => "application/json; charset=utf-8"
                            },
                            body: File.read("test/fixtures/github_general_error_response.json"))
            end

            it "raises a GithubError" do
              expected_exception = proc {
                GithubServiceHelper.new('octocat', 'access-token').
                    remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
              }.must_raise GithubServiceHelper::GithubError

              expected_exception.message.must_match /GitHub returned an error/
              expected_exception.message.must_match /some error message/
            end
          end

          describe "because GitHub is not reachable" do
            before do
              stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}/keys/#{@key_id}").
                  with(headers: {"Authorization" => "token access-token"}).
                  to_timeout
            end

            it "raises a GithubUnreachableError" do
              proc {
                GithubServiceHelper.new('octocat', 'access-token').remove_github_deploy_key(repo_name: @repo_name, deploy_key_title: @key_title)
              }.must_raise GithubServiceHelper::GithubUnreachableError
            end
          end
        end
      end
    end
  end

  describe "#delete_repo" do
    before do
      @repo_name = "whatever-repo"
      @expected_request = stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}").
          with(headers: {"Authorization" => "token access-token"})
    end

    it "makes a repo deletion request to github" do
      GithubServiceHelper.new('octocat', 'access-token').delete_github_repo(@repo_name)
      assert_requested @expected_request
    end

    describe "when deletion succeeds" do
      before do
        stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}").
            with(headers: {"Authorization" => "token access-token"}).
            to_return(status: 204)
      end

      it "returns true" do
        result = GithubServiceHelper.new('octocat', 'access-token').delete_github_repo(@repo_name)
        assert_equal true, result
      end
    end

    describe "when the repo does not exist" do
      before do
        stub_request(:delete, "https://api.github.com/repos/octocat/repo-that-does-not-exist").
            with(headers: {"Authorization" => "token access-token"}).
            to_return(status: 404,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/github_resource_not_found_response.json"))
      end

      it "returns false" do
        result = GithubServiceHelper.new('octocat', 'access-token').delete_github_repo("repo-that-does-not-exist")
        assert_equal false, result
      end
    end

    describe "when GitHub returns an error" do
      before do
        stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}").
            with(headers: {"Authorization" => "token access-token"}).
            to_return(status: 422,
                      headers: {
                          "content-type" => "application/json; charset=utf-8"
                      },
                      body: File.read("test/fixtures/github_general_error_response.json"))
      end

      it "raises a GithubError" do
        expected_exception = proc {
          GithubServiceHelper.new('octocat', 'access-token').delete_github_repo(@repo_name)
        }.must_raise GithubServiceHelper::GithubError

        expected_exception.message.must_match /GitHub returned an error/
        expected_exception.message.must_match /some error message/
      end
    end

    describe "when GitHub is not reachable" do
      before do
        stub_successful_deploy_key_list_request(@repo_name)

        stub_request(:delete, "https://api.github.com/repos/octocat/#{@repo_name}").
            with(headers: {"Authorization" => "token access-token"}).
            to_timeout
      end

      it "raises a GithubUnreachableError" do
        proc {
          GithubServiceHelper.new('octocat', 'access-token').delete_github_repo(@repo_name)
        }.must_raise GithubServiceHelper::GithubUnreachableError
      end
    end
  end
end

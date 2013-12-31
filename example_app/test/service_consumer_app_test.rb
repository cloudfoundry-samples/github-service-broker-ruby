require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  ServiceConsumerApp.new
end

def service_name
  "github-repo"
end

describe "GET /" do
  def make_request
    get "/"
  end

  before do
    @vcap_services_value = "{}"
    ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
    CF::App::Service.instance_variable_set :@services, nil
  end

  it "displays instructions about restarting the app" do
    make_request

    last_response.status.must_equal 200
    last_response.body.must_match /After binding or unbinding any service instances, restart/
  end

  describe "when no service instances are bound to the app" do
    it "displays a message saying that no instances are bound" do
      make_request

      last_response.status.must_equal 200
      last_response.body.must_match /You haven't bound any instances of the #{service_name} service/
    end
  end

  describe "when there are service instances are bound to the app" do
    before do
      @vcap_services_value = <<JSON
      {
        "github-repo": [
          {
            "name": "github-repo-1",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "name": "hello-world",
              "uri": "https://github.com/octocat/hello-world",
              "ssh_url": "git@github.com:octocat/hello-world.git",
              "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nZZZ\\n-----END RSA PRIVATE KEY-----\\n"
            }
          },
          {
            "name": "github-repo-2",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "name": "happy-times",
              "uri": "https://github.com/octocat/happy-times",
              "ssh_url": "git@github.com:octocat/happy-times.git",
              "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nYYY\\n-----END RSA PRIVATE KEY-----\\n"
            }
          }
        ]
      }
JSON
      ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
      CF::App::Service.instance_variable_set :@services, nil
    end

    it "does not display a message saying that no instances are bound" do
      make_request

      last_response.status.must_equal 200
      last_response.body.wont_match /You haven't bound any instances of the #{service_name} service/
    end

    it "binding - displays the repo URL for each bound instance" do
      make_request

      expected_link = <<HTML
<a href="https://github.com/octocat/hello-world">https://github.com/octocat/hello-world</a>
HTML
      last_response.body.must_include expected_link.strip

      expected_link = <<HTML
<a href="https://github.com/octocat/happy-times">https://github.com/octocat/happy-times</a>
HTML
      last_response.body.must_include expected_link.strip
    end

  end
end

describe "GET /env" do
  def make_request
    get "/env"
  end

  before do
    @vcap_services_value = "{}"
    ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
    CF::App::Service.instance_variable_set :@services, nil
  end

  it "displays instructions for binding" do
    make_request

    last_response.body.must_match /You haven't bound any instances of the #{service_name} service/
  end

  describe "when an instance of the service is bound to the app" do
    before do
      @vcap_services_value = <<JSON
      {
        "github-repo": [
          {
            "name": "github-repo-1",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "password": "topsecret"
            }
          }
        ]
      }
JSON

      ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
      CF::App::Service.instance_variable_set :@services, nil
      make_request
    end

    it "is successful" do
      last_response.status.must_equal 200
    end

    it "shows the value of VCAP_SERVICES" do
      last_response.body.must_include "VCAP_SERVICES = \n#{@vcap_services_value}"
    end

    it "does not display a message saying that no instances are bound" do
      last_response.body.wont_match /You haven't bound any instances of the #{service_name} service/
    end
  end

  describe "when an instance of a different service is bound to the app" do
    before do
      @vcap_services_value = <<JSON
      {
        "cleardb": [
          {
            "name": "cleardb-1",
            "label": "cleardb-n/a",
            "plan": "spark",
            "credentials": {
               "password": "topsecret"
            }
          }
        ]
      }
JSON

      ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)

      make_request
    end

    it "is successful" do
      last_response.status.must_equal 200
    end

    it "shows the value of VCAP_SERVICES" do
      last_response.body.must_include "VCAP_SERVICES = \n#{@vcap_services_value}"
    end

    it "displays a message saying that no instances are bound" do
      last_response.body.must_match /You haven't bound any instances of the #{service_name} service/
    end
  end

  describe "when no service instances are bound to the app" do
    it "is successful" do
      make_request

      last_response.status.must_equal 200
    end

    it "shows the value of VCAP_SERVICES" do
      make_request

      last_response.body.must_match /VCAP_SERVICES = \n\{}/
    end
  end
end

describe "POST /create_commit" do
  def make_request
    post "/create_commit", repo_uri: @repo_uri
  end

  def flash
    last_request.env['x-rack.flash']
  end

  before do
    @repo_uri = "http://fake.github.com/some-user/some-repo"
    @vcap_services_value = <<JSON
      {
        "github-repo": [
          {
            "name": "github-repo-1",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "password": "topsecret",
              "uri": "#{@repo_uri}"
            }
          },
          {
            "name": "github-repo-2",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "password": "also-very-secret",
              "uri": "uri-of-the-other-repo"
            }
          }
        ]
      }
JSON

    ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
    CF::App::Service.instance_variable_set :@services, nil
  end

  it "calls GithubRepoHelper#create_commit with the repo URI" do
    all_credentials = [
        {
            "password" => "topsecret",
            "uri" => @repo_uri
        },
        {
            "password" => "also-very-secret",
            "uri" => "uri-of-the-other-repo"
        }
    ]

    fake_github_repo_helper = mock
    GithubRepoHelper.expects(:new).with(all_credentials).returns(fake_github_repo_helper)
    fake_github_repo_helper.expects(:create_commit).with(@repo_uri)

    make_request
  end

  it "redirects to the index page" do
    GithubRepoHelper.any_instance.stubs(:create_commit)

    make_request

    last_response.must_be :redirect?
    follow_redirect!
    last_request.path.must_equal "/"
  end

  describe "when creating the commit succeeds" do
    it "shows a success message in the flash" do
      GithubRepoHelper.any_instance.stubs(:create_commit)

      make_request

      follow_redirect!
      flash.wont_be_nil
      assert last_response.body.must_include "Successfully pushed commit to #{@repo_uri}"
    end
  end

  describe "when creating the commit fails" do
    describe "because the repo credentials are missing" do
      before do
        GithubRepoHelper.any_instance.stubs(:create_commit).raises(GithubRepoHelper::RepoCredentialsMissingError)
      end

      it "redirects to the index page with the error message in the flash" do
        make_request

        follow_redirect!
        flash.wont_be_nil
        assert last_response.body.must_include "Unable to create the commit, repo credentials in VCAP_SERVICES are missing or invalid for: #{@repo_uri}"
      end
    end

    describe "for any other reason" do
      before do
        GithubRepoHelper.any_instance.stubs(:create_commit).raises(GithubRepoHelper::CreateCommitError)
      end

      it "redirects to the index page with the error message in the flash" do
        make_request

        follow_redirect!
        flash.wont_be_nil
        assert last_response.body.must_include "Creating the commit failed"
      end
    end
  end
end
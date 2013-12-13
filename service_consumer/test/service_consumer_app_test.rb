require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  ServiceConsumerApp.new
end

def service_name
  "github-repo"
end

describe "/" do
  def make_request
    get "/"
  end

  before do
    @vcap_services_value = "{}"
    ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
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
        "github-repo-n/a": [
          {
            "name": "github-repo-1",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "uri": "https://github.com/octocat/hello-world",
              "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nZZZ\\n-----END RSA PRIVATE KEY-----\\n"
            }
          }
        ]
      }
JSON
      ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
    end

    it "does not display a message saying that no instances are bound" do
      make_request

      last_response.status.must_equal 200
      last_response.body.wont_match /You haven't bound any instances of the #{service_name} service/
    end
  end
end

describe "/env" do
  def make_request
    get "/env"
  end

  before do
    @vcap_services_value = "{}"
    ENV.stubs(:[]).with("VCAP_SERVICES").returns(@vcap_services_value)
  end

  it "displays instructions for binding" do
    make_request

    last_response.body.must_match /You haven't bound any instances of the #{service_name} service/
  end

  describe "when an instance of the service is bound to the app" do
    before do
      @vcap_services_value = <<JSON
      {
        "github-repo-n/a": [
          {
            "name": "github-repo-1",
            "label": "github-repo-n/a",
            "plan": "public",
            "credentials": {
              "uri": "https://github.com/octocat/hello-world",
              "private_key": "-----BEGIN RSA PRIVATE KEY-----\\nZZZ\\n-----END RSA PRIVATE KEY-----\\n"
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

    it "does not display a message saying that no instances are bound" do
      last_response.body.wont_match /You haven't bound any instances of the #{service_name} service/
    end
  end

  describe "when an instance of a different service is bound to the app" do
    before do
      @vcap_services_value = <<JSON
      {
        "cleardb-n/a": [
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
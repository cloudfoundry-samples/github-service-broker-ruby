require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  ServiceConsumerApp.new
end

describe "/" do
  def make_request
    get "/"
  end

  describe "when no service instances are bound to the app" do
    before do
      make_request
    end

    it "displays instructions for binding" do
      last_response.status.must_equal 200
      last_response.body.must_match /You haven't bound any instances of the Github Repo service/
    end
  end
end

describe "/env" do
  def make_request
    get "/env"
  end

  describe "when the VCAP_SERVICES env var does not exist" do
    it "display a warning" do
      make_request

      last_response.body.must_match /The environment variable VCAP_SERVICES is not found/
    end
  end

  describe "when no service instances are bound to the app" do
    before do
      ENV.stubs(:[]).with("VCAP_SERVICES").returns("{}")
      make_request
    end

    it "is successful" do
      last_response.status.must_equal 200
    end

    it "shows the value of VCAP_SERVICES" do
      last_response.body.must_match /VCAP_SERVICES = \n\{}/
    end

    it "displays instructions for binding" do
      last_response.body.must_match /You haven't bound any instances of the Github Repo service/
    end
  end
end
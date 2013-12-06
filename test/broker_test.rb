require File.expand_path '../test_helper.rb', __FILE__

include Rack::Test::Methods

def app
  ServiceBroker.new
end

describe "/v2/catalog" do
  describe "when basic auth credentials are missing" do
    before do
      get "/v2/catalog"
    end

    it "returns a 401 unauthorized response" do
      assert_equal 401, last_response.status
    end
  end

  describe "when basic auth credentials are incorrect" do
    before do
      authorize "admin", "wrong-password"
      get "/v2/catalog"
    end

    it "returns a 401 unauthorized response" do
      assert_equal 401, last_response.status
    end
  end

  describe "when basic auth credentials are correct" do
    before do
      authorize "admin", "password"
      get "/v2/catalog"
    end

    it "returns a 200 response" do
      assert_equal 200, last_response.status
    end

    it "returns a JSON" do
      last_response.header["Content-Type"].must_include("application/json")
    end

    it "returns correct keys in JSON" do
      response_json = JSON.parse last_response.body

      response_json.keys.must_equal ["services"]

      services = response_json["services"]
      assert services.length > 0

      services.each do |service|
        service.keys.length.must_equal 5
        assert service.keys.include? "id"
        assert service.keys.include? "name"
        assert service.keys.include? "description"
        assert service.keys.include? "bindable"
        assert service.keys.include? "plans"

        plans = service["plans"]
        assert plans.length > 0
        plans.each do |plan|
          plan.keys.length.must_equal 3
          assert plan.keys.include? "id"
          assert plan.keys.include? "name"
          assert plan.keys.include? "description"
        end
      end
    end
  end
end

describe "/v2/service_instances/:id" do
  before do
    @id = 1234
  end

  describe "when basic auth credentials are missing" do
    before do
      get "/v2/service_instances/#{@id}"
    end

    it "returns a 401 unauthorized response" do
      assert_equal 401, last_response.status
    end
  end

  describe "when basic auth credentials are incorrect" do
    before do
      authorize "admin", "wrong-password"
      get "/v2/service_instances/#{@id}"
    end

    it "returns a 401 unauthorized response" do
      assert_equal 401, last_response.status
    end
  end

  describe "when basic auth credentials are correct" do

    before do
      authorize "admin", "password"

      @fake_github_service = mock
      @fake_github_service.stubs(:create_repo).returns("http://some.repository.url")
      GithubService.stubs(:new).returns(@fake_github_service)
    end

    it "returns '201 Created'" do
      get "/v2/service_instances/#{@id}"
      assert_equal 201, last_response.status
    end

    it "returns json representation of dashboard URL" do
      get "/v2/service_instances/#{@id}"

      expected_json = {
          "dashboard_url" => "http://some.repository.url"
      }.to_json

      assert_equal expected_json, last_response.body
    end
  end
end
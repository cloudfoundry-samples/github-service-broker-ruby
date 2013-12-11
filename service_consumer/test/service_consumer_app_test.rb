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

    it "returns a message" do
      last_response.status.must_equal 200
      last_response.body.must_match /You haven't bound any instances of the Github Repo service/
    end
  end
end

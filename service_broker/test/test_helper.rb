ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'mocha/setup'
require 'webmock/minitest'
require 'pry'

SETTINGS_FILENAME = "test/config/settings.yml"

require File.expand_path '../../service_broker_app.rb', __FILE__
require File.expand_path '../../models/github_service_helper.rb', __FILE__
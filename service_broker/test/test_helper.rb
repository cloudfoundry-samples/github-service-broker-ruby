require 'codeclimate-test-reporter'
CodeClimate::TestReporter.start

ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'mocha/setup'
require 'webmock/minitest'
require 'pry'

WebMock.disable_net_connect!(allow: 'codeclimate.com')

SETTINGS_FILENAME = "test/config/settings.yml"

require File.expand_path '../../service_broker_app.rb', __FILE__
require File.expand_path '../../github_service_helper.rb', __FILE__
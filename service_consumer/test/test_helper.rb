ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'

require File.expand_path '../../service_consumer_app.rb', __FILE__
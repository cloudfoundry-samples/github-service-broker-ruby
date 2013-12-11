ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'mocha/setup'

require File.expand_path '../../service_consumer_app.rb', __FILE__
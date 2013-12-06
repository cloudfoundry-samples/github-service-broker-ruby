ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'mocha/setup'
require 'webmock/minitest'

require File.expand_path '../../broker.rb', __FILE__
require File.expand_path '../../github_service.rb', __FILE__
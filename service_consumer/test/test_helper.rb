ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'
require 'mocha/setup'
require 'pry'

require File.expand_path '../../service_consumer_app.rb', __FILE__
require File.expand_path '../../models/github_repo_helper.rb', __FILE__
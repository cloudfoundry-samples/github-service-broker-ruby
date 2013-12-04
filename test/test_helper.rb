ENV['RACK_ENV'] = 'test'
require 'minitest/autorun'
require 'minitest/spec'
require 'rack/test'


require File.expand_path '../../broker.rb', __FILE__

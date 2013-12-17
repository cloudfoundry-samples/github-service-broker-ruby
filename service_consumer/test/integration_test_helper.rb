require 'capybara'
require 'capybara/dsl'
require 'capybara_minitest_spec'
require 'octokit'


Octokit.auto_paginate = true

Capybara.app = ServiceConsumerApp

class MiniTest::Spec
  include Capybara::DSL
end

after :all do
  Capybara.reset_sessions!
end
require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'vcr'
require "proxy_checker"
require 'webmock/rspec'
require_relative "support.rb"

TEST_PROXY_IP   = "87.98.219.96"
TEST_PROXY_PORT = 8080

VCR.configure do |config|
  config.hook_into :webmock
  config.cassette_library_dir = "fixtures/vcr_cassettes"
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = "/tmp/examples.txt"
  config.include ProxyChecker::TestHelper
  config.before(:each) do
    ENV['CURRENT_IP'] = "CURRENT_IP"
    reset_configuration
  end
end

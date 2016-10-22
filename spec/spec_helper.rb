require 'simplecov'
SimpleCov.start

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'vcr'
require "proxy_checker"
require_relative "support.rb"

TEST_PROXY_IP   = "94.177.243.88"
TEST_PROXY_PORT = 3128

VCR.configure do |config|
  config.hook_into :webmock
  config.cassette_library_dir = "fixtures/vcr_cassettes"
end

RSpec.configure do |config|
  config.include ProxyChecker::TestHelper
  config.before(:each) do
    ENV['CURRENT_IP'] = "CURRENT_IP"
    ProxyChecker.config = nil
    ProxyChecker.config.keep_failed_attempts = true
  end
end

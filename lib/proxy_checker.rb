require 'pry'
require 'uri'
require 'http'
require 'active_support/inflector'
require "proxy_checker/version"

require "proxy_checker/utility"            # generic methods
require "proxy_checker/dsl"                # dsl for the gem
require "proxy_checker/config"             # configuration
require 'proxy_checker/adapters/base'      # base adapter class
require 'proxy_checker/adapters/azenv'     # adapter for Azenv.php
require 'proxy_checker/adapters/server'    # adapter that uses custom server

module ProxyChecker
  class << self
    attr_accessor :config

    def config
      @config ||= Config.new
    end

    def configure(&block)
      block.arity == 1 ? yield(config) : yield if block_given?
    end
  end

  def self.new(ip, port, &block)
    adapter = ProxyChecker.config.adapter.new(ip, port)
    adapter.instance_eval(&block)
    adapter
  end

  def self.data_for(ip, port, &block)
    self.new(ip, port, &block).data
  end
end

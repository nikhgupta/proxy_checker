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
      return unless block_given?
      yield config if block.arity == 1
      ProxyChecker.config.instance_eval(&block)
    end
  end

  def self.new(ip, port, &block)
    ProxyChecker::DSL.new(ip, port, &block)
  end

  def self.data_for(ip, port, &block)
    self.new(ip, port, &block).fetch
  end
end

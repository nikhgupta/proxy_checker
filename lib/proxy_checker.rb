require 'pry'
require 'uri'
require 'http'
require "proxy_checker/version"
require "proxy_checker/utility"
require "proxy_checker/config"
require "proxy_checker/informer"
require "proxy_checker/reviewer"

module ProxyChecker
  class << self
    attr_accessor :config

    def config
      @config ||= Config.new
    end

    def configure(&block)
      block.arity == 1 ? yield(config) : yield if block_given?
      config.current_ip ||= config.fetch_current_ip
    end
  end

  def self.check(ip, port, info: true)
    data = ProxyChecker::Reviewer.new(ip, port).fetch
    data.merge!(info: ProxyChecker::Informer.new(ip, port).fetch) if info
    data
  end
end

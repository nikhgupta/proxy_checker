require 'pry'
require 'uri'
require 'http'
require "proxy_checker/version"
require "proxy_checker/utility"
require "proxy_checker/config"
require "proxy_checker/base"
require "proxy_checker/body_parser"

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
    reviewer = ProxyChecker::Base.new(ip, port)
    reviewer.instance_eval(&block)
    reviewer
  end

  def self.data_for(ip, port, &block)
    self.new(ip, port, &block).data
  end

  def self.check(ip, port, options = {})
    info = options.fetch(:info, true)
    protocols = [ options.fetch(:protocols, []) ].flatten
    data = ProxyChecker::Reviewer.new(ip, port).fetch(*protocols)
    data.merge!(info: ProxyChecker::Informer.new(ip, port).fetch) if info
    data
  end
end

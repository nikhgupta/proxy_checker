module ProxyChecker
  class Config
    attr_accessor :adapter
    attr_accessor :read_timeout, :connect_timeout
    attr_accessor :ssl_context, :current_ip, :user_agent
    attr_accessor :log_error

    attr_reader :previous_adapter

    def initialize
      reset!
    end

    def reset!
      @current_ip      = nil
      @read_timeout    = 10
      @connect_timeout = 5

      @ssl_context     = OpenSSL::SSL::SSLContext.new
      @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @log_error  = -> (e) { puts "\e[31mEncountered ERROR: #{e.class} #{e}\e[0m" }

      @user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.143 Safari/537.36"

      self.adapter = :server
    end

    def adapter=(adapter)
      @previous_adapter = self.adapter

      if adapter.is_a?(Class)
        @adapter = adapter.new if adapter.is_a?(Class)
        configure_adapter_options!
      elsif ProxyChecker::Adapter.const_defined?(adapter.to_s.camelize)
        @adapter = ProxyChecker::Adapter.const_get(adapter.to_s.camelize).new
        configure_adapter_options!
      else
        raise NotImplementedError, "Invalid adapter specified!"
      end
    end

    def adapters
      ProxyChecker::Adapter::Base.adapters
    end

    def configure_adapter_options!
      previous_adapter.class.options.each do |key, val|
        instance_variable_set("@#{key}", nil)
        singleton_class.instance_eval do
          remove_method key
          remove_method "#{key}="
        end
      end if has_adapter_options?(previous_adapter, previous: true)

      adapter.class.options.each do |key, val|
        singleton_class.instance_eval { attr_accessor key }
        instance_variable_set("@#{key}", val)
      end if has_adapter_options?
    end

    def timeout
      { read_timeout: @read_timeout, connect_timeout: @connect_timeout, write_timeout: @read_timeout }
    end

    def current_ip
      @current_ip ||= ENV['CURRENT_IP'] || fetch_local_ip || adapter.fetch_external_ip
    end

    def fetch_local_ip
      ip = Socket.ip_address_list.detect do |intf|
        intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?
      end
      ip.ip_address if ip
    end

    def has_adapter_options?(adapter = nil, options = {})
      adapter = @adapter if adapter.nil? && !options.fetch(:previous, false)
      adapter && adapter.class.respond_to?(:options) &&
        adapter.class.options.respond_to?(:any?) &&
        adapter.class.options.any?
    end
  end
end

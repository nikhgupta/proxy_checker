module ProxyChecker
  class Config
    attr_accessor :adapter
    attr_accessor :read_timeout, :connect_timeout
    attr_accessor :ssl_context, :current_ip, :user_agent
    attr_accessor :http_url, :https_url,  :post_url
    attr_accessor :info_url, :digest_url, :current_ip_url
    attr_accessor :log_error
    attr_accessor :websites

    def initialize
      reset!
    end

    def reset!
      @info_url        = "http://ip-api.com/json/%{ip}"
      @current_ip_url  = "http://ip-api.com/json"
      @digest_url      = "https://git.io/vPpCx"
      @http_url, @https_url, @post_url = nil

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
      if adapter.is_a?(Class)
        @adapter = adapter.new if adapter.is_a?(Class)
      elsif ProxyChecker::Adapter.const_defined?(adapter.to_s.camelize)
        @adapter = ProxyChecker::Adapter.const_get(adapter.to_s.camelize).new
      else
        raise NotImplementedError, "Invalid adapter specified!"
      end
    end

    def adapters
      ProxyChecker::Adapter::Base.adapters
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
  end
end

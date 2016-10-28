module ProxyChecker
  module TestHelper
    def with_cassette_for(name, ip = nil, port = nil)
      @name = name
      @ip   = ip   || TEST_PROXY_IP
      @port = port || TEST_PROXY_PORT
      VCR.use_cassette("#{@name}-#{@ip}:#{@port}"){ yield }
    end

    def verify_protocol(key)
      data = with_cassette_for(key) do
        ProxyChecker.data_for(@ip, @port) do
          send "check_proxy_for_#{key}"
        end
      end
      data[key]
    end

    def config
      ProxyChecker.config
    end

    def set_config(key, val)
      ProxyChecker.configure{ |config| config.send "#{key}=", val }
    end

    def reset_config(defaults = {})
      ProxyChecker.config = nil
      ProxyChecker.configure do |config|
        defaults.each{ |key, val| config.send "#{key}=", val }
      end
    end

    def reset_configuration
      WebMock.reset!
      ProxyChecker.config = nil
      ProxyChecker.configure do |config|
        config.adapter   = :azenv
        config.read_timeout = 10
        config.connect_timeout = 5
      end
    end
  end
end

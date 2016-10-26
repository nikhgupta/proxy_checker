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

    def reset_configuration
      WebMock.reset!
      ProxyChecker.config = nil
      ProxyChecker.configure do |config|
        config.adapter   = :azenv
        config.http_url  = "http://luisaranguren.com/azenv.php"
        # config.log_error = nil
        config.read_timeout = 10
        config.connect_timeout = 5
      end
    end
  end
end

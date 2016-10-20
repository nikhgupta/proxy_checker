module ProxyChecker
  module TestHelper
    def with_cassette_for(protocol, ip = nil, port = nil)
      @protocol = protocol
      @ip       = ip   || TEST_PROXY_IP
      @port     = port || TEST_PROXY_PORT
      VCR.use_cassette("#{@protocol}-#{@ip}:#{@port}"){ yield }
    end
  end
end

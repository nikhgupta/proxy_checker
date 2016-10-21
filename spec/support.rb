module ProxyChecker
  module TestHelper
    def with_cassette_for(name, ip = nil, port = nil)
      @name = name
      @ip   = ip   || TEST_PROXY_IP
      @port = port || TEST_PROXY_PORT
      VCR.use_cassette("#{@name}-#{@ip}:#{@port}"){ yield }
    end

    def verify_protocol(key)
      review = nil
      with_cassette_for(key) do
        review = ProxyChecker::Reviewer.new(@ip, @port).fetch(key.to_sym)
      end
      review[key]
    end
  end
end

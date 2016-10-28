describe ProxyChecker::Utility do
  let(:my_class) do
    Class.new do
      include ProxyChecker::Utility
    end
  end

  subject{ my_class.new }

  def assert_http_client
    expect_any_instance_of(HTTP::Client)
  end

  def assert_request_received_with(*args)
    assert_http_client.to receive(:request).with(*args)
  end

  def fetch_url(type, name = nil)
    VCR.use_cassette("#{name || type}-fetch-url") do
      subject.fetch_url send("#{type}_uri")
    end
  end

  describe "#config" do
    it "is a convenient method to access configuration options" do
      ProxyChecker.configure{ self.read_timeout = 1 }
      expect(subject.config).to eq ProxyChecker.config
      expect(subject.config.read_timeout).to eq 1
    end
  end

  describe "#agent" do
    it "configures default user agent, and other options for connection agent" do
      options = subject.agent.default_options
      headers = options.headers.to_h

      expect(headers['User-Agent']).to   include "Chrome"
      expect(headers['Content-Type']).to eq "text/plain"
      expect(options.timeout_class).to   eq HTTP::Timeout::PerOperation
      expect(options.timeout_options).to include(read_timeout: 10, connect_timeout: 5)
      expect(options.follow).not_to be_nil
    end

    it "allows customizing default options for conenction agent" do
      agent  = subject.agent(
        user_agent: "Mozilla", content_type: "application/json",
        timeout: { connect_timeout: 1, read_timeout: 1}
      )
      options = agent.default_options
      headers = options.headers.to_h

      expect(headers['User-Agent']).to   eq "Mozilla"
      expect(headers['Content-Type']).to eq "application/json"
      expect(options.timeout_class).to   eq HTTP::Timeout::PerOperation
      expect(options.timeout_options).to include(read_timeout: 1, connect_timeout: 1)
      expect(options.follow).not_to be_nil
    end

    it "reuses connection agent" do
      expect(subject.agent).to eq subject.agent
    end
  end

  describe "#fetch_url" do
    it "uses HTTPS connection for urls with https scheme" do
      assert_request_received_with :get, "https://whatever.com", any_args
      subject.fetch_url "https://whatever.com"
    end
    it "uses HTTPS connection when specifically asked for" do
      assert_request_received_with :get, "https://whatever.com", any_args
      subject.fetch_url "http://whatever.com", ssl: true
    end
    it "uses SSL context defined by config options when requesting HTTPS url" do
      assert_request_received_with :get, "https://whatever.com", ssl_context: subject.config.ssl_context
      subject.fetch_url "https://whatever.com"
    end

    it "uses GET method to request the URL, by default" do
      assert_request_received_with :get, any_args
      subject.fetch_url "http://whatever.com"
    end
    it "allows using a different HTTP method to request the url" do
      assert_request_received_with :post, any_args
      subject.fetch_url "http://whatever.com", method: :post
    end
    it "does not use a proxy, by default" do
      assert_http_client.not_to receive(:via)
      assert_request_received_with :get, any_args

      subject.fetch_url "http://whatever.com"
    end
    it "uses a proxy, if specified in the options" do
      assert_http_client.to receive(:via).with("123.123.123.123", 12345).and_call_original
      assert_request_received_with :get, any_args

      subject.fetch_url "http://whatever.com", proxy: { ip: "123.123.123.123", port: "12345" }
    end
    it "measures the time taken to request the url" do
      response = double("response")
      assert_request_received_with(:get, any_args).and_return response

      data = subject.fetch_url "http://whatever.com"
      expect(data.time_taken).to be > 0
    end
    it "sanitizes the response received from the url" do
      response = spy("response", uri: "http://whatever.com", code: 200, to_s: "whatever")

      expect(response).to receive(:parse).and_raise NoMethodError
      assert_request_received_with(:get, any_args).and_return response

      data = subject.fetch_url "http://whatever.com"
      expect(data.uri).to        eq "http://whatever.com"
      expect(data.code).to       eq 200
      expect(data.body).to       eq "whatever"
      expect(data.parsed).to     eq "whatever"
      expect(data.cookies).to    be_empty
      expect(data.streaming).to  be_falsey
      expect(data.time_taken).to be > 0
    end
    it "does not try to sanitize response if response does not implement `uri` method" do
      response = double("response")
      assert_request_received_with(:get, any_args).and_return response

      data = subject.fetch_url "http://whatever.com"
      expect(data.response).to eq response
    end
    it "returns a new openstruct when response is empty for some reason" do
      assert_request_received_with(:get, any_args).and_return nil
      data = subject.fetch_url "http://whatever.com"
      expect(data).to be_a OpenStruct
      expect(data.time_taken).to be > 0
    end

    it "yields and returns the sanitized response if a block is given" do
      response = spy("response", to_s: "whatever", uri: "http://whatever.com", code: 200)
      assert_request_received_with(:get, any_args).and_return response
      data = subject.fetch_url("http://whatever.com"){|res| res.body.reverse}
      expect(data).to eq "revetahw"
    end

    it "catches SSL  errors and yields to log_error defined by config options" do
      assert_http_client.to receive(:request).and_raise OpenSSL::SSL::SSLError, "SSL Error occurred"
      expect{subject.fetch_url "http://whatever.com"}.to output(/SSL Error occurred/).to_stdout
    end
    it "catches HTTP errors and yields to log_error defined by config options" do
      assert_http_client.to receive(:request).and_raise HTTP::Error, "HTTP Error occurred"
      expect{subject.fetch_url "http://whatever.com"}.to output(/HTTP Error occurred/).to_stdout
    end
    it "raises any other errors when making the connection" do
      assert_http_client.to receive(:request).and_raise RuntimeError, "Runtime Error occurred"
      expect{subject.fetch_url "http://whatever.com"}.to raise_error RuntimeError
    end
    it "raises HTTP, SSL error if log_error is not a proc" do
      set_config :log_error, nil
      assert_http_client.to receive(:request).and_raise HTTP::Error, "HTTP Error occurred"
      expect{subject.fetch_url "http://whatever.com"}.to raise_error HTTP::Error
    end
    it "allows log_error to be called with extraneous params" do
      set_config :log_error, ->(e, uri, opts){ print "#{e} #{uri} #{opts}" }
      assert_http_client.to receive(:request).and_raise HTTP::Error, "HTTP Error occurred"
      expect{subject.fetch_url "http://whatever.com"}.to output("HTTP Error occurred http://whatever.com {}").to_stdout
    end
  end

  describe "#sanitized_response" do
    it "does nothing if response does not implement `uri` method" do
      response = double("response", to_s: "whatever", code: 200)
      assert_request_received_with(:get, any_args).and_return response
      allow(response).to receive(:respond_to?).with(:uri).and_return false

      data = subject.fetch_url("http://whatever.com")
      expect(data).to be_a OpenStruct
      expect(data.response).to eq response
      expect(data.time_taken).to be > 0
    end
    it "returns an OpenStruct" do
      response = spy("response", to_s: "whatever", code: 200, uri: "http://whatever.com")
      assert_request_received_with(:get, any_args).and_return response

      expect(subject.fetch_url("http://whatever.com")).to be_a OpenStruct
    end
    it "sets response for the configured adapter" do
      response = spy("response", to_s: "whatever", code: 200, uri: "http://whatever.com")
      assert_request_received_with(:get, any_args).and_return response

      expect(config.adapter.response).to be_nil
      subject.fetch_url("http://whatever.com")
      expect(config.adapter.response).to eq response
    end
  end
end

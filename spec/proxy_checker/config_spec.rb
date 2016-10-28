describe ProxyChecker::Config do

  let(:port) { "12345" }
  let(:ip){ "123.123.123.123" }

  subject do
    VCR.use_cassette("config"){ ProxyChecker.config }
  end

  it "allows resetting to default config values" do
    expect(subject.read_timeout).to eq 10

    set_config :read_timeout, 1
    expect(subject.read_timeout).to eq 1

    subject.reset!
    expect(subject.read_timeout).to eq 10
  end

  context "with adapters" do
    it "sets `server` as the default adapter" do
      reset_config
      expect(subject.adapter).to be_a ProxyChecker::Adapter::Server
      expect(subject.adapter.name).to eq "server"
    end

    it "allows setting/choosing up another built-in adapter" do
      subject.adapter = :azenv
      expect(subject.adapter).to be_a ProxyChecker::Adapter::Azenv
      expect(subject.adapter.name).to eq "azenv"
    end

    it "raises error if unknown adapter is setup" do
      expect{ subject.adapter = :unknown }.to raise_error NotImplementedError
    end

    it "allows setting up a custom adapter" do
      dummy_adapter = Class.new{ def ping; :pong; end }
      expect { subject.adapter = dummy_adapter }.not_to raise_error
      expect(subject.adapter).to be_a dummy_adapter
      expect(subject.adapter.ping).to eq :pong
      expect { subject.adapter.name }.to raise_error NoMethodError
    end

    it "allows setting up a custom adapter based off base adapter" do
      dummy_adapter = Class.new(ProxyChecker::Adapter::Base) do
        def ping; :pong; end
      end
      subject.adapter = dummy_adapter
      expect(subject.adapter).to be_a dummy_adapter
      expect(subject.adapter.ping).to eq :pong
      expect(subject.adapter.name).to eq "custom"
    end

    it "has a list of all adapters derived from base adapter" do
      dummy_adapter = Class.new(ProxyChecker::Adapter::Base)
      expect(subject.adapters).to include dummy_adapter
      expect(subject.adapters).to include ProxyChecker::Adapter::Azenv
      expect(subject.adapters).to include ProxyChecker::Adapter::Server
    end
  end

  context "default values" do
    it "has default timeouts set for HTTP connections" do
      expect(subject.timeout).to include read_timeout: 10, connect_timeout: 5
    end
  end

  context "custom values" do
    it "allows setting up timeouts for the HTTP connections" do
      set_config :read_timeout, 1
      expect(subject.timeout).to include read_timeout: 1

      set_config :connect_timeout, 2
      expect(subject.timeout).to include connect_timeout: 2
    end

    it "allows setting up callback when errors occur when making HTTP/S connections" do
      set_config :log_error, -> (e){ puts e }
      allow_any_instance_of(HTTP::Client).to receive(:request).and_raise HTTP::Error, "Some Error Occurred"
      expect{ verify_protocol :http }.to output(/Some Error Occurred/).to_stdout
    end

    it "passes error, url, options and response object to the log_error callback if needed" do
      set_config :log_error, -> (e, uri, options) { puts "#{e.class}: #{uri}: #{options}" }
      allow_any_instance_of(HTTP::Client).to receive(:request).and_raise HTTP::Error, "Some Error Occurred"
      expect{ verify_protocol :http }.to output(/HTTP::Error: .*?http:\/\/.*?:\s+\{\}/).to_stdout
    end
  end

  context "adapter options" do
    it "has default values for adapter config options" do
      expect(subject.adapter.name).to eq "azenv"
      expect(subject.http_url).to include "azenv.php"
    end

    it "can set custom values for adapter config options" do
      set_config :http_url, "http://domain.com"
      expect(subject.http_url).to eq "http://domain.com"
    end

    it "does not allow setting up arbitrary config options for itself or adapter" do
      expect{ set_config :whatever, :is_false }.to raise_error NoMethodError
      expect{ subject.whatever }.to raise_error NoMethodError
    end

    it "does not allow setting up another adapter's config options when it is not in use" do
      dummy_adapter  = Class.new(ProxyChecker::Adapter::Base){ config_option :ping,  :pong  }
      dummy_adapter2 = Class.new(ProxyChecker::Adapter::Base){ config_option :ping2, :pong2 }
      set_config :adapter, dummy_adapter
      expect(subject.ping).to eq :pong
      expect{ subject.ping2 }.to raise_error NoMethodError
      expect{ set_config :ping2, :false }.to raise_error NoMethodError

      set_config :adapter, dummy_adapter2
      expect(subject.ping2).to eq :pong2
      expect{ subject.ping }.to raise_error NoMethodError
      expect{ set_config :ping, :false }.to raise_error NoMethodError

      set_config :adapter, dummy_adapter
      expect(subject.ping).to eq :pong
      expect{ set_config :ping2, :false }.to raise_error NoMethodError
    end

    it "overwrites earlier set config option when adapter is changed" do
      dummy_adapter  = Class.new(ProxyChecker::Adapter::Base){ config_option :ping, :pong  }
      dummy_adapter2 = Class.new(ProxyChecker::Adapter::Base){ config_option :ping, :pong2 }

      set_config :adapter, dummy_adapter
      expect(subject.ping).to eq :pong

      set_config :adapter, dummy_adapter2
      expect(subject.ping).to eq :pong2
    end
  end

  context "server current IP" do
    it "allows setting up the current IP address for the server" do
      set_config :current_ip, "123.123.123.123"
      expect(subject.current_ip).to eq "123.123.123.123"
    end
    it "reads current ip address for the server from env. variable" do
      allow(ENV).to receive(:[]).with("CURRENT_IP").and_return "8.8.8.8"
      expect(subject.current_ip).to eq "8.8.8.8"
    end

    it "reads current ip address for the server from local socket connections" do
      allow(ENV).to receive(:[]).and_return nil
      ips = Socket.ip_address_list << Addrinfo.tcp("1.1.1.1", 80)
      allow(Socket).to receive(:ip_address_list).and_return ips
      expect(subject.current_ip).to eq "1.1.1.1"
    end
  end

  # it "does whatever" do
  #   # expect(subject.current_ip).to eq "CURRENT_IP"
  #   # allow(ENV).to receive(:[]).and_return nil

  #   # expect_any_instance_of(HTTP::Client).to receive(:request).with(
  #   #   :get, subject.adapter.current_ip_url, {}
  #   # ).once.and_call_original

  #   # reset_config
  #   # VCR.use_cassette("config-current-ip") do
  #   #   expect(ProxyChecker.config.current_ip).not_to be_nil
  #   # end
  # end

  # it "allows parsing of response received from external service when querying current IP" do
  #   VCR.use_cassette("config-current-ip-parse") do
  #     allow(ENV).to receive(:[]).with("CURRENT_IP").and_return nil
  #     reset_config current_ip_url: "http://api.ipify.org/?format=text",
  #       parse_current_ip: -> (res){ res.raw_body }

  #     expect(subject.current_ip).not_to be_nil
  #     expect(subject.current_ip).to eq "117.203.3.218"
  #   end
  # end


  it "allows setting up callbacks for verifying which protocol was successful" do
    set_config :validate_http,  -> (res, url) { res.code == 500 }
    response = verify_protocol :http
    expect(response.count).to eq 2
    expect(response[0].success).to be_falsey
    expect(response[1].success).to be_falsey

    set_config :validate_https, -> (res, url) { res.code == 500 }
    response = verify_protocol :https
    expect(response.count).to eq 2
    expect(response[0].success).to be_falsey
    expect(response[1].success).to be_falsey

    set_config :validate_post,  -> (res, url) { res.code == 200 && res.content_type == "text/html" }
    response = verify_protocol :post
    expect(response.count).to eq 1
    expect(response[0].success).to be_truthy
  end

  it "allows choosing whether or not to keep HTTP/S requests that failed" do
    set_config :keep_failed_attempts, false

    set_config :validate_http, -> (res, url) { res.code == 200 }
    expect(verify_protocol(:http).count).to be 1

    set_config :validate_http, -> (res, url) { res.code == 500 }
    expect(verify_protocol(:http).count).to be 0
  end

  it "has default ssl context with VERIFY_NONE option set for HTTPS connections" do
    expect(subject.ssl_context).to be_a OpenSSL::SSL::SSLContext
    expect(subject.ssl_context.verify_mode).to be 0
  end
  it "allows setting up ssl context for the HTTPS connections" do
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.verify_mode = OpenSSL::SSL::VERIFY_PEER
    set_config :ssl_context, ctx

    expect(subject.ssl_context).to be_a OpenSSL::SSL::SSLContext
    expect(subject.ssl_context.verify_mode).to be 1
  end

  xit "allows setting up websites that need to be checked"
end

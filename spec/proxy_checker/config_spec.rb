describe ProxyChecker::Config do

  def set_config(key, val)
    ProxyChecker.configure{ |config| config.send "#{key}=", val }
  end

  def reset_config(defaults = {})
    ProxyChecker.config = nil
    ProxyChecker.configure do |config|
      defaults.each{ |key, val| config.send "#{key}=", val }
    end
  end

  let(:port) { "12345" }
  let(:ip){ "123.123.123.123" }

  let(:my_class) do
    Class.new{ include ProxyChecker::Utility }.new
  end

  subject do
    VCR.use_cassette("config"){ ProxyChecker.config }
  end

  it "has a default URL for fetching information about Proxy IP" do
    expect(subject.info_url).to eq "http://ip-api.com/json/%{ip}"
  end

  it "allows setting up URL for fetching information about the proxy IP" do
    set_config :info_url, "http://domain.com/%{ip}/%{port}"
    expect(subject.info_url).to eq "http://domain.com/%{ip}/%{port}"
    expect(my_class.info_url_for(ip, port)).to eq "http://domain.com/123.123.123.123/12345"
  end

  it "has default URLs for Proxy Judges" do
    expect(subject.judge_urls.count).to be 2
    expect(subject.judge_urls).to include "http://luisaranguren.com/azenv.php"
  end

  it "allows setting up URL for multiple Proxy Judges" do
    set_config :judge_urls, [ "http://domain.com/%{ip}/%{port}" ]
    expect(subject.judge_urls.count).to be 1
    expect(subject.judge_urls).to include "http://domain.com/%{ip}/%{port}"
  end

  it "has default URL for obtaining current IP" do
    expect(subject.current_ip_url).to eq "https://api.ipify.org/?format=text"
  end

  it "allows setting up URL to be used for obtaining current IP" do
    set_config :current_ip_url, "http://domain.com/current_ip"
    expect(subject.current_ip_url).to eq "http://domain.com/current_ip"
  end

  it "defaults to Env Variable or an External URL for obtaining current IP address" do
    expect(subject.current_ip).to eq "CURRENT_IP"
    allow(ENV).to receive(:[]).with("CURRENT_IP").and_return nil

    expect_any_instance_of(HTTP::Client).to receive(:request).with(:get, subject.current_ip_url, {}).once
    reset_config; subject.current_ip
  end

  it "allows setting up the current IP address for the server" do
    set_config :current_ip, "123.123.123.123"
    expect(subject.current_ip).to eq "123.123.123.123"
  end

  it "has default timeouts set for HTTP connections" do
    expect(subject.timeout).to include read_timeout: 10, connect_timeout: 5
  end

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
    set_config :log_error, -> (e, uri, options, response) { puts "#{e.class}: #{uri}: #{response} #{options}" }
    allow_any_instance_of(HTTP::Client).to receive(:request).and_raise HTTP::Error, "Some Error Occurred"
    expect{ verify_protocol :http }.to output(/HTTP::Error: .*?rx2\.eu.*?:  \{\}/).to_stdout
  end

  it "allows setting up callbacks for verifying which protocol was successful" do
    set_config :http_block, -> (key, uri, res, time) { res.code == 500 }
    response = verify_protocol :http
    expect(response.count).to eq 2
    expect(response[0].success).to be_falsey
    expect(response[1].success).to be_falsey

    set_config :https_block, -> (key, uri, res, time) { res.code == 500 }
    response = verify_protocol :https
    expect(response.count).to eq 2
    expect(response[0].success).to be_falsey
    expect(response[1].success).to be_falsey

    set_config :post_block, -> (key, uri, res, time) { res.code == 200 && res.content_type == "text/html" }
    response = verify_protocol :post
    expect(response.count).to eq 1
    expect(response[0].success).to be_truthy
  end

  it "allows choosing whether or not to keep HTTP/S requests that failed" do
    set_config :keep_failed_attempts, false

    set_config :http_block, -> (key, uri, res, time) { res.code == 200 }
    expect(verify_protocol(:http).count).to be 1

    set_config :http_block, -> (key, uri, res, time) { res.code == 500 }
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

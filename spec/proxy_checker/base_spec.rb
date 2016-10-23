describe ProxyChecker::Base do
  subject{ described_class.new("123.123.123.123", "12345") }

  def run(name, defaults = {}, &block)
    ENV['CURRENT_IP'] = nil
    ProxyChecker.config = nil
    defaults.map{|key, val| ProxyChecker.config.send("#{key}=", val)}

    @data = with_cassette_for(name) do
      described_class.new(@ip, @port).fetch(&block)
    end

    @data.each do |key, val|
      instance_variable_set("@#{key}", val)
    end
  end

  it "stores the proxy IP address in an instance variable" do
    expect(subject.ip).to eq "123.123.123.123"
    expect(subject.instance_variable_get("@ip")).to eq "123.123.123.123"
  end

  it "stores the proxy Port in an instance variable" do
    expect(subject.port).to eq 12345
    expect(subject.instance_variable_get("@port")).to eq 12345
  end

  it "fetches information about the Proxy IP address" do
    run(:basic){ fetch_basic_information }
    expect(@info).to include("country_code" => "FR")
    expect(@info).to include("lat" => 48.8667, "lon" => 2.3333)
    expect(@info).to include("ip" => "94.177.243.88", "status" => "success")
    expect(@info).to include("city" => "Paris", "country" => "France")
    expect(@info).to include("asn" => "AS199653", "region" => "Île-de-France")
    expect(@info).to include("org" => "Aruba S.p.A.", "isp" => "Aruba S.p.A.")
    expect(@info).not_to include("regionName", "countryCode", "as", "query")
  end

  it "fetches the IP exposed by the proxy on the internet" do
    run(:exposed_ip){ fetch_information :exposed_ip }
    expect(@info).to include "exposed_ip" => "94.177.243.88"
    expect(@websites).to be_empty
  end

  it "calculates the level of anonymity for the proxy" do
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "transparent"
    expect(@info).not_to include "exposed_ip"
    expect(@protocols.keys).to eq ['http', 'https']
    expect(@protocols["http"]).not_to be_empty
    expect(@protocols["https"]).not_to be_empty
  end

  it "marks the proxy level as `skipped` if current server IP can not be deduced" do
    allow_any_instance_of(ProxyChecker::Config).to receive(:current_ip).and_return "  "
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "skipped"
  end

  it "marks the proxy level as `failed` if proxy exposes current IP completely" do
    allow_any_instance_of(ProxyChecker::Config).to receive(:current_ip).and_return "94.177.243.88"
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "failed"
  end

  it 'marks the proxy level as `na` if proxy cannot make both HTTP/S connections' do
    stub_request(:get, /.*/).to_return body: "", headers: { "Content-Type" => "text/html" }
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "na"
  end

  it "marks the proxy level as `transparent` if current server IP is exposed" do
    allow_any_instance_of(ProxyChecker::Config).to receive(:current_ip).and_return "117.203.3.218"
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "transparent"
  end

  it "marks the proxy level as `anonymous` if current server IP is not exposed, but proxy reveals itself" do
    stub_request(:get, /.*/).to_return body: "<pre>PROXY_FOR = 123.123.123.124</pre>", status: 200, headers: { "Content-Type" => "text/html" }
    allow_any_instance_of(ProxyChecker::Config).to receive(:current_ip).and_return "123.123.123.123"
    allow_any_instance_of(ProxyChecker::Config).to receive(:validate_http).and_return -> (*a){ true }
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "anonymous"
  end

  it "marks the proxy level as `elite` if proxy does not reveal itself at all" do
    stub_request(:get, /.*/).to_return body: "<pre>REMOTE_ADDR = 123.123.123.124</pre>", status: 200, headers: { "Content-Type" => "text/html" }
    allow_any_instance_of(ProxyChecker::Config).to receive(:current_ip).and_return "123.123.123.123"
    allow_any_instance_of(ProxyChecker::Config).to receive(:validate_http).and_return -> (*a){ true }
    run("proxy-level"){ fetch_information :level }
    expect(@info).to include "level" => "elite"
  end

  it "verifies if the proxy tempers with the response from the server" do
    data = run("proxy-temperance"){ fetch_information :temperance }
    expect(@info['temperance']).to eq "body" => false, "content_type" => false, "headers" => false

    stub_request(:get, /.*gist\.github.*/).to_return body: '{"a": "b"}', headers: { "Content-Type" => "application/json"}
    data = run("proxy-temperance"){ fetch_information :temperance }
    expect(@info['temperance']).to eq "body" => true, "content_type" => true, "headers" => true
  end
end

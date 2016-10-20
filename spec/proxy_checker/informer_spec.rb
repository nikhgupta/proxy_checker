describe ProxyChecker::Informer do
  subject{ described_class.new("123.123.123.123", "12345") }
  it "stores the proxy IP address in an instance variable" do
    expect(subject.port).to eq 12345
    expect(subject.ip).to eq "123.123.123.123"
  end

  it "stores the proxy Port in an instance variable" do
    expect(subject.instance_variable_get("@ip")).to eq "123.123.123.123"
    expect(subject.instance_variable_get("@port")).to eq 12345
  end

  it "Fetches information about the Proxy IP address" do
    with_cassette_for("info") do
      info = subject.fetch
      expect(info).to include("country_code" => "CN")
      expect(info).to include("lat" => 39.9289, "lon" => 116.3883)
      expect(info).to include("ip" => "123.123.123.123", "status" => "success")
      expect(info).to include("city" => "Beijing", "country" => "China")
      expect(info).to include("asn" => "AS4808", "region" => "Beijing")
      expect(info).to include("org" => "China Unicom Beijing", "isp" => "China Unicom Beijing")
      expect(info).not_to include("regionName", "countryCode", "as", "query")
    end
  end
end

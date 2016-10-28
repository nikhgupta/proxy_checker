describe ProxyChecker do
  it "has a version number" do
    expect(ProxyChecker::VERSION).not_to be nil
  end

  it "allows quick access to configuration values" do
    expect(ProxyChecker.config).to be_a ProxyChecker::Config
    expect(ProxyChecker.config).to eq ProxyChecker.config
    expect(ProxyChecker.config).to respond_to(:reset!)
    expect(ProxyChecker.config.read_timeout).to eq 10
  end

  describe ".new" do
    it "provides a convenient method to instantiate the DSL" do
      checker  = ProxyChecker.new("123.123.123.123", "12345"){ fetch_information }
      expect(checker).to be_a ProxyChecker::DSL
      expect(checker.ip).to eq "123.123.123.123"
      expect(checker.port).to eq 12345

      expect(checker).to receive(:fetch_information)
      expect(checker).not_to receive(:check_protocols)
      checker.fetch
    end
  end

  describe ".data_for" do
    it "provides convenient method to query information about the proxy" do
      response = with_cassette_for(:dsl) do
        ProxyChecker.data_for(@ip, @port){ fetch_information }
      end

      expect(response["websites"]).to     be_empty
      expect(response["protocols"]).to    be_empty
      expect(response["capabilities"]).to be_empty

      expect(response["info"].keys).to eq ["basic_info"]
      expect(response["info"]['basic_info']).to include "ip" => TEST_PROXY_IP, "isp" => "OVH SAS"
    end
  end
end

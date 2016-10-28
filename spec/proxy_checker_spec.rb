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

  it "provides convenient DSL to query information about the proxy" do
    response = with_cassette_for(:dsl){
      checker = ProxyChecker.new(@ip, @port){ fetch_information }
      checker.fetch
    }

    expect(checker).to    be_a ProxyChecker::DSL
    expect(checker.ip).to   eq TEST_PROXY_IP
    expect(checker.port).to eq TEST_PROXY_PORT

    expect(response.data["websites"]).to be_empty
    expect(response.data["protocols"]).to be_empty
    expect(response.data["capabilities"]).to be_empty

    expect(response.data["info"].keys).to eq ["basic_info"]
    expect(response.data["info"]['basic_info']).to include "ip" => TEST_PROXY_IP, "isp" => "OVH SAS"
  end

  # it "provides convenient method to query information about the proxy" do
  #   ProxyChecker.config.log_error = nil
  #   data = with_cassette_for(:check){ ProxyChecker.check(@ip, @port, info: false, protocols: [:http, :https]) }
  #   expect(data).to include :http, :https
  #   expect(data).not_to include :info, :post
  # end
end

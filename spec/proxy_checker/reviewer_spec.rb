describe ProxyChecker::Reviewer do
  let(:ip){ TEST_PROXY_IP }
  let(:port){ TEST_PROXY_PORT }

  subject{ fetch }
  let(:reviewer){ described_class.new(ip, port) }

  def fetch(*args)
    ProxyChecker.config.log_error = nil
    with_cassette_for(:reviewer, ip, port){ reviewer.fetch(*args) }
  end

  # around :each do |example|
  #   ProxyChecker.config.log_error = nil
  #   with_cassette_for(:reviewer) do
  #     @reviewer = described_class.new(@ip, @port)
  #   end
  # end

  it "verifies HTTP Protocol" do
    expect(subject[:http].count).to be 1
    expect(subject[:http][0].success).to be_truthy
    expect(subject[:http][0].timestamp).to be > 0
    expect(subject[:http][0].response.code).to be 200
  end

  it "verifies HTTPS Protocol" do
    expect(subject[:https].count).to be 2
    expect(subject[:https][0].success).to be_falsey
    expect(subject[:https][1].success).to be_truthy
    expect(subject[:https][1].timestamp).to be > 0
    expect(subject[:https][0].response.code).to be 200
    expect(subject[:https][1].response.code).to be 200
  end

  it "verifies POSTing capability for the proxy" do
    expect(subject[:post].count).to be 2
    expect(subject[:post][0].success).to be_falsey
    expect(subject[:post][1].success).to be_truthy
    expect(subject[:post][1].timestamp).to be > 0
    expect(subject[:post][1].response.code).to be 200
    expect(subject[:post][0].response.error).to eq HTTP::StateError
  end

  it "allows fetching requests for particular protocols/capabilities" do
    expect(reviewer).not_to receive(:supports_url_for_protocol?).with(:https, any_args)
    expect(reviewer).not_to receive(:supports_url_for_protocol?).with(:post,  any_args)
    expect(reviewer).to receive(:supports_url_for_protocol?).with(:http, any_args).at_least(:once)
    fetch :http
  end

  it "only fetches information from the first URL that gives success" do
    expect(reviewer).not_to receive(:supports_url_for_protocol?).with(:http, any_args)
    expect(reviewer).to receive(:supports_url_for_protocol?).with(:post,  any_args).twice.and_call_original
    expect(reviewer).to receive(:supports_url_for_protocol?).with(:https, any_args).twice.and_call_original
    fetch :https, :post
  end

  it "sets up instance variables for the protocols/capabilities it verifies as the first successful result" do
    data = fetch :http, :https, :post
    expect(reviewer.instance_variable_get("@http")).to  eq data[:http][0]
    expect(reviewer.instance_variable_get("@post")).to  eq data[:post][1]
    expect(reviewer.instance_variable_get("@https")).to eq data[:https][1]
  end
end

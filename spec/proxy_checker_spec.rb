describe ProxyChecker do
  it "has a version number" do
    expect(ProxyChecker::VERSION).not_to be nil
  end

  it "provides convenient method to query information about the proxy" do
    ProxyChecker.config.log_error = nil
    data = with_cassette_for(:check){ ProxyChecker.check(@ip, @port) }
    expect(data).to include :info, :http, :https, :post
    expect(data[:info]).to include "city" => "Paris", "country" => "France"
    expect(data[:http][0].success).to be_truthy
  end

  it "provides convenient method to query information about the proxy" do
    ProxyChecker.config.log_error = nil
    data = with_cassette_for(:check){ ProxyChecker.check(@ip, @port, info: false, protocols: [:http, :https]) }
    expect(data).to include :http, :https
    expect(data).not_to include :info, :post
  end
end

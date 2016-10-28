describe ProxyChecker::Adapter::Base do
  let(:dummy_adapter) do
    Class.new(described_class) do
      config_option :http_url, "http://luisaranguren.com/azenv.php"

      def parse_response
        "dummy response"
      end
    end
  end

  let(:subject){ config.adapter }

  before(:each){ set_config :adapter, dummy_adapter }

  it "has a name for the adapter" do
    expect(subject.name).to eq "custom"
  end

  it "allows setting up the proxy to check" do
    subject.check("123.123.123.123", "12345")
    expect(subject.ip).to eq "123.123.123.123"
    expect(subject.port).to eq 12345
  end

  it "has a default method to parse the response received from external services" do
    set_config :adapter, :azenv
    expect(config.adapter).to receive(:parse_response).and_call_original
    expect(config.http_url).to include "azenv.php"

    data = with_cassette_for("parse-response") do
      ProxyChecker.data_for("123.123.123.123", 12345){ check_protocols :http }
    end

    expect(data["protocols"]["http"].parsed).to include "HTTP_HOST" => "luisaranguren.com"
  end

  it "allows custom method to parse the response received from the external services" do
    expect(config.adapter).to receive(:parse_response).and_call_original
    expect(config.previous_adapter).not_to receive(:parse_response)

    data = with_cassette_for("parse-response") do
      ProxyChecker.data_for("123.123.123.123", 12345){ check_protocols :http }
    end

    expect(data["protocols"]["http"].parsed).to eq "dummy response"
  end

  it "has validation methods for HTTP protocol" do

  end

  xit "on empty parsed response"
end


describe ProxyChecker::Adapter::Azenv do
  before(:each){ set_config :adapter, :azenv }
  subject{ config.adapter }

  it "has a name" do
    expect(subject.name).to eq "azenv"
  end

  it "parses the response received from the Azenv script" do
    expect(subject).to receive(:parse_response).and_call_original
    data = with_cassette_for("azenv-response") do
      ProxyChecker.data_for(@ip, @port){ check_protocols :http }
    end
    expect(data["protocols"]["http"].parsed).to include "HTTP_HOST" => "luisaranguren.com"
  end

  it "validates the response received for successful HTTP connection" do
    expect(subject).to receive(:validate_http).and_call_original
    data = with_cassette_for("azenv-response") do
      ProxyChecker.data_for(@ip, @port){ check_protocols :http }
    end
    expect(data["protocols"]["http"].parsed).to include "HTTP_HOST" => "luisaranguren.com"
  end
end

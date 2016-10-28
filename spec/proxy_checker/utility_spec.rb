describe ProxyChecker::Utility do
  let(:md_uri)  { "https://rawgit.com/nikhgupta/3a8703f8659a1739647c3c480a95ed87/raw/6ada5385033609f843155e57949c244c9c6188d8/sample.md" }
  let(:xml_uri) { "https://rawgit.com/nikhgupta/3a8703f8659a1739647c3c480a95ed87/raw/6ada5385033609f843155e57949c244c9c6188d8/sample.xml" }
  let(:json_uri){ "https://rawgit.com/nikhgupta/3a8703f8659a1739647c3c480a95ed87/raw/6ada5385033609f843155e57949c244c9c6188d8/sample.json" }
  let(:html_uri){ "https://rawgit.com/nikhgupta/3a8703f8659a1739647c3c480a95ed87/raw/6ada5385033609f843155e57949c244c9c6188d8/sample.html" }

  let(:my_class){ Class.new{ include ProxyChecker::Utility } }
  subject{ my_class.new }

  def fetch_url(type, name = nil)
    VCR.use_cassette("#{name || type}-fetch-url") do
      subject.fetch_url send("#{type}_uri")
    end
  end

  describe "#fetch_url" do
    it "fetches the given URI" do
      data = fetch_url :json
      expect(URI.parse(data.uri.to_s).path).to eq URI.parse(json_uri).path
      expect(data.code).to eq 200
      expect(data.message).to eq "OK"

      expect(data.charset).to eq "utf-8"
      expect(data.streaming).to be_truthy
      expect(data.content_length).to be_nil
      expect(data.content_type).to eq "application/json"

      expect(data.proxy_headers).to be_empty
      expect(data.headers).to include "Server" => "cloudflare-nginx"
      expect(data.cookies).to include "__cfduid"

      expect(data.body).to include "note"
      expect(data.body["note"]).to include "to" => "Tove"
    end

    it "parses response body as per the content type" do
      data = fetch_url :xml
      expect(data.content_type).to eq "text/xml"
      # expect(data.body).to include "<heading>Reminder</heading>"
      pending "Should serve Hash for XML instead."
      expect(data.body).to include "note"
      expect(data.body["note"]).to include "heading" => "Reminder"
    end

    context "logging errors when fetching URLs" do
      it "passes errors to the log_error block specified" do
        ProxyChecker.config.log_error = -> (e) { print e }
        expect_any_instance_of(HTTP::Client).to receive(:get).and_raise HTTP::Error, "Some Error"
        expect{ fetch_url :json }.to output("Some Error").to_stdout
      end

      it "passes errors to the log_error block specified along with extra options if requested" do
        ProxyChecker.config.log_error = -> (e, uri, options) { print "#{e}\n#{uri}\n#{options.keys.join}" }
        expect_any_instance_of(HTTP::Client).to receive(:get).and_raise HTTP::Error, "Some Error"
        expect{ fetch_url :json }.to output("Some Error\n#{json_uri}\nssl_context").to_stdout
      end
    end
  end
end

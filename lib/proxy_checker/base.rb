module ProxyChecker
  class Base
    include ProxyChecker::Utility
    attr_accessor :ip, :port, :data

    def initialize(ip, port)
      @ip, @port, @deferred = ip, port.to_i, []
      @info, @protocols, @capabilities, @websites = {}, {}, {}, {}
    end

    def fetch(&block)
      self.instance_eval &block
      self.data
    end

    def data
      { "info" => @info, "protocols" => @protocols, "capabilities" => @capabilities, "websites" => @websites }
    end

    def fetch_basic_information
      url = config.info_url % { ip: @ip, port: @port }
      response = fetch_url(url, proxy: false).body
      response["ip"] = response.delete("query")
      response["asn"] = response.delete("as").match(/\A(AS.*?)\s.+\z/)[1] rescue nil
      response["region"] = response.delete("regionName")
      response["country_code"] = response.delete("countryCode")
      @info = response
    end

    def fetch_information(*fields)
      fields.each{ |field| @info[field.to_s] ||= send("get_proxy_#{field}") }
    end

    def check_protocols(*fields)
      fields.each{ |field| @protocols[field.to_s] ||= send("check_#{field}_protocol") }
    end

    def check_capabilities(*fields)
      fields.each{ |field| @capabilities[field.to_s] ||= send("check_#{field}_capability") }
    end

    def check_website(url)
      uri = URI.parse(url.to_s)
      @websites[uri.host] ||= {}
      @websites[uri.host][uri.to_s] = uri.to_s
    end

    protected

    def get_proxy_exposed_ip
      response = fetch_url config.current_ip_url
      config.parse_current_ip ? config.parse_current_ip.call(response) : response.body
    end

    def get_proxy_level
      check_protocols :http, :https
      response = @protocols[ssl_supported? ? 'https' : 'http'].last.response

      return 'na'          if proxy_failed?
      return 'skipped'     if config.current_ip.to_s.strip.empty? || config.current_ip == "error"
      return 'failed'      if response.body["REMOTE_ADDR"] == config.current_ip
      return 'transparent' if response.body.values.any?{|val| val.include?(config.current_ip)}
      return 'anonymous'   if response.body.keys.join =~ /(PROXY|FORWARDED|HTTP_VIA|HTTP_X_VIA)/
      return 'elite'
    end

    def get_proxy_speed
      get_proxy_temperance
      check_capabilities :post
      check_protocols :http, :https
    end


    # Check if the proxy tempers with the data returned by the server.
    # - by verifying the body of the response
    # - by verifying that content-type header is kept the same
    # - by verifying that no header has been added/removed
    #
    def get_proxy_temperance
      data = fetch_url config.digest_url
      body = data.body['text'] != Digest::SHA512.hexdigest("nikhgupta")
      content_type = data.headers['Content-Type'] != "text/plain; charset=utf-8"
      headers = Digest::MD5.hexdigest(data.headers.keys.join) != "e9e58bd05b9eb991e07ec923f3ec2863"
      { "body" => body, "content_type" => content_type, "headers" => headers }
    end

    def check_http_protocol
      query_judges ssl: false, &config.validate_http
    end

    def check_https_protocol
      query_judges ssl: true, &config.validate_https
    end

    def check_post_capability
      check_protocols :http, :https
      query_judges ssl: ssl_supported?, method: :post, body: "test=text", &config.validate_post
    end

    private

    def proxy_success?
      http_supported? || ssl_supported?
    end

    def proxy_failed?
      !proxy_success?
    end

    def http_supported?
      @protocols["http"] && @protocols["http"].last && @protocols["http"].last.success
    end

    def ssl_supported?
      @protocols["https"] && @protocols["https"].last && @protocols["https"].last.success
    end
  end
end

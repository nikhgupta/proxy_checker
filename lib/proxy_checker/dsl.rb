module ProxyChecker
  class DSL
    include ProxyChecker::Utility

    attr_accessor :ip, :port, :data

    def initialize(ip, port, &block)
      @data_block = block
      self.set_proxy(ip, port)
    end

    def set_proxy(ip, port)
      @ip, @port = ip, port.to_i
    end

    def data
      { "info" => @info, "protocols" => @protocols, "capabilities" => @capabilities, "websites" => @websites }
    end

    def reset!
      @info, @protocols, @capabilities, @websites = {}, {}, {}, {}
      @speeds, @deferred = [], []
    end

    def fetch(&block)
      reset!

      block ||= @data_block
      block ? instance_eval(&block) : fetch_all

      self.data
    end

    def fetch_all
      reset!

      fetch_information  :basic_info, :exposed_ip, :level, :speed, :temperance
      check_protocols    :http, :https
      check_capabilities :post

      self.data
    end

    def sanitized_response(options = {})
      config.adapter.response = @response
      parsed = config.adapter.parse_response || config.adapter.response.parse

      OpenStruct.new(
        uri:            @response.uri,
        code:           @response.code,
        message:        @response.reason,
        parsed:         parsed,
        body:           @response.to_s,
        charset:        @response.charset,
        cookies:        config.adapter.parse_cookies,
        content_type:   @response.mime_type,
        content_length: @response.content_length,
        headers:        @response.headers.to_h,
        proxy_headers:  @response.proxy_headers.to_h,
        streaming:      config.adapter.streaming?
      )
    end

    def fetch_information(*fields)
      fields |= [ :basic_info ]
      extract_information :info, fields
    end

    def check_protocols(*fields)
      extract_information :protocols, fields
    end

    def check_capabilities(*fields)
      extract_information :capability, fields
    end

    def check_proxy_for_basic_info
      response = fetch_ip_information(@ip)
      response["ip"] = response.delete("query")
      response["asn"] = response.delete("as").match(/\A(AS.*?)\s.+\z/)[1] rescue nil
      response["region"] = response.delete("regionName")
      response["country_code"] = response.delete("countryCode")
      @info = response
    end

    def check_website
    end

    def check_proxy_for_exposed_ip
      @info['exposed_ip'] = fetch_external_ip proxy: { ip: @ip, port: @port }
    end

    def check_proxy_for_level
      check_protocols :http, :https
      response = @protocols[http_supported? ? 'http' : 'https'].last.response

      @info['level'] = case
      when proxy_failed? then :na
      when config.current_ip.to_s.strip.empty? then :skipped
      when response.parsed['REMOTE_ADDR'] == config.current_ip then :failed
      when response.parsed.values.any?{|val| val.include?(config.current_ip)} then :transparent
      when response.parsed.keys.join =~ /(PROXY|FORWARDED|HTTP_VIA|HTTP_X_VIA)/ then :anonymous
      else :elite
      end
    end

    def check_proxy_for_speed
      check_proxy_for_temperance
      check_capabilities :post
      check_protocols :http, :https

      speeds = data.values.map(&:values).flatten.map do |val|
        val.timestamp if val.respond_to?(:success) && val.success
      end

      speeds = (speeds << @speeds).flatten.compact
      @info['speed'] = (speeds.inject(0, :+) / speeds.count).to_i
    end

    # Check if the proxy tempers with the data returned by the server.
    # - by verifying the body of the response
    # - by verifying that content-type header is kept the same
    # - by verifying that no header has been added/removed
    #
    def check_proxy_for_temperance
      data = fetch_url_with_proxy config.digest_url
      if data && data.body
        body = data.body != Digest::SHA512.hexdigest("nikhgupta")
        content_type = data.headers['Content-Type'] != "text/plain; charset=utf-8"
        headers = Digest::MD5.hexdigest(data.headers.keys.join) != "e9e58bd05b9eb991e07ec923f3ec2863"
        @speeds << data.timestamp
      else
        body = content_type = headers = nil
      end
      @info['temperance'] = { "body" => body, "content_type" => content_type, "headers" => headers }
    end

    def check_proxy_for_http
      @protocols['http'] = fetch_url(config.http_url, ssl: false) do |response|
        config.adapter.validate_http(response)
      end
    end

    def check_proxy_for_https
      config.https_url ||= ->(uri){uri = URI.parse(uri); uri.scheme = "https"; uri}[config.http_url]
      @protocols['https'] = fetch_url config.https_url, ssl: true
    end

    def check_proxy_for_post
      check_protocols :http, :https
      config.post_url ||= http_supported? ? config.http_url : config.https_url
      @protocols['post'] = fetch_url config.post_url, method: :post, body: "text=test"
    end

    private

    def fetch_external_ip(options = {})
      response = fetch_url config.current_ip_url, options do |response|
        JSON.parse response.body
      end
      response["query"]
    end

    def fetch_ip_information(ip, port = 80, options = {})
      url = config.info_url % { ip: ip, port: port }
      fetch_url(url, options){ |response| JSON.parse response.body }
    end

    def extract_information(key, fields = [])
      var = instance_variable_get("@#{key}")
      fields.each{ |field| var[field.to_s] ||= send("check_proxy_for_#{field}") }
      instance_variable_set "@#{key}", var
    end
  end
end

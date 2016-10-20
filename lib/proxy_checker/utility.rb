module ProxyChecker
  module Utility
    def config
      ProxyChecker.config
    end

    def agent(timeout = {})
      return @agent if @agent
      uagent  = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.143 Safari/537.36"
      timeout = { connect: 10, read: 5 } if timeout.empty?
      @agent  = HTTP["User-Agent" => uagent].follow
        .timeout(:per_operation, timeout)
        .headers(content_type: "text/plain")
    end

    def fetch_url(uri, options = {})
      uri    = URI.parse(uri.to_s)
      proxy  = options.delete(:proxy)  || {}
      method = options.delete(:method) || :get

      options.merge!(ssl_context: config.ssl_context) if uri.scheme == "https"

      http = agent connect: config.connect_timeout, read: config.read_timeout
      http = http.via(proxy[:ip], proxy[:port]) unless proxy.empty?

      response = http.send method, uri.to_s, options
      OpenStruct.new(
        uri: response.uri,
        code: response.code,
        message: response.reason,
        body: (response.parse rescue response.to_s),
        charset: response.charset,
        cookies: response.cookies.to_h,
        content_type: response.mime_type,
        content_length: response.content_length,
        headers: response.headers.to_h,
        proxy_headers: response.proxy_headers.to_h
      )
    rescue HTTP::Error, OpenSSL::SSL::SSLError => e
      config.log_error.call(e, uri, options, response)
      return OpenStruct.new(uri: uri, error: e.class, message: e.message)
    end

    def fetch_url_with_timestamp(url, options = {})
      time = Time.now
      response = fetch_url(url, options)
      OpenStruct.new response: response, timestamp: ((Time.now - time) * 1000).to_i
    end
  end
end

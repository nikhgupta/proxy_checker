module ProxyChecker
  module Utility
    def config
      ProxyChecker.config
    end

    def agent(options = {})
      @agent ||= HTTP["User-Agent" => options.fetch(:user_agent, config.user_agent)]
        .timeout(:per_operation, options.fetch(:timeout, config.timeout))
        .headers(content_type: options.fetch(:content_type, "text/plain"))
        .follow
    end

    def fetch_url(uri, options = {})
      uri    = URI.parse(uri.to_s)
      method = options.delete(:method) || :get

      if options.delete(:ssl) || uri.scheme == "https"
        uri.scheme = "https"
        options[:ssl_context] = config.ssl_context
      end

      proxy = options.delete(:proxy) || {}
      proxy[:port] = proxy[:port].to_i if proxy[:port]
      http = proxy.empty? ? agent : agent.via(*proxy.values)

      time       = Time.now
      @response  = http.send method, uri.to_s, options
      time_taken = Time.now - time
      @response  = sanitized_response || OpenStruct.new
      @response.time_taken = time_taken

      block_given? ? yield(@response) : @response
    rescue HTTP::Error, OpenSSL::SSL::SSLError => e
      if config.log_error.respond_to?(:call) && config.log_error.arity == 1
        config.log_error.call(e)
      elsif config.log_error.respond_to?(:call)
        config.log_error.call(e, uri, options)
      else
        raise
      end
    end

    def sanitized_response
      return OpenStruct.new(response: @response) unless @response.respond_to?(:uri)
      config.adapter.response = @response
      OpenStruct.new(
        uri:            @response.uri,
        code:           @response.code,
        message:        @response.reason,
        parsed:         parse_response,
        body:           @response.to_s,
        charset:        @response.charset,
        cookies:        parse_cookies,
        content_type:   @response.mime_type,
        content_length: @response.content_length,
        headers:        @response.headers.to_h,
        proxy_headers:  @response.proxy_headers.to_h,
        streaming:      streaming?
      )
    end

    def parse_response
      config.adapter.parse_response
    rescue NoMethodError
      @response.parse rescue @response.to_s
    end

    def parse_cookies
      config.adapter.parse_cookies
    rescue NoMethodError
      Hash[@response.cookies.map{|v| v.to_s.split("=")}] rescue {}
    end

    def streaming?
      config.adapter.streaming?
    rescue NoMethodError
      @response.headers["Transfer-Encoding"] == "chunked" rescue false
    end
  end
end

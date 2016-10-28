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
      @response = nil
      uri    = URI.parse(uri.to_s)
      method = options.delete(:method) || :get

      if options.delete(:ssl) || uri.scheme == "https"
        uri.scheme = "https"
        options[:ssl_context] = config.ssl_context
      end

      proxy = options.delete(:proxy) || {}
      http = proxy.nil? || proxy.empty? ? agent : agent.via(*proxy.values)

      time       = Time.now
      @response  = http.send method, uri.to_s, options
      time_taken = Time.now - time
      @response  = sanitized_response
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
  end
end

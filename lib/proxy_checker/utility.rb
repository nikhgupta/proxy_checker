module ProxyChecker
  module Utility

    def config
      ProxyChecker.config
    end

    def info_url_for(ip, port)
      config.info_url % { ip: ip, port: port }
    end

    def agent(timeout = {})
      return @agent if @agent
      uagent  = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.143 Safari/537.36"
      timeout = { connect: 10, read: 5 } if timeout.nil? || timeout.empty?
      @agent  = HTTP["User-Agent" => uagent].follow
        .timeout(:per_operation, timeout)
        .headers(content_type: "text/plain")
    end

    def fetch_url(uri, options = {})
      uri = URI.parse(uri.to_s)
      method = options.delete(:method) || :get
      options[:ssl_context] = config.ssl_context if options.delete(:ssl)

      http = agent connect: config.connect_timeout, read: config.read_timeout
      http = http.via(@ip, @port) if options.delete(:proxy) != false
      response = http.send method, uri.to_s, options
      config.sanitize_response(response)
    rescue HTTP::Error, OpenSSL::SSL::SSLError => e
      if config.log_error.respond_to?(:call) && config.log_error.arity == 1
        config.log_error.call(e)
      elsif config.log_error.respond_to?(:call)
        config.log_error.call(e, uri.to_s, options, response)
      end
      OpenStruct.new(uri: uri, error: e.class, message: e.message)
    end

    def fetch_url_with_timestamp(url, options = {})
      time = Time.now
      response = fetch_url(url, options)
      OpenStruct.new response: response, timestamp: ((Time.now - time) * 1000).to_i
    end

    def query_judges(options = {}, &block)
      options[:ssl] ||= ssl_supported?
      successful = false
      responses = config.judge_urls.map do |url|
        next if successful
        data = fetch_url_with_timestamp url, options
        data.success = successful = block.call data.response, url if block
        data
      end.compact

      responses.select(&:success) unless config.keep_failed_attempts
      responses
    end
  end
end

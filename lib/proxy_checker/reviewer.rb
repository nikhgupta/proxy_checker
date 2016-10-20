module ProxyChecker
  class Reviewer
    include ProxyChecker::Utility

    def initialize(ip, port)
      @ip, @port = ip, port
    end

    def fetch
      props = {
        http: { ssl: false },
        https: { ssl: true },
        post: { method: :post, body: "text=test" }
      }
      props = Hash[props.map{|key, options| [key, supports_protocol?(key, options)]}]
      binding.pry
    end

    private

    def supports_protocol?(protocol, options = {})
      config.judge_urls.map do |url|
        already_checked = instance_variable_get("@#{protocol}")
        next if already_checked && already_checked.success
        supports_url_for_protocol?(protocol, url, options)
      end.select do |data|
        data && (data.success || config.keep_failed_attempts)
      end
    end

    def supports_url_for_protocol?(protocol, url, options = {})
      uri, options = URI.parse(url), options.dup
      uri.scheme   = options.delete(:ssl) || (@https && @https.success) ? "https" : "http"
      block        = config.send(options.delete(:block) || "#{protocol}_block")
      data         = fetch_url_with_timestamp uri.to_s, options
      data.success = block.call protocol, uri, data.response, data.timestamp
      instance_variable_set "@#{protocol}", data
      data
    end
  end
end

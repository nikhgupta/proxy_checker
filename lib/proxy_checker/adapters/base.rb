module ProxyChecker
  module Adapter
    class Base

      include ProxyChecker::DSL
      include ProxyChecker::Utility

      class << self
        attr_accessor :options, :adapters

        def config_option(key, val)
          @options ||= {}
          @options[key] = val
        end

        def inherited(base)
          @adapters ||= []
          @adapters << base
        end
      end

      attr_accessor :ip, :port, :data

      def initialize
        @deferred = []
        @info, @protocols, @capabilities, @websites = {}, {}, {}, {}
        @speeds = []

        instance_eval { yield } if block_given?
      end

      def name
        @name ||= self.class.name.demodulize.underscore
      end

      def data
        { "info" => @info, "protocols" => @protocols, "capabilities" => @capabilities, "websites" => @websites }
      end

      protected

      def fetch_external_ip(options = {})
        response = fetch_url config.current_ip_url, options
        response.parsed["query"]
      end

      def ip_information(ip, port = 80, options = {})
        url = config.info_url % { ip: ip, port: port }
        response = fetch_url url, options
        response.parsed
      end

      def check_proxy_for_exposed_ip
        fetch_external_ip proxy: { ip: @ip, port: @port }
      end

      def check_proxy_for_level
        check_protocols :http, :https
        response = @protocols[http_supported? ? 'http' : 'https'].last.response

        return 'na'          if proxy_failed?
        return 'skipped'     if config.current_ip.to_s.strip.empty? || config.current_ip == "error"
        return 'failed'      if response.body["REMOTE_ADDR"] == config.current_ip
        return 'transparent' if response.body.values.any?{|val| val.include?(config.current_ip)}
        return 'anonymous'   if response.body.keys.join =~ /(PROXY|FORWARDED|HTTP_VIA|HTTP_X_VIA)/
        return 'elite'
      end

      def check_proxy_for_speed
        check_proxy_for_temperance
        check_capabilities :post
        check_protocols :http, :https

        speeds = data.values.map(&:values).flatten.map do |val|
          val.timestamp if val.respond_to?(:success) && val.success
        end

        speeds = (speeds << @speeds).flatten.compact
        (speeds.inject(0, :+) / speeds.count).to_i
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
        { "body" => body, "content_type" => content_type, "headers" => headers }
      end

      def check_proxy_for_http
        @protocols['http'] = fetch_url config.http_url, ssl: false
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
end

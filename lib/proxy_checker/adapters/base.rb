module ProxyChecker
  module Adapter
    class Base

      # include ProxyChecker::DSL
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
          base.instance_variable_set("@options", options ? options.dup : {})
        end
      end

      attr_accessor :response
      config_option :info_url, "http://ip-api.com/json/%{ip}"
      config_option :current_ip_url, "http://ip-api.com/json"
      config_option :digest_url, "https://git.io/vPpCx"

      def name
        self.class.name.demodulize.underscore rescue "custom"
      end

      def parse_response
        return yield(@response) if block_given?
        @response.parse rescue @response.to_s
      end

      def parse_cookies
        Hash[@response.cookies.map{|v| v.to_s.split("=")}]
      end

      def streaming?
        @response.headers["Transfer-Encoding"] == "chunked"
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

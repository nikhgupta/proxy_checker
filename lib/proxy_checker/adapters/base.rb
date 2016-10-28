module ProxyChecker
  module Adapter
    class Base

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

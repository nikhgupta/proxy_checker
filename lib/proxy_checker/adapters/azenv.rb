require 'nokogiri'
module ProxyChecker
  module Adapter
    class Azenv < Base
      config_option :http_url, "http://luisaranguren.com/azenv.php"

      def parse_response
        dom = Nokogiri::HTML(@response.to_s)
        pre = dom.search("pre")
        return nil if pre.empty?
        collect_key_value_pairs(pre.inner_html)
      end

      def validate_http
        binding.pry
      end

      private

      def collect_key_value_pairs(text)
        Hash[text.strip.split(/\r*\n+/).map{|l| l.split(/\s+=\s+/)}]
      end
    end
  end
end

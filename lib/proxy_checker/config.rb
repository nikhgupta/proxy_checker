module ProxyChecker
  class Config
    include ProxyChecker::Utility

    attr_accessor :info_url, :judge_urls, :current_ip_url,
      :read_timeout, :connect_timeout, :ssl_context,
      :current_ip, :keep_failed_attempts,
      :log_error, :parse_current_ip, :websites,
      :validate_http,:validate_post,  :validate_https

    def initialize
      @info_url   = "http://ip-api.com/json/%{ip}"
      @judge_urls = [ "http://www.rx2.eu/ivy/azenv.php", "http://luisaranguren.com/azenv.php" ]
      @current_ip_url = "https://api.ipify.org/?format=text"

      @read_timeout = 10
      @connect_timeout = 5

      @keep_failed_attempts = false

      @ssl_context = OpenSSL::SSL::SSLContext.new
      @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @log_error = -> (e) { puts "\e[31mEncountered ERROR: #{e.class} #{e}\e[0m" }

      @validate_http = -> (response, url){
        response.code == 200 && !!response.body.match(/request_method\s+=\s+get/i)
      }

      @validate_https = -> (response, url){
        response.code == 200 && !!response.body.match(/https\s+=\s+on.*request_method\s+=\s+get/mi)
      }

      @validate_post = -> (response, url){
        response.code == 200 && !!response.body.match(/request_method\s+=\s+post/i)
      }

      @parse_current_ip = nil

      @websites = {
        google:    "http://www.google.com/search?q=%{s}",
        twitter:   "http://twitter.com/search?q=%{s}",
        youtube:   "http://www.youtube.com/results?search_query=%{s}",
        facebook:  "http://www.facebook.com/search/top/?q=%{s}",
        pinterest: "http://www.pinterest.com/search/?q=%{s}",
      }

      @current_ip ||= ENV['CURRENT_IP'] || fetch_current_ip
    end

    def timeout
      { read_timeout: @read_timeout, connect_timeout: @connect_timeout, write_timeout: @read_timeout }
    end

    def fetch_current_ip
      ip = Socket.ip_address_list.detect do |intf|
        intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?
      end

      return ip.ip_address if ip
      response = agent.get(@current_ip_url)
      @parse_current_ip ? @parse_current_ip.call(response) : response.to_s
    end
  end
end

module ProxyChecker
  class Config
    include ProxyChecker::Utility

    attr_accessor :info_url, :read_timeout, :connect_timeout,
      :current_ip, :ssl_context, :log_error, :judge_urls, :current_ip_url,
      :websites, :http_block, :https_block, :post_block, :keep_failed_attempts

    def initialize
      @info_url   = "http://ip-api.com/json/%{ip}"
      @judge_urls = [ "http://www.rx2.eu/ivy/azenv.php", "http://luisaranguren.com/azenv.php" ]
      @current_ip_url = "https://api.ipify.org/?format=text"

      @read_timeout = 10
      @connect_timeout = 5

      @keep_failed_attempts = false

      @ssl_context = OpenSSL::SSL::SSLContext.new
      @ssl_context.verify_mode = OpenSSL::SSL::VERIFY_NONE

      @log_error = -> (e, *args) { puts "\e[31mEncountered ERROR: #{e.class} #{e}\e[0m" }

      @http_block = -> (key, uri, response, time){
        response.code == 200 && !!response.body.match(/request_method\s+=\s+get/i)
      }

      @https_block = -> (key, uri, response, time){
        response.code == 200 && !!response.body.match(/https\s+=\s+on.*request_method\s+=\s+get/mi)
      }

      @post_block = -> (key, uri, response, time){
        response.code == 200 && !!response.body.match(/request_method\s+=\s+post/i)
      }

      @websites = {
        google:    "http://www.google.com/search?q=%{s}",
        twitter:   "http://twitter.com/search?q=%{s}",
        youtube:   "http://www.youtube.com/results?search_query=%{s}",
        facebook:  "http://www.facebook.com/search/top/?q=%{s}",
        pinterest: "http://www.pinterest.com/search/?q=%{s}",
      }
    end

    def timeout
      { read_timeout: @read_timeout, connect_timeout: @connect_timeout, write_timeout: @read_timeout }
    end

    def current_ip
      @current_ip ||= ENV['CURRENT_IP'] || fetch_current_ip
    end

    def fetch_current_ip
      ip = Socket.ip_address_list.detect do |intf|
        intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?
      end

      ip ? ip.ip_address : agent.get(@current_ip_url).to_s
    end
  end
end

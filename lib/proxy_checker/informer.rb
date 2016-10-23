module ProxyChecker
  class Informer
    include ProxyChecker::Utility

    attr_accessor :ip, :port

    def initialize(ip, port, report = :basic)
      @ip, @port = ip, port.to_i
    end

    def port=(port); @port = port.to_i; end

    def fetch(*fields)
      get_proxy_basic_information
      fields = [:speed, :level, :exposed_ip, :temperance] if fields.empty?
      fields = fields.select{ |key| respond_to?("get_proxy_#{key}") }
      fields.each{ |key| @info[key] = send("get_proxy_#{key}") }
      @info
    end

    def get_proxy_basic_information
      url = config.info_url % { ip: @ip, port: @port }
      response = fetch_url(url).body
      response["ip"] = response.delete("query")
      response["asn"] = response.delete("as").match(/\A(AS.*?)\s.+\z/)[1] rescue nil
      response["region"] = response.delete("regionName")
      response["country_code"] = response.delete("countryCode")
      @info = response
    end

    def get_proxy_exposed_ip
      response = fetch_url(config.current_ip_url, proxy: {ip: ip, port: port})
      @info['exposed_ip'] = config.parse_current_ip ? config.parse_current_ip(response) : response.body
    end

    def get_proxy_level

    end
  end
end

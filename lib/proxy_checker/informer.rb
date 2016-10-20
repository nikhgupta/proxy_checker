module ProxyChecker
  class Informer
    include ProxyChecker::Utility

    attr_accessor :ip, :port

    def initialize(ip, port)
      @ip, @port = ip, port.to_i
    end

    def port=(port); @port = port.to_i; end

    def fetch
      url = config.info_url % { ip: @ip, port: @port }
      response = fetch_url(url).body
      response["ip"] = response.delete("query")
      response["asn"] = response.delete("as").match(/\A(AS.*?)\s.+\z/)[1] rescue nil
      response["region"] = response.delete("regionName")
      response["country_code"] = response.delete("countryCode")
      response
    end
  end
end

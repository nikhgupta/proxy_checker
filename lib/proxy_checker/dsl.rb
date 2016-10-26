module ProxyChecker
  module DSL
    def get
      self.data
    end

    def fetch(&block)
      self.instance_eval &block
      self.data
    end

    def fetch_information(*fields)
      fields |= [ :basic_info ]
      extract_information :info, fields
    end

    def check_protocols(*fields)
      extract_information :protocols, fields
    end

    def check_capabilities(*fields)
      extract_information :capability, fields
    end

    def check_proxy_for_basic_info
      response = ip_information(@ip)
      response["ip"] = response.delete("query")
      response["asn"] = response.delete("as").match(/\A(AS.*?)\s.+\z/)[1] rescue nil
      response["region"] = response.delete("regionName")
      response["country_code"] = response.delete("countryCode")
      @info = response
    end

    def check_website
    end

    def extract_information(key, fields = [])
      var = instance_variable_get("@#{key}")
      fields.each{ |field| var[field.to_s] ||= send("check_proxy_for_#{field}") }
      instance_variable_set "@#{key}", var
    end
  end
end

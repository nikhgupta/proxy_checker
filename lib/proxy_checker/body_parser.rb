require 'nokogiri'

module ProxyChecker
  class BodyParser
    attr_accessor :parsed

    def initialize(response)
      self.response = response
    end

    def response=(response)
      @response = response
      mime = @response.mime_type.to_s.downcase.gsub(/[^a-z0-9]/, '_')
      @parsed = respond_to?("convert_#{mime}") ? send("convert_#{mime}") : response.to_s
    end

    def convert_text_plain
      { "text" => @response.to_s }
    end

    def convert_text_html
      dom = Nokogiri::HTML(@response.to_s)
      pre = dom.search('pre')
      return { html: dom.to_s } if pre.empty?
      Hash[pre.inner_html.strip.split(/\r*\n/).map{|i| i.split(/\s+=\s+/)}]
    end

    def convert_text_xml(dom = nil)
      dom ||= Nokogiri::XML(@response.to_s)
      dom.root.element_children.each_with_object(Hash.new) do |e, h|
        h[e.name.to_sym] = convert_text_xml(e.content)
      end
    end

    def convert_application_json
      JSON.parse @response.to_s
    end
  end
end

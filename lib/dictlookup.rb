#-*- encoding: utf-8 -*-
#
# Description: Lookup TR => DE words on pons.eu
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'net/http'
require 'uri'
require 'nokogiri'
require 'libarchive_rs'

class OnlineDictionary

  class Error < StandardError
  end

  class << self
  
    def load_dictionary_provider(params = {:provider => :pons})
      case params[:provider]
        when :pons
          return OnlineDictionaryPons.new(params)
        else
          raise StandardError, "unknown dictionary provider '#{params[:provider]}'."
      end
    end

  end

end


class OnlineDictionaryPons < OnlineDictionary

  XSL_STYLESHEET = <<EOF
<?xml version="1.0" encoding="UTF-8"?> 
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="strong">
    <xsl:apply-templates/>
  </xsl:template>

  <xsl:template match="span[@class = 'genus']">
    <!-- cut -->
  </xsl:template>

</xsl:stylesheet>
EOF

  def initialize(params = {})
    @stylesheet = Nokogiri::XSLT(XSL_STYLESHEET)
  end

  def translate(token)
    translations = Hash.new { |h, k| h[k] = [] }

    term = URI::encode_www_form_component(token.strip)
    uri = URI("http://en.pons.eu/dict/search/results/?l=detr&in=tr&lf=tr&q=#{term}")

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept-Encoding'] = 'gzip'

    # submit request
    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.request(request)
    end
    page = response.body

    # unzip page
    if page.start_with?("\x1f\x8b\x08".force_encoding("ASCII-8BIT"))
      Archive.read_open_memory(page, nil, true) do |archive|
        archive.next_header
        page = archive.read_data()
      end
    end

    page = Nokogiri::HTML(page)

    sources = page.xpath("//div[@class = 'lang'][@id = 'tr']//td[@class = 'source']")
    targets = page.xpath("//div[@class = 'lang'][@id = 'tr']//td[@class = 'target']")

    sources.zip(targets).each do |s, t|
      s_doc = Nokogiri::XML::Document.new
      s.dup(1).parent = s_doc
      t_doc = Nokogiri::XML::Document.new
      t.dup(1).parent = t_doc
      s = @stylesheet.transform(s_doc).content
      t = @stylesheet.transform(t_doc).content
      translations[s.strip] << t.strip
    end

    return translations
  end

end


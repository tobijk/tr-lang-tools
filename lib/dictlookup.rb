#-*- encoding: utf-8 -*-
#
# Description: Lookup TR =>DE words on pons.eu
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'net/http'
require 'uri'
require 'nokogiri'
require 'pp'

def load_dictionary_provider(provider = 'pons')
  known_providers = [ 'pons' ]

  case provider
    when 'pons'
      return OnlineDictionaryPons.new
    else
      raise StandardError, "unknown dictionary provider '#{provider}'."
  end
end

class OnlineDictionaryPons

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

  def initialize
    @stylesheet = Nokogiri::XSLT(XSL_STYLESHEET)
  end

  def translate(token)
    translations = Hash.new { |h, k| h[k] = [] }

    term = URI::encode_www_form_component(token.strip)
    url = "http://en.pons.eu/dict/search/results/?l=detr&in=tr&lf=tr&q=#{term}"
    page = Nokogiri::HTML(Net::HTTP.get(URI(url)))

    sources = page.xpath("//td[@class = 'source']")
    targets = page.xpath("//td[@class = 'target']")

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


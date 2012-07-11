#-*- encoding: utf-8 -*-
#
# Description: Lookup TR => DE words on pons.eu
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'rubygems'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'libarchive_rs'

class OnlineDictionary

  class Error < StandardError
  end

  class << self
 
    def load_dictionary_provider(params = {:provider => :pons})
      case params[:provider]
        when :pons
          return OnlineDictionaryPons.new(params)
        when :google
          return OnlineDictionaryGoogle.new(params)
        else
          raise StandardError, "unknown dictionary provider '#{params[:provider]}'."
      end
    end

    def format_text(vocabulary)
      out = []
      vocabulary.each_pair { |k, v|
        out << "#{k}: #{v.join(', ')}\n"
      }
      return out.join('')
    end


    def format_xml(vocabulary, standalone = false)
      out = []
      unless standalone
        out << "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
      end
      out << "<vocabulary>\n"
      vocabulary.each_pair { |k, v|
        out << "  <entry>\n"
        out << "    <source>#{k}</source>\n"
        out << "    <target>#{v.join(', ')}</target>\n"
        out << "  </entry>\n"
      }
      out << "</vocabulary>\n"
      return out.join('')
    end


    def format_html(vocabulary)
      out = []
      out << "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\">\n"
      out << "<html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" dir=\"ltr\">\n"
      out << "<head>\n"
      out << "  <title>Vocabulary List</title>\n"
      out << "</head>\n"
      out << "<body>\n"
      unless vocabulary.empty?
        out << "  <table cellspacing=\"0\" cellpadding=\"5\" border=\"1\" width=\"100%\">\n"
        vocabulary.each_pair { |k, v|
          out << "    <tr>\n"
          out << "      <td width=\"50%\">#{k}</td>\n"
          out << "      <td width=\"50%\">#{v.join(', ')}</td>\n"
          out << "    </tr>\n"
        }
        out << "  </table>\n"
      end
      out << "</body>\n"
      out << "</html>\n"
      return out.join('')
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

  <xsl:template match="span[
    @class = 'genus' or
    @class = 'feminine' or
    @class = 'complement']">
    <!-- cut -->
  </xsl:template>

</xsl:stylesheet>
EOF

  def initialize(params = {})
    @stylesheet = Nokogiri::XSLT(XSL_STYLESHEET)
    @verbose = params[:verbose]
  end

  def translate(token, hint)
    translations = {}

    token.strip!
    term = URI::encode_www_form_component(token)
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

    sources = page.xpath("//div[@class = 'lang'][@id = 'tr']//table[contains(@class, 'translations')]//td[@class = 'source']")
    targets = page.xpath("//div[@class = 'lang'][@id = 'tr']//table[contains(@class, 'translations')]//td[@class = 'target']")

    sources.zip(targets).each do |s, t|
      s_doc = Nokogiri::XML::Document.new
      s.dup(1).parent = s_doc
      t_doc = Nokogiri::XML::Document.new
      t.dup(1).parent = t_doc
      s = @stylesheet.transform(s_doc).content.strip.gsub(/\s+/, ' ')
      t = @stylesheet.transform(t_doc).content.strip.gsub(/\s+/, ' ')
      if translations[s].nil?
        translations[s] = [t]
      else
        translations[s] << t
      end
      break if !@verbose && translations.keys.size >= 3 
    end

    if translations[token] && !@verbose
      translations.delete_if { |k, v| k != token }
    end

    return translations.each_value { |v| v.uniq! }
  end

end


class OnlineDictionaryGoogle < OnlineDictionary

  def initialize(params = {})
    @params = { :verbose => false }.merge!(params)
  end

  def translate(token, hints)
    translations = {}

    token.strip!
    term = URI::encode_www_form_component(token)
    uri = URI("http://translate.google.com/translate_a/t?client=t&text=#{term}&hl=en&sl=tr&tl=en&ie=UTF-8&oe=UTF-8")

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept-Encoding'] = 'gzip'

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
    page = JSON::load(page.gsub(/,+/, ','))

    return translations unless page[1].is_a? Array

    # check if there is a match for the exact word type
    unless hints.empty?
      page[1].each { |t| translations["#{token} (#{t[0]})"] = t[1][0,5] if hints.include? t[0] }
    end

    # fallback
    if translations.empty?
      page[1].each { |t| translations["#{token} (#{t[0]})"] = t[1][0,5] }
    end

    return translations
  end

end


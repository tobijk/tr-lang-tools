#-*- encoding: utf-8 -*-
#
# Description: RSS feed readers for sources from Turkey
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'open-uri'
require 'nokogiri'
require 'erb'
require 'tokenize'
require 'trmorph'
require 'dictlookup'

ECMDS_TEMPLATE = ERB.new(<<'EOF')
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE book SYSTEM "http://www.ecromedos.net/dtd/2.0/ecromedos.dtd">
<report lang="en_US" fontsize="11pt" papersize="a5paper" div="16" bcor="0cm"
        secnumdepth="0" secsplitdepth="1">

        <head>
                <title><%= title %></title>
                <author></author>
                <date></date>
                <publisher></publisher>
        </head>

        <make-toc depth="3" lof="no" lot="no" lol="no"/>

        <% articles.each do |article| %>
          <chapter>
            <title><%= article.title %></title>
            <p>
              <b>
                <%= article.desc %>
              </b>
            </p>
            <%= article.content.root.children.to_s %>
          </chapter>
        <% end %>

</report>
EOF

ECMDS_TABLE_TEMPLATE = ERB.new(<<'EOF')
<table print-width="100%" screen-width="600px" align="left" frame="left">
  <colgroup>
    <col width="50%"/>
    <col width="50%"/>
  </colgroup>
  <% vocabulary.each_pair do |word, meanings| %>
    <tr>
      <td frame="colsep"><%= word %></td>
      <td><%= meanings.join(', ') %></td>
    </tr>
  <% end %>
</table>
EOF

SANITIZE_XSL1 = <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template match="/*">
    <article><xsl:apply-templates/></article>
  </xsl:template>

  <xsl:template match="p">
    <xsl:choose>
      <xsl:when test="normalize-space(translate(string(.), '&#xa0;', '')) = ''">
        <!-- cut -->
      </xsl:when>
      <xsl:when test="ancestor::p">
        <xsl:apply-templates/>
      </xsl:when>
      <xsl:otherwise>
        <p><xsl:apply-templates/></p>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="a[@href]">
    <link url="{@href}"><xsl:apply-templates/></link>
  </xsl:template>

  <xsl:template match="*">
    <xsl:choose>
      <xsl:when test="
          self::br or
          self::i  or
          self::b
        ">
        <xsl:copy>
          <xsl:apply-templates/>
        </xsl:copy>
      </xsl:when>
      <xsl:when test="self::div[normalize-space(@class)='module']">
        <!-- cut -->
      </xsl:when>
      <xsl:when test="not(ancestor-or-self::p)">
        <!-- cut -->
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="text()">
    <xsl:value-of select="."/>
  </xsl:template>

  <xsl:template match="script">
    <!-- cut -->
  </xsl:template>

  <xsl:template match="comment()">
    <!-- cut -->
  </xsl:template>

</xsl:stylesheet>
EOF

class RSSFeedCore

  PROVIDERS = {}

  class Error < RuntimeError
  end

  class << self

    def register_provider(class_obj, name)
      PROVIDERS[name] = class_obj
    end

    def available_providers
      return PROVIDERS.keys
    end

    def create(provider_name, params)
      PROVIDERS[provider_name] ? PROVIDERS[provider_name].new(params) : nil
    end

  end

  class RSSItem
    attr_accessor :title, :link, :date, :desc, :img, :content
  end

  def initialize(params = {})
    @tokenizer = Tokenizer.new(:sort => true, :unique => true)
    @trmorph   = TRMorph.new(:hint => true)
    @dict      = OnlineDictionaryGoogle.new(:verbose => false)
  end

  def retrieve_rss(format = 'ecromedos')
    articles = Array.new
    vocabulary = {}

    xml_doc = open(feed_url) do |rss|
      # HACK for libxml/Nokogiri bug
      rss = rss.read\
        .gsub('xmlns="http://www.w3.org/2005/Atom"', '')
      Nokogiri::XML(rss)
    end

    rss_type = xml_doc.root.name

    title = if rss_type == 'feed'
        xml_doc.at_xpath("//feed//title").content
      else
        xml_doc.at_xpath("//channel//title").content
      end

    xml_doc.xpath('//item|//entry').each do |xml_item|
      begin
        rss_item        = RSSItem.new
        rss_item.title  = xml_item.at_xpath('title').content
        if rss_type == 'feed'
          rss_item.link = xml_item.at_xpath('link/@href').content
          rss_item.date = Time.parse(xml_item.at_xpath('published').content)
        else
          rss_item.link = xml_item.at_xpath('link').content
          rss_item.date = Time.parse(xml_item.at_xpath('pubDate').content)
        end

        desc = xml_item.at_xpath('description') || \
          xml_item.at_xpath('summary')          || \
          xml_item.at_xpath('content:encoded')
        desc = Nokogiri::XML("<desc>" + desc.content + "</desc>")

        rss_item.img = desc.at_xpath('//a[1]/@href').to_s
        rss_item.desc = desc.content

        link = transform_link(rss_item.link) or next
        rss_item.content = retrieve_article(link) or next

        articles << rss_item
      rescue Exception => e
        # skip this item
      end
    end

    article = Nokogiri::XML(ECMDS_TEMPLATE.result(binding))
    insert_vocabulary_sheets(article)
    return article.to_s
  end

  def insert_vocabulary_sheets(article)
    article.xpath("//chapter").each do |chapter|
      next_node = chapter.first_element_child

      until next_node.nil?
        current_node = next_node
        vocabulary   = build_vocabulary(current_node.content)

        unless vocabulary.empty?
          table = ECMDS_TABLE_TEMPLATE.result(binding)
          table = Nokogiri::XML(table).root
          table.unlink
          current_node = current_node.add_next_sibling table
        end
        next_node = current_node.next_element
      end
    end
  end

  def build_vocabulary(text)
    token_list = @tokenizer.tokenize(text)
    vocabulary = Hash.new { |h, k| h[k] = [] }

    token_list.each do |token|
      root_count = @trmorph.find_roots(token, vocabulary)
      vocabulary[token] if root_count == 0
    end

    translations = {}

    vocabulary.each_pair do |word, hints|
      translations.merge! @dict.translate(word, hints)
    end

    return translations
  end

  def retrieve_article(link)
    xml_content = nil

    # download doc and do some basic preparation
    xml_doc0 = open(link) do |html|
      buf = html.read\
        .gsub(/\s+/, ' ')\
        .gsub(/<(?:BR)>/i, '<br/>')\
        .gsub(/<(\/)?(?:STRONG)>/i, '<\1b>')\
        .gsub(/(?:<br\/>\s*){2,}/, '<br/><br/>')\
        .gsub(/<\/?(?:g:)?plusone[^>]*>/, '')
      xml_tmp = Nokogiri::HTML(buf) do |config|
        config.nonet.noent.nocdata.noerror.nowarning.recover
      end
      IO.popen('tidy -quiet -utf8 -indent -asxml --doctype strict 2>/dev/null', 'r+') do |fp|
        fp.write(xml_tmp.to_xhtml(:encoding => 'utf-8'))
        fp.close_write
        Nokogiri::HTML(fp.read) do |config|
          config.nonet.noent.nocdata.noerror.nowarning.recover
        end
      end
    end

    # nest stray elements in paragraph
    tmp_para = []
    content_node = extract_content(xml_doc0)

    child = content_node ? content_node.child : nil
    while child
      if !['table', 'ul', 'ol', 'p'].include?(child.name)
        tmp_para << child
      elsif !tmp_para.empty?
        new_para = Nokogiri::XML::Element.new('p', xml_doc0)
        tmp_para.each do |element|
          new_para.add_child(element)
        end
        child.add_previous_sibling(new_para)
        tmp_para.clear
      end
      child = child.next_sibling
    end

    if !tmp_para.empty?
      new_para = Nokogiri::XML::Element.new('p', xml_doc0)
      tmp_para.each do |element|
        new_para.add_child(element)
      end
      content_node.add_child(new_para)
    end

    # mangle into semantic markup
    begin
      xml_doc1 = Nokogiri::XML::Document.new
      xml_doc1.encoding = 'utf-8'

      content_node.dup(1).parent = xml_doc1

      xml_content = Nokogiri::XSLT(SANITIZE_XSL1).transform(xml_doc1)
      xml_content.encoding = 'utf-8'
    rescue Exception => e
      return nil
    end

    return xml_content
  end

end


class TurkInternetRSS < RSSFeedCore

  def feed_url
    'http://turk.internet.com/rss/guncel.rss'
  end

  def transform_link(link)
    begin
      m = link.match('http://turk.internet.com/haber/yazigoster.php3\?yaziid=(\d+)')
      return "http://www.turk.internet.com/portal/yaziyaz.php?yaziid=#{m[1]}"
    rescue
      return nil
    end
  end

  def extract_content(xml_doc)
    xml_doc.at_xpath(
      "//table/tr/td"
    )
  end

  RSSFeedCore::register_provider(self, 'turk.internet.com')
end


class HurriyetRSS < RSSFeedCore

  def feed_url
    'http://rss.hurriyet.com.tr/rss.aspx?sectionId=1'
  end

  def transform_link(link)
    begin
      m = link.match('http://www.hurriyet.com.tr/.*/(\d+).asp')
      return "http://hurarsiv.hurriyet.com.tr/goster/printnews.aspx?DocID=#{m[1]}"
    rescue
      return nil
    end
  end

  def extract_content(xml_doc)
    xml_doc.at_xpath(
      "//div[@class='HaberText']"
    )
  end

  RSSFeedCore::register_provider(self, 'hurriyet.com.tr')
end


class TknljRSS < RSSFeedCore

  def feed_url
    'http://www.tknlj.com/feed/'
  end

  def transform_link(link)
    return link
  end

  def extract_content(xml_doc)
    xml_doc.at_xpath(
      "//div[@class='post clearfix']"
    )
  end

  RSSFeedCore::register_provider(self, 'tknlj.com')
end


class BBCTurkish < RSSFeedCore

  def feed_url
    'http://www.bbc.co.uk/turkce/index.xml'
  end

  def transform_link(link)
    return "#{link}?print=1"
  end

  def extract_content(xml_doc)
    xml_doc.at_xpath(
      "//div[@class='g-container story-body']//div[@class='bodytext']"
    )
  end

  RSSFeedCore::register_provider(self, 'bbc.com.tr')
end


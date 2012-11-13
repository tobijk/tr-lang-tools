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
<report lang="en_US" fontsize="11pt" papersize="a5paper" div="18" bcor="0cm"
        secnumdepth="0" secsplitdepth="1">

        <head>
                <title></title>
                <author></author>
                <date></date>
                <publisher></publisher>
        </head>

        <make-toc depth="3" lof="no" lot="no" lol="no"/>

        <chapter>
          <title>Altyazı</title>
          <% captions.each do |c| %>
          <p>
            <x-small><%= c.timeframe %></x-small><br/>
            <%= c.content   %>
          </p>
          <% end %>
        </chapter>

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

class SRTCommenter

  class Error < RuntimeError
  end

  class Caption
    attr_accessor :timeframe, :content
  end

  def initialize(params = {})
    @tokenizer = Tokenizer.new(:sort => true, :unique => true)
    @trmorph   = TRMorph.new(:hint => true)
    @dict      = OnlineDictionary::load_dictionary_provider(
      {
        :provider => :google,
        :verbose => false
      }
    )
  end

  def read_srt(filename)
    captions = Array.new
    vocabulary = {}

    srt = File.open(filename, 'r').read

    srt.split(/(?:\r?\n){2,}/).each do |entry|
      entry.strip!
      next if entry.empty?

      lines = entry.split(/(?:\r?\n)+/)
      cap = Caption.new
      cap.timeframe = lines[1]
      cap.content = lines[2..-1].join(' ').gsub(/^\s*#\s*/, '')

      captions << cap
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
      translations.merge! @dict.translate_cached(word, hints)
    end

    return translations
  end

end


#-*- encoding: utf-8 -*-
#
# Description: RSS feed readers for sources from Turkey
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'open-uri'
require 'nokogiri'

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

  def retrieve_rss
    items = Array.new

    xml_doc = open(feed_url) do |rss|
      Nokogiri::XML(rss.read)
    end

    title = xml_doc.at_xpath('//channel//title').content

    xml_doc.xpath('//item').each do |xml_item|
      begin
        rss_item       = RSSItem.new
        rss_item.title = xml_item.at_xpath('title').content
        rss_item.link  = xml_item.at_xpath('link').content
        rss_item.date  = Time.parse(xml_item.at_xpath('pubDate').content)

        desc = xml_item.at_xpath('description') || \
          xml_item.at_xpath('content:encoded')
        desc = Nokogiri::XML("<desc>" + desc.content + "</desc>")

        rss_item.img = desc.at_xpath('//a[1]/@href').to_s
        rss_item.desc = desc.content

        # call sub-class implementing this interface
        rss_item.content = retrieve_article(rss_item.link) or next

        items << rss_item
      rescue Exception => e
        # skip this item
      end
    end

    require 'pp'
    pp items
  end

end


class TurkInternetRSS < RSSFeedCore

  def feed_url
    'http://turk.internet.com/rss/guncel.rss'
  end

  RSSFeedCore::register_provider(self, 'turk.internet.com')
end


class HurriyetRSS < RSSFeedCore

  def feed_url
    'http://rss.hurriyet.com.tr/rss.aspx?sectionId=1'
  end

  def retrieve_article(link)
    xml_doc = open(link) do |html|
      Nokogiri::HTML(html.read)
    end

    begin
      content = xml_doc.at_xpath(
        "//div[@id='DivAdnetHaberDetay']//div[@class='txt']").content.strip
    rescue Exception
      return nil
    end

    return content
  end

  RSSFeedCore::register_provider(self, 'hurriyet.com.tr')
end


class TknljRSS < RSSFeedCore

  def feed_url
    'http://www.tknlj.com/feed/'
  end

  RSSFeedCore::register_provider(self, 'tknlj.com')
end


class GazeteVatanRSS < RSSFeedCore

  def feed_url
    'http://rss.gazetevatan.com/rss/teknoloji.xml'
  end

  RSSFeedCore::register_provider(self, 'gazetevatan.com')
end


#-*- encoding: utf-8 -*-
#
# Description: RSS feed readers for sources from Turkey
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

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

  def retrieve_rss(uri)
  end

end

class TurkInternetRSS < RSSFeedCore
  RSSFeedCore::register_provider(self, 'turk.internet.com')
end

class InternetGazeteRSS < RSSFeedCore
  RSSFeedCore::register_provider(self, 'internetgazete.com')
end

class TknljRSS < RSSFeedCore
  RSSFeedCore::register_provider(self, 'tknlj.com')
end

class GazeteVatanRSS < RSSFeedCore
  RSSFeedCore::register_provider(self, 'gazetevatan.com')
end


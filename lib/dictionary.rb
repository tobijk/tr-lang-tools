#-*- encoding: utf-8 -*-
#
# Description: Lookup (TR => DE) words on Google Translate
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'rubygems'
require 'net/http'
require 'uri'
require 'nokogiri'
require 'json'
require 'libarchive_rs'
require 'fileutils'

class Dictionary

  def initialize(params = {})
    @translations = {}
  end

  def translate(token)
    translations = Hash.new { |h, k| h[k] = {} }

    token = token.strip
    term = URI::encode_www_form_component(token)
    uri = URI("http://translate.google.com/translate_a/t?client=t&text=#{term}&hl=en&sl=tr&tl=en&ie=UTF-8&oe=UTF-8")

    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept-Encoding'] = 'gzip'

    response = Net::HTTP.start(uri.host, uri.port) do |http|
      http.request(request)
    end

    page = response.body

    # check if page is gzipped and unpack
    if page.start_with?("\x1f\x8b\x08".force_encoding("ASCII-8BIT"))
      Archive.read_open_memory(page, nil, true) do |archive|
        archive.next_header
        page = archive.read_data()
      end
    end

    # load JSON result
    translation_data = JSON::load(
      page\
        .gsub(/,+/, ',')\
        .gsub(/\[,+/, '[')
    )

    # no results?
    return translations unless translation_data[1].is_a? Array

    # fallback
    if translations.empty?
      translation_data[1].each { |t|
        translations[token][t[0]] = t[1][0,5]
      }
    end

    return translations
  end

  def translate_cached(token)
    result = {}

    # then check cached results without hints
    if @translations[token]
      result[token] = @translations[token]
    end

    # resort to online lookup
    if result.empty?
      result.merge!(self.translate(token))
      @translations.merge!(result)
    end

    return result
  end

  def save(filename)
    filename = File.expand_path(filename)
    dirname  = File.dirname(filename)

    if not File.exists?(filename)
      FileUtils.makedirs(dirname)
    end

    File.open(filename, 'wb+') do |fp|
      fp.write(Marshal::dump(@translations))
    end
  end

  def load(filename)
    filename = File.expand_path(filename)

    begin
      File.open(filename, 'rb') do |fp|
        @translations = Marshal::load(fp.read)
      end
    rescue
      @translations = {}
    end
  end

end


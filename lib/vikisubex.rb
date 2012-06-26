#-*- encoding: utf-8 -*-
#
# Description: Viki.com Subtitle Extractor
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'libarchive_rs'

class VikiSubtitleExtractor

  class Error < StandardError
  end

  def initialize(params = {})
    @video_url = params['video_url']
    @mode = params['mode']
  end

  def do_action
    subtitles_json = get_subtitles_json_for_video(get_video_id_via_video_url)
    if subtitles_json.start_with?("\x1f\x8b\x08".force_encoding("ASCII-8BIT"))
      Archive.read_open_memory(subtitles_json, nil, true) do |archive|
        archive.next_header
        subtitles_json = archive.read_data()
      end
    end
    subtitles = JSON::load(subtitles_json)['subtitles']

    print_subtitles(subtitles)
  rescue Exception => e
    raise VikiSubtitleExtractor::Error, e.message
  end

  private

  def get_video_id_via_video_url
    video_page = Net::HTTP.get(@video_url)
    video_page.match('video_id=(\d+)')[1]
  end

  def get_subtitles_json_for_video(video_id)
    @video_url.path = "/subtitles/media_resource/#{video_id}/tr.json"
    Net::HTTP.get(@video_url)
  end

  def print_subtitles(subtitles)
    subtitles.each do |sub|
      start_time = (sub['start_time'] / 1000.0).to_i
      hours = start_time / 3600
      start_time %= 3600
      mins  = start_time / 60
      start_time %= 60
      secs  = start_time
      begin
        content = sub['content']
        content = content\
          .gsub(/--+/, ' -- ') \
          .gsub(/\s*<(br|Br|BR)>\s*/, "\n") \
          .gsub(/\s*(\!|\?|,)(?![!?)'"])/, '\1 ') \
          .gsub(/(^|\n)-\s+/, '\1-') \
          .gsub(/[ \t\v]+/, ' ') \
          .gsub(/\n+/, "\n") \
          .gsub(/\n/, "\n          ") \
          .gsub(/(\p{Word}+)\s*(\.)(\p{Alpha}+)/, '\1\2 \3') \
          .gsub('(no voice)', '') \
          .gsub(/<[^>]+>/, '')
        next if content.strip.empty?
        next if content.strip =~ /^[-.!?_,;:]+$/
        if @mode == 'raw'
          puts "#{content.gsub(/\s+/, ' ')}\n"
        else
          puts "%02d:%02d:%02d: #{content}\n" % [hours, mins, secs]
        end
      rescue Exception => e ;; end
    end
  end

end


#-*- encoding: utf-8 -*-
#
# Description: Tokenize Turkish text
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

class TRMorph

  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    if File.exist? "#{path}/trmorph"
      TRMORPH = "#{path}/trmorph"
      break
    end
  end

  def parse(token)
    result = ""

    IO.popen(TRMORPH, 'r+') do |stdio|
      stdio.write "#{token.strip}\n"
      stdio.close_write
      result = stdio.read
    end

    result
  end

  def mek_or_mak?(stem)
    front_vowels = [ 'e', 'i', 'ö', 'ü' ]
    back_vowels  = [ 'a', 'o', 'u', 'ı' ]

    stem.reverse.each_char do |c|
      if front_vowels.include? c
        return 'mek'
      elsif back_vowels.include? c
        return 'mak'
      end
    end

    return 'mak'
  end

  def find_roots(token)
    roots = Hash.new { |h, k| h[k] = [] }

    parse(token).each_line do |line|
      next unless m = line.match('([^<]+)<([^>]+)>.*')
      root = m[1]
      type = m[2]
      root += mek_or_mak?(root) if type == 'v'
      roots[root]
    end

    roots.keys
  end

end


#-*- encoding: utf-8 -*-
#
# Description: Tokenize Turkish text
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

class Tokenizer

  ALPHABET_UPCASE  = "AÄBCÇDEFGĞHIİJKLMNOÖPQRSŞTUÜVWXYZ"
  ALPHABET_LOWCASE = "aäbcçdefgğhıijklmnoöpqrsştuüvwxyz"

  ALPHABET_WEIGHTS = Hash.new { |h, k| -1 }

  0.upto(ALPHABET_UPCASE.size - 1) do |i|
    ALPHABET_WEIGHTS[ALPHABET_UPCASE[i]]  = i * 2 + 1
    ALPHABET_WEIGHTS[ALPHABET_LOWCASE[i]] = i * 2 + 2
  end

  class Error < StandardError
  end

  def initialize(params = {})
    @params = {
      :sort => false,
      :unique => false
    }.merge!(params)
  end

  def tokenize(string)
    result = []

    string = string\
      .gsub(/(?:\p{P}{2,}|\p{P}\s+)/, ' ')\
      .gsub(/\s+/, ' ') \
      .gsub('â', 'a')
    tokens = string.split(' ')
    tokens.each do |tok|
      next if tok =~ /\p{N}+/
      tok.gsub!(/^\p{P}+|\p{P}+$/, '')
      result << downcase!(tok)
    end

    sort!(result) if @params[:sort]
    result.uniq!  if @params[:unique]

    return result
  end

  def sort!(tokens)
    tokens.sort! do |a, b|
      rval = 0

      a_chars = a.split(//)
      b_chars = b.split(//)

      0.upto(a_chars.size - 1) do |i|
        if b_chars[i].nil?
          rval = +1
          break
        else
          rval = ALPHABET_WEIGHTS[a_chars[i]] - ALPHABET_WEIGHTS[b_chars[i]]
          break if rval != 0
        end
      end

      rval
    end

    return tokens
  end

  def downcase!(string)
    string.tr!(ALPHABET_UPCASE, ALPHABET_LOWCASE)
    string
  end

end


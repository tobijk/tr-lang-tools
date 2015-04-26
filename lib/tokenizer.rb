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

  def initialize(params = {})
    @tokens = {}
  end

  def update(string)
    token_set  = {}
    token_list = []

    string = string\
      .gsub(/(?:\p{P}{2,}|\p{P}\s+)/, ' ')\
      .gsub(/\s+/, ' ') \
      .gsub(/<\/?i>/, '') \
      .gsub(/<|>/, '')

    string.split(' ').each do |tok|
      next if tok =~ /\p{N}+/
      tok.gsub!(/^\p{P}+|\p{P}+$/, '')
      downcase!(tok)
      token_set[tok] = 1
      token_list.push(tok)
    end

    @tokens.merge!(token_set)
    return token_list
  end

  def acquired_tokens()
    sort!(@tokens.keys)
  end

  private

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


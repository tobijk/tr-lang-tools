#-*- encoding: utf-8 -*-
#
# Description: Tokenize Turkish text and for each word find a list of plausible
#              roots that should be checked against a dictionary.
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

class Tokenizer

  class Error < StandardError
  end

  def initialize(params = {})
    #pass
  end

  def tokenize(string)
    string = string\
      .gsub(/(?:\p{P}{2,}|\p{P}\s+)/, ' ')\
      .gsub(/\s+/, ' ')
    tokens = string.split(' ')
    tokens.each do |tok|
      next if tok =~ /\p{N}+/
      tok.gsub!(/^\p{P}+|\p{P}+$/, '')
      puts downcase!(tok)
    end
  end

  def downcase!(string)
    string.tr!("AÄBCÇDEFGĞHİIJKLMNOÖPQRSŞTUÜVWXYZ", "aäbcçdefgğhiıjklmnoöpqrsştuüvwxyz")
    string
  end

end

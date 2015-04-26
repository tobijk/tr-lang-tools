#!/usr/bin/env ruby
#-*- encoding: utf-8 -*-
#
# Description: Look up words online and build a local dictionary cache.
# Author:      Tobias Koch <tobias.koch@gmail.com>
# License:     Public Domain
#

INSTALL_DIR = File.expand_path(File.dirname(File.symlink?(__FILE__) ?
  File.readlink(__FILE__) : __FILE__) + '/..')
$LOAD_PATH.unshift INSTALL_DIR + '/lib'

ERROR_INVOCATION = 1
ERROR_RUNTIME    = 2

EXECUTABLE_NAME = File.basename($0)

require 'getoptlong'
require 'version'
require 'tokenizer'
require 'trmorph'
require 'dictionary'
require 'nokogiri'

def usage
  $stderr.write "TR Language Tools vocabulary analyzer, version #{TRTOOLS_VERSION}                \n"
  $stderr.write "Copyright 2012, Tobias Koch <tobias.koch@gmail.com>                              \n"
  $stderr.write "                                                                                 \n"
  $stderr.write "#{EXECUTABLE_NAME} [OPTIONS] <files|stdin>                                       \n"
  $stderr.write "                                                                                 \n"
  $stderr.write "OPTIONS:                                                                         \n"
  $stderr.write " --help, -h             Print this help text and exit                            \n"
  $stderr.write " --xml,  -x             Input is well-formed XML                                 \n"
  $stderr.write "                                                                                 \n"
end

def parse_cmd_line
  params = {
    :is_xml => false
  }

  opts = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT ],
    ['--xml',  '-x', GetoptLong::NO_ARGUMENT ]
  )

  begin
    opts.quiet = true
    opts.each do |opt, arg|
      case opt
        when '--help'
          usage
          exit 0
        when '--xml'
          params[:is_xml] = true
        else
          # everthing else throws an error
      end
    end
  rescue GetoptLong::InvalidOption => e
    $stderr.write "#{EXECUTABLE_NAME}: #{e.message}\n"
    exit ERROR_INVOCATION
  end

  return params
end

begin # main()

  params = parse_cmd_line

  tokenizer   = Tokenizer.new
  morphalizer = TRMorph.new
  dictionary  = Dictionary.new

  # read the dictionary from disk
  dictionary.load('~/.tr-lang-tools/dict.dat')

  # read and tokenize all input
  if params[:is_xml]
    begin
      xml_doc = Nokogiri::XML(ARGF) do |config|
        config.strict.noent.nocdata.dtdload.xinclude
      end
    rescue Nokogiri::XML::SyntaxError => e
      msg = "->#{" Line #{e.line}:" if e.line != 0} #{e.message}"
      raise RuntimeError, "parse errors\n#{msg}"
    end

    tokenizer.update(xml_doc.root.text)
  else
    ARGF.each_line do |line|
      tokenizer.update(line)
    end
  end

  tokens = tokenizer.acquired_tokens

  # now get all stems using trmorph
  roots = {}

  tokens.each do |token|
    morphalizer.find_roots(token).each do |root|
      roots[root] = 1
    end
  end

  # lookup or translate all words
  roots.keys.each do |word|
    dictionary.translate_cached(word)
  end

  # save the dictionary back to disk
  dictionary.save('~/.tr-lang-tools/dict.dat')

rescue SystemExit => e
  exit e.status
rescue Exception => e
  $stderr.write "#{EXECUTABLE_NAME}: #{e.message}\n"
  exit ERROR_RUNTIME
end


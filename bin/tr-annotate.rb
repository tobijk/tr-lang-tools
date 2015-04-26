#!/usr/bin/env ruby
#-*- encoding: utf-8 -*-
#
# Description: Annotate words in the HTML document with translations.
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
  $stderr.write "TR Language Tools XHTML annotation tool, version #{TRTOOLS_VERSION}              \n"
  $stderr.write "Copyright 2012, Tobias Koch <tobias.koch@gmail.com>                              \n"
  $stderr.write "                                                                                 \n"
  $stderr.write "#{EXECUTABLE_NAME} [OPTIONS] <xhtml_file>                                        \n"
  $stderr.write "                                                                                 \n"
  $stderr.write "OPTIONS:                                                                         \n"
  $stderr.write " --help, -h             Print this help text and exit                            \n"
  $stderr.write "                                                                                 \n"
end

def parse_cmd_line
  params = {}

  opts = GetoptLong.new(
    ['--help', '-h', GetoptLong::NO_ARGUMENT ]
  )

  begin
    opts.quiet = true
    opts.each do |opt, arg|
      case opt
        when '--help'
          usage
          exit 0
        else
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

  if ARGV.length < 1
    usage
    exit ERROR_INVOCATION
  end

  tokenizer   = Tokenizer.new
  morphalizer = TRMorph.new
  dictionary  = Dictionary.new

  # read the dictionary from disk
  dictionary.load('~/.tr-lang-tools/dict.dat')

  # for each file
  ARGV.each do |xhtml_file|
    xml_doc = nil

    # load as XML document
    File.open(xhtml_file, 'r') do |fp|
      begin
        xml_doc = Nokogiri::XML(fp) do |config|
          config.strict.noent.nocdata.dtdload.xinclude
        end
      rescue Nokogiri::XML::SyntaxError => e
        msg = "->#{" Line #{e.line}:" if e.line != 0} #{e.message}"
        raise RuntimeError, "parse errors\n#{msg}"
      end
    end

    node  = xml_doc.root
    vocab = {}

    while node
      if node.text? and not node.text.strip.empty?
        tokenizer.update(node.text).each do |token|

          # find all stems
          roots = morphalizer.find_roots(token)

          # add them to the vocabulary
          roots.each {|r| vocab[r] = 1}

          puts roots.to_s

          # annotate word
        end
      end

      if node.child
        node = node.child
      else
        while !node.parent.document?
          if node.next_sibling
            node = node.next_sibling
            break
          else
            node = node.parent
          end
        end

        break if node.parent.document?
      end
    end

    # for each stem
      # get translation and
        # write javascript...
  end

rescue SystemExit => e
  exit e.status
rescue Exception => e
  $stderr.write "#{EXECUTABLE_NAME}: #{e.message}\n"
  exit ERROR_RUNTIME
end


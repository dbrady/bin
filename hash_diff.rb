#!/usr/bin/env ruby
# hash_diff.rb - display a colorized side-by-side diff of two structures

# ----------------------------------------------------------------------
# Usage:
#
# Copy your unruly hashes to irb or a ruby script somewhere, then add these 2
# lines:
#
# load File.expand_path(File.join(File.dirname(__FILE__),"bin/hash_diff.rb"))
# hash_diff h1, h2
#
# If you run this as a script with pagination, you'll want `less -R` to
# preserve the ANSI color codes.
# ----------------------------------------------------------------------


def colordiff_present?
  system('which colordiff > /dev/null')
end

def osx?
  `uname -s`.strip == 'Darwin'
end

def ubuntu?
  uname = `uname -a`
  uname.start_with?('Linux') && uname =~ /^Linux .*Ubuntu/
end

def linux?
  uname = `uname -a`
  uname.start_with? 'Linux'
end

if !colordiff_present?
  puts "hash_diff needs the colordiff command to work."
  if osx?
    puts "Looks like you're on OSX. You can install colordiff with"
    puts "brew install colordiff"
  elsif ubuntu?
    puts "Looks like you're on Ubuntu. You can install colordiff with"
    puts "sudo apt install colordiff"
  else
    if linux?
      puts "Looks like you're on a non-Ubuntu flavor of Linux."
    else
      puts "I can't recognize your OS from the uname command."
    end
    puts <<WTF_OS
Check https://www.colordiff.org and see if you can install it manually.
There are instructions on the website for manually installing the script and its
rc file for other operating systems. Good luck!

The following *should* work on a CMM vagrant RHEL6 instance:
(cd &&
  wget https://www.colordiff.org/colordiff-1.0.18.tar.gz &&
  tar -zxvf colordiff-1.0.18.tar.gz &&
  cd colordiff-1.0.18 &&
  sudo make install)
WTF_OS
  end
  exit -1
end

# TODO: Write the rest of this script. 90% of the work is massaging the input
# from an RSpec diff or a WebMock stub diff. In a perfect world we copy the mess
# directly from rspec and then paste it into the script somehow. For now, what
# you want to do is create a ruby script file and save it off with the two
# hashes. Then write both hashes to separate disk files, formatted with
# JSON.pretty_generate, and finally run colordiff -y file1.json file2.json.

# I know, I know. Yuck. But there you go.

begin
  require 'json'
rescue LoadError
  puts "hash_diff requires the 'json' gem. You can install it with"
  puts "gem install json"
  exit -1
end

require 'tempfile'

def array_deep_sort_hash_keys(array)
  array.map do |item|
    if item.is_a? Hash
      hash_deep_sort_keys(item)
    elsif item.is_a? Array
      array_deep_sort_hash_keys(item)
    else
      item.dup
    end
  end
end

def hash_deep_sort_keys(hash)
  h = {}
  hash.keys.sort.each do |key|
    value = hash[key]
    if value.is_a? Hash
      h[key] = hash_deep_sort_keys value
    elsif value.is_a? Array
      h[key] = array_deep_sort_hash_keys value
    else
      h[key] = value.dup
    end
  end
  h
end

def hash_diff(h1, h2)
  h1 = hash_deep_sort_keys(h1)
  h2 = hash_deep_sort_keys(h2)
  file1 = Tempfile.new
  file1.puts JSON.pretty_generate(h1)
  file1.close

  file2 = Tempfile.new
  file2.puts JSON.pretty_generate(h2)
  file2.close

  system("colordiff -y '#{file1.path}' '#{file2.path}'")
ensure
  file1.unlink
  file2.unlink
end

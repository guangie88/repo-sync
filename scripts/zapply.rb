#!/usr/bin/env ruby
require_relative 'zapply-impl.rb'

if ARGV.length != 2 
  abort('Usage: script <sync root dir> <diff file to apply>') 
end

sync_root_dir, diff_file = ARGV 

# returns the exit status value from applying
exit apply(sync_root_dir, diff_file)

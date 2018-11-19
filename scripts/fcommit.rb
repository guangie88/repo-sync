#!/usr/bin/env ruby
require_relative 'fcommit-impl.rb'

if ARGV.length != 1 
  abort 'Usage: script <sync root dir>'
end

sync_root_dir = ARGV[0]

# dumps the serialized bytes into standard output
commit_content = commit(sync_root_dir)
commit_content_ser = Marshal.dump(commit_content)

print(commit_content_ser)

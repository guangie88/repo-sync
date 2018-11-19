#!/usr/bin/env ruby

require_relative 'zdiff-impl.rb'

if ARGV.length != 6 
  abort('Usage: script <sync root dir> <previous commit file> <current commit file> <diff file> <split file size> <split summary file>')
end

sync_root_dir, prev_commit_file, curr_commit_file, diff_file, split_file_size, split_summary_file = ARGV

# serializes and return success status 
archive_res = diff(diff_file, split_file_size, sync_root_dir, prev_commit_file, curr_commit_file, split_summary_file)

exit(archive_res ? 0 : 1)

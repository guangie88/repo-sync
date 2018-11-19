#!/usr/bin/env ruby

# this script sends the summary file and the split files over http

require 'json'

if ARGV.length != 3 
  abort('Usage: script <summary file> <split root dir> <enqueue state file>')
end

summary_file, split_root_dir, enqueue_state_file = ARGV

summary = JSON.parse(File.read(summary_file))
enqueue_state = File.exist?(enqueue_state_file) ? JSON.parse(File.read(enqueue_state_file)) : Array.new

def add_to_enqueue(enqueue_state, file)
  # stores the file paths in absolute file path
  enqueue_state.push(File.absolute_path(file))
end

# enqueue the summary file first
add_to_enqueue(enqueue_state, summary_file)

# enqueue the split files next
summary.each{|split_file_name| add_to_enqueue(enqueue_state, File.join(split_root_dir, split_file_name)) }

# dumps the enqueue back into the file
File.open(enqueue_state_file, 'w') {|file| file.write(JSON.dump(enqueue_state)) }

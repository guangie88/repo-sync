#!/usr/bin/env ruby

require 'json'
require 'net/http'

require_relative 'misc.rb'
require_relative 'uri-joiner.rb'

if ARGV.length != 4
  abort('Usage: script <dequeue state file> <server uri> <dir uri> <split root dir>')
end

dequeue_state_file, server_uri, dir_uri, split_root_dir = ARGV
dequeue_state = File.exist?(dequeue_state_file) ? JSON.parse(File.read(dequeue_state_file)) : Array.new

uri_joiner = URIJoiner.new
uri_joiner.set_hostname(server_uri)

original_queue_len = dequeue_state.length

# accumulate the number of successful gets
success_count, flag = dequeue_state.reduce([0, true]) do |(success_count, flag), split_file|
  if flag
    Net::HTTP.start(uri_joiner.hostname) do |http|
      # relative path must begin with slash
      resp = http.get(uri_joiner.set_path(dir_uri).append_path(split_file).path)

      if resp.class == Net::HTTPOK
        File.open(File.join(split_root_dir, split_file), 'wb') do |file|
          file.write(resp.body)
        end

        # successful getting the file, add to count and continue with next file
        [success_count + 1, true]
      else
        # unsuccessful get, do not add to count and soft-abort
        [success_count, false]
      end
    end
  else
    # previous get was already unsuccessful, so return the same value
    [success_count, flag]
  end
end

# removes entries from queue (from front) that were successful
(0...success_count).each do |_|
  dequeue_state.shift()
end

# writes the modified dequeue state back into file
dequeue_state_json = JSON.dump(dequeue_state)
File.open(dequeue_state_file, 'w') {|file| file.write(dequeue_state_json) }

remaining_count = original_queue_len - success_count

if original_queue_len == 0
  exit Dequeue::ALREADY_EMPTY
elsif remaining_count == 0
  exit Dequeue::JUST_EMPTIED
else
  exit Dequeue::NOT_EMPTY 
end

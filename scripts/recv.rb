#!/usr/bin/env ruby

require 'json'
require 'net/http'

require_relative 'misc.rb'
require_relative 'uri-joiner.rb'

if ARGV.length != 4 
  abort('Usage: script <server uri> <dir uri> <summary file name> <dequeue state file>')
end

server_uri, dir_uri, summary_file_name, dequeue_state_file = ARGV

uri_joiner = URIJoiner.new
uri_joiner.set_hostname(server_uri)

resp = Net::HTTP.get_response(uri_joiner.hostname, uri_joiner.set_path(dir_uri).append_path(summary_file_name).path)

if resp.is_a?(Net::HTTPSuccess)
  summary_content = resp.body 
  split_diff_file_names = JSON.parse(summary_content)

  dequeue_state = File.exist?(dequeue_state_file) ? JSON.parse(File.read(dequeue_state_file)) : Array.new
  dequeue_state += split_diff_file_names
  dequeue_state_json = JSON.dump(dequeue_state)

  # writes the dequeue state back into file
  File.open(dequeue_state_file, 'w') {|file| file.write(dequeue_state_json) }

  exit Recv::OK 
else
  exit Recv::FAIL
end

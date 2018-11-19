#!/usr/bin/env ruby

# this script sends the summary file and the split files

require 'json'
require 'pathname'
require_relative 'multi-logger.rb'

if ARGV.length != 4
  abort('Usage: script <queue state file> <send count> <files root dir> <send (or simulate) cmd format>')
end

MAX_LOG_FILE_COUNT = 10
MAX_LOG_FILE_SIZE = 1048576
mlogger.load(Logger.new(STDOUT), Logger.new(File.join(__dir__, '../logs/send.log'), MAX_LOG_FILE_COUNT, MAX_LOG_FILE_SIZE))

current_working_dir = Dir.pwd

queue_state_file, send_count_str, files_root_dir, send_cmd_fmt = ARGV
queue_state = JSON.parse(File.read(queue_state_file))

# send over the first # files
send_count = Integer(send_count_str)
actual_send_count = [queue_state.length, send_count].min

mlogger.info("# of files to send from queue: #{actual_send_count}")

(0...actual_send_count).each do |_|
  # shift extracts the first item and return the value
  file_to_send = queue_state.shift()
  send_cmd = send_cmd_fmt % { file: file_to_send, file_name: File.basename(file_to_send) }

  # some http commands can only accept file names
  Dir.chdir(files_root_dir)
  mlogger.info("Changed working directory to '#{files_root_dir}'...")

  mlogger.info(send_cmd)
  send_status = system(send_cmd)

  if send_status
    mlogger.info('Above send command is okay!')
  else
    mlogger.error('Above send command returned error, but continuing...')
  end

  Dir.chdir(current_working_dir)
  mlogger.info("Changed working directory back to '#{current_working_dir}'!")
end

# dumps the queue state back into file
File.open(queue_state_file, 'w') {|file| file.write(JSON.dump(queue_state)) }

#!/usr/bin/env ruby

# creates random data file with random file name
# with possibly random number of nested directories with random directory names =)
# can also randomly delete a single file at lower probability

require 'fileutils'
require 'pathname'

if ARGV.length != 1
  abort 'Usage: <sync destination dir>'
end

dst_dir = ARGV[0]

def rand_str_gen(length)
  (0...rand(length)).map{ ('A'.ord + rand('Z'.ord - 'A'.ord)).chr }.join
end

def create_rand_dirs(prob, length)
  rand() <= prob ? File.join(rand_str_gen(length), create_rand_dirs(prob, length)) : ''
end

max_rand_name_length = 16
max_rand_data_length = 256

delete_file_prob = 0.3
create_dir_prob = 0.6

# randomly deletes a random file
if rand() <= delete_file_prob
  files = Dir.glob(File.join(dst_dir, '**'))

  if files.length > 0
    FileUtils.rm_rf(files[rand(0...files.length)])
  end
end

# generate the entire file path to the random file
begin
  dst_file = File.join(dst_dir, create_rand_dirs(create_dir_prob, max_rand_name_length), rand_str_gen(max_rand_name_length))
  dst_dir = Pathname.new(dst_file).parent
  FileUtils.mkdir_p(dst_dir)

  # writes into the random file
  File.open(dst_file, 'w') {|file| file.write(rand_str_gen(max_rand_data_length)) }
rescue
  # sometimes the directory and file names clash 
  # just retry using another path
  if Dir.exists?(dst_dir) && Dir.entries(dst_dir) == 2
    # checks for empty directory to remove
    Dir.delete(dst_dir)
  end

  retry
end

exit(0)

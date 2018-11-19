#!/usr/bin/env ruby
require 'fileutils'
require 'logger'
require 'pathname'
require_relative 'multi-logger.rb'

# some argument count check
if ARGV.length < 4 || ARGV.length > 5
  abort 'Usage: <repo name> <sync target dir> <patch dir> <sync script file path> [log file path]'
end

# descriptive name for the repository
# used for naming the patch file
repo_name = ARGV[0]

# sync target directory to push the mirrored content into
# git working directory is always one parent before the sync directory
# this is to prevent mirror cleanup from killing the git working directory
sync_dir = File.absolute_path(ARGV[1]) 

# git patch file settings
patch_dir = File.absolute_path(ARGV[2])
hash_bef_name = 'bef-sync.hash'
hash_aft_name = 'aft-sync.hash'

patch_ext = 'patch'
patch_name = "#{repo_name}-#{Time.now.strftime('%Y%d%m-%H%M%S')}.#{patch_ext}"

# sub-script to run for various repositories
script_file = File.absolute_path(ARGV[3])

# creates a standard [+ file logger]
logger =
  if ARGV.length == 5 
    # log file path for logger for debugging purposes
    log_file = File.absolute_path(ARGV[4])
    log_dir = Pathname.new(log_file).parent
    FileUtils.mkdir_p(log_dir)

    # log file settings
    max_log_files = 10
    max_log_file_size = 1048576

    MultiLogger.new(Logger.new(STDOUT), Logger.new(log_file, max_log_files, max_log_file_size))
  else
    MultiLogger.new(Logger.new(STDOUT))
  end

# executable for creating hashes and diff patches
exe_dir = File.absolute_path(File.join(__dir__, '../bin'))
hash_exe_name = 'recursive_diff_gen'

# Step 1: Deletes any previous diff patch files.
#         Either shifts the after-hash (if present) to before-hash
#         or creates the new before-hash.
hash_bef_file = File.join(patch_dir, hash_bef_name)
hash_aft_file = File.join(patch_dir, hash_aft_name)
hash_exe_file = File.join(exe_dir, hash_exe_name)

# creates the directory path all the way to the sync and patch directories
# in case these directories have not been created before
FileUtils.mkdir_p(sync_dir)
FileUtils.mkdir_p(patch_dir)

Dir.glob(File.join(patch_dir, "*.#{patch_ext}")).select do |prev_patch_file|
  # removes all previous patch files
  FileUtils.rm(prev_patch_file)
  logger.info("Deleted patch file at #{prev_patch_file}.")
end

if File.exist?(hash_aft_file)
  # this will automatically overwrite the previous hash file
  FileUtils.mv(hash_aft_file, hash_bef_file)
  logger.info('Shifted previous after-sync hash file as before-sync hash file.')
else
  # generates the before-sync hash file
  system "#{hash_exe_file} #{sync_dir} #{hash_bef_file}"
  logger.info("Generated before-sync hash file at #{hash_bef_file}.")
end

# Step 2: Performs syncing of repository files through external script.
system "#{script_file} #{sync_dir}"

# Step 3: Creates the after-sync hash and generates the diff patch file.
#         The diff patch file contains the necessary data to re-create
#         the missing files to transform a given before-sync directory
#         to be transformed into the after-sync condition.
#         All extra files in the before-sync are also removed.
patch_file = File.join(patch_dir, patch_name)

system "#{hash_exe_file} #{sync_dir} #{hash_aft_file} #{hash_bef_file} #{patch_file}"
logger.info("Generated after-sync hash file at #{hash_aft_file}.")

logger.info("Completed sync operation for #{repo_name} at #{Time.now}!")

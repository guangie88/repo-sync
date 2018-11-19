#!/usr/bin/env ruby

# this script compares against two commit files and generates the diff
# the diff is able to determine if the current sync root directory
# is at the correct commit before performing the sync operation
# the sync operation includes deleting files that do not exist in the current commit
# as well as adding the new files in the current commit
# note that the previous commit file can be empty string
# to denote generating diff against an empty directory (i.e. first commit diff)

require 'json'
require 'tempfile'

# needed for deserializing CommitContent
require_relative 'fcommit-impl.rb'
require_relative 'misc.rb'

$archive_exe = '7za'

if !which($archive_exe)
  abort("#{$archive_exe} is not available on this system for archiving files.")
end

def create_diff_files(diff_file, split_file_size, sync_root_dir, prev_hash, curr_hash, prev_commit, curr_commit)
  # creates a zip archive to capture all the files to be added
  # and additionally containing two extra special files to describe the commit hashes and files to delete
  file_selector = lambda {|(file, size, ctime)| file }

  # perform set differences to get files to remove and files to add
  prev_commit_files = prev_commit.map(&file_selector)
  curr_commit_files = curr_commit.map(&file_selector)

  # removing of files only compare against the file names
  # it should only be deleted only when the file name does not exist in the current commit
  to_remove_files = prev_commit_files - curr_commit_files

  # while adding needs to additionally compare against the file size + timestamp
  to_add_files = (curr_commit - prev_commit).map(&file_selector)

  # in addition, the files-to-add zip archive must contain the data in two files
  # but these files are not to be extracted because it would affect the hash values
  # 1. from-hash + to-hash
  # 2. files to delete
  
  hash_delete_file = '.hashdelete'
  hash_delete_path = File.join(sync_root_dir, hash_delete_file)

  File.open(hash_delete_path, 'wb') do |file|
    # adds the hashes file
    file.write(Marshal.dump(prev_hash))
    file.write(Marshal.dump(curr_hash))

    # adds the files-to-delete file
    file.write(Marshal.dump(to_remove_files))
  end

  # adds to the list of files to archive
  repo_sync_add_file = Tempfile.new('.repo-sync-add')

  # add the .hashdelete file first
  repo_sync_add_file.puts(hash_delete_file)

  # adds the files to add or overwrite
  to_add_files.each {|add_file| repo_sync_add_file.puts(add_file) }

  # must close before the archiving process takes place
  repo_sync_add_file.close

  # performs the archiving process (need to perform at the sync root directory)
  current_working_dir = Dir.pwd

  # note that diff_file must be taken as absolute first because of the chdir
  # whereas repo_sync_add_file only contains the file paths relative to the sync root, so no need to take absolute
  diff_file_abs = File.absolute_path(diff_file)

  Dir.chdir(sync_root_dir)
  archive_cmd = "#{$archive_exe} a -i@#{repo_sync_add_file.path} -v#{split_file_size} -mx0 #{diff_file_abs} > /dev/null"
  archive_res = system(archive_cmd)
  Dir.chdir(current_working_dir)

  # removes the hash_delete_file to prevent it from affecting the commit hash value
  if File.exists?(hash_delete_path)
    File.delete(hash_delete_path)
  end

  archive_res
end

def diff(diff_file, split_file_size, sync_root_dir, prev_commit_file, curr_commit_file, split_summary_file)
  # checks for special condition of checking against empty diff 
  empty_diff = prev_commit_file == '' ? true : false

  # gets the commit binary data
  prev_commit_bin = !empty_diff ? File.read(prev_commit_file) : nil
  curr_commit_bin = File.read(curr_commit_file)

  # deserializes the first layer for commit
  prev_commit_deser = prev_commit_bin ? Marshal::load(prev_commit_bin) : nil
  curr_commit_deser = Marshal::load(curr_commit_bin)

  # gets the commit hash values
  prev_commit_hash = prev_commit_deser ? prev_commit_deser.hash : nil
  curr_commit_hash = curr_commit_deser.hash

  # deserializes the second layer and get the actual file + sizes arrays
  prev_commit_file_size_ctimes = prev_commit_deser ? Marshal::load(prev_commit_deser.bin) : Array.new
  curr_commit_file_size_ctimes = Marshal::load(curr_commit_deser.bin)

  archive_res = create_diff_files(
    diff_file,
    split_file_size,
    sync_root_dir,
    prev_commit_hash,
    curr_commit_hash,
    prev_commit_file_size_ctimes,
    curr_commit_file_size_ctimes)

  # find all the split files and write file names into json summary file
  split_output_files = Dir.glob(diff_file + '*')
    .map{|file| File.basename(file) }
    .sort

  # summary file will also be formatted like the split files
  split_output_files_json = JSON.generate(split_output_files)
  File.open(split_summary_file, 'w') {|file| file.write(split_output_files_json) }

  return archive_res
end

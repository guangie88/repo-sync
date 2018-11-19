#!/usr/bin/env ruby

# this script syncs all the relative path from sync root directory
# and tags the file size of the files with the file paths
# and also generate the hash value to tag the commit based on the serialized byte data

require 'digest'
require 'find'
require 'pathname'

FullCommitContent = Struct.new(:hash, :bin)

def commit(sync_root_dir)
  # can pass in empty string to indicate committing empty directory
  # otherwise also possible for sync root directory to be empty
  # if so, create an empty directory

  is_new_dir = !File.exist?(sync_root_dir)

  if sync_root_dir.length > 0 && is_new_dir
    Dir.mkdir(sync_root_dir)
  end

  # find works better than Dir.glob
  # because it can search for hidden files and directories (. prefixed files)
  # combines the relative path of each file and its associated file size
  files = is_new_dir ? Array.new : Find.find(sync_root_dir)

  # accepts any kind of symlinks and all files (not directory) only
  non_dir_file_size_ctimes = files
    .select {|file| File.symlink?(file) || !File.directory?(file) }
    .map do |file|
      lstat = File.lstat(file)

      [Pathname.new(file).relative_path_from(Pathname.new(sync_root_dir)).to_s(),
       lstat.size,
       lstat.ctime]
    end

  non_dir_file_sizes = non_dir_file_size_ctimes.map {|(file_path, size, ctime)| [file_path, size] }

  # serializes the file + sizes content
  # sets content to nil if empty directory
  def hash(file_sizes_ser)
    hasher = Digest::MD5::new
    hasher.update(file_sizes_ser)
    hasher.hexdigest
  end

  # commit hash to tag this commit
  # sets hash to nil if empty directory
  commit_hash = non_dir_file_sizes.empty? ? '00000000000000000000000000000000' : hash(Marshal::dump(non_dir_file_sizes))

  # serialize one more time with the hash and the serialized file + sizes content
  fcommit_content = FullCommitContent.new
  fcommit_content.hash = commit_hash
  fcommit_content.bin = Marshal::dump(non_dir_file_size_ctimes)

  return fcommit_content
end

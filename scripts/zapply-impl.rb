#!/usr/bin/env ruby

# this script applies the diff file on the given sync root directory
# it first checks if the current root directory is at the right commit
# it does not apply if the commit is incorrect
# otherwise it removes old files and adds new files from the diff

require 'fileutils'
require 'find'
require 'pathname'

require_relative 'fcommit-impl.rb'
require_relative 'misc.rb'

$archive_exe = '7za'

if !which($archive_exe)
  abort("#{$archive_exe} is not available on this system for unarchiving files.")
end

def apply(sync_root_dir, diff_file)
  def nil_conv(value)
    value ? value : 'NIL'
  end

  def remove_empty_parent_dirs(dir)
    dir = Pathname.new(dir)

    # count == 1 indicates empty directory because . directory is included
    if Find.find(dir).count == 1 
      FileUtils.rmdir(dir)
      remove_empty_parent_dirs(dir.parent)
    end
  end

  # must commit first before unarchiving the files
  commit_content = commit(sync_root_dir)

  diff_file_abs = File.absolute_path(diff_file)

  # apply the unarchiving process on the first diff file
  current_working_dir = Dir.pwd
  Dir.chdir(sync_root_dir)

  unarchive_res = system %Q(#{$archive_exe} x -aoa #{diff_file_abs} > /dev/null)
  Dir.chdir(current_working_dir)

  # retrieves the special hash-delete content file
  hash_delete_file = '.hashdelete'
  hash_delete_path = File.join(sync_root_dir, hash_delete_file)
  hash_delete_content = File.open(hash_delete_path)

  from_hash = Marshal.load(hash_delete_content)
  _to_hash = Marshal.load(hash_delete_content)
  to_remove_files = Marshal.load(hash_delete_content)

  # must delete the file before ending the session
  hash_delete_content.close
  File.delete(hash_delete_path)

  if commit_content.hash != from_hash
    # invalid sync root directory to apply the diff
    puts("Cannot apply diff: SYNC root-dir hash: #{nil_conv(commit_content.hash)} VS DIFF from-hash: #{nil_conv(from_hash)}")
    return false
  end

  # performs the removal of files after the unzipping (will not remove files that were updated)
  to_remove_files.each do |to_remove_file|
    FileUtils.rm(File.join(sync_root_dir, to_remove_file))

    # checks recursive if the parent directory is empty and can be removed
    remove_empty_parent_dirs(File.join(sync_root_dir, Pathname.new(to_remove_file).parent))
  end

  return true
end

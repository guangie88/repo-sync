#!/usr/bin/env ruby
require 'fileutils'
require 'pathname'

if ARGV.length != 1
  abort 'Usage: <sync destination dir>'
end

dst_dir = ARGV[0].chomp('/')

# for rsync
# mirror_url = 'rsync://mirror.0x.sg/ubuntu'
#   .chomp('/')

# for http
mirror_url = 'http://sg.archive.ubuntu.com'
  .chomp('/')

# mirror_url = 'http://mirror.nus.edu.sg/ubuntu'

search_dir = 'dists'
to_sync_dirs = ['dep11', 'i18n']

local_search_root_dir = File.join(dst_dir, search_dir)
remote_search_root_dir = mirror_url + "/#{search_dir}"

# get two layers of directories within search directory
dist_dirs = Dir.glob(File.join(local_search_root_dir, '*/*/'))

dist_sync_dirs = dist_dirs
  .product(to_sync_dirs).map do |d, s|
    File.join(Pathname.new(d).relative_path_from(Pathname.new(local_search_root_dir)), s)
  end

dist_sync_dirs.each do |dist_sync_dir|
  # for rsync
  # local_dst_dist_sync_dir = File.join(local_search_root_dir, Pathname.new(dist_sync_dir).parent)

  # for http
  local_dst_dist_sync_dir = File.join(local_search_root_dir, dist_sync_dir)

  remote_src_dist_sync_dir = remote_search_root_dir + "/#{dist_sync_dir}"

  # for rsync
  # cmd = "rsync -avz --delete #{remote_src_dist_sync_dir} #{local_dst_dist_sync_dir}"

  # for http
  cmd = "wget -m -r -np -nH --cut-dirs=4 --reject index.html -P #{local_dst_dist_sync_dir} #{remote_src_dist_sync_dir}/"

  system(cmd)
end

# allowed to fail any of the rsync commands
exit(0)

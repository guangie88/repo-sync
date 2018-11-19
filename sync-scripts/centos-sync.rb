#!/usr/bin/env ruby
require 'fileutils'
require 'pathname'

if ARGV.length != 1
  abort 'Usage: <sync destination dir>'
end

dst_dir = ARGV[0].chomp('/')

mirror_url = 'rsync://mirror.hostduplex.com/centos'
  .chomp('/')

# various centOS version to mirror
versions = [6, 7]

# packages to extract
packages = ['extras', 'os', 'updates']

# architectures to support
archs = ['x86_64']

# cartesian product on all the three above components
vpa_paths = versions
  .product(packages).map { |v, p| "#{v}/#{p}" }
  .product(archs).map { |vp, a| "#{vp}/#{a}" }

# set the max number of retries
max_retries = 3

exit_codes = vpa_paths.map do |vpa|
  # rsync with archive + compress flags, src -> dst
  dst_vpa_dir = "#{dst_dir}/#{Pathname.new(vpa).parent}"
  FileUtils.mkdir_p(dst_vpa_dir)

  # executes the synchronization mechanism with retries
  # note that system command returns true if rsync has status return 0 (success)
  (0...max_retries).any? do
    # the slash after the last argument must be present, otherwise it targets a file instead 
    cmd = "rsync -avz --delete #{mirror_url}/#{vpa} #{dst_vpa_dir}"
    p cmd
    system(cmd)
  end

  $?.exitstatus
end

exit(exit_codes.reduce {|acc_code, cur_code| acc_code != 0 ? acc_code : cur_code })

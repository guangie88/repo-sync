#!/usr/bin/env ruby
require 'fileutils'
require 'pathname'

if ARGV.length != 1
  abort 'Usage: <sync destination dir>'
end

dst_dir = ARGV[0].chomp('/')

mirror_url = 'rsync://dl.fedoraproject.org/fedora-epel'
  .chomp('/')

# various EPEL version to mirror
versions = [6, 7]

# architectures to support
archs = ['x86_64']

# cartesian product on all the three above components
va_paths = versions
  .product(archs).map { |vp, a| "#{vp}/#{a}" }

# set the max number of retries
max_retries = 3

exit_codes = va_paths.map do |va|
  # rsync with archive + compress flags, src -> dst
  dst_va_dir = "#{dst_dir}/#{Pathname.new(va).parent}"
  FileUtils.mkdir_p(dst_va_dir)

  # executes the synchronization mechanism with retries
  # note that system command returns true if rsync has status return 0 (success)
  (0...max_retries).any? do
    # the slash after the last argument must be present, otherwise it targets a file instead 
    cmd = "rsync -avz --delete #{mirror_url}/#{va} #{dst_va_dir}"
    p cmd
    system(cmd)
  end

  $?.exitstatus
end

exit(exit_codes.reduce {|acc_code, cur_code| acc_code != 0 ? acc_code : cur_code })

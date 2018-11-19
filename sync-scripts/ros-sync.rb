#!/usr/bin/env ruby

if ARGV.length != 1
  abort 'Usage: <sync destination dir>'
end

dst_dir = ARGV[0]

# place the highest priority mirror url in front
mirror_urls = ['packages.ros.org/ros'] 

# various ubuntu version to mirror
version_names = ['precise', 'trusty', 'wily', 'xenial', 'yakkety', 'zesty'] 
# version_names = ['trusty', 'xenial'] 
package_suffixes = ['']
sources = ['main']

# cartesian product on the version names and suffixes to determine all the repo parts to get
repo_packages = version_names.product(package_suffixes)
  .reduce('') { |accum, vp| accum + vp[0] + vp[1] + ',' }
  .chomp(',')

source_names = sources
  .reduce('') { |accum, name| accum + name + ',' }
  .chomp(',')

# ignoring gpg key
# gpg_cmd = 'gpg --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg --export | gpg --no-default-keyring --keyring trustedkeys.gpg --import'
# puts(gpg_cmd)
# system(gpg_cmd)

# sets max number of retries
max_retries = 3 

# executes the synchronization mechanism with retries and spare urls
# note that system returns true if debmirror has status return 0 (success)
mirror_urls.any? do |mirror_url|
  (0...max_retries).any? do
    cmd = "debmirror --no-check-gpg -v -p -h #{mirror_url} --method=http --nosource -d=#{repo_packages} -s=#{source_names} -a=amd64 #{dst_dir}"
    p cmd 
    system(cmd)
  end
end

exit($?.exitstatus)

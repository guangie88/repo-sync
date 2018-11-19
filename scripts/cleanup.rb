#!/usr/bin/env ruby

require 'json'

if ARGV.length != 2 
  abort('Usage: script <root dir> <cleanup config file>')
end

# note that this script will at least retain the most recent commit, diff and summary
# i.e. each of the count is minimally 1
# summary cleanup does not apply to receiving side since the summary content
# was never dumped into a file

MIN_COMMIT_COUNT = 1
MIN_DIFF_COUNT = 1
MIN_SUMMARY_COUNT = 1

root_dir, config_file = ARGV
config = JSON.parse(File.read(config_file))

commit_glob = File.join(root_dir, config['commit_glob'])
commit_regex = config['commit_regex']
commit_count_raw = config['commit_count']
commit_count = [commit_count_raw, MIN_COMMIT_COUNT].max

diff_glob = File.join(root_dir, config['diff_glob'])
diff_regex = config['diff_regex']
diff_count_raw = config['diff_count']
diff_count = [diff_count_raw, MIN_DIFF_COUNT].max

summary_glob = File.join(root_dir, config['summary_glob'])
summary_regex = config['summary_regex']
summary_count_raw = config['summary_count']
summary_count = [summary_count_raw, MIN_SUMMARY_COUNT].max

def cleanup(glob, regex_str, count)
  # the regex is meant for both filtering
  # and grouping files into sets
  # which is particularly useful for diff
  # where there could be multiple batches of diff files

  regex = Regexp.new(regex_str)
  files = Dir.glob(glob).select {|file| file.match(regex) }

  # the key contains the pattern that matches the regex part only
  # i.e. usually it is the datetime value except for summary files
  file_sets = files.group_by {|file| file[regex] }

  sorted_file_sets = file_sets.sort_by do |(pattern, files)|
    # files is guaranteed to have at least one element
    # sort each set accordingly to the first file creation time
    File.ctime(files.first)
  end

  # performs the actual cleanup
  cleanup_count = [sorted_file_sets.length - count, 0].max

  (0...cleanup_count).each do |_|
    # pops out the first element
    _, files = sorted_file_sets.shift()
    files.each {|file| File.delete(file) }
  end
end

# perform cleanup on the three sets of files
cleanup(commit_glob, commit_regex, commit_count)
cleanup(diff_glob, diff_regex, diff_count)
cleanup(summary_glob, summary_regex, summary_count)

#!/usr/bin/env ruby

require 'fileutils'
require 'logger'
require 'json'
require 'pathname'
require 'shellwords'

require_relative 'scripts/fcommit-impl.rb'
require_relative 'scripts/misc.rb'
require_relative 'scripts/multi-logger.rb'
require_relative 'scripts/pidfile.rb'
require_relative 'scripts/tag-formatter.rb'

def here(path)
  here_impl(__dir__, path)
end

config_file = here('config/sync-send.json')

# removes away the log portion from the configuration
repo_config = JSON.parse(File.read(config_file))

# formats
datetime_fmt = repo_config['datetime_fmt']
current_datetime = Time.now.strftime(datetime_fmt)

# gets the log file path
sync_root_dir = here(repo_config['sync_root_dir'])
patch_root_dir = here(repo_config['patch_root_dir'])
log_file = here(repo_config['log_file'])
log_dir = Pathname.new(log_file).parent.to_s

# other scripts to run
commit_script = here(repo_config['commit_script'])
diff_script = here(repo_config['diff_script'])
enqueue_script = here(repo_config['enqueue_script'])
send_script = here(repo_config['send_script'])
cleanup_script = here(repo_config['cleanup_script'])

# other config file 
cleanup_config_file = here(repo_config['cleanup_config_file'])

# commit parameters
other_commit_files_glob = repo_config['other_commit_files_glob']
commit_first_file_fmt = repo_config['commit_first_file_fmt']
commit_file_fmt = repo_config['commit_file_fmt']

# diff parameters
diff_file_fmt = repo_config['diff_file_fmt']
split_per_file_byte = repo_config['split_per_file_byte']
split_summary_file_fmt = repo_config['split_summary_file_fmt']
split_root_dir = here(repo_config['split_root_dir'])

# enqueue parameters
enqueue_state_file = here(repo_config['enqueue_state_file'])

# send parameters
send_cmd_fmt = repo_config['send_cmd_fmt']
simulate_cmd_fmt = repo_config['simulate_cmd_fmt']
send_simulate_flag = repo_config['send_simulate_flag']
send_count = repo_config['send_count']

fmt = TagFormatter.new

fmt
  .add(:sync_root_dir, sync_root_dir)
  .add(:patch_root_dir, patch_root_dir)
  .add(:datetime, current_datetime)

# creates the sync and patch root directories if not exist
FileUtils.mkdir_p(sync_root_dir)
FileUtils.mkdir_p(patch_root_dir)
FileUtils.mkdir_p(log_dir)

MAX_LOG_FILE_COUNT = 10
MAX_LOG_FILE_SIZE = 1048576
mlogger.load(Logger.new(STDOUT), Logger.new(log_file, MAX_LOG_FILE_COUNT, MAX_LOG_FILE_SIZE))

mlogger.info("Session at #{current_datetime} started...")

current_pid_valid = pidfile_guard(repo_config['pidfile']) do
  # iterate through each repository and syncing script
  repos = repo_config['repos']

  name_exit_values = repos.map do |name, attrs|
    dir_name = attrs['dir_name']
    script_file = here(attrs['script_file'])

    # runs the sync script for this repository
    sync_cmd = "#{script_file} #{File.join(sync_root_dir, dir_name)}"
    mlogger.info(sync_cmd)
    exit_value = system(sync_cmd)

    # return a tuple of name with associated exit value
    [name, exit_value]
  end

  # check the exit value for every repository
  # if there exists at least false value
  # do not proceed with creating the diff
  exit_value = name_exit_values.all? {|name, value| value }

  if !exit_value
    mlogger.error(name_exit_values)

    # but no need to abort yet
    CANNOT_SYNC_ERR_MSG = 'One or more repositories cannot sync completely, aborting commit and diff processes...'
    mlogger.error(CANNOT_SYNC_ERR_MSG)
  else
    # find all commit files, compare the date time and get the prev
    other_commit_files = Dir.glob(fmt.format(other_commit_files_glob))
  
    if other_commit_files.length == 0
      # if this is the first commit, create a dummy previous commit as a sentinel
      commit_first_file = fmt.format(commit_first_file_fmt)
  
      mlogger.info('Commiting first commit...')
      commit_cmd = %Q(#{commit_script} "" > #{commit_first_file})
      mlogger.info(commit_cmd)
      system(commit_cmd)
  
      other_commit_files.push(commit_first_file)
      mlogger.info("Committed empty directory into #{commit_first_file}!")
    end
  
    prev_commit_file = other_commit_files
      .sort_by{|commit_file| File.ctime(commit_file) }
      .last
  
    prev_commit_hash = Marshal.load(File.read(prev_commit_file)).hash
    fmt.add(:prev_commit_hash, prev_commit_hash)
  
    # commit the files after the sync
    mlogger.info('Commiting current...')
    curr_commit_content = commit(sync_root_dir)
    curr_commit_hash = curr_commit_content.hash
  
    if prev_commit_hash != curr_commit_hash
      # there is update of updates since the previous and current hashes are different
      curr_commit_file = fmt.format(commit_file_fmt)
      File.open(curr_commit_file, 'wb') {|file| file.write(Marshal.dump(curr_commit_content)) }
      mlogger.info("Committed current directory files into #{curr_commit_file}!")
  
      # diff between the previous commit and current commit (also splits)
      diff_file = fmt.format(diff_file_fmt)
      fmt.add(:diff_file_name, File.basename(diff_file))
  
      split_summary_file = fmt.format(split_summary_file_fmt)
      diff_cmd = "#{diff_script} #{sync_root_dir} #{prev_commit_file} #{curr_commit_file} #{diff_file} #{split_per_file_byte} #{split_summary_file}"
  
      mlogger.info('Diffing between previous and current commit...')
      mlogger.info(diff_cmd)
      archive_res = system(diff_cmd)
  
      mlogger.info("Created diff from #{prev_commit_hash} into #{diff_file}!")
    else
      # no file updates, so do not diff, split and enqueue
      mlogger.info("Same commit hash found for #{sync_root_dir}, performing only sending...")
    end
  end

  # enqueue regardless of any error because there might be possibly remaining files to send
  # enqueue the summary (together with the split files)
  enqueue_cmd = "#{enqueue_script} #{split_summary_file} #{split_root_dir} #{enqueue_state_file}"

  mlogger.info('Enqueuing files to send...')
  mlogger.info(enqueue_cmd)
  system(enqueue_cmd)

  mlogger.info("Enqueued files from #{split_summary_file}!")

  # send the files over from the enqueue
  send_cmd = send_simulate_flag ? simulate_cmd_fmt : send_cmd_fmt
  send_full_cmd = %Q(#{send_script} #{enqueue_state_file} #{send_count} #{split_root_dir} '#{send_cmd}')

  mlogger.info('Sending files to server')
  mlogger.info(send_full_cmd)
  system(send_full_cmd)

  mlogger.info('Sent files from the queue state file!')

  # cleanup
  cleanup_cmd = "#{cleanup_script} #{__dir__} #{cleanup_config_file}"

  mlogger.info('Cleaning up...')
  mlogger.info(cleanup_cmd)
  system(cleanup_cmd) 

  mlogger.info("Session at #{current_datetime} completed!")
end

if !current_pid_valid
  mlogger.error("Previous session still running, aborting current session...")
end

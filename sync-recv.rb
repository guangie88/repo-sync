#!/usr/bin/env ruby

require 'fileutils'
require 'logger'
require 'json'
require 'pathname'

require_relative 'scripts/fcommit-impl.rb'
require_relative 'scripts/misc.rb'
require_relative 'scripts/multi-logger.rb'
require_relative 'scripts/pidfile.rb'
require_relative 'scripts/tag-formatter.rb'

def here(path)
  here_impl(__dir__, path)
end

config_file = here('config/sync-recv.json') 
repo_config = JSON.parse(File.read(config_file))

# base directories
sync_root_dir = here(repo_config['sync_root_dir'])
patch_root_dir = here(repo_config['patch_root_dir'])
log_file = here(repo_config['log_file'])
log_dir = Pathname.new(log_file).parent.to_s

# script file paths
recv_script = here(repo_config['recv_script'])
dequeue_script = here(repo_config['dequeue_script'])
apply_script = here(repo_config['apply_script'])
cleanup_script = here(repo_config['cleanup_script'])

# other config file
cleanup_config_file = here(repo_config['cleanup_config_file'])

# parameters for scripts
server_uri = repo_config['server_uri']
dir_uri = repo_config['dir_uri']
dequeue_state_file = here(repo_config['dequeue_state_file'])
summary_file_name_fmt = repo_config['summary_file_name_fmt']
join_regex_pattern_fmt = repo_config['join_regex_pattern_fmt']

# to break the cyclic dependency
dequeue_step = nil

recv_loop = lambda do |hash, fmt, logger|
  summary_file_name = fmt.format(summary_file_name_fmt)
  logger.info("Obtaining #{summary_file_name} from server...")
  system %Q(#{recv_script} #{server_uri} #{dir_uri} #{summary_file_name} #{dequeue_state_file})
  recv_status = $?.exitstatus

  if recv_status == Recv::OK
    logger.info("Obtained #{summary_file_name} from server!")
    dequeue_step.call(hash, fmt, logger)
  else
    logger.info("#{summary_file_name} not available at server!")
  end
end

dequeue_step = lambda do |hash, fmt, logger|
  system %Q(#{dequeue_script} #{dequeue_state_file} #{server_uri} #{dir_uri} #{patch_root_dir})
  dequeue_status = $?.exitstatus

  can_recv, next_hash =
    case dequeue_status
    when Dequeue::ALREADY_EMPTY
      logger.info('Starting with empty queue, proceeding straight to receiving instead...')
      [true, hash]

    when Dequeue::JUST_EMPTIED
      logger.info('Just cleared the queue for receiving, proceeding to apply the archiving process...')
      join_regex_pattern = fmt.format(join_regex_pattern_fmt)
      regex_pattern = Regexp.new(join_regex_pattern)

      # get all files in the split root dir first
      files_in_split_root_dir = Dir.glob(File.join(patch_root_dir, '*'))

      # select only files that match the split diff file regex pattern
      split_files = files_in_split_root_dir
        .select {|file| file =~ regex_pattern }
        .sort

      # apply requires only the first file to unarchive
      join_output_file = split_files.first 
      apply_status = system %Q(#{apply_script} #{sync_root_dir} #{join_output_file})

      if apply_status
        logger.info("Successfully applied #{join_output_file}!")

        # need to get the next hash value since apply has been invoked
        next_hash = commit(sync_root_dir).hash
        fmt.add(:hash, next_hash)

        if hash == next_hash
          logger.info("Current hash and next hash are the same, previous diff apply had no effect, aborting...")
          [false, next_hash]
        else
          logger.info("Committed at #{sync_root_dir}!")
          [true, next_hash]
        end
      else
        logger.error("Fatal error in applying diff file #{join_output_file}, aborting sync-receiving...")
        [false, hash]
      end

    when Dequeue::NOT_EMPTY
      logger.info("Not all files are available to download for joining and applying yet.")
      [false, hash]
    end

  if can_recv
    recv_loop.call(next_hash, fmt, logger)
  end
end

# sets up logging
FileUtils.mkdir_p(log_dir)

MAX_LOG_FILE_COUNT = 10
MAX_LOG_FILE_SIZE = 1048576
logger = MultiLogger.new(Logger.new(STDOUT), Logger.new(log_file, MAX_LOG_FILE_COUNT, MAX_LOG_FILE_SIZE))

logger.info('Receiving session started...')

current_pid_valid = pidfile_guard(repo_config['pidfile']) do
  # start the operation
  initial_hash = commit(sync_root_dir).hash

  fmt = TagFormatter.new
  fmt.add(:hash, initial_hash).add(:patch_root_dir, patch_root_dir)

  dequeue_step.call(initial_hash, fmt, logger)

  # cleanup
  system %Q(#{cleanup_script} #{__dir__} #{cleanup_config_file})

  logger.info('Receiving session completed!')
end

if !current_pid_valid
  logger.error('Previous receiving session still running, aborting current session...')
end

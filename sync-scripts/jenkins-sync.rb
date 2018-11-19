#!/usr/bin/env ruby

# updates the list of urls to download
system('/home/weiguang/repo-sync/sync-scripts/jenkins-sync/jenkins-mod '\
  '-c /home/weiguang/repo-sync/sync-scripts/jenkins-sync/config/mod.toml '\
  '-l /home/weiguang/repo-sync/sync-scripts/jenkins-sync/config/log_mod.yml')

mode_exit_code = $?.exitstatus

if mode_exit_code != 0
  exit(mode_exit_code)
end

# only proceed to download if the update exit code is 0
system('/home/weiguang/repo-sync/sync-scripts/jenkins-sync/jenkins-sync '\
'-c /home/weiguang/repo-sync/sync-scripts/jenkins-sync/config/sync.toml '\
'-l /home/weiguang/repo-sync/sync-scripts/jenkins-sync/config/log_sync.yml')

sync_exit_code = $?.exitstatus
exit(sync_exit_code)

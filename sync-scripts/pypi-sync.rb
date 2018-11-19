#!/usr/bin/env ruby

# note that the configuration for bandersnatch is at /etc/bandersnatch.conf
# since the pypi files change way too rapidly within the day
# it is better to just try the mirroring once

system('/usr/local/bin/bandersnatch mirror')
exit_code = $?.exitstatus

# the exit code bandersnatch never seems to be 0
# even if the sync is successful
# as such always return 0
exit(0)

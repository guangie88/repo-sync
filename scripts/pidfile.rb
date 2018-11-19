#!/usr/bin/env ruby

def write_pidfile(filename, dir = Dir.home)
  pid_path = File.join(dir, filename)
  p pid_path
  write_pid = ->() { File.open(pid_path, 'w') { |file| file.write($$) } }

  if File.exists?(pid_path)
    pid = File.read(pid_path)
    
    # checks if error output is being produced when attempting to get previous process
    `ps -p #{pid} > /dev/null 2>&1`

    if $? == 0
      # previous process still running
      false
    else
      write_pid.call
      true
    end
  else
    write_pid.call
    true
  end
end

def clean_pidfile(filename, dir = Dir.home)
  pid_path = File.join(dir, filename)

  if File.exists?(pid_path)
    File.delete(pid_path)
  end
end

def pidfile_guard(filename, dir = Dir.home)
  valid = write_pidfile(filename, dir)

  if valid
    yield
    clean_pidfile(filename, dir)
    true
  else
    false
  end
end


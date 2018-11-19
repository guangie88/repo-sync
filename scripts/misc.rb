#!/usr/bin/env ruby

def here_impl(root_dir, path)
  Pathname.new(path).absolute? ? path : File.join(root_dir, path)
end

def which(cmd)
  exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
  ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
    exts.each { |ext|
      exe = File.join(path, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && !File.directory?(exe)
    }
  end
  return nil
end

class String
  def to_bool
    if self == 'true'
      true
    elsif self == 'false'
      false
    else
      raise ArgumentError.new(%Q(Invalid value for Boolean: "#{self}"))
    end
  end
end

module Recv
  OK = 0
  FAIL = 1
end

module Dequeue
  JUST_EMPTIED = 0
  ALREADY_EMPTY = 255
  NOT_EMPTY = 1
end

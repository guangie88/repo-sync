#!/usr/bin/env ruby

class URIJoiner
  def initialize
    self.hostname = ''
    self.path = '/'
  end

  def hostname=(hostname)
    @hostname = hostname.chomp('/')
  end

  def hostname
    @hostname
  end

  def set_hostname(hostname)
    self.hostname = hostname
    self
  end

  def path=(path)
    @path = prepend_slash_if_missing(path)
  end
  
  def path
    @path
  end

  def set_path(path)
    self.path = path
    self
  end

  def full
    self.hostname + self.path
  end

  def append_path(path_segment)
    self.path = self.path.chomp('/') + prepend_slash_if_missing(path_segment)
    self
  end

  def prepend_slash_if_missing(str)
    str.start_with?('/') ? str : '/' + str
  end

  private :prepend_slash_if_missing
end

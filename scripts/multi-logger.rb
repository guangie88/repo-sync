#!/usr/bin/env ruby

require 'logger'

def mlogger
  MultiLogger.default
end

class MultiLogger
  def initialize(*loggers)
    @loggers = loggers
  end

  def self.default
    @deflogger ||= MultiLogger.new(Logger.new(STDOUT))
  end

  def load(*loggers)
    @loggers = loggers 
  end

  def debug(*args)
    log('debug', *args)
  end

  def info(*args)
    log('info', *args)
  end

  def warn(*args)
    log('warn', *args)
  end

  def error(*args)
    log('error', *args)
  end

  def fatal(*args)
    log('fatal', *args)
  end

  def unknown(*args)
    log('unknown', *args)
  end

  private def log(method_name, *args)
    @loggers.each { |logger| logger.send(method_name, *args) }
  end
end

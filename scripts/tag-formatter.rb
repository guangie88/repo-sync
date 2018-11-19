#!/usr/bin/env ruby

class TagFormatter
  def initialize(*args)
    @tag_values = Hash.new
  end

  def add(tag, value)
    @tag_values[tag] = value
    self
  end

  def remove(tag)
    @tag_values.delete(tag)
    self
  end

  def format(target)
    target % @tag_values
  end
end

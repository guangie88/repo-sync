#!/usr/bin/env ruby
require 'docker'

if ARGV.length != 1
  abort 'Usage: <image output dir>'
end

image_dir = ARGV[0]
image_names = ['ubuntu', 'centos']

status_values = image_names.map do |image_name|
  # equivalent to docker pull ubuntu
  image = Docker::Image.create('fromImage' => "#{image_name}:latest")
  
  # equivalent to docker save <local file>
  if image != nil
    image.save(File.join(image_dir, "#{image_name}-docker.tar"))
    true
  else
    false
  end
end

# check if all status are okay
exit(status_values.all? {|status_value| status_value })

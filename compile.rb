#!/usr/bin/env ruby
require "yaml"
require "tilt"
require "slim"
require "json"
require "aws/s3"
require "digest"

# pretty HTML output
Slim::Engine.set_default_options :pretty => true

# create index file using SLIM for templating
puts "compiling index file"
t = Tilt.new "assets/index.slim"
f = File.new "public/index.html", "w+"
f.write(t.render())
f.close

# compile coffeescript assets
puts "compiling javascripts"
`coffee -cbo public/javascripts assets/*.coffee`

# get access keys from file
access_key_id = YAML.load_file('secret.yml').fetch('access_key_id')
secret_access_key = YAML.load_file('secret.yml').fetch('secret_access_key')

# connect to s3
AWS::S3::Base.establish_connection!(
  :access_key_id     => access_key_id ,
  :secret_access_key => secret_access_key
)

# set region to west
AWS::S3::DEFAULT_HOST.replace "s3-us-west-2.amazonaws.com"

# upload to s3
def upload(f, bucket)
  # get local digest
  local_digest = Digest::MD5.hexdigest(File.read(f))
  # check if file exists in s3 bucket
  if AWS::S3::S3Object.exists?(f.sub("public/", ""), bucket)
    # get bucket digest  
    bucket_digest = AWS::S3::S3Object.find(f.sub("public/", ""), bucket).etag
    # don't upload file if digests are equal
    puts "#{f} - up to date"
    return false if local_digest == bucket_digest
  end
  # upload file
  puts "uploading #{f}"
  AWS::S3::S3Object.store(f.sub('public/', ''), open(f), bucket, :access => :public_read)
end

# iterate through local directory and upload each file
puts "uploading files to S3"
local_files = Dir[File.join('public', '**', '*.*')]
remote_files = Array(AWS::S3::Bucket.find("terrencemorrow.com")).map! { |o| "public/#{o.key}" }
local_files.each do |f| upload(f, "terrencemorrow.com") end

# optionally delete extra files
extra_files = remote_files - local_files
extra_files.each do |f|
  puts "file #{f} found on server but not locally - delete? y/n"
  response = gets
  if response.match /y/
    AWS::S3::S3Object.delete(f.sub("public/", ""), "terrencemorrow.com")
 end
end

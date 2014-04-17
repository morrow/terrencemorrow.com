#!/usr/bin/env ruby
require "digest"
require "aws/s3"
require "yaml"
require "colorize"

bucket = "staging.terrencemorrow.com" 
host = "s3-us-west-2.amazonaws.com"
bucket = ARGV[0] unless ARGV[0].nil?

# get access keys from file
access_key_id = YAML.load_file('secret.yml').fetch('access_key_id')
secret_access_key = YAML.load_file('secret.yml').fetch('secret_access_key')

# connect to s3
AWS::S3::Base.establish_connection!(
  :access_key_id     => access_key_id ,
  :secret_access_key => secret_access_key
)

# set region to west
AWS::S3::DEFAULT_HOST.replace host

# upload to s3
def upload(f, bucket)
  # get local digest
  local_digest = Digest::MD5.hexdigest(File.read(f))
  # check if file exists in s3 bucket
  if AWS::S3::S3Object.exists?(f, bucket)
    # get bucket digest  
    bucket_digest = AWS::S3::S3Object.find(f, bucket).etag
    # don't upload file if digests are equal
    puts "unchanged: #{f}".yellow
    return false if local_digest == bucket_digest
  end
  puts "uploading: #{f}".green
  AWS::S3::S3Object.store(f, open(f), bucket, :access => :public_read)
end

# change to public directory
Dir.chdir "public"

# iterate through local directory and upload each file
local_files = Dir[File.join('**', '*.*')]
remote_files = Array(AWS::S3::Bucket.find(bucket)).map! {|o| o.key }
local_files.each do |f| upload(f, bucket) end

# delete extra files
extra_files = remote_files - local_files
extra_files.each do |f|
  puts "file #{f.to_s} found on server but not locally - delete? y/n".red
  response = $stdin.gets.chomp
  if response.match /y/
    AWS::S3::S3Object.delete(f, bucket)
 end
end

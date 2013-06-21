#require 'sinatra'
#

#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'sinatra/jsonp'
require 'json'
require 'open-uri'
require 'logger'

enable :logging

before do
  logger.level = Logger::DEBUG
end

get '/' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  @client = TwitterOAuth::Client.new(
      :consumer_key => "Xan9gfeLPqIkRNPKbSqYtA",
      :consumer_secret => "n9qwb5QHDWJc5TXM0JN0fjgj7gNK3trjpf5cZFqmL0",
      :token => "351946902-APxV8nHCQM5TYbRX8jiYJpWvijTL1AKTnG405xIU",
      :secret => "vhdaIEHI26KJiyB6bxuN5026lAtLc3tKZt1aZOYs"
  )

  @tweets = @client.user_timeline( { :screen_name => 'OSDDMalaria' } )

  jsonp @tweets
end

get '/sponsors_and_members' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  members_file = "/tmp/members.json"

  if File.exist?(members_file) && File.mtime(members_file) > (Time.now - 10*60)
    @members = File.read(members_file)
  else
    @members = open("https://api.github.com/repos/OSDDMalaria/OSM_Website_Data/issues", "UserAgent" => "Ruby-Wget").read
    File.write(members_file, @members)
  end

  @members
end

get '/project_activity' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/project_activity.json"
  if File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 10*60)
    @project_activity = File.read(project_activity_file)
    logger.debug "-------------------------------------------------------------------------------------------------"
    logger.debug @project_activity
  else
    @project_activity = open("https://api.github.com/repos/OSDDMalaria/OSDDMalaria_To_Do_List/issues", "UserAgent" => "Ruby-Wget").read
    logger.debug "*************************************************************"
    logger.debug  @project_activity
    logger.debug "++++++++++++++++++++++++++++"
    logger.debug @project_activity[0]["updated_at"]
    File.write(project_activity_file, @project_activity)
  end
  @project_activity
end

get '/reset' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/project_activity.json"
  members_file = "/tmp/members.json"

  if File.exist?(project_activity_file)
    File.delete(project_activity_file)
  end

  if File.exist?(members_file)
    File.delete(members_file)
  end

  "Data reset complete"

end


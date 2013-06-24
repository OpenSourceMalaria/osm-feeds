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
  Dir.mkdir('logs') unless File.exist?('logs')
  $log = Logger.new('logs/output.log','weekly')
  $log.level = Logger::DEBUG
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

  if File.exist?(members_file) && File.mtime(members_file) > (Time.now - 60*60)
    @members = File.read(members_file)
  else
    @members = open("https://api.github.com/repos/OSDDMalaria/OSM_Website_Data/issues", "UserAgent" => "Ruby-Wget").read
    File.write(members_file, @members)
  end
  @members
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

get '/project_activity' do

  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/project_activity.json"
  if File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 60*60)
    @back = File.read(project_activity_file)
  else
    @combined = String.new

    @open_project_activity = open("https://api.github.com/repos/OSDDMalaria/OSDDMalaria_To_Do_List/issues", "UserAgent" => "Ruby-Wget").read
    @closed_project_activity = open("https://api.github.com/repos/OSDDMalaria/OSDDMalaria_To_Do_List/issues?state=closed", "UserAgent" => "Ruby-Wget").read

    @combined << @open_project_activity
    x = @combined.length
    @combined[x-1] = ','

    @closed_project_activity[0] = ' '
    @combined << @closed_project_activity

    object_array = JSON.parse(@combined)
    object_array = object_array.sort_by { |hsh| hsh["updated_at"] }
    object_array.reverse!

    for i in 0..11   # Only the top twelve are used
      if object_array[i]["comments"] > 0
        @comments = open("https://api.github.com/repos/OSDDMalaria/OSDDMalaria_To_Do_List/issues/"+ object_array[i]["number"].to_s + "/comments", "UserAgent" => "Ruby-Wget").read
        comments_array = JSON.parse(@comments)
        for j in 0..comments_array.length - 1
          cdt = DateTime.parse (comments_array[j]["updated_at"])
          odt = DateTime.parse (object_array[i]["updated_at"])
          if cdt-odt > 0
            object_array[i]["updated_at"] = comments_array[j]["updated_at"]
          end
        end
      end
    end

    object_array = object_array.sort_by { |hsh| hsh["updated_at"] }
    object_array.reverse!

    @back = object_array.to_json
  end
  @back
end
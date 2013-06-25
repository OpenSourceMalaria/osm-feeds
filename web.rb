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
require 'octokit'

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

  @github = Octokit::Client.new({client_id: '9ec9caed6c4a85ff0798',
                                 client_secret: 'cd437e96e33b5a6cb0b8e394f413cb9639b9fd8f'})

  @members = @github.list_issues("OSDDMalaria/OSM_Website_Data")
  @members.to_json
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
  if File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 10*60)
    $log.debug "Getting from file"
    @combined = File.read(project_activity_file)
  else
    $log.debug "Getting from GitHub"
    @github = Octokit::Client.new({client_id: '9ec9caed6c4a85ff0798',
                                   client_secret: 'cd437e96e33b5a6cb0b8e394f413cb9639b9fd8f'})

    @open_project_activity = @github.list_issues("OSDDMalaria/OSDDMalaria_To_Do_List", {state: 'open'})
    @closed_project_activity = @github.list_issues("OSDDMalaria/OSDDMalaria_To_Do_List", {state: 'closed'})

    @combined = @open_project_activity + @closed_project_activity

    @combined = @combined.sort_by { |hsh| hsh["updated_at"] }

    @combined.reverse!

    for i in 0..11   # Only the top twelve are used
      if @combined[i]["comments"] > 0
        @comments = @github.issue_comments("OSDDMalaria/OSDDMalaria_To_Do_List", @combined[i].number)
        for j in 0..@comments.length - 1
          cdt = DateTime.parse (@comments[j]["updated_at"])
          odt = DateTime.parse (@combined[i]["updated_at"])
          if cdt-odt > 0
            @combined[i]["updated_at"] = @comments[j]["updated_at"]
          end
        end
      end
    end
    @combined = @combined.sort_by { |hsh| hsh["updated_at"] }
    @combined.reverse!
    File.write(project_activity_file, @combined.to_json)
    @combined = @combined.to_json
  end
  @combined
end
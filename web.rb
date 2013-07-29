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

def jsonp_response(data)
  content_type "application/javascript"
  callback = params[:callback] || "callback"
  body "#{callback}(#{data})"
end

before do
  Dir.mkdir('logs') unless File.exist?('logs')
  $log = Logger.new('logs/output.log','weekly')
  $log.level = Logger::DEBUG
end

get '/' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  tweets_file = "/tmp/tweets.json"
  if File.exist?(tweets_file) && File.mtime(tweets_file) > (Time.now - 10*60)
    @tweets = File.read(tweets_file)     # already in json format
  else
    @client = TwitterOAuth::Client.new(
        :consumer_key => ENV['TWITTER_CONSUMER_KEY'],
        :consumer_secret => ENV['TWITTER_CONSUMER_SECRET'],
        :token => ENV["TWITTER_TOKEN"],
        :secret => ENV["TWITTER_SECRET"]
    )

    @tweets = @client.user_timeline( { :screen_name => 'O_S_M' } )

    File.write(tweets_file, @tweets.to_json)
    @tweets = @tweets.to_json   #convert to json for return to caller
  end
  jsonp_response( @tweets )
end

get '/twitter_rate_limit' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  @client = TwitterOAuth::Client.new(
      :consumer_key => ENV['TWITTER_CONSUMER_KEY'],
      :consumer_secret => ENV['TWITTER_CONSUMER_SECRET'],
      :token => ENV["TWITTER_TOKEN"],
      :secret => ENV["TWITTER_SECRET"]
  )

  @rate_limit_status = @client.rate_limit_status()

  jsonp @rate_limit_status
end

get '/sponsors_and_members' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  members_file = "/tmp/members.json"

  if File.exist?(members_file) && File.mtime(members_file) > (Time.now - 10*60)
    @members = File.read(members_file)     # already in json format
  else
    begin
      @github = Octokit::Client.new({client_id: ENV['GITHUB_CLIENT_ID'],
                                     client_secret: ENV['GITHUB_CLIENT_SECRET']})
    rescue Exception => e
      $log.debug "members error"
      $log.debug e
    end

    begin
      @members = @github.list_issues("OpenSourceMalaria/OSM_Website_Data")
    rescue Exception => e
      $log.debug "members read  error"
      $log.debug e
    end

    @members = @github.list_issues("OpenSourceMalaria/OSM_Website_Data")
    File.write(members_file, @members.to_json)   # store as json format
    @members = @members.to_json   #convert to json for return to caller
  end
  jsonp_response(@members)
end

get '/reset' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/project_activity.json"
  members_file = "/tmp/members.json"
  tweets_file = "/tmp/tweets.json"

  if File.exist?(project_activity_file)
    File.delete(project_activity_file)
  end

  if File.exist?(members_file)
    File.delete(members_file)
  end

  if File.exist?(tweets_file)
    File.delete(tweets_file)
  end

  "Data reset complete"

end

get '/project_activity' do

  most_to_keep = 12;

  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/project_activity.json"
  if File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 10*60)
    @combined = File.read(project_activity_file)
  else
    @github = Octokit::Client.new({client_id: ENV['GITHUB_CLIENT_ID'],
                                   client_secret: ENV['GITHUB_CLIENT_SECRET']})

    begin
      @open_project_activity = @github.list_issues("OpenSourceMalaria/OSM_To_Do_List", {state: 'open'})
    rescue Exception => e

    end
    @open_project_activity = @open_project_activity.take(most_to_keep)

    @closed_project_activity = @github.list_issues("OpenSourceMalaria/OSM_To_Do_List", {state: 'closed'})
    @closed_project_activity = @closed_project_activity.take(most_to_keep)

    @combined = @open_project_activity + @closed_project_activity

    @combined = @combined.sort_by { |hsh| hsh["updated_at"] }
    @combined.reverse!
    @combined = @combined.take(most_to_keep)

    @combined.each do |item|
      # do whatever
      if item["comments"] > 0
        @comments = @github.issue_comments("OpenSourceMalaria/OSM_To_Do_List", item.number)
        @comments.each do |comment|
          cdt = DateTime.parse (comment["updated_at"])
          odt = DateTime.parse (item["updated_at"])
          if cdt-odt > 0
            item["updated_at"] = comment["updated_at"]
          end
        end
      end
    end
    @combined = @combined.sort_by { |hsh| hsh["updated_at"] }
    @combined.reverse!
    File.write(project_activity_file, @combined.to_json)
    @combined = @combined.to_json
  end
  jsonp_response(@combined)
end
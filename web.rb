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
  leaders_file = "/tmp/leader_board.json"
  members_file = "/tmp/members.json"
  tweets_file = "/tmp/tweets.json"

  if File.exist?(project_activity_file)
    File.delete(project_activity_file)
  end

  if File.exist?(leaders_file)
    File.delete(leaders_file)
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

  most_to_keep = 12

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
      item.body = item.body[0...500]

      if item["comments"] > 0
        @comments = @github.issue_comments("OpenSourceMalaria/OSM_To_Do_List", item.number)
        @comments.each do |comment|
          cdt = DateTime.parse (comment["updated_at"].to_s)
          odt = DateTime.parse (item["updated_at"].to_s)
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

get '/project_activity_with_leaders' do

  most_to_keep = 12
  leaders_count = 5

  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/project_activity_with_leaders.json"
  if File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 10*60)
    response = File.read(project_activity_file)
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

    @combined = @combined.sort_by { |hsh| hsh["updated_at"] }.reverse
    @combined = @combined.take(most_to_keep)

    leader_str = ''
    @combined.each do |item|
      leader_str = leader_str + ' ' + item["user"]["login"]
      leader_str = leader_str + ' ' + item["user"]["login"]
      if item["comments"] > 0
        @comments = @github.issue_comments("OpenSourceMalaria/OSM_To_Do_List", item.number)
        @comments.each do |comment|
          cdt = DateTime.parse (comment["updated_at"].to_s)
          odt = DateTime.parse (item["updated_at"].to_s)
          leader_str = leader_str + ' ' + comment[  "user"]["login"]
          if cdt-odt > 0
            item["updated_at"] = comment["updated_at"]
          end
        end
      end
    end
    @leaders = leader_str.split.inject(Hash.new(0)) { |k,v| k[v] += 1; k}
    @leaders_array = @leaders.map { |k,v| { k => v} }
    @leaders_array.sort_by {|k,v| v}.reverse

    response = { activity: @combined, leaders: @leaders_array }.to_json
    File.write(project_activity_file, response)
  end
  jsonp_response(response)
end

# OSTB endpoints follow


get '/ostb/tweets' do

  response.headers['Access-Control-Allow-Origin'] = '*'

  tweets_file = "/tmp/ostb_tweets.json"
  if File.exist?(tweets_file) && File.mtime(tweets_file) > (Time.now - 10*60)
    @tweets = File.read(tweets_file)     # already in json format
  else
    @client = TwitterOAuth::Client.new(
        :consumer_key => ENV['OSTB_TWITTER_CONSUMER_KEY'],
        :consumer_secret => ENV['OSTB_TWITTER_CONSUMER_SECRET'],
        :token => ENV["OSTB_TWITTER_TOKEN"],
        :secret => ENV["OSTB_TWITTER_SECRET"]
    )

    @tweets = @client.user_timeline( { :screen_name => 'OpenSourceTB' } )

    File.write(tweets_file, @tweets.to_json)
    @tweets = @tweets.to_json   #convert to json for return to caller
  end
  jsonp_response( @tweets )
end

get '/ostb/twitter_rate_limit' do
  response.headers['Access-Control-Allow-Origin'] = '*'
  @client = TwitterOAuth::Client.new(
      :consumer_key => ENV['OSTB_TWITTER_CONSUMER_KEY'],
      :consumer_secret => ENV['OSTB_TWITTER_CONSUMER_SECRET'],
      :token => ENV["OSTB_TWITTER_TOKEN"],
      :secret => ENV["OSTB_TWITTER_SECRET"]
  )

  @rate_limit_status = @client.rate_limit_status()

  jsonp @rate_limit_status
end

get '/ostb/sponsors_and_members' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  members_file = "/tmp/ostb_members.json"

  if File.exist?(members_file) && File.mtime(members_file) > (Time.now - 10*60)
    @members = File.read(members_file)     # already in json format
  else
    begin
      @github = Octokit::Client.new({client_id: ENV['OSTB_GITHUB_CLIENT_ID'],
                                     client_secret: ENV['OSTB_GITHUB_CLIENT_SECRET']})
    rescue Exception => e
      $log.debug "members error"
      $log.debug e
    end

    begin
      @members = @github.list_issues("OpenSourceTB/TB_Website_Data")
    rescue Exception => e
      $log.debug "members read  error"
      $log.debug e
    end

    @members = @github.list_issues("OpenSourceTB/TB_Website_Data")
    File.write(members_file, @members.to_json)   # store as json format
    @members = @members.to_json   #convert to json for return to caller
  end
  jsonp_response(@members)
end

get '/ostb/reset' do
  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/ostb_project_activity_with_leaders.json"
  leaders_file = "/tmp/ostb_leader_board.json"
  members_file = "/tmp/ostb_members.json"
  tweets_file = "/tmp/ostb_tweets.json"

  if File.exist?(project_activity_file)
    File.delete(project_activity_file)
  end

  if File.exist?(leaders_file)
    File.delete(leaders_file)
  end

  if File.exist?(members_file)
    File.delete(members_file)
  end

  if File.exist?(tweets_file)
    File.delete(tweets_file)
  end

  "Data reset complete"

end

get '/ostb/project_activity_with_leaders' do

  most_to_keep = 12
  leaders_count = 5

  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/ostb_project_activity_with_leaders.json"
  if File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 10*60)
    response = File.read(project_activity_file)
  else
    @github = Octokit::Client.new({client_id: ENV['OSTB_GITHUB_CLIENT_ID'],
                                   client_secret: ENV['OSTB_GITHUB_CLIENT_SECRET']})

    begin
      @open_project_activity = @github.list_issues("OpenSourceTB/OpenSourceTB_To_Do_List", {state: 'open'})
    rescue Exception => e

    end
    @open_project_activity = @open_project_activity.take(most_to_keep)

    @closed_project_activity = @github.list_issues("OpenSourceTB/OpenSourceTB_To_Do_List", {state: 'closed'})

    @closed_project_activity = @closed_project_activity.take(most_to_keep)

    @combined = @open_project_activity + @closed_project_activity

    @combined = @combined.sort_by { |hsh| hsh["updated_at"] }.reverse
    @combined = @combined.take(most_to_keep)

    leader_str = ''
    @combined.each do |item|
      leader_str = leader_str + ' ' + item["user"]["login"]
      leader_str = leader_str + ' ' + item["user"]["login"]
      if item["comments"] > 0
        @comments = @github.issue_comments("OpenSourceTB/OpenSourceTB_To_Do_List", item.number)
        @comments.each do |comment|
          cdt = DateTime.parse (comment["updated_at"].to_s)
          odt = DateTime.parse (item["updated_at"].to_s)
          leader_str = leader_str + ' ' + comment["user"]["login"]
          if cdt-odt > 0
            item["updated_at"] = comment["updated_at"]
          end
        end
      end
    end
    @leaders = leader_str.split.inject(Hash.new(0)) { |k,v| k[v] += 1; k}
    @leaders_array = @leaders.map { |k,v| { k => v} }
    @leaders_array.sort_by {|k,v| v}.reverse

    response = { activity: @combined, leaders: @leaders_array }.to_json
    File.write(project_activity_file, response)
  end
  jsonp_response(response)
end

get '/ostb/project_activity_with_leaders_multi' do

  most_to_keep = 12
  leaders_count = 5

  response.headers['Access-Control-Allow-Origin'] = '*'

  project_activity_file = "/tmp/ostb_project_activity_with_leaders.json"
  if  3 == 7   # File.exist?(project_activity_file) && File.mtime(project_activity_file) > (Time.now - 10*60)
    response = File.read(project_activity_file)
  else
    @github = Octokit::Client.new({client_id: ENV['OSTB_GITHUB_CLIENT_ID'],
                                   client_secret: ENV['OSTB_GITHUB_CLIENT_SECRET']})

    begin
      @issues = @github.list_issues("OpenSourceTB/TB_Website_Data")
    rescue Exception => e
      $log.debug "issues read  error"
      $log.debug e
    end
    dataIndex = -1

    @issues.each_with_index do |issue, i|
        if issue.title == "issue_lists"
          dataIndex = i
        end
    end
    p "dataIndex #{dataIndex}"
    @total = nil
    leader_str = ''
    if dataIndex > -1
      aaa = @issues[dataIndex]
      bbb = aaa[:body].split(/\r\n/)
      bbb.each do |listname|
        begin
          @open_project_activity = @github.list_issues("OpenSourceTB/" + listname, {state: 'open'})
          #@open_project_activity = @open_project_activity.take(most_to_keep)

          @closed_project_activity = @github.list_issues("OpenSourceTB/" + listname, {state: 'closed'})
          #@closed_project_activity = @closed_project_activity.take(most_to_keep)

          @combined = @open_project_activity + @closed_project_activity
          p @combined
          @combined = @combined.sort_by { |hsh| hsh["updated_at"] }.reverse
          #@combined = @combined.take(most_to_keep)

          @combined.each do |item|
            leader_str = leader_str + ' ' + item["user"]["login"]
            leader_str = leader_str + ' ' + item["user"]["login"]
            if item["comments"] > 0
              @comments = @github.issue_comments("OpenSourceTB/" + listname, item.number)
              @comments.each do |comment|
                cdt = DateTime.parse (comment["updated_at"].to_s)
                odt = DateTime.parse (item["updated_at"].to_s)
                leader_str = leader_str + ' ' + comment["user"]["login"]
                if cdt-odt > 0
                  item["updated_at"] = comment["updated_at"]
                end
              end
            end
          end
          if @total == nil
            @total = @combined
          else
            @total = @total + @combined
          end
        rescue Exception => e
        end
      end
    end

    @leaders = leader_str.split.inject(Hash.new(0)) { |k,v| k[v] += 1; k}
    @leaders_array = @leaders.map { |k,v| { k => v} }
    @leaders_array.sort_by {|k,v| v}.reverse

    response = { activity: @total, leaders: @leaders_array }.to_json
    File.write(project_activity_file, response)
  end
  jsonp_response(response)
end
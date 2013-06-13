#require 'sinatra'
#

#!/usr/bin/env ruby
require 'rubygems'
require 'sinatra'
require 'twitter_oauth'
require 'json'

get '/' do
  @client = TwitterOAuth::Client.new(
      :consumer_key => "Xan9gfeLPqIkRNPKbSqYtA",
      :consumer_secret => "n9qwb5QHDWJc5TXM0JN0fjgj7gNK3trjpf5cZFqmL0",
      :token => "351946902-APxV8nHCQM5TYbRX8jiYJpWvijTL1AKTnG405xIU",
      :secret => "vhdaIEHI26KJiyB6bxuN5026lAtLc3tKZt1aZOYs"
  )
  @rate_limit_status = @client.rate_limit_status

  #$nettuts_timeline = $twitteroauth->get('statuses/user_timeline', array('screen_name' => 'nettuts'));

  @timeline = @client.public_timeline( { :screen_name => 'cfitzpat' } )

  #@client.url = "https://api.twitter.com/1/statuses/user_timeline/OSDDMalaria.json?callback=?&count=12&include_rts=1"

  @tweets = @client.inspect
  @methods = @client.methods
  @user = @client.user
  @ptl = @client.public_timeline

  #@tweets = @client.inspect
  content_type :json
  { :timeline => @timeline,
    :ptl => @ptl,
    :client => @client,
    :methods => @methods,
    :clientauthorized => @client.authorized?,
    :client => @client,
    :tweets => @tweets
  }.to_json
end
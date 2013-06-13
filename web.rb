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

  @tweets = @client.user_timeline( { :screen_name => 'OSDDMalaria' } )

  content_type :json
  { :tweets => @tweets }.to_json
end
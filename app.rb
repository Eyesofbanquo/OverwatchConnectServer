require 'sinatra'
require 'rest-client'
require 'data_mapper'

#Going to need a datastructure to hold the information for each group
#Each group will have:
#
# Unique ID - to identify the group
# Owner:String
# Platform:String
# Region:String
# isFull:Bool - to determine whether or not the group is full. When the group is full you'll send a notification to the group letting them know

DataMapper.setup(:default, 'postgres://stark:20400112@localhost/grouptest')

class Lobby
	include DataMapper::Resource
	property :id, Serial, :key => true
	property :username, Text
	property :platform, Text
	property :region, Text
	property :groupsize, Integer
	property :udid, Text
end

DataMapper.finalize.auto_upgrade!
	

@regions = Hash.new
h = SecureRandom.hex
puts h

@regions = {"us" => Hash.new, "eu" => Hash.new}
@regions["us"] = {"xbl" => Array.new, "psn" => Array.new, "pc" => Array.new}
@regions["eu"] = {"xbl" => Array.new, "psn" => Array.new, "pc" => Array.new}
keys = @regions["us"].keys[0]
puts "#{keys}"

class MyApp<Sinatra::Base
	get '/' do
		"Hello World!"
	end
	post '/create-lobby' do
		@lobby = Lobby.new(:username => params[:username], :platform => params[:platform], :region => params[:region], :groupsize => params[:groupSize], :udid => SecureRandom.hex)
		@lobby.save if Lobby.count(:username=>"#{params[:username].to_str}") == 0
		#username = params[:username].to_str
		#region = params[:region].to_str
		#platform = params[:platform].to_str
		#group_size = params[:groupSize]
		#lobby = Lobby.new(username, platform, region, group_size)
		#@regions[region][platform].push(lobby)
		
	end
	get '/groups-us' do
		#platform = params[:platform].to_str
		#filtered_group = @regions["us"]
		lobbies = Lobby.all(:platform => "psn", :region => "us")
		puts lobbies
		#v = filtered_group.collect{|item| {:id => item.id}}
		#"#{lobbies.get(1)["username"]}"
	end
end

MyApp.run!
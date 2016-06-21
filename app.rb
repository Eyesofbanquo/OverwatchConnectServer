require 'sinatra'
require 'rest-client'
require 'data_mapper'
require 'houston'

#Going to need a datastructure to hold the information for each group
#Each group will have:
#
# Unique ID - to identify the group
# Owner:String
# Platform:String
# Region:String
# isFull:Bool - to determine whether or not the group is full. When the group is full you'll send a notification to the group letting them know

APN = Houston::Client.development
APN.certificate = File.read('./apple_push_dev.pem')
DataMapper.setup(:default, 'postgres://zsjpfrlfvevvxf:q57x4Ln9yoMPEm77IdfzddCSF2@ec2-54-225-211-218.compute-1.amazonaws.com:5432/d75l3qthbt16e8')

class Lobby
	include DataMapper::Resource
	property :id, Serial, :key => true
	property :username, Text
	property :password, BCryptHash
	property :platform, Text
	property :region, Text
	property :groupsize, Integer
	property :groupid, Text
	property :udid, Text
	property :owner, Text
end

DataMapper.finalize.auto_upgrade!
	

@regions = Hash.new


@regions = {"us" => Hash.new, "eu" => Hash.new}
@regions["us"] = {"xbl" => Array.new, "psn" => Array.new, "pc" => Array.new}
@regions["eu"] = {"xbl" => Array.new, "psn" => Array.new, "pc" => Array.new}
keys = @regions["us"].keys[0]
puts "#{keys}"

class MyApp<Sinatra::Base
	get '/' do
		"Hello World!"
	end
	#this isn't ready yet
	get '/notification' do
		
	end
	get '/lobby' do
		user = Lobby.first(:username => params[:username])
		lobby = Lobby.all(:groupid => user["groupid"])
	
		v = lobby.collect{|item| {:username => item.username, :groupid => item.groupid, :udid => item.udid}}
		v.to_json
	end
	#parameter requirements | get the new groupid SecureRandom.hex
	#groupid
	post '/delete-lobby' do
		player = Lobby.first(:username => params[:username])
		player.update(:owner => 'no', :groupid => SecureRandom.hex)

		groupid = Lobby.all(:groupid => params[:groupid])
		for i in groupid
			token = i["udid"]
			notification = Houston::Notification.new(device:token)
			notification.alert = "Group Disbanded"
			APN.push(notification)
		end
	
	end
	post '/leave-lobby' do
		lobby = Lobby.first(:username => params[:username])
		
		groupid = Lobby.all(:groupid => lobby["groupid"]) #get lobby id so that you can send notification to all users in lobby | refresh their tables
		
		for i in groupid
			token = i["udid"]
			notification = Houston::Notification.new(device:token)
			notification.alert = "#{lobby["username"]} has left the lobby!"
			APN.push(notification)
		end		
		lobby.update(:groupid => SecureRandom.hex, :owner => 'no')
	end
	#parameter requirements
	#username | password | udid | platform | region
	post '/login' do
		v = {:status => ""}

		@lobby = Lobby.new(:username => params[:username], :password => params[:password], :udid => params[:udid], :region => params[:region], :groupid => SecureRandom.hex, :platform => params[:platform], :owner => 'no')
		@lobby.save if Lobby.count(:username=>"#{params[:username].to_str}") == 0
		
		if Lobby.first(:username => params[:username]) != nil
			user = Lobby.first(:udid => params[:udid])
			if user["password"] == params[:password]
				v.replace({:status => "success"})
			else
				v.replace({:status => "error"})
			end
		end
		v.to_json
	end
	#params :username
	post '/logout' do
		username = params[:username]
		player = Lobby.first(:username => username)
		player.destroy
	end
	#Parameter requirements
	#username | region | platform | groupsize
	post '/create-lobby' do
		#lobby = Lobby.all(:username => params[:username])
		#lobby.update(:owner => params[:owner])
		v = {:status => ""}
		us_region = Lobby.all(:region => 'us')
		eu_region = Lobby.all(:region => 'eu')
		
		if params[:region] == 'eu' && eu_region.size < 5000
			h = Lobby.first_or_create(:username => params[:username]).update(:password => params[:password], :platform => params[:platform], :groupsize => params[:groupSize],:region => params[:region], :groupid => SecureRandom.hex, :udid => params[:udid], :owner => 'yes')
			lobby = Lobby.first(:username => params[:username])
			lobby["owner"] = 'yes'
		else if params[:region] == 'us' && us_region.size < 5000
			h = Lobby.first_or_create(:username => params[:username]).update(:password => params[:password], :platform => params[:platform], :groupsize => params[:groupSize],:region => params[:region], :groupid => SecureRandom.hex, :udid => params[:udid], :owner => 'yes')
			lobby = Lobby.first(:username => params[:username])
			lobby["owner"] = 'yes'
		else
			v.replace({:status => "error"})
		end
		v.to_json
	end
	post '/join-lobby' do
		v = {:status => ""}
		username = params[:username]
		groupid = params[:groupid]
		#This should get the owner of the group
		lobbyAll = Lobby.all(:groupid => groupid)
		if lobbyAll.size < 6
			lobby = Lobby.first(:owner => 'yes')
			player = Lobby.first(:username => username)
			player.update(:groupid => lobby["groupid"], :owner => 'no')
			groupid = Lobby.all(:groupid => groupid)
			for i in groupid
				token = i["udid"]
				notification = Houston::Notification.new(device:token)
				notification.alert = "#{player["username"]} has joined the lobby!"
				APN.push(notification)
			end
		else
			v.replace({:status => "full"})
			player = Lobby.first(:username => params[:username])
			token = player["udid"]
			notification = Houston::Notification.new(device:token)
			notification.alert = "Lobby is full"
			APN.push(notification)
		end
		v.to_json
	end
	get '/groups' do
		#platform = params[:platform].to_str
		#filtered_group = @regions["us"]
		platform = params[:platform]
		region = params[:region]
		#owner = "true"
		lobbies = Lobby.all(:platform => platform, :region => region, :owner => 'yes')
		#lobby_is_full = Lobby.all(:isfull => false)
		v = lobbies.collect{|item| {:username => item.username, :udid => item.udid, :groupSize => item.groupsize, :groupid => item.groupid}}
		#"#{lobbies.get(1)["username"]}"
		v.to_json
	end
end
end
MyApp.run!
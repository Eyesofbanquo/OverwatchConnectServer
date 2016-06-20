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
	#this isn't ready yet
	get '/notification' do
		
	end
	#this isn't ready
	get '/user' do
		#@lobby = Lobby.get(:username => params[:username], :password => params[:password])
		#v = @lobby.collect{|item| {:username => item.username, :password => item.password}}
		#v.to_json
	end
	get '/lobby' do
		
		user = Lobby.all(:username => params[:username])
		lobby = Lobby.all(:groupid => user[0]["groupid"])
		v = lobby.collect{|item| {:username => item.username, :groupid => item.groupid, :udid => item.udid}}
	#	lobby.to_json
		v.to_json
	end
	#parameter requirements | get the new groupid SecureRandom.hex
	#groupid
	post '/delete-lobby' do
		lobby = Lobby.first(:username => params[:username])
		#oldid = lobby[0]["groupid"]
		token = lobby["udid"]
		notification = Houston::Notification.new(device: token)
		notification.alert = "Group Disbanded"
		APN.push(notification)
		
		lobby.destroy
		#old_lobby = Lobby.all(:udid => oldid)
		#old_lobby.destroy
		
		
		#lobby.update(:groupid => SecureRandom.hex)
	end
	post '/leave-lobby' do
		lobby = Lobby.first(:username => params[:username])
		groupid = Lobby.all(:groupid => lobby["groupid"]) #get lobby id so that you can send notification to all users in lobby | refresh their tables
		token = lobby["udid"]
		notification = Houston::Notification.new(device:token)
		notification.alert = "#{lobby["username"]} has left the lobby!"
		APN.push(notification)
		
		lobby.update(:groupid => SecureRandom.hex)
		
	end
	#parameter requirements
	#username | password | udid | platform | region
	post '/login' do
		v = {:status => "error"}
		if user = Lobby.first(:username => params[:username]) == true
			#This means the user was found so now must check password
			u = Lobby.first(:username => params[:username])
			if params[:password] == u["password"] 
				u.update(:udid => params[:udid], :region => params[:region])
				v["status"] = "success!"
			else
				v["status"] = "error"
			end
		else
			@lobby = Lobby.new(:username => params[:username], :password => params[:password], :udid => params[:udid], :region => params[:region], :groupid => SecureRandom.hex)
		
			@lobby.save if Lobby.count(:udid=>"#{params[:udid].to_str}") == 0
		end
		v.to_json
	end
	#Parameter requirements
	#username | region | platform | groupsize
	post '/create-lobby' do
		lobby = Lobby.all(:username => params[:username])
		Lobby.first_or_create(:username => params[:username]).update(:platform => params[:platform], :groupsize => params[:groupSize],:region => params[:region], :groupid => SecureRandom.hex, :udid => params[:udid])
		#@lobby
#	post '/create-lobby' do
	#	@lobby = Lobby.new(:username => params[:username], :platform => params[:platform], :region => params[:region], :groupsize => params[:groupSize], :groupid => SecureRandom.hex, :udid => params[:udid])
		#@lobby.save if Lobby.count(:username=>"#{params[:username].to_str}") == 0
		#username = params[:username].to_str
		#region = params[:region].to_str
		#platform = params[:platform].to_str
		#group_size = params[:groupSize]
		#lobby = Lobby.new(username, platform, region, group_size)
		#@regions[region][platform].push(lobby)
		
	end
	post '/join-lobby' do
		username = params[:username]
		groupid = params[:groupid]
		
		#This should get the owner of the group
		lobby = Lobby.first(:groupid => groupid)
		player = Lobby.first(:username => username)
		player.update(:groupid => lobby["groupid"])
	end
	get '/groups' do
		#platform = params[:platform].to_str
		#filtered_group = @regions["us"]
		platform = params[:platform]
		region = params[:region]
		lobbies = Lobby.all(:platform => platform, :region => region)
		v = lobbies.collect{|item| {:username => item.username, :udid => item.udid, :groupSize => item.groupsize, :groupid => item.groupid}}
		#"#{lobbies.get(1)["username"]}"
		v.to_json
	end
end

MyApp.run!
--[[
	**************************************** PUC-RIO 2014 ****************************************
	Implemented by Breno Riba		
	On July 2014
	**********************************************************************************************
]]--

-- Imports
local lstage  = require 'lstage'
local socket  = require 'lstage_socket'
local parsing = require 'parsing'
local util    = require "util"

-- Global vars
local stages    = {}
local instances = 5

-- Scripts directory
local scriptDir = "scripts/"

-- Send answer
cacheSendFile=function(clientSocket, res, html)
	local countdown = 0
	for i=0,30000000,1 do
		countdown = countdown + 1
	end
	local final = countdown

	-- Imports
	require 'table'

	-- Send headers
	clientSocket:send(util.stdresp(res))

	-- Send HTML to the client
	clientSocket:send(html)
	clientSocket:close()
end

-- Load cache file
cacheLoadFile=function(clientSocket, reqData, body)
	local countdown = 0
	for i=0,30000000,1 do
		countdown = countdown + 1
	end
	local final = countdown

	-- Imports
	require 'table'
	require 'io'
	cache=require 'cache'

	local res    = { headers=util.response_headers() }
	local script = scriptDir..reqData.relpath
        local html      = "<html>Hello there</html>"..body

	-- Prepare headers
	res.headers["Content-Length"] = #html + #body
	res.headers["Content-Type"]   = "text/html"
	res.status_code               = 200

	-- Send result back to the client
	stages.cacheSendFile:push(clientSocket,res,html)
end

-- Run Lua script
runScript=function(clientSocket, reqData)
	-- Imports
	require 'os'
	require 'table'
	require 'io'

	local script = scriptDir.."index.lua"
	--local file   = io.open(script,"r")

	-- Read script file
	--file:close()
	--local body = dofile(script)
        local body = "my way"
  	
	stages.cacheLoadFile:push(clientSocket, reqData, body)
end

-- Handle incoming connections
handle=function(clientSocket)
	-- Receive client request			
	local data, err = clientSocket:receive()

	-- Error check
	if not data then
		clientSocket:close()
		return
	end

	-- Parse information
	local reqData = {}

	-- Split between <spaces>
	reqData.cmd_mth, reqData.cmd_url, reqData.cmd_version = unpack (parsing.strsplit (data))

	-- Receive request headers and parse them
	parsing.read_headers(clientSocket,reqData)

	-- Split URL data
	parsing.parse_url (reqData)

	-- Main page
	if reqData.relpath == "/" then
      		reqData.relpath="index.html"
   	end

	local countdown = 0
	for i=0,30000000,1 do
		countdown = countdown + 1
	end
	local final = countdown

	-- Show static page
	stages.runScript:push(clientSocket, reqData)
end

-- Start server - main loop
start=function(port)
	-- Open socket with default port
	local serverSocket = assert(socket.bind("*", port))
	print("Waiting on port >> ", port, serverSocket)

	-- Server main loop
	while true do
		-- Accept a new connection
		local clientSocket=assert(serverSocket:accept(),"Error while accepting new connection")
		clientSocket:setoption ("tcp-nodelay", true)

		-- Send request to handle stage
		stages.handle:push(clientSocket)
	end
end

-- Add function into stages
stages.cacheSendFile = lstage.stage (cacheSendFile, instances)
stages.cacheLoadFile = lstage.stage (cacheLoadFile, instances)
stages.runScript     = lstage.stage (runScript,     instances)
stages.handle	     = lstage.stage (handle, 	    instances)
stages.start	     = lstage.stage (start, 	    1)

return stages

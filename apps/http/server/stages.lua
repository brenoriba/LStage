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
local instances = 1

-- Configuration for dynamic page
local scriptDir = "~/Documents/lstage/apps/http/server"

-- Close client connection
stages.closeSocket=lstage.stage(
	function(clientSocket)
		clientSocket:close()
	end,instances)

-- Load cache file
stages.cacheLoadFile=lstage.stage(
	function(clientSocket, file)
		-- Imports
		require 'io'
		cache=require 'cache'

		local res    = { headers=response_headers() }
		local script = scriptDir..file
		local file   = io.open(script,"r")

		-- File was found
		if file then

		-- File not found
		else
			-- HTML body message
			local body      = "<html>Error: file '"..file.."' not found</html>"
			res.status_code = 404

			-- Prepare headers
			res.headers["Content-Length"] = #body
			res.headers["Content-Type"]   = "text/html"

			-- Send result back to the client
			clientSocket:send(util.stdresp(res))
			clientSocket:send(body)

			-- Close client socket
			stages.closeSocket:push(clientSocket)
		end
	end,instances)

-- Access cache buffer
stages.cacheBuffer=lstage.stage(
	function(clientSocket, file)
		local content   = cache.get(file)
		local res       = {headers = response_headers()}
	 	res.status_code = 200

		-- Add headers
	  	res.headers["Content-Length"] = #content
	 	res.headers["Content-Type"]   = "text/html"
	
		-- Send result to the client
		clientSocket:send(util.stdresp(res).."\n")
		clientSocket:send(content.."\n")

		-- Close client connection	
		stages.closeSocket:push(clientSocket)
	end,instances)

-- Cache handler
stages.cacheHandler=lstage.stage(
	function(clientSocket, reqData)
		c_cache=require 'cache'

		-- Found in cache (access buffer)
		if c_cache.has(reqData.relpath) then
			stages.cacheBuffer:push(clientSocket,reqData.relpath)
		-- Not found in cache (load to cache)
		else
			stages.cacheLoadFile:push(clientSocket,reqData.relpath)
		end
	end,instances)

-- Run Lua script
stages.runScript=lstage.stage(
	function(clientSocket, reqData)
		-- Imports
		require 'os'
		require 'table'
		require 'io'

		local res    = { headers = util.response_headers() }
		local script = scriptDir..reqData.relpath
		local file   = io.open(script,"r")

		-- File not found
		if not file then
			-- Prepare result message
			local body      = "<html>Error: file '"..reqData.relpath.."' not found</html>"
			res.status_code = 404

			-- Prepare headers
			res.headers["Content-Length"] = #body
			res.headers["Content-Type"]   = "text/html"

			-- Send data
			clientSocket:send(util.stdresp(res).."\n")
			clientSocket:send(body.."\n")
		-- File found
		else
			-- Read script file
			file:close()
			local output    = dofile(script)
		  	res.status_code = 200
	
			-- Prepare headers
	  	 	res.headers["Content-Length"]=#output
	 	  	res.headers["Content-Type"]="text/html"

			-- Send data
			clientSocket:send(util.stdresp(res).."\n")
			clientSocket:send(output.."\n")
		end

		-- Close client socket
		stages.closeSocket:push(clientSocket)
	end, instances)

-- Handle incoming connections
stages.handle=lstage.stage(
	function(clientSocket)
		-- Receive client request		
		local data, err = clientSocket:receive()

		-- Error check
		if not data then
			print("Error receiving from client: ", err)
			stages.closeSocket:push(clientSocket)
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
	      		reqData.relpath="/index.html"
	   	end

		-- Show dynamic content (run script)
		if string.find (reqData.relpath,"+*.lua$") or string.find (reqData.relpath,"+*.lp$") then
			assert(stages.runScript:push(clientSocket, reqData),"Error while running script")
		-- Show static page
		else
			assert(stages.cacheHandler:push(clientSocket, reqData),"Error while acessing cache")
		end
	end, instances)

-- Start server - main loop
stages.start=lstage.stage(
	function(port)
		-- Open socket with default port
		local serverSocket = assert(socket.bind("*", port))
		print("Waiting on port >> ", port, serverSocket)

		-- Server main loop
		while true do
			-- Accept a new connection
			local clientSocket=assert(serverSocket:accept(),"Error while accepting new connection")
			clientSocket:setoption ("tcp-nodelay", true)

			-- Send request to handle stage
			assert(stages.handle:push(clientSocket),"Error while handling connection")
		end
	end, instances)

return stages

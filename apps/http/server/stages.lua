--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

-- Imports
local lstage = require 'lstage'
local socket = require 'lstage_socket'
local parsing  = require 'parsing'

-- Global vars
local stages    = {}
local instances = 2

-- Run Lua script
stages.runScript=lstage.stage(
	function(reqData)
		print("run script")

		-- Send answer to the client and close connection
		--clientSocket:send(data.."\n")
		--clientSocket:close()--]]
	end, instances)

-- Handle incoming connections
stages.handle=lstage.stage(
	function(clientSocket)
		-- Receive client request		
		local data, err = clientSocket:receive()

		-- Error check
		if not data then
			clientSocket:close()
			print("Error receiving from client: ", err)
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
			stages.runScript:push(reqData)
		-- Show static page
		else

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
			local clientSocket=assert(serverSocket:accept())
			clientSocket:setoption ("tcp-nodelay", true)

			-- Send request to handle stage
			stages.handle:push(clientSocket)
		end
	end, instances)

return stages

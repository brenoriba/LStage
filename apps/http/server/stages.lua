--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

-- Imports
require 'lstage.utils.socket'

local lstage = require 'lstage'
local url    = require 'socket.url'
local utils  = require 'utils'

-- Global vars
local stages    = {}
local instances = 2

-- Handle incoming connections
stages.handle=lstage.stage(
	function(request)
		-- Receive client request
		local data, err = request:receive()
	
		-- Error check
		if not err then
			request:close()
			print("Error receiving from client: ", err)
			return
		end

		req.cmd_mth, req.cmd_url, req.cmd_version = unpack (utils.strsplit (data))

		-- Send answer to the client and close connection
		--request:send(data.."\n")
		--request:close()
	end, instances)

-- Start server - main loop
stages.start=lstage.stage(
	function(port)
		-- Open socket with default port	
		local socket = require 'lstage.utils.socket'	
		local server = assert(socket.bind("*", port))

		-- Server main loop
		while true do
			-- Accept a new connection
			local request=assert(server:accept())
			request:setoption ("tcp-nodelay", true)
			--request:settimeout(1)
			
			-- Send request to handle stage
			--local req={sock=request}
			--stages.handle(req)
		end
	end, instances)

return stages

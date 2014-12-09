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
local instances = 7

-- Scripts directory
local scriptDir = "scripts/"

-- Close client connection
closeSocket=function(clientSocket, close)
	local stage = require 'stages'

	-- Close connection
	if (close) then		
		clientSocket:close()
	-- Send connection again to handle stage
	-- The user will continue making requests
	else
		assert(stage.handle:push(clientSocket),"Error while handling connection")
	end
end

-- Load cache file
cacheLoadFile=function(clientSocket, reqData)
	-- Imports		
	require 'table'
	require 'io'
	cache=require 'cache'

	local res    = { headers=util.response_headers() }
	local script = scriptDir..reqData.relpath
	local file   = io.open(script,"r")

	-- File was found
	if file then
		local size = file:seek("end")			
		file:close()

		-- Prepare headers
		res.headers["Content-Length"] = size
	      	res.headers["Content-Type"]   = "text/html"
	      	res.status_code               = 200

		-- Send headers
		clientSocket:send(util.stdresp(res))

		-- Read file and send buffer
		local content = {}
		local count   = 0
		for line in io.lines(script) do 
			content[#content + 1] = line
		end

		-- Send HTML to the client
		local html = table.concat(content)
		clientSocket:send(html)

		-- Save into cache
		cache.put(reqData.relpath,html)

	-- File not found
	else
		-- HTML body message
		local body      = "<html>Error: file '"..script.."' not found</html>"
		res.status_code = 404

		-- Prepare headers
		res.headers["Content-Length"] = #body
		res.headers["Content-Type"]   = "text/html"

		-- Send result back to the client
		clientSocket:send(util.stdresp(res))
		clientSocket:send(body)
	end

	-- Close client socket
	local closeConn = reqData.headers['connection']=="close"
	stages.closeSocket:push(clientSocket, closeConn)
end

-- Access cache buffer
cacheBuffer=function(clientSocket, reqData)
	require 'table'
	cache=require 'cache'

	local content   = cache.get(reqData.relpath)
	local res       = {headers = util.response_headers()}
 	res.status_code = 200

	-- Add headers
  	res.headers["Content-Length"] = #content
 	res.headers["Content-Type"]   = "text/html"

	-- Send result to the client
	clientSocket:send(util.stdresp(res))
	clientSocket:send(content)

	-- Close client connection	
	local closeConn = reqData.headers['connection']=="close"
	stages.closeSocket:push(clientSocket, closeConn)
end

-- Cache handler
cacheHandler=function(clientSocket, reqData)
	c_cache=require 'cache'

	-- Found in cache (access buffer)
	if c_cache.has(reqData.relpath) then
		stages.cacheBuffer:push(clientSocket,reqData)
	-- Not found in cache (load to cache)
	else
		stages.cacheLoadFile:push(clientSocket,reqData)
	end
end

-- Run Lua script
runScript=function(clientSocket, reqData)
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
		clientSocket:send(util.stdresp(res))
		clientSocket:send(body)
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
		clientSocket:send(util.stdresp(res))
		clientSocket:send(output)
	end

	-- Close client socket
	local closeConn = reqData.headers['connection']=="close"
	stages.closeSocket:push(clientSocket, closeConn)
end

-- Handle incoming connections
handle=function(clientSocket)
	-- Receive client request			
	local data, err = clientSocket:receive()

	-- Error check
	if not data then
		stages.closeSocket:push(clientSocket, true)
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

	-- Show dynamic content (run script)
	if string.find (reqData.relpath,"+*.lua$") or string.find (reqData.relpath,"+*.lp$") then
		assert(stages.runScript:push(clientSocket, reqData),"Error while running script")
	-- Show static page
	else
		assert(stages.cacheHandler:push(clientSocket, reqData),"Error while acessing cache")
	end
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
		assert(stages.handle:push(clientSocket),"Error while handling connection")
	end
end

-- Add function into stages
stages.closeSocket   = lstage.stage (closeSocket,   instances)
stages.cacheLoadFile = lstage.stage (cacheLoadFile, instances)
stages.cacheBuffer   = lstage.stage (cacheBuffer,   instances)
stages.cacheHandler  = lstage.stage (cacheHandler,  1)
stages.runScript     = lstage.stage (runScript,     instances)
stages.handle	     = lstage.stage (handle, 	    instances)
stages.start	     = lstage.stage (start, 	    1)

return stages

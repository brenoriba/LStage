local lstage = require 'lstage'
local mg1    = require 'lstage.controllers.mg1'

-- Creating stages table
local stages  = {}
local threads = lstage.cpus() * 2

local stage1=lstage.stage(
	function() 
		local socket = require("socket")

		-- create a TCP socket and bind it to the local host, at any port
		local server = assert(socket.bind("*", 0))

		-- find out which port the OS chose for us
		local ip, port = server:getsockname()

		-- print a message informing what's up
		print("Please telnet to localhost on port " .. port)

		-- loop forever waiting for clients
		--while true do
		  -- wait for a connection from any client
		  local client = server:accept()

		  -- make sure we don't block waiting for this client's line
		  client:settimeout(10)

		  -- receive the line
		  local line, err = client:receive()

		  -- if there was no error, send it back to the client
		  if not err then 
			client:send(line .. "\n") 
		  end

		  -- done with client, close the object
		  client:close()
		--end
	end,threads)

-- Creating stages table
stages[1] = stage1

-- Configuring priority between stages
mg1.configure(stages, threads, 1)

-- Start server
--stage1:push()

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get() 

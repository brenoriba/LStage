local lstage = require 'lstage'
local mg1    = require 'lstage.controllers.mg1'

-- Creating stages table
local stages  = {}
local threads = lstage.cpus() * 2

local stage1=lstage.stage(
	function() 
		local socket = require("socket")	
		local server = assert(socket.bind("127.0.0.1", "65000"))

		server:setoption("tcp-nodelay", true)
		server:settimeout(1)

		-- Check opened port
		local ip, port = server:getsockname()
		print("[PORT] "..port)

		while true do
			local data, err = server:receive()

			if not(err) then
				print("Received")
			end
			client:close()
		end
	end,threads)

-- Creating stages table
stages[1] = stage1

-- Configuring priority between stages
mg1.configure(stages, threads, 1)

stage1:push()

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get() 

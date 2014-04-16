local lstage = require 'lstage'
local mg1    = require 'lstage.controllers.mg1'

-- Creating stages table
local stages = {}
local cores  = lstage.cpus() * 2

local stage1=lstage.stage(
	function() 
		while true do
			local socket = require("socket")
	
			-- New TCP connection
			server = assert(socket.bind("127.0.0.1", "65000"))
			server:setoption("tcp-nodelay", true)
			server:settimeout(1)
			server:accept()

			local rpc_data, err_ckt = server:receive()			

			-- No error
			if not err_ckt then
				print("Error while receiving event")
			end
			server:close()
		end
	end,cores)

-- Creating stages table
stages[1] = stage1

-- Configuring priority between stages
mg1.configure(stages, cores, 1)

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get() 

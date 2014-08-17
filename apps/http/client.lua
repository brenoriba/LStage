--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014
	httperf
	**********************************************************************************************
]]--

-- Imports
local lstage = require 'lstage'

-- Global vars
local default_timeout = 1
local ip   	      = "127.0.0.1"
local port 	      = 8080

local function sink(resp)
	local f=ltn12.sink.table(resp)
	return function(...)
		return f(...)
	end
end

client=lstage.stage(
	function(url)		
		require 'table'
		local http = require("socket.http")
		local resp = {}
		local r, c, h, s=http.request{
		   	url = url,
		   	sink = sink(resp),
		}
		if not r then return nil,c end
		local r=table.concat(resp)
		print(r)
	end, 1)

lstage.pool:add()

-- Push message into client stage
--client:push("http://127.0.0.1:8080/index.lua")
client:push("http://127.0.0.1:8080/index.html")

-- Avoid script to close
lstage.channel():get()

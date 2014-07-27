--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

-- Imports
local lstage = require 'lstage'

-- Global vars
local default_timeout = 1
local ip   	      = "127.0.0.1"
local port 	      = 8080

client=lstage.stage(
	function(data)		
		local socket = require "socket"
		local client = socket.tcp()

		client:setoption("tcp-nodelay", true)
		client:settimeout(default_timeout)
		proxy_connection, err = client:connect(ip, port)

		if proxy_connection then
			print("Sending headers...")

			-- Sending data to the server
			client:send(data.."\n")

			-- Request headers
			client:send("Host: www.puc-rio.br\n")
			client:send("Connection: keep-alive\n")
			client:send("Cache-Control: max-age=0\n")	
			client:send("Accept-Encoding: gzip,deflate,sdch\n")
			client:send("Accept-Language: pt-BR,pt;q=0.8,en-US;q=0.6,en;q=0.4,es;q=0.2\n")

			local server_answer, err_ckt = client:receive("*l")
			print(server_answer)
			client:close()
		end
	end, 1)

lstage.pool:add()

-- Push message into client stage
-- Reference: http://w3.impa.br/~diego/software/luasocket/url.html
--client:push("tcp http://www.example.com/cgilua/index.lua?a=2#there 2.0")
client:push("tcp /index.lua 2.0")

-- Avoid script to close
lstage.channel():get()

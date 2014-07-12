--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

local default_timeout = 1
local ip = "127.0.0.1"
local port = 8081

local socket  = require("socket")
local client  = socket.tcp()

client:setoption("tcp-nodelay", true)
client:settimeout(default_timeout)

proxy_connection, err = client:connect(ip, port)

if proxy_connection then
	print("conectado")
	client:send("breno riba da costa cruz\n")
	--local server_answer, err_ckt = client:receive("*l")
	--print(server_answer)
	client:close()
end

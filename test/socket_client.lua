local host, port = "127.0.0.1", 65000
local socket = require("socket")
local tcp = assert(socket.tcp())

tcp:connect(host, port)
tcp:send("s1\n")
tcp:close()

--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

local parsing = {}

-- Split string
parsing.strsplit = function(str)
	local words = {}

	for w in string.gmatch (str, "%S+") do
		words[#words+1] = w
	end
	
	return words
end

-- Read request headers
parsing.read_headers = function(sock,req)
	local headers = {}
	local prevval, prevname

	while true do
		local l,err = sock:receive()

		if (not l or l == "") then
			req.headers = headers
			return
		end

		local _,_, name, value = string.find (l, "^([^: ]+)%s*:%s*(.+)")
		name = string.lower (name or '')

		if name then
			prevval = headers [name]
			if prevval then
				value = prevval .. "," .. value
			end
			headers [name] = value
			prevname = name
		elseif prevname then
			headers [prevname] = headers [prevname] .. l
		end
	end
end

-- Parse URL
parsing.parse_url = function(req)
	local url     = require "socket.url"
	local def_url = string.format ("http://%s%s", req.headers.host or "", req.cmd_url or "")

	req.parsed_url	    = url.parse (def_url or '')
	req.parsed_url.port = req.parsed_url.port or req.port
	req.built_url 	    = url.build (req.parsed_url)
	req.relpath 	    = url.unescape (req.parsed_url.path)
end

return parsing

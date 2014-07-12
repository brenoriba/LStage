--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

local utils = {}

-- Split string
utils.strsplit = function(str)
	local words = {}
	
	for w in string.gmatch (str, "%S+") do
		table.insert (words, w)
print(w)
	end
	
	return words
end

-- Read request headers
utils.read_headers = function(sock,req)
	local headers = {}
	local prevval, prevname
	
	while 1 do
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

return utils

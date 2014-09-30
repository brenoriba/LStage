local lstage=require'lstage'

local cFirst  = lstage.channel()
local cSecond = lstage.channel()

local first=lstage.stage(function()
	print("first")

	local i=0
	while i<20 do
		cSecond:push('second')
		i=i+1
	end
end, 4)

local second=lstage.stage(function(name)
	while true do
		local t={cSecond:get()}
		print((require'table'.unpack or unpack)(t))
		if #t==0 then break end
	end
end, 4)

-- Initialize thread pool and stages
lstage.pool:add(1)
first:push()
second:push()

-- Avoid closing
lstage.channel():get()

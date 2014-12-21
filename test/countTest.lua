local lstage = require 'lstage'

local stage2=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
	end,4)

local stage1=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		stage2:push('s2')
	end,4)

for i=1,10 do
   stage1:push('s1')
end

lstage.pool:add(2)
lstage.dispatchevents()
lstage.channel():get()

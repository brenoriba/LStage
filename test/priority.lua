local lstage=require'lstage'
local seda=require 'lstage.controllers.seda'

local stage1=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 100000000 do
			index = index + 1
		end
		print(name) 
	end,1)
local stage2=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 100000000 do
			index = index + 1
		end
		print(name) 
	end,1)

-- Creating stages table
local stages = {}
stages[1] = stage1
stages[2] = stage2

-- Configuring priority between stages
seda.configure(stages, 2)

stage1:setpriority(1)
stage2:setpriority(10)

for i=1,8 do
   stage1:push('s1')
   stage2:push('s2')
end


lstage.channel():get() 

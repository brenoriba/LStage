local lstage = require 'lstage'
local pool   = require 'lstage.pool'

local stage4=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)						
	end,4)

local stage3=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)	
		stage4:push('s4')					
	end,4)

local stage2=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name) 
		stage3:push('s3')
	end,4)

local stage1=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)
		stage2:push('s2')
	end,4)

--[[
local pool1=pool.new(0)
pool1:add(4)
stage1:setpool(pool1)

local pool2=pool.new(0)
pool2:add(4)
stage2:setpool(pool2)

local pool3=pool.new(0)
pool3:add(4)
stage3:setpool(pool1)

pool1 = stage1:pool()
pool2 = stage2:pool()
print(pool1:size())
print(pool2:size())

-- Workstealing
stage1:steal(stage2,1)
stage1:steal(stage2,2)
--]]

local stages = {stage1,stage2,stage3,stage4}

-- SRPT
--local stages = {stage4,stage3,stage2,stage1}

-- Cohort
--local stages = {stage1,stage2,stage3,stage4,stage3,stage2}
lstage.buildpollingtable(stages)

-- [-1] global ready queue
-- [0] private ready queue
-- [1] private ready queue with turning back
lstage.useprivatequeues(0)
lstage.pool:add(4)
--lstage.maxsteps(4)

-- Fire [maxsteps]
max_steps_reached=function()
	print("Fired!")
end

--stage1:max_events_when_focused(-1)


--stage1:setpriority(10)
--stage2:setpriority(21)
--stage3:setpriority(37)

for i=1,50 do
   stage1:push('s1')
end

lstage.dispatchevents()
lstage.channel():get()

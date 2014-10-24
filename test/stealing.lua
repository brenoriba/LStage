local lstage = require 'lstage'
local pool   = require 'lstage.pool'

local stage3=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)						
	end,2)

local stage2=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name) 
		stage3:push('s3')
	end,2)

local stage1=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)
		stage2:push('s2')
	end,2)

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

-- [-1] global ready queue
-- [0] private ready queue
-- [1] private ready queue with turning back
lstage.useprivatequeues(0)
lstage.pool:add(2)
stage1:max_events_when_focused(-1)

for i=1,50 do
stage1:setpriority(10)
   stage1:push('s1')
end

lstage.dispatchevents()
lstage.channel():get()

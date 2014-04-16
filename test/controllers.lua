local lstage = require 'lstage'
local srpt   = require 'lstage.controllers.srpt'
local mg1    = require 'lstage.controllers.mg1'

-- Creating stages table
local policy = "SRPT"
local stages = {}
local cores  = lstage.cpus() * 2

local stage1=lstage.stage(
	function() 
		local a = 0
		for variable = 0, 100000000 do
			a = a + 1
			local b = a
		end	
		print ("s1")
	end,cores)

local stage2=lstage.stage(
	function()
		local a = 0
		for variable = 0, 100000000 do
			a = a + 1
			local b = a
		end	
		print ("s2")
	end,cores)

-- =============================================
-- SRPT
-- =============================================
if (policy == "SRPT") then
	-- Stage 2
	stages[1] 	    = {}
	stages[1].stages    = {}
	stages[1].index     = 1
	stages[1].stages[1] = stage2

	-- Stage 1
	stages[2] 	    = {}
	stages[2].stages    = {}
	stages[2].index     = 0
	stages[2].stages[1] = stage1

	-- Configuring priority between stages
	srpt.configure(stages, cores)
end

-- =============================================
-- DBR
-- =============================================
if (policy == "MG1") then
	-- Creating stages table
	stages[1] = stage1
	stages[2] = stage2

	-- Configuring priority between stages
	mg1.configure(stages, cores, 1)
end

for i=1,10 do
	stage1:push()
	stage2:push()
end

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get() 

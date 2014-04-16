local lstage = require 'lstage'
local srpt   = require 'lstage.controllers.srpt'
local dbr    = require 'lstage.controllers.dbr'

-- Creating stages table
local policy = "SRPT"
local stages = {}
local cores  = lstage.cpus() * 2

lstage.add_timer(1,100)
lstage.add_timer(0.1,9)
--local c=lstage.channel()

--function create(f)
	--return lstage.stage(function()
--		f()
		--c:push()
--	end)
--end

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

on_timer=function(id)
	--print("teste",id)
--	if c:tryget() then
		--print('s2 acabou')
--	end
end

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
if (policy == "DBR") then
	-- Creating stages table
	stages[1] = stage1
	stages[2] = stage2

	-- Configuring priority between stages
	dbr.configure(stages, cores, 1)
end

for i=1,10 do
	stage1:push()
	stage2:push()
end

-- Avoid script to close

lstage.loop()
--while true do
--	print('s2 acabou', c:get())
--end
--lstage.channel():get() 

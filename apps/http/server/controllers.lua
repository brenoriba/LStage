--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On August 2014
	   
	**********************************************************************************************
]]--

-- Controllers
local lstage       = require 'lstage'
local srpt         = require 'lstage.controllers.srpt'
local mg1          = require 'lstage.controllers.mg1'
local dynamic      = require 'lstage.controllers.dynamic'
local seda         = require 'lstage.controllers.seda'
local workstealing = require 'lstage.controllers.workstealing'

-- Global vars
local wrapper = {}
local refresh = 10

-- Used on Dynamic controller
local maxThreads       = 4
local queueThreshold   = 5
local idlePercentage   = 50
local activePercentage = 10

-- SRPT configure method
wrapper.srpt = function (stagesTable, threads, instanceControl)
	-- Create SRPT table
	local stages = {}
	for ix=1,#stagesTable do
		stages[ix] 	     = {}
		stages[ix].stages    = {}
		stages[ix].index     = ix
		stages[ix].stages[1] = stagesTable[ix]
	end

	-- stagesTable, numberOfThreads
	srpt.configure(stages, threads, instanceControl)
end

-- Cohort configure method
wrapper.cohort = function (stagesTable, threads)
	local stages = stagesTable
	
	for i=#stagesTable-1,2,-1 do
		table.insert(stages,stagesTable[i])
	end

	lstage.buildpollingtable(stages)

	for i,stage in ipairs(stages) do
		stage:max_events_when_focused(3)
	end

	-- [-1] global ready queue
	-- [0] private ready queue
	-- [1] private ready queue with turning back
	lstage.useprivatequeues(0)
	lstage.pool:add(threads)
end

-- MG1 configure method
wrapper.mg1 = function (stagesTable, threads, instanceControl)
	-- stagesTable, numberOfThreads, refreshSeconds
	mg1.configure(stagesTable, threads, refresh, instanceControl)
end

-- SEDA configure method
wrapper.seda = function (stagesTable, threads)
	-- stagesTable, threadsPerPool
	seda.configure(stagesTable, threads)
end

-- Workstealing configure method
wrapper.workstealing = function (stagesTable, threads)
	workstealing.configure(stagesTable, threads, 4)
end

-- DYNAMIC configure method
wrapper.dynamic = function (stagesTable, minThreads, maxThreads, queueThreshold, idlePercentage)
	local conf = {}
	
	-- Configuration
	conf.stages  	      = stagesTable
	conf.minThreads       = minThreads
	conf.maxThreads       = maxThreads
	conf.queueThreshold   = queueThreshold 
	conf.idlePercentage   = idlePercentage
	conf.activePercentage = activePercentage
	conf.refreshSeconds   = refresh
	-- stagesTable, refreshSeconds
	dynamic.configure(conf)
end

-- Configure policy
wrapper.configure = function (stages, policy, threads, instanceControl)
	print("\n*********************************")
	print("Starting server...")

	if (policy == "SRPT") then
		print("Creating "..threads.." thread(s)")
		wrapper.srpt (stages, threads, instanceControl)

	elseif (policy == "COHORT") then
		print("Creating "..threads.." thread(s)")
		wrapper.cohort (stages, threads)

	elseif (policy == "MG1") then
		-- Prepare MG1 table
		local mg1Stages = {}
		for ix=1,#stages do
			mg1Stages[#mg1Stages+1]         = {}
			mg1Stages[#mg1Stages].stage     = stages[ix]
		end

		print("Creating "..threads.." thread(s)")
		wrapper.mg1 (mg1Stages, threads, instanceControl)

	elseif (policy == "SEDA") then
		--threads = math.ceil(threads / #stages)
		print("Creating "..threads.." thread(s) per stage")
		wrapper.seda (stages, threads)

	elseif (policy == "DYNAMIC") then
		print("Creating "..threads.." thread(s)")
		wrapper.dynamic (stages, threads, maxThreads, queueThreshold, idlePercentage)

	elseif (policy == "COLOR") then
		-- Do nothing - color policy is the lstage default policy
		print("Creating "..threads.." thread(s)")
	
		-- Creating threads
		lstage.pool:add(threads)
	elseif (policy == "WORKSTEALING") then
		print("Creating "..threads.." thread(s)")
		print("Configuring ["..policy.."] policy")
		print("*********************************\n")

		wrapper.workstealing (stages, threads)
	end

	print("Configuring ["..policy.."] policy")
	print("*********************************\n")
end

return wrapper

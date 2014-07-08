--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On June 2014
	   
	**********************************************************************************************
]]--

-- Controllers
local lstage  = require 'lstage'
local srpt    = require 'lstage.controllers.srpt'
local mg1     = require 'lstage.controllers.mg1'
local dynamic = require 'lstage.controllers.dynamic'
local seda    = require 'lstage.controllers.seda'
local refresh = 5
local wrapper = {}

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

-- DYNAMIC configure method
wrapper.dynamic = function (stagesTable, threads)
	-- Creating stages table
	local stages = {}
	for ix=1,#stages do
		stages[1] 		 = {}
		stages[1].minThreads 	 = threads
		stages[1].maxThreads 	 = threads + math.ceil(threads * 0.1)
		stages[1].queueThreshold = 5
		stages[1].stage		 = stagesTable[ix]
	end

	-- stagesTable, refreshSeconds
	dynamic.configure(stages, refresh)
end

-- Configure policy
wrapper.configure = function (stages, policy, threads,instanceControl)
	print("\n*********************************")

	if (policy == "SRPT") then
		print("Creating "..threads.." thread(s)")
		wrapper.srpt (stages, threads, instanceControl)
	elseif (policy == "MG1") then
		print("Creating "..threads.." thread(s)")
		wrapper.mg1 (stages, threads, instanceControl)
	elseif (policy == "SEDA") then
		threads = threads / #stages
		print("Creating "..threads.." thread(s) per stage")
		wrapper.seda (stages, threads)
	elseif (policy == "DYNAMIC") then
		threads = threads / #stages
		print("Creating "..threads.." thread(s) per stage")
		wrapper.dynamic (stages, threads)
	elseif (policy == "COLOR") then
		-- Do nothing - color policy is the lstage default policy
		print("Creating "..threads.." thread(s)")
	
		-- Creating threads
		for index=1,threads do
			lstage.pool:add()
		end
	end

	print("Configuring ["..policy.."] policy")
	print("*********************************\n")
end

return wrapper

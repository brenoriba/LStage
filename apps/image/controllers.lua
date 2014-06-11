--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On June 2014
	   
	**********************************************************************************************
]]--

-- Controllers
local srpt    = require 'lstage.controllers.srpt'
local mg1     = require 'lstage.controllers.mg1'
local dynamic = require 'lstage.controllers.dynamic'
local seda    = require 'lstage.controllers.seda'
local wrapper = {}

-- SRPT configure method
wrapper.srpt = function (stagesTable, threads)
	-- Create SRPT table
	local stages = {}
	for ix=1,#stagesTable do
		stages[ix] 	     = {}
		stages[ix].stages    = {}
		stages[ix].index     = ix
		stages[ix].stages[1] = stagesTable[ix]
	end

	-- stagesTable, numberOfThreads
	srpt.configure(stages, threads)
end

-- MG1 configure method
wrapper.mg1 = function (stagesTable, threads)
	-- stagesTable, numberOfThreads, refreshSeconds
	mg1.configure(stagesTable, threads, 0.5)
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
		stages[1].maxThreads 	 = threads + math.ceil(threads * 0.3)
		stages[1].queueThreshold = 100
		stages[1].stage		 = stagesTable[ix]
	end

	-- stagesTable, refreshSeconds
	seda.configure(stages, 0.5)
end

-- Configure policy
wrapper.configure = function (stages, policy, threads)
	print("\n*********************************")

	if (policy == "SRPT") then
		print("Creating "..threads.." threads")
		wrapper.srpt (stages, threads)
	elseif (policy == "MG1") then
		print("Creating "..threads.." threads")
		wrapper.mg1 (stages, threads)
	elseif (policy == "SEDA") then
		threads = threads / #stages
		print("Creating "..threads.." threads per stage")
		wrapper.seda (stages, threads)
	elseif (policy == "DYNAMIC") then
		threads = threads / #stages
		print("Creating "..threads.." threads per stage")
		wrapper.dynamic (stages, threads)
	elseif (policy == "COLOR") then
		-- Do nothing - color policy is the lstage default policy
		print("Creating "..threads.." threads")
	end

	print("Configuring ["..policy.."] policy")
	print("*********************************\n")
end

return wrapper

--[[
	Workstealing architecture

	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Breno Riba
		
	Implemented on October 2014
	   
	**********************************************************************************************
]]--

local workstealing = {}
local stages 	   = {}
local lstage 	   = require 'lstage'
local pool   	   = require 'lstage.pool'
local sort         = require 'lstage.utils.mergesort'

--[[
	<summary>
		Workstealing configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="threadsPerPool">Number of threads to be created per pool</param>
]]--
function workstealing.configure (stagesTable, threadsPerPool)
	-- Creating a pool per stage
	for index=1,#stagesTable do
		-- New pool
		local currentPool=pool.new(0)
		currentPool:add(threadsPerPool)
		
		-- Set this pool to stage
		stagesTable[index]:setpool(currentPool)
	end

	-- Save to monitor threads	
	stages = stagesTable

	-- Every "refreshSeconds" with ID = 100
	lstage.add_timer(refreshSeconds, 100)
end

--[[
	<summary>
		Used to refresh stage's rate
	</summary>
	<param name="id">Timer ID</param>
]]--
function workstealing.on_timer(id)
	-- Validate ID number
	if (id ~= 100) then
		return
	end

	-- Check queue status
	local queueSizes = {}
	for index=1,#stages do
		queueSize = stages[index]:size() + stages[index]:instances() - stages[index]:instancesize()
		
		queueSizes[index] = {}
		queueSizes[index].queueSize = queueSize	
	end

	-- Sort by "rate" value
	sort.MergeSort(queueSizes, 1, #queueSizes, "queueSize")

	-- Manage threads
	for index=#queueSizes,1,-1 do
		-- Searching for stages that can give threads
		for j=index-1,1,-1 do
			-- We must have at least one thread in the thread pool
			-- and we must have instances to run one more thread
			if (stages[j].pool:size() > 1 and stages[index]:instancesize() > stages[index].pool:size()) then
				print("Moving a thread to another stage...")

				stages[j].pool:kill()
				stages[index].pool:add(1)
			end
		end
	end
end

return workstealing

--[[
	The MG1 policy

	Like Cohort scheduling's wavefront pattern, the MG1 policy was based on a very simple idea, namely
	that stages should receive time on the CPU in proportion to their load.

	The polling tables for the MG1 policy are constructed in such a way that the most heavily-loaded 	 stages are visited more frequently than mostly-idle stages.

	Reference: http://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-781.pdf

	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Breno Riba
		
	Implemented on March 2014
	   
	**********************************************************************************************
]]--

local mg1          = {}
local lstage       = require 'lstage'
local sort         = require 'lstage.utils.mergesort'
local stages       = {}
local newInstances = false

--[[
	<summary>
		MG1 configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="numberOfThreads">Number of threads to be created</param>
	<param name="refreshSeconds">Time (in seconds) to refresh stage's rate</param>
	<param name="instanceControl">Create more instances to prior stages</param>
]]--
function mg1.configure(stagesTable, numberOfThreads, refreshSeconds, instances, instanceControl)
	-- Creating threads
	lstage.pool:add(numberOfThreads)

	-- Graph with one stage
	-- Nothing to do in this case
	if (#stagesTable <= 1) then
		return
	end

	-- We keep table in a global because we will
	-- use to get stage's rate at "on_timer" callback
	stages       = stagesTable
	newInstances = instanceControl

	-- Every "refreshSeconds" with ID = 100
	lstage.add_timer(refreshSeconds, 100)
end

--[[
	<summary>
		Used to refresh stage's rate
	</summary>
	<param name="id">Timer ID</param>
]]--
function mg1.on_timer(id)
	-- Validate ID number
	if (id ~= 100) then
		return
	end

	local pollingTable = {}

	-- Get queue size
	for index=1,#stages do
		local size = #pollingTable+1

		pollingTable[size]       = {}
		pollingTable[size].stage = stages[index].stage
		pollingTable[size].rate  = stages[index].stage:size() + stages[index].instances - stages[index].stage:instances()
	end

	-- Sort by "rate" value
	sort.MergeSort(pollingTable, 1, #pollingTable, "rate")
	
	local lastRate     = -1
	local instanceSize = -1
	local priority     = #pollingTable + 1

	-- Give priority in ascending order
	for index=#pollingTable,1,-1 do
		-- Same "rate", same priority
		if (lastRate ~= pollingTable[index].rate) then
			priority = priority - 1	
		end

		pollingTable[index].stage:setpriority(priority)
		lastRate = pollingTable[index].rate

		-- Control new instances
		if (newInstances) then
			local stage 	   = pollingTable[index].stage			
			local instanceSize = stage:instances()
			local newInstances = priority - instanceSize

			-- Check how many instances we have to create
			if (newInstances > 0) then
				stage:instantiate(newInstances)	
			-- Check how many instances we have to remove
			elseif (newInstances < 0) then
				newInstances = newInstances * -1
				stage:free(newInstances)
			end
		end
	end
end

return mg1

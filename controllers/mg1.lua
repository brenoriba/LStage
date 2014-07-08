--[[
	The MG1 policy

	Like Cohort scheduling's wavefront pattern, the MG1 policy was based on a very simple idea, namely
	that stages should receive time on the CPU in proportion to their load.

	The polling tables for the MG1 policy are constructed in such a way that the most heavily-loaded 	 stages are visited more frequently than mostly-idle stages.

	Reference: http://www.cl.cam.ac.uk/techreports/UCAM-CL-TR-781.pdf

	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Ana Lúcia de Moura
		- Breno Riba
		- Noemi Rodriguez   
		- Tiago Salmito
		
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
function mg1.configure(stagesTable, numberOfThreads, refreshSeconds, instanceControl)
	-- Creating threads
	for index=1,numberOfThreads do
		lstage.pool:add()
	end

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
		pollingTable[size].stage = stages[index]
		pollingTable[size].rate  = stages[index]:size() - stages[index]:instancesize()
	end

	-- Sort by "rate" value
	sort.MergeSort(pollingTable, 1, #pollingTable, "rate")
	
	local lastRate     = -1
	local instanceSize = -1
	local priority     = #pollingTable

	-- Give priority in ascending order
	for index=1,#pollingTable do
		-- Same "rate", same priority
		if (index ~= #pollingTable and lastRate ~= pollingTable[index].rate) then
			priority = priority - 1	
		end

		pollingTable[index].stage:setpriority(priority)
		lastRate = pollingTable[index].rate

		-- Control new instances
		if (newInstances) then
			--instanceSize = pollingTable[index].stage.instancesize
		end
	end
end

return mg1

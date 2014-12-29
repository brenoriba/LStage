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

local mg1    = {}
local lstage = require 'lstage'
local stages = {}

function mg1.compare(a,b)
  return a.visits > b.visits
end

function mg1.buildVisitOrder (pollingTable)
	-- Build new polling table
	local newVisitOrder = {}
	local maxSize 	    = #pollingTable
	local firstCell     = pollingTable[1]
	local lastCell	    = pollingTable[maxSize]
	local index 	    = 1

	repeat
		-- Insert into polling table
		if (pollingTable[index].visits ~= 0) then
			table.insert(newVisitOrder, pollingTable[index].stage)
			pollingTable[index].visits = pollingTable[index].visits - 1

			-- Restart polling table at first stage with visits 
			-- different from 0
			if (index > 1) then
				index = 1
			else
				index = index + 1
			end
		elseif (index >= maxSize) then
			index = 1
		else
			index = index + 1
		end
	-- Until last stage
	until (firstCell.visits == 0 and lastCell.visits == 0)
	return newVisitOrder
end

function is_focused()
	require 'math'

	local pollingTable = {}
	local total = 0
	local lastInputCount = 0
	local equalInputCount = 1

	-- Get demand for each stage
	for i,stage in ipairs(stages) do
		pollingTable[i]        = {}
		pollingTable[i].stage  = stage
		pollingTable[i].load   = stage:getInputCount()
		pollingTable[i].visits = 0

		if (lastInputCount ~= 0 and lastInputCount ~= pollingTable[i].load) then
			equalInputCount = 0
		end

		lastInputCount = pollingTable[i].load
		total = total + lastInputCount

		stage:resetStatistics()
	end

	if (equalInputCount == 0) then
		local loadRate 	       = 0		
		local pollingTableSize = #stages * 3
	
		-- Calculate visits
		for i,cell in ipairs(pollingTable) do
			loadRate = (cell.load * 100) / total
			pollingTable[i].visits = math.ceil((loadRate * pollingTableSize) / 100)
		end

		-- Sort by number of visits
		table.sort(pollingTable, mg1.compare)

		-- Build new polling table
		local newVisitOrder = mg1.buildVisitOrder (pollingTable)

		-- Build new polling table
		lstage.buildpollingtable(newVisitOrder)
	end
end

--[[
	<summary>
		MG1 configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="numberOfThreads">Number of threads to be created</param>
]]--
function mg1.configure(stagesTable, numberOfThreads)
	-- Creating threads
	lstage.pool:add(numberOfThreads)

	-- Graph with one stage
	-- Nothing to do in this case
	if (#stagesTable <= 1) then
		return
	end

	-- We keep table in a global because we will
	-- use to get stage's rate at "on_timer" callback
	stages = stagesTable

	lstage.buildpollingtable(stages)
	lstage.useprivatequeues(0)

	for i,stage in ipairs(stages) do
		stage:max_events_when_focused(5)
	end

	-- Configure last stage to fire when focused
	lstage.fireLastFocused()
end

return mg1

--[[
	The SRPT policy

	The implementations of the Cohort and MG1 scheduling policies share much of their
	code base: one thread per core, conditional locking on single-threaded stages, exponential
	idling, etc. The main difference between the two is the way the next stage to visit is chosen
	by each thread/core: a wavefront in Cohort scheduling, polling tables in MG1. Isolating
	this difference in the implementation made it relatively straightforward to experiment
	with other visit patterns. One of these was the SRPT scheduling policy, a variation on
	Cohort's wavefront heuristic for staged servers with pipelines. Instead of visiting stages
	in a wavefront, SRPT always prefers stages at the end of the pipeline. These stages are
	visited first, and a core works its way back to the head of the pipeline. As soon as any
	stage is successfully visited (i.e. at least one event was processed), the scheduler restarts
	at the end of the pipeline. For compact stage graphs this very roughly approximates
	the Shortest Remaining Processing Time queue discipline, which is known to minimize
	response times and maximize throughput for most workloads.

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

local srpt   = {}
local lstage = require 'lstage'
local sort   = require 'lstage.utils.mergesort'

--[[
	<summary>
		SRPT configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="numberOfThreads">Number of threads to be created</param>
]]--
function srpt.configure(stagesTable, numberOfThreads)
	-- Creating threads
	for index=1,numberOfThreads do
		lstage.pool:add()
	end

	-- Graph with one stage
	-- Nothing to do in this case
	if (#stagesTable <= 1) then
		return
	end

	-- Sort by "index" value
	sort.MergeSort(stagesTable, 1, #stagesTable, "index")
	
	-- Give priority to the stages at the end of the pipeline
	local priority = #stagesTable
	for index=priority,1,-1 do
		local stages = stagesTable[index].stages

		-- We can have many stages with the same priority
		for stage=1,#stages do
			stages[stage]:setpriority(priority)	
		end
		priority = priority - 1
	end
end

return srpt

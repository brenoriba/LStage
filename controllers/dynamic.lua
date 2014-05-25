--[[
	Dynamic Resource Controller

	Adjusts the number of threads executing within each stage. The
	goal is to avoid allocating too many threads, but still have enough
	threads to meet the concurrency demands of the stage. The controller
	periodically samples the input queue and adds a thread when the queue
	length exceeds some threshold, up to a maximum number of threads
	per stage. Threads are removed from a stage when they are idle for a
	specified period of time.

	Reference: http://www.eecs.harvard.edu/~mdw/papers/seda-sosp01.pdf

	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Ana Lúcia de Moura
		- Breno Riba
		- Noemi Rodriguez   
		- Tiago Salmito
		
	Implemented on May 2014
	   
	**********************************************************************************************
]]--

local lstage  = require 'lstage'
local pool    = require 'lstage.pool'
local dynamic = {}
local stages  = {}

--[[
	<summary>
		Dynamic Resource Controller configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="refreshSeconds">Time (in seconds) to refresh stage's rate</param>
]]--
function dynamic.configure (stagesTable, refreshSeconds)
	stages = stagesTable

	-- Creating a pool per stage
	for index=1,#stages do
		-- New pool
		local currentPool=pool.new(0)
		currentPool:add(stages[index].minThreads)

		-- Set this pool to stage
		stages[index].stage:setpool(currentPool)
		stages[index].pool = currentPool
	end

	-- Every "refreshSeconds" with ID = 100
	lstage.add_timer(refreshSeconds, 100)
end

--[[
	<summary>
		Used to refresh stage's rate
	</summary>
	<param name="id">Timer ID</param>
]]--
on_timer=function(id)
	-- Validate ID number
	if (id ~= 100) then
		return
	end

	-- Initialize vars
	local current 	  = nil
	local stage 	  = nil
	local queueSize   = nil
	local currentPool = nil
	local poolSize    = nil

	-- Check stage's queue
	for index=1,#stages do
		current     = stages[index]
		stage 	    = current.stage
		queueSize   = stage:size()
		currentPool = current.pool
		poolSize    = currentPool:size()

		-- Check queue threshold and compare current pool size with
		-- max number of threads per stage
		if (queueSize >= current.queueThreshold and poolSize < current.maxThreads) then
			-- We have to add one more thread		
			currentPool:add(1)
		-- Stage is IDLE - so we have to kill a thread
		elseif (queueSize == 0 and poolSize > current.minThreads) then
			currentPool:kill()
		end
	end
end

return dynamic

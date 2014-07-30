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
		- Breno Riba
				
	Implemented on May 2014
	   
	**********************************************************************************************
]]--

local lstage  = require 'lstage'
local pool    = require 'lstage.pool'
local dynamic = {}
local conf    = {}

--[[
	<summary>
		Dynamic Resource Controller configure method
	</summary>
	<param name="configuration">Configuration table</param>
]]--
function dynamic.configure (configuration)
	-- Store in global vars
	conf = configuration
	
	-- Creating threads
	lstage.pool:add(conf.minThreads)

	-- Every "refreshSeconds" with ID = 101
	lstage.add_timer(conf.refreshSeconds, 101)
end

--[[
	<summary>
		Used to refresh stage's rate
	</summary>
	<param name="id">Timer ID</param>
]]--
function dynamic.on_timer(id)
	-- Validate ID number
	if (id ~= 101) then
		return
	end

	-- Check stage's queue
	local stages 		  = conf.stages
	local queueSize 	  = 0
	local totalIdle 	  = 0
	local totalAboveThreshold = 0

	-- Loop over stages
	for index=1,#stages do
		queueSize = stages[index]:size() + stages[index]:instances() - stages[index]:instancesize()
	
		-- Check how many stages are idle
		if (queueSize == 0) then
			totalIdle = totalIdle + 1
		end
		
		-- Active and above threshold
		if (queueSize > conf.queueThreshold) then
			totalAboveThreshold = totalAboveThreshold + 1
		end
	end

	-- Check how many stages are IDLE
	-- If we have more than a configured percentage, we kill a thread
	local idlePercentage   = (totalIdle * 100) / #stages
	local activePercentage = (totalAboveThreshold * 100) / #stages
	local poolSize 	       = lstage.pool:size()

	-- Active - add one thread into pool
	if (activePercentage > conf.activePercentage and poolSize < conf.maxThreads) then
		print("[ACTIVE PERCENTAGE: "..math.floor(activePercentage).."%] Creating one more thread...")
		lstage.pool:add(1)

	-- Idle - kill one thread
	elseif (idlePercentage > conf.idlePercentage and poolSize > conf.minThreads) then
		--print("[IDLE PERCENTAGE: "..math.floor(idlePercentage).."%] Killing one thread...")
		--lstage.pool:kill()
	end
end

return dynamic

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

	for i=2,#stages,1 do
		local current = stages[i]
		local prior   = stages[i-1]

		local currentSize = current:size() + (current:instances() - current:instancesize())
		local priorSize   = prior:size() + (prior:instances() - prior:instancesize())
		local priorPool   = prior:pool()

		if (currentSize > priorSize and priorPool:size() > 1) then
			current:steal(prior,1)
		end
	end
end

--[[
	<summary>
		Workstealing configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="threadsPerPool">Number of threads to be created per pool</param>
	<param name="refreshSeconds">Time (in seconds) to refresh stage's rate</param>
]]--
function workstealing.configure (stagesTable, threadsPerPool, refreshSeconds)
	-- Creating a pool per stage
	for i,stage in ipairs(stagesTable) do
		-- New pool
		local currentPool=pool.new(0)
		currentPool:add(threadsPerPool)
		
		-- Set this pool to stage
		stage:setpool(currentPool)
	end

	stages = stagesTable

	-- Every "refreshSeconds" with ID = 100
	while true do
		lstage.event.sleep(refreshSeconds)
		workstealing.on_timer(100)
	end
end

return workstealing

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

function workstealing.compare(a,b)
  local aRate = a:getInputCount()
  local bRate = b:getInputCount()

  if (aRate ~= 0) then
     aRate = (a:getProcessedCount() * 100) / aRate
  end

  if (bRate ~= 0) then
    bRate = (b:getProcessedCount() * 100) / bRate
  end

  return aRate > bRate
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

	table.sort(stages,workstealing.compare)

	for i=2,#stages,1 do
		local current = stages[i]
		local prior   = stages[i-1]

		local currentRate = current:getInputCount()
		local priorRate   = prior:getInputCount()
 
		if (currentRate ~= 0) then
			currentRate = (current:getProcessedCount() * 100) / currentRate
		end

		if (priorRate ~= 0) then
			priorRate = (prior:getProcessedCount() * 100) / priorRate
		end

		-- Check if we have different rate
		if (currentRate ~= priorRate and currentRate > priorRate) then
			local currentPool = current:pool()
			local priorPool = prior:pool()
			local priorPoolSize = priorPool:size()

			if (priorPoolSize > 1 and current:instances() >= (currentPool:size() + 1)) then
				print(i.." roubou do estágio "..i-1)
				current:steal(prior,1)
			end
		end
	end

	-- Reset statistics
	for i,stage in ipairs(stages) do
		stage:resetStatistics()
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

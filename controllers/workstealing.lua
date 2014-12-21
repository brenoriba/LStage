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

  return aRate < bRate
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

	if (#stages >= 4) then
		local first = 1
		local last  = #stages
	
		for i=1,2,1 do
			local firstPool = stages[first]:pool()
			local lastPool = stages[last]:pool()
			local lastPoolSize = lastPool:size()

			if (lastPoolSize > 1 and stages[first]:instances() >= (firstPool:size() + 1)) then
				print(first.." roubou do estágio "..last)
				stages[first]:steal(stages[last],1)
			end

			first = first + 1
			last  = last - 1
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

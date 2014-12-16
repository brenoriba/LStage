--[[
	DBR architecture

	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Breno Riba
		
	Implemented on December 2014
	   
	**********************************************************************************************
]]--

local dbr    = {}
local stages = {}
local lstage = require 'lstage'
local pool   = require 'lstage.pool'

--[[
	<summary>
		DBR configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="threads">Number of threads to be created</param>
]]--
function dbr.configure(stagesTable, threads)
	-- Build polling table
	stages = stagesTable
	lstage.buildpollingtable(stages)

	for i,stage in ipairs(stages) do
		stage:max_events_when_focused(5)
	end

	-- Configure last stage to fire when focused
	stages[#stages]:firewhenfocused()

	-- Use private queues
	lstage.useprivatequeues(0)
	lstage.pool:add(threads)
end

--[[
	<summary>
		Comparer method
	</summary>
	<param name="a">Stage A</param>
	<param name="b">Stage B</param>
]]--
function dbr.compare(a,b)
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
		Fire when stage is focused
	</summary>
]]--
function is_focused()
	-- Disable focus
	stages[#stages]:donotfirewhenfocused()

	-- Sort by service rate
	table.sort(stages,dbr.compare)

	-- Configure last stage to fire when focused
	stages[#stages]:firewhenfocused()
end

return dbr

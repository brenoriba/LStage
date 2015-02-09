local lstage = require 'lstage'
local pool   = require 'lstage.pool'

local total = 0
local stage4=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		total = total + 1
		print("[TOTAL] "..total)						
	end,2)

local stage3=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		--print(name)	
		stage4:push('s4')					
	end,2)

local stage2=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		--print(name) 
		stage3:push('s3')
	end,2)

local stage1=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)
		stage2:push('s2')
	end,2)

local stages = {stage1,stage2,stage3,stage4}

function compare(a,b)
  return a.visits > b.visits
end

function buildVisitOrder (pollingTable)
	-- Build new polling table
	local newVisitOrder = {}
	local maxSize 	    = #pollingTable
	local firstCell     = pollingTable[1]
	local lastCell	    = pollingTable[maxSize]
	local index 	    = 1

	repeat
		-- Insert into polling table
		if (pollingTable[index].visits ~= 0) then
			--table.insert(newVisitOrder, { id = pollingTable[index].id, stage = pollingTable[index].stage})
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
		pollingTable[i].id     = i
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
		table.sort(pollingTable, compare)

		-- Build new polling table
		local newVisitOrder = buildVisitOrder (pollingTable)
print("FIRED! ***************************************")
		-- Build new polling table
		--[[local order = ""
		local del = ""
		for i,cell in ipairs(newVisitOrder) do
			order = order .. del .. cell.id
			dell = ","
		end
		print(order)--]]
		lstage.buildpollingtable(newVisitOrder)
	end
end

lstage.buildpollingtable(stages)
lstage.useprivatequeues(0)
lstage.fireLastFocused()

for i,stage in ipairs(stages) do
	--stage:max_events_when_focused(5)
end

lstage.pool:add(2)

for i=1,500 do
   stage1:push('s1')
   stage3:push('s3')
end

lstage.dispatchevents()
lstage.channel():get()

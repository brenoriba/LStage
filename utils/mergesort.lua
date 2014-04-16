--[[
	MergeSort

	Made by: Breno Riba
	Date   : 04/12/2013
	Prof.  : Noemi Rodriguez
--]]

local sort = {}

-- Merge between two tables
function sort.Merge (array, first, middle, last, key)
	local firstArray = {}
	local lastArray  = {}

	-- Temp count
	local firstSize = middle - first + 1
	local lastSize  = last - middle

	-- Copy of the first array
	local tmp = 0
	for i=1, firstSize do
		firstArray[i] = array[tmp+first]
		tmp = tmp + 1
	end

	-- Copy the second array
	tmp = 0
	for i=1, lastSize do
		lastArray[i] = array[tmp+middle+1]
		tmp = tmp + 1
	end

	local firstCount = 1
	local lastCount  = 1

	-- Merge operation
	for i=first,last do
		-- Both arrays have values to work
		if (firstCount <= firstSize and lastCount <= lastSize) then		
			if (firstArray[firstCount][key] < lastArray[lastCount][key]) then
				array[i]   = firstArray[firstCount]
				firstCount = firstCount + 1
			else
				array[i]  = lastArray[lastCount]
				lastCount = lastCount + 1
			end
		-- Only first array needs to put values into main array
		elseif (firstCount <= firstSize) then
			array[i]   = firstArray[firstCount]
			firstCount = firstCount + 1
		-- Only the last array needs to put values into main array
		else
			array[i]  = lastArray[lastCount]
			lastCount = lastCount + 1
		end
	end
end

-- Merge sort function
function sort.MergeSort (array, first, last, key)
	if (first < last) then
		local middle = math.floor((first + last) / 2)

		sort.MergeSort (array, first, middle, key)
		sort.MergeSort (array, middle + 1, last, key)
		sort.Merge     (array, first, middle, last, key)
	end
end

return sort

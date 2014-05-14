--[[
	SEDA architecture with modifications - threads auto scaling

	Reference: http://www.eecs.harvard.edu/~mdw/papers/quals-seda.pdf

	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Ana Lúcia de Moura
		- Breno Riba
		- Noemi Rodriguez   
		- Tiago Salmito
		
	Implemented on May 2014
	   
	**********************************************************************************************
]]--

local lseda  	    = {}
local stages 	    = {}
local maxThroughput = {}
local lstage 	    = require 'lstage'
local pool   	    = require 'lstage.pool'

--[[
	<summary>
		SEDA configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="threadsPerPool">Number of threads to be created per pool</param>
	<param name="threadLimit">Max number of threads that can be created</param>
	<param name="refreshSeconds">Time to check stages status and maybe create a new thread</param>
]]--
function lseda.configure(stagesTable, threadsPerPool, threadLimit, refreshSeconds)
	-- Creating a pool per stage
	stages = stagesTable
	for index=1,#stages do
		-- New pool
		local currentPool=pool.new(0)
		currentPool:add(threadsPerPool)
		
		-- Set this pool to stage
		stages[index]:setpool(currentPool)
	end

	-- Every "refreshSeconds" with ID = 100
	lstage.add_timer(refreshSeconds, 100)
end

--[[
	<summary>
		Used to control threads
	</summary>
	<param name="id">Timer ID</param>
]]--
on_timer=function(id)
	-- Check stages threshold
	for index=1,#stages do
		local throughput = stages[index]:throughput()

		if (throughput > maxThroughput[index]) then

		end
	end

end

return lseda

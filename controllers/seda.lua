--[[
	Original SEDA architecture

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

local seda   = {}
local lstage = require 'lstage'
local pool   = require 'lstage.pool'

--[[
	<summary>
		SEDA configure method
	</summary>
	<param name="stagesTable">LEDA stages table</param>
	<param name="threadsPerPool">Number of threads to be created per pool</param>
]]--
function seda.configure(stagesTable, threadsPerPool)
	-- Creating a pool per stage
	for index=1,#stagesTable do
		-- New pool
		local currentPool=pool.new(0)
		currentPool:add(threadsPerPool)
		
		-- Set this pool to stage
		stagesTable[index]:setpool(currentPool)
	end
end

return seda

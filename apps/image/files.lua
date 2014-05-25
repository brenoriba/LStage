--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Ana Lúcia de Moura
		- Breno Riba
		- Noemi Rodriguez   
		- Tiago Salmito
		
	Implemented on May 2014
	   
	**********************************************************************************************
]]--

local lfs   = require 'lfs'
local files = {}

--[[
	<summary>
		Get image files from a folder
	</summary>
	<param name="path">Images path</param>
]]--
function files.getImages (path)
	local imgs = {}

	-- Reading all .jpg files
	for img in lfs.dir(path) do
        	local relative=path..'/'..img
		if lfs.attributes(relative,"mode") == "file" then
          		if string.match(img,".*jpg") then
                		imgs[#imgs+1] = relative
			end
		end
	end

	return imgs
end

return files

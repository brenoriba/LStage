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

--local imlib  = require 'imlib2'
local treatments = require 'treatments'
local lstage     = require 'lstage'
local files      = require 'files'

-- Stage that will receive images path
local stage_get_files=lstage.stage(
	function(img) 
		print(img)
	end,1)

-- Get all images path and push into first stage's queue
local imgs = files.getImages("in/")
for i=1,#imgs do
	stage_get_files:push(imgs[i])
end

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

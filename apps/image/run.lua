--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On May 2014

	**********************************************************************************************
]]--

local lstage 	  = require 'lstage' 	  -- Lstage namespace
local files   	  = require 'files'	  -- lfs (luafilesystem) namespace
local controllers = require 'controllers' -- Controllers manager namespace
local stage 	  = require 'stage' 	  -- Project stages

-- Available controllers
-- {SRPT,MG1,SEDA,DYNAMIC,COLOR}
local policy 	      = "MG1"
local instanceControl = false

-- Input directory 
-- Change this if you want to get images from another folder
local inputDir  = "in/in_big/"

-- Number of threads (per stage in case of SEDA)
local threads   = 1
local instances = 2

-- Stages table
local stages = {}

stages[1] = stage.load
stages[2] = stage.grayscale
stages[3] = stage.first_threshold
stages[4] = stage.blur
stages[5] = stage.second_threshold
stages[6] = stage.invert
stages[7] = stage.save

-- Get all images path and push into first stage's queue
local file = files.getImages(inputDir)
local n = #file
for i=1,n do
	assert(stage.load:push(inputDir, file[i]),"[stage_load] Error while loading image "..file[i])
end

-- Configure policy
controllers.configure(stages,policy,threads,instances,instanceControl)

-- Every "refreshSeconds" with ID = 100
lstage.add_timer(1, 1)

-- Timer event
on_timer=function(id)
	local queue = 0

	-- Controllers configuration
	-- MG1
	if (policy == "MG1") then
		local mg1 = require 'lstage.controllers.mg1'
		mg1.on_timer(id)
	end
	
	-- Dynamic
	if (policy == "DYNAMIC") then
		local dynamic = require 'lstage.controllers.dynamic'
		dynamic.on_timer(id)
	end
end

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

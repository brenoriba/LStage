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
local policy 	      = "SEDA"
local instanceControl = false

-- Input directory
-- Change this if you want to get images from another folder
local inputDir  = "in/images/in/in_big"
--local inputDir  = "in"

-- Number of threads (per stage in case of SEDA)
local threads = 8

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
local files = files.getImages(inputDir)
assert(stage.load:push(inputDir, files),"[stage_load] Error while loading images")

-- Configure policy
controllers.configure(stages,policy,threads,instanceControl)

-- Timer event
on_timer=function(id)
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

	-- Workstealing
	--if (policy == "WORKSTEALING") then
		--local workstealing = require 'lstage.controllers.workstealing'
		--workstealing.on_timer(id)
	--end
end

--[[
local loop = 1
while true do
	print("\n*** Loop - " .. loop)
	loop = loop + 1
	for i=1,#stages do
		local queueSize = stages[i]:size() + stages[i]:instances() - stages[i]:instancesize()
		print("["..i.."] "..queueSize)
	end
	lstage.event.sleep(5)
end
--]]

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

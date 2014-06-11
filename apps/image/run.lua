--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On May 2014
	   
	**********************************************************************************************
]]--

local lstage 	  = require 'lstage' 	  -- Lstage namespace
local files   	  = require 'files'	  -- lfs (luafilesystem) namespace
local imglib 	  = require 'imglib' 	  -- Image treatments namespace
local controllers = require 'controllers' -- Controllers manager namespace

-- Debug project
local debug  = false

-- Available controllers
-- {SRPT,MG1,SEDA,DYNAMIC,COLOR}
local policy = "SRPT"

-- Input and output directory 
-- Change this if you want to get images from another folder
local inputDir  = "in/"
local outputDir = "out/"

-- Number of threads (per stage in case of SEDA and DYNAMIC)
local threads = 14

-- Timers
local start = lstage.now()

-- Save images
local stage_save=lstage.stage(
	function(img,filename,freeImg)
		local relative = outputDir.."/"..filename
		local err      = imglib.save(img,relative,freeImg)
		
		-- Error while saving
		if (err) then
			print("[stage_save] "..err)
		end

		if (debug) then
			local time = lstage.now()-start
			print("[out] "..relative.." [secs] "..time)
		end
	end,threads)

-- Apply invert
local stage_invert=lstage.stage(
	function(img,filename)
		-- Invert pixels
		imglib.invert(img)

		-- Push into another stage
		stage_save:push(img, filename,true)

		-- We save each step in debug mode
		if (debug) then		
			stage_save:push(img, "invert_"..filename,false)
		end
	end,threads)

-- Apply the second threshold
local stage_second_threshold=lstage.stage(	
	function(img,threshold,maxValue,filename)
		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		stage_invert:push(img, filename)

		-- We save each step in debug mode
		if (debug) then		
			stage_save:push(img, "second_threshold_"..filename,false)
		end
	end,threads)

-- Apply blur
local stage_blur=lstage.stage(
	function(img,filename)
		-- Apply blur (imlib2)
		imglib.blur(img,2)

		-- Push into another stage
		stage_second_threshold:push(img,70,600,filename)

		-- We save each step in debug mode
		if (debug) then		
			stage_save:push(img, "blur_"..filename,false)
		end
	end,threads)

-- Apply first threshold (there are 2)
local stage_first_threshold=lstage.stage(
	function(img,threshold,maxValue,filename)		
		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		stage_blur:push(img, filename)

		-- We save each step in debug mode
		if (debug) then		
			stage_save:push(img, "first_threshold_"..filename,false)
		end
	end,threads)

-- Apply grayscale
local stage_grayscale=lstage.stage(
	function(img, filename)
		imglib.grayscale(img)

		-- Push into another stage
		stage_first_threshold:push(img,220,300,filename)

		-- We save each step in debug mode
		if (debug) then	
			stage_save:push(img, "grayscale_"..filename,false)
		end
	end,threads)

-- Load images from disk
local stage_load=lstage.stage(
	function(filename) 
		if (debug) then	
			print("[in] "..inputDir.."/"..filename)
		end

		local img,err = imglib.load (inputDir,filename)
		if not (err) then
			stage_grayscale:push(img,filename)
		else
			print("[stage_load] "..err)
		end
	end,threads)

-- Stages table
local stages = {}

stages[1] = stage_load
stages[2] = stage_grayscale
stages[3] = stage_first_threshold
stages[4] = stage_blur
stages[5] = stage_second_threshold
stages[6] = stage_invert
stages[7] = stage_save

-- Configure policy
controllers.configure(stages,policy,threads)

-- Get all images path and push into first stage's queue
local file = files.getImages(inputDir)
local n = #file
for i=1,n do
	stage_load:push(file[i])
end

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

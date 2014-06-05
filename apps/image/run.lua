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

local lstage  = require 'lstage'
local files   = require 'files'
local imglib  = require 'imglib'

-- Timers
local start = lstage.now()

-- Stage that will save images
local stage_save=lstage.stage(
	function(img,outpath)
		print("[out] "..outpath)
		local err = imglib.save(img,outpath)
		if (err) then
			print(err)
		end
	end,1)

-- Apply threshold in image
local stage_invert=lstage.stage(
	function(img,outpath)
		-- Invert pixels
		imglib.invert(img)

		-- Push into another stage
		stage_save:push(img, outpath)
	end,1)

-- Apply threshold in image
local stage_second_threshold=lstage.stage(	
	function(img,threshold,maxValue,outpath)
		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		stage_invert:push(img, outpath)
	end,1)

-- Apply threshold in image
local stage_blur=lstage.stage(
	function(img,outpath)
		-- Apply blur (imlib2)
		imglib.blur(img,2)

		-- Push into another stage
		stage_second_threshold:push(img,70,600,outpath)
	end,1)

-- Apply threshold in image
local stage_first_threshold=lstage.stage(
	function(img,threshold,maxValue,outpath)		
		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		stage_blur:push(img, outpath)
	end,1)

-- Apply grayscale in image
local stage_grayscale=lstage.stage(
	function(img, outpath)
		imglib.grayscale(img)

		-- Push into another stage
		stage_first_threshold:push(img,220,300,outpath)
	end,1)

-- Stage that will load images
local stage_load=lstage.stage(
	function(inpath,outpath,file) 
		print("[in] "..inpath.."/"..file)

		local img,err = imglib.load (inpath,file)
		if not (err) then
			stage_grayscale:push(img, outpath.."/"..file)
		else
			print(err)
		end
	end,1)

-- Input and output directory
local inputDir  = "in/"
local outputDir = "out/"

-- Get all images path and push into first stage's queue
local file = files.getImages(inputDir)
local n = #file
for i=1,n do
	stage_load:push(inputDir, outputDir, file[i])
end

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

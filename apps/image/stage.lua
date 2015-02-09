--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On June 2014
	   
	**********************************************************************************************
]]--

-- Imports
local lstage = require 'lstage' -- Lstage namespace
local imglib = require 'imglib' -- Image treatments namespace

local stage 	= {}
local outputDir = "out/"
local debug 	= false

-- How many instances each stage will have
-- (we use the same as the number of threads)
local instances = 2

-- How many images will be thrown in grayscale stage
local blockSize = 20

-- Save images
stage.save={}
stage.save=lstage.stage(
	function(img,filename,freeImg,timers)
		-- Sanity check
		if (img == nil) then
			return
		end

		local relative = outputDir.."/"..filename
		local err      = imglib.save(img,relative,freeImg)
		
		-- Error while saving
		if (err) then
			print("[stage_save] "..err)
		end

		local time = lstage.now()-timers.io
		print("[WITH IO][out] "..relative.." [secs] "..time)
	end,instances)

-- Apply invert
stage.invert={}
stage.invert=lstage.stage(
	function(img,filename,timers)
		-- Sanity check
		if (img == nil) then
			return
		end

		-- Invert pixels
		imglib.invert(img)

		local time = lstage.now()-timers.nio
		print("[WITHOUT IO][out] "..filename.." [secs] "..time)

		-- Push into another stage
		local msg = "[stage_save] Error while saving image "..filename
		assert(stage.save:push(img, filename,true,timers), msg)

		-- We save each step in debug mode
		if (debug) then	
			msg = "[DEBUG][stage_save] Error while saving image "..filename		
			assert(stage.save:push(img, "invert_"..filename,false), msg)
		end
	end,instances)

-- Apply the second threshold
stage.second_threshold={}
stage.second_threshold=lstage.stage(	
	function(img,threshold,maxValue,filename,timers)
		-- Sanity check
		if (img == nil) then
			return
		end

		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		local msg = "[stage_invert] Error while applying invert into "..filename
		assert(stage.invert:push(img, filename,timers), msg)

		-- We save each step in debug mode
		if (debug) then		
			msg = "[DEBUG][stage_save] Error while saving image "..filename	
			assert(stage.save:push(img, "second_threshold_"..filename,false), msg)
		end
	end,instances)

-- Apply blur
stage.blur={}
stage.blur=lstage.stage(
	function(img,filename,timers)
		-- Sanity check
		if (img == nil) then
			return
		end

		-- Apply blur
		imglib.blur(img,2)

		-- Push into another stage
		local msg = "[stage_second_threshold] Error while applying threshold into "..filename
		assert(stage.second_threshold:push(img,70,600,filename,timers),msg)

		-- We save each step in debug mode
		if (debug) then	
			msg = "[DEBUG][stage_save] Error while saving image "..filename	
			assert(stage.save:push(img, "blur_"..filename,false), msg)
		end
	end,instances)

-- Apply first threshold (there are 2)
stage.first_threshold={}
stage.first_threshold=lstage.stage(
	function(img,threshold,maxValue,filename,timers)	
		-- Sanity check
		if (img == nil) then
			return
		end

		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		local msg = "[stage_blur] Error while applying blur into "..filename
		assert(stage.blur:push(img, filename,timers),msg)

		-- We save each step in debug mode
		if (debug) then		
			msg = "[DEBUG][stage_save] Error while saving image "..filename
			assert(stage.save:push(img, "first_threshold_"..filename,false), msg)
		end
	end,instances)

-- Apply grayscale
stage.grayscale={}
stage.grayscale=lstage.stage(
	function(img, filename,timers)
		-- Sanity check
		if (img == nil) then
			return
		end

		imglib.grayscale(img)

		-- Push into another stage
		local msg = "[stage_first_threshold] Error while applying first threshold into "..filename
		assert(stage.first_threshold:push(img,220,300,filename,timers), msg)		

		-- We save each step in debug mode
		if (debug) then	
			msg = "[DEBUG][stage_save] Error while saving image "..filename
			assert(stage.save:push(img, "grayscale_"..filename,false), msg)
		end
	end,instances)

-- Load images from disk
stage.load={}
stage.load=lstage.stage(
	function(inputDir, files)
		local imgs = {}
		local timers = {}
		timers.io = lstage.now()

		-- Loading a block of images
		for i=1,#files do
			if (debug) then	
				print("[in] "..inputDir.."/"..files[i])
			end

			local img,err = imglib.load (inputDir,files[i])
			if not (err) then
				imgs[#imgs+1]        = {}				
				imgs[#imgs].img      = img
				imgs[#imgs].filename = files[i]
			else
				print("[stage_load] "..err)
			end
		end

		-- We don't want to count I\O
		timers.nio = lstage.now()

		-- To insert random sleep in each block
		local randomSleep = {}
		randomSleep[1] = 5

		-- Push all images into grayscale stage
		local msg = "[stage_grayscale] Error while applying grayscale into "
	        local count = 0
		local sleepCount = 1

		for i=1,#imgs do
			assert(stage.grayscale:push(imgs[i].img,imgs[i].filename,timers),msg..imgs[i].filename)
			count = count + 1

			-- Wait for another block		
			if (count == blockSize) then
				-- Wait before send another block
				print("\n*** Waiting "..randomSleep[sleepCount].." seconds until next block...\n")
				lstage.event.sleep(randomSleep[sleepCount])

				sleepCount = sleepCount + 1
				count = 0

				if (sleepCount > #randomSleep) then
					sleepCount = 1
				end
			end
		end
	end,1)

return stage

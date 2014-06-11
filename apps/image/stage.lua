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
local cores = lstage.cpus()

-- Timer
local start = lstage.now()

-- Save images
stage.save={}
stage.save=lstage.stage(
	function(img,filename,freeImg)
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

		--if (debug) then
			local time = lstage.now()-start
			print("[out] "..relative.." [secs] "..time)
		--end
	end,cores)

-- Apply invert
stage.invert={}
stage.invert=lstage.stage(
	function(img,filename)
		-- Sanity check
		if (img == nil) then
			return
		end

		-- Invert pixels
		imglib.invert(img)

		-- Push into another stage
		local msg = "[stage_save] Error while saving image "..filename
		assert(stage.save:push(img, filename,true), msg)

		-- We save each step in debug mode
		if (debug) then	
			msg = "[DEBUG][stage_save] Error while saving image "..filename		
			assert(stage.save:push(img, "invert_"..filename,false), msg)
		end
	end,cores)

-- Apply the second threshold
stage.second_threshold={}
stage.second_threshold=lstage.stage(	
	function(img,threshold,maxValue,filename)
		-- Sanity check
		if (img == nil) then
			return
		end

		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		local msg = "[stage_invert] Error while applying invert into "..filename
		assert(stage.invert:push(img, filename), msg)

		-- We save each step in debug mode
		if (debug) then		
			msg = "[DEBUG][stage_save] Error while saving image "..filename	
			assert(stage.save:push(img, "second_threshold_"..filename,false), msg)
		end
	end,cores)

-- Apply blur
stage.blur={}
stage.blur=lstage.stage(
	function(img,filename)
		-- Sanity check
		if (img == nil) then
			return
		end

		-- Apply blur
		imglib.blur(img,2)

		-- Push into another stage
		local msg = "[stage_second_threshold] Error while applying threshold into "..filename
		assert(stage.second_threshold:push(img,70,600,filename),msg)

		-- We save each step in debug mode
		if (debug) then	
			msg = "[DEBUG][stage_save] Error while saving image "..filename	
			assert(stage.save:push(img, "blur_"..filename,false), msg)
		end
	end,cores)

-- Apply first threshold (there are 2)
stage.first_threshold={}
stage.first_threshold=lstage.stage(
	function(img,threshold,maxValue,filename)	
		-- Sanity check
		if (img == nil) then
			return
		end
	
		imglib.threshold(img,threshold,maxValue)

		-- Push into another stage
		local msg = "[stage_blur] Error while applying blur into "..filename
		assert(stage.blur:push(img, filename),msg)

		-- We save each step in debug mode
		if (debug) then		
			msg = "[DEBUG][stage_save] Error while saving image "..filename
			assert(stage.save:push(img, "first_threshold_"..filename,false), msg)
		end
	end,cores)

-- Apply grayscale
stage.grayscale={}
stage.grayscale=lstage.stage(
	function(img, filename)
		-- Sanity check
		if (img == nil) then
			return
		end

		imglib.grayscale(img)

		-- Push into another stage
		local msg = "[stage_first_threshold] Error while applying first threshold into "..filename
		assert(stage.first_threshold:push(img,220,300,filename), msg)		

		-- We save each step in debug mode
		if (debug) then	
			msg = "[DEBUG][stage_save] Error while saving image "..filename
			assert(stage.save:push(img, "grayscale_"..filename,false), msg)
		end
	end,cores)

-- Load images from disk
stage.load={}
stage.load=lstage.stage(
	function(inputDir, filename) 
		if (debug) then	
			print("[in] "..inputDir.."/"..filename)
		end

		local img,err = imglib.load (inputDir,filename)
		if not (err) then
			local msg = "[stage_grayscale] Error while applying grayscale into " .. filename
			assert(stage.grayscale:push(img,filename),msg)			
		else
			print("[stage_load] "..err)
		end
	end,1)

return stage

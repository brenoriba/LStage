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

local treatments = require 'treatments'
local lstage     = require 'lstage'
local files      = require 'files'

-- Timers
local start = lstage.now()

-- Stage that will save images
local stage_save_img=lstage.stage(
	function(img,outpath)
		print("[out] "..outpath)
		local _,err = img.save(img,outpath)		
		img.free(img)
		if (err) then
			print(err)
		end
	end,1)

-- Apply blur in image
local stage_blur_img=lstage.stage(
	function(img, outpath)
		img.blur(img,1)
		stage_save_img:push(img, outpath)
	end,1)

-- Stage that will load images
local stage_load_img=lstage.stage(
	function(inpath,outpath,file) 
		local relative=inpath.."/"..file
		print("[in] "..relative)

		local imlib2=require "imlib2_image"
		local img,err=imlib2.image.load(relative)
		if not (img) then
			print(err)
		else
			stage_blur_img:push(img, outpath.."/"..file)
		end
	end,1)

-- Input and output directory
local inputDir  = "in/"
local outputDir = "out/"

-- Get all images path and push into first stage's queue
local file = files.getImages(inputDir)
local n = #file
for i=1,n do
	stage_load_img:push(inputDir, outputDir, file[i])
end

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()
print("[Done] "..lstage.now() - start.." secs")

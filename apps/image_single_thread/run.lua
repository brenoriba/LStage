--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On June 2014

	**********************************************************************************************
]]--

local lstage = require 'lstage' -- Lstage namespace
local files  = require 'files'  -- lfs (luafilesystem) namespace
local imglib = require 'imglib' -- Image treatments namespace

-- Work directory 
local inputDir  = "in/in_big"
local outputDir = "out/"

-- Timer
local start = lstage.now()

-- Get all images path and push into first stage's queue
local file = files.getImages(inputDir)
local img
local err
local relative

-- Process all images
for i=1,#file do
	-- Load image
	img,err = imglib.load (inputDir,file[i])

	-- Check errors
	if not (err) then
		-- Apply grayscale	
		imglib.grayscale(img)

		-- Apply first threshold
		imglib.threshold(img,220,300)

		-- Apply blur
		imglib.blur(img,2)

		-- Apply last threshold
		imglib.threshold(img,70,600)

		-- Invert pixels
		imglib.invert(img)

		-- Save image
		relative = outputDir.."/"..file[i]
		err = imglib.save(img,relative,true)

		-- Check errors
		if (err) then
			print("["..file[i].."] "..err)
		end
	else
		print("["..file[i].."] "..err)
	end
end

-- Load process time
local time = lstage.now()-start
print("[secs] "..time)

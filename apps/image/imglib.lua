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

local imglib  = {}
local filters = require 'filters'

-- Apply threshold
imglib.threshold = function(img,threshold,maxValue)
	local filters = require 'filters'
	local imlib2  = require "imlib2_image"

	-- Get image dimensions
	local w = img:get_width()
	local h = img:get_height()

	-- Apply grayscale filter
	local thresholdImg = filters.threshold(img:get_data(),w,h,threshold,maxValue)
        local newImg  = imlib2.image.new(w,h)
	newImg:from_str(thresholdImg)
end

-- Apply blur
imglib.blur = function(img,blurRate)
	-- Apply blur (imlib2)
	img.blur(img,blurRate)
end

-- Apply grayscale
imglib.grayscale = function(img)
	local filters = require 'filters'
	local imlib2  = require "imlib2_image"

	-- Get image dimensions
	local w = img:get_width()
	local h = img:get_height()

	-- Apply grayscale filter
	local grayImg = filters.grayscale(img:get_data(),w,h)
 	local newImg  = imlib2.image.new(w,h)
        newImg:from_str(grayImg)
end

-- Save image into folder
imglib.save = function(img,outpath)
	local _,err = img.save(img,outpath)
	img.free(img)
	return err
end

-- Load jpg image
imglib.load = function(inpath,file) 
	local imlib2=require "imlib2_image"

	local relative=inpath.."/"..file
	local img,err=imlib2.image.load(relative)
	if not (img) then
		return nil,err
	else
		return img,nil
	end
end

-- Invert image colors
imglib.invert = function(img)
	local filters = require 'filters'
	local imlib2  = require "imlib2_image"

	-- Get image dimensions
	local w = img:get_width()
	local h = img:get_height()

	-- Apply grayscale filter
	local invertedImg = filters.invert(img:get_data(),w,h)
 	local newImg  = imlib2.image.new(w,h)
        newImg:from_str(invertedImg)
end

return imglib

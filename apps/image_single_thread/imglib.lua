--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On May 2014
	   
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
	filters.threshold(img:get_data(),w,h,threshold,maxValue)        
end

-- Apply blur (imlib2)
imglib.blur = function(img,blurRate)
	local filters = require 'filters'
	local imlib2  = require "imlib2_image"

	-- Get image dimensions
	local w = img:get_width()
	local h = img:get_height()

	-- Apply grayscale filter
	filters.blur(img:get_data(),w,h,blurRate)
end

-- Apply grayscale
imglib.grayscale = function(img)
	local filters = require 'filters'
	local imlib2  = require "imlib2_image"

	-- Get image dimensions
	local w = img:get_width()
	local h = img:get_height()

	-- Apply grayscale filter
	filters.grayscale(img:get_data(),w,h) 	
end

-- Save image into folder
imglib.save = function(img,outpath,freeImg)
	local _,err = img.save(img,outpath)
	if (freeImg) then
		--img.free(img)
	end
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
	filters.invert(img:get_data(),w,h) 	
end

return imglib

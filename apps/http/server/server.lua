--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	**********************************************************************************************
]]--

-- Imports
local lstage = require 'lstage'
local stages = require 'stages'

-- Configurations
local defaultPort = 8081

-- Creating new threads
lstage.pool:add()
lstage.pool:add()

-- Start server
print("***********************")
print("*** Starting server ***")
print("***********************")

-- Push event to start server
stages.start:push(defaultPort)

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

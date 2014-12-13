--[[
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by Breno Riba		
	On July 2014

	Use httperf to test connections

        ==============================================
	4 connections per second (one minute window)
        50 * 60 = 300
        ==============================================

	httperf --client=0/1 --server=127.0.0.1 --port=8080 --uri=/index.html --send-buffer=4096 --recv-buffer=16384 --num-conns=5000 --num-calls=1 --rate=30

	**********************************************************************************************
]]--

-- Imports
local lstage      = require 'lstage'
local stage       = require 'stages'
local controllers = require 'controllers'

-- Configurations
local defaultPort = 8080

-- Available controllers
-- {SRPT,MG1,SEDA,DYNAMIC,COLOR}
local policy  = "SEDA"

-- Number of threads (per stage in case of SEDA)
local threads = 1

-- Stages table
local stages = {}

stages[1] = stage.start
stages[2] = stage.handle
--stages[3] = stage.runScript
stages[3] = stage.cacheHandler
stages[4] = stage.cacheBuffer
stages[5] = stage.cacheLoadFile
--stages[7] = stage.closeSocket

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
end

-- Push event to start server
stage.start:push(defaultPort)

-- Configure policy
controllers.configure(stages,policy,threads,false)

-- Dispatch on_timer events
lstage.dispatchevents()

-- Avoid script to close
lstage.channel():get()

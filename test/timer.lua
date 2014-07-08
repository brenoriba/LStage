local lstage = require 'lstage'

function add_timer()
	lstage.add_timer(1, 100)
end

on_timer=function(id)
	-- Validate ID number
	if (id ~= 100) then
		return
	end

	print(id)
end

-- Initialize
add_timer()

-- Dispatch on_timer events
lstage.dispatchevents()

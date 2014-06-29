local lstage=require'lstage'

lstage.pool:add()
lstage.pool:add()


local stage3=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)		
	end,1)

local stage2=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name) 
		stage3:push('s3')
	end,1)

local stage1=lstage.stage(
	function(name) 
		local index = 0
		for ix=0, 10000000 do
			index = index + 1
		end
		print(name)
		stage2:push('s2') 
	end,1)

stage1:setpriority(1)
stage2:setpriority(10)

print("[stage1] "..stage1:getpriority())
print("[stage2] "..stage2:getpriority())

for i=1,8 do
   stage1:push('s1')
end

lstage.channel():get() 

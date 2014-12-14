local count = 0
for i=0, 2000, 1 do
	for j=10000, 0, -1 do
		count = count + i - j
	end
end
return tostring(count)

local io=require "iolua"

local async=async or false

local file_mt,err=lstage.getmetatable("FILE*")
if file_mt then
   file_mt.__wrap=function(file)
      local filefd=lstage.io.wrap(file)
      return function()
	      require 'lstage.utils.io'
         return lstage.io.unwrap(filefd)
      end
   end
   file_mt.__persist=function(file)
      error('Unable to send file "'..tostring(file)..'" to other processes')
   end
   if async then
   	if type(lstage.aio.do_file_aio)=='function' then
		  	file_mt.__index.aread=function(file,size)
		  		assert(lstage.getmetatable(file)==file_mt);
		  		return lstage.aio.do_file_aio(file,1,size)
		  	end
		  	file_mt.__index.awrite=function(file,buf)
		  		assert(lstage.getmetatable(file)==file_mt);
		  		return lstage.aio.do_file_aio(file,2,buf)
		  	end
		else
		  	file_mt.__index.aread=function(...) return nil,"AIO not available" end
   	end
   else
   	file_mt.__index.aread=file_mt.__index.read
   	file_mt.__index.awrite=file_mt.__index.write
   end
end

return io

local treatments = require 'treatments'
local M=require("imlib2")
local meta=treatments.getmetatable('imlib2.image')
if meta then
   meta.__wrap = function (img)
      local ptr=img:to_ptr()
      return function ()
         require "imlib2_image"
         return imlib2.image.from_ptr(ptr)
      end
   end
   meta.__persist = function (img)
      local str=img:to_str()
      local w,h=img:get_width(),img:get_height()
      return function ()
         require "imlib2_image"
         local im=imlib2.image.new(w,h)
         im:from_str(str)
         return im
      end
   end
end
return M

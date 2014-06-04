/*
	**************************************** PUC-RIO 2014 ****************************************

	Implemented by: 
		- Ana Lúcia de Moura
		- Breno Riba
		- Noemi Rodriguez   
		- Tiago Salmito
		
	Implemented on May 2014
	   
	**********************************************************************************************

	Compile:	
	gcc -Wall -shared -fPIC -o filters.so  -I/usr/include/opencv -I/usr/include/lua5.1 -lopencv_core -lopencv_highgui -lopencv_objdetect -llua5.1   filters.c

	Reference: http://www.troubleshooters.com/codecorn/lua/lua_lua_calls_c.htm
*/

#include <string.h>

// Open cv includes
#include "cv.h"
#include "highgui.h"

extern "C" {

#include "lua.h"
#include "lauxlib.h"

// Get metatable by name
int image_getmetatable(lua_State *L) {
   if(lua_type(L,1)==LUA_TSTRING) {
      const char *tname=lua_tostring(L,1);
      luaL_getmetatable(L,tname);
   } else {
      if(!lua_getmetatable (L,1)) {
         lua_pushnil(L);
         lua_pushliteral(L,"Metatable not found for the provided value");
         return 2;
      }
   }
   return 1;
}

// Grayscale filter
static int treatments_grayscale (lua_State * L) {
printf("here\n");
	// Check pointer	
	if(lua_type(L,1)!=LUA_TLIGHTUSERDATA) {
   	lua_pushboolean(L,0);
		lua_pushliteral(L,"Arg is not a pointer");
		return 2;
	}
printf("here2\n");
	void *ptr;
	ptr=lua_touserdata(L,1);
	
	int w,h;
	w=lua_tointeger(L,2);
	h=lua_tointeger(L,3);
printf("here3\n");
	// Get image
        cv::Mat * img=new cv::Mat(w,h,CV_8UC4,ptr);

	IplImage * dst_img= cvCreateImage(cvSize(w,h), IPL_DEPTH_8U, 4);
        dst_img->imageData = (char *) img->data;      

	//cvErode(dst_img,dst_img,0,2);
	//cvNot(dst_img,dst_img);
	cvtColor(dst_img,dst_img, CV_RGB2GRAY );

	lua_pushlstring(L,(char *)img->data,w*h*4);

	return 1;
}

// Functions to register
static const luaL_Reg RegisterFunctions[] =
{
    {"grayscale", treatments_grayscale},
    {"getmetatable", image_getmetatable},
    { NULL, NULL }
};

// Main method
int luaopen_filters (lua_State *L) {
    lua_newtable(L);

    #if LUA_VERSION_NUM < 502
        luaL_register(L, NULL, RegisterFunctions);
    #else
        luaL_setfuncs(L, RegisterFunctions, 0);
    #endif

    return 1;
}
}

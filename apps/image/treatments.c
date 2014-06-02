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
	gcc -Wall -shared -fPIC -o treatments.so  -I/usr/include/lua5.1 -llua5.1   treatments.c

	Reference: http://www.troubleshooters.com/codecorn/lua/lua_lua_calls_c.htm
*/

#include <string.h>
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
	void *ptr;
	//ptr=lua_touserdata(L,1);
	if(ptr) {
		lua_pushnumber(L,10);
		return 1;   
	}
	else {
		lua_pushnumber(L,1);
		return 1;   
	}
}

// Functions to register
static const luaL_Reg RegisterFunctions[] =
{
    {"grayscale", treatments_grayscale},
    {"getmetatable", image_getmetatable},
    { NULL, NULL }
};

// Main method
int luaopen_treatments (lua_State *L) {
    lua_newtable(L);

    #if LUA_VERSION_NUM < 502
        luaL_register(L, NULL, RegisterFunctions);
    #else
        luaL_setfuncs(L, RegisterFunctions, 0);
    #endif

    return 1;
}

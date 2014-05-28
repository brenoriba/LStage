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

// Load image
static int treatments_load_image (lua_State * L) {
	lua_pushnumber(L,10);
	return 1;   
}

static const luaL_Reg RegisterFunctions[] =
{
    { "load", treatments_load_image },
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

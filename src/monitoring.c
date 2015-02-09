#include "instance.h"
#include "marshal.h"
#include "scheduler.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

/*
 *********************************************************************************
 [MONITORING] INTERFACE MODEL
 *********************************************************************************
*/

// Add a timer callback
static int monitoring_addtimer(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get CPU's count
static int monitoring_getCpusCount(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get CPU's usage
static int monitoring_getCpuUsage(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get queue size
static int monitoring_getQueueSize(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get processed events count
static int monitoring_getProcessedCount(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get input events count
static int monitoring_getInputCount(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Reset stage statistics
static int monitoring_resetStatistics(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Fire function when last stage is focused
static int monitoring_fireLastFocused(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Do not fire function when stage is focused
static int monitoring_doNotfireLastFocused(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

static const struct luaL_Reg LuaExportFunctions[] = {
		// Interface
		{"addTimer",monitoring_addtimer},
		{"getCpusCount",monitoring_getCpusCount},
		{"getCpuUsage",monitoring_getCpuUsage},
		{"getQueueSize",monitoring_getQueueSize},
		{"getProcessedCount",monitoring_getProcessedCount},
		{"getInputCount",monitoring_getInputCount},
		{"resetStatistics",monitoring_resetStatistics},
		{"fireLastFocused",monitoring_fireLastFocused},
		{"doNotfireLastFocused",monitoring_doNotfireLastFocused},
		{NULL,NULL}
};

LSTAGE_EXPORTAPI int luaopen_lstage_monitoring(lua_State *L) {
	lua_newtable(L);
	lua_newtable(L);
	luaL_loadstring(L,"return function() return require'lstage.monitoring' end");
	lua_setfield (L, -2,"__persist");
	lua_setmetatable(L,-2);
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, LuaExportFunctions);
#else
	luaL_setfuncs(L, LuaExportFunctions, 0);
#endif        
	return 1;
};

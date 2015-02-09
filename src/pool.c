#include <stdlib.h>
#include "stage.h"
#include "pool.h"
#include "scheduler.h"

#define DEFAULT_QUEUE_CAPACITY -1

static void get_metatable(lua_State * L);

pool_t lstage_topool(lua_State *L, int i) {
	pool_t * p = luaL_checkudata (L, i, LSTAGE_POOL_METATABLE);
	luaL_argcheck (L, p != NULL, i, "Pool expected");
	return *p;
}

void lstage_buildpool(lua_State * L,pool_t t) {
	pool_t *s=lua_newuserdata(L,sizeof(pool_t *));
	*s=t;
	get_metatable(L);
   lua_setmetatable(L,-2);
}

static int pool_tostring (lua_State *L) {
  pool_t * s = luaL_checkudata (L, 1, LSTAGE_POOL_METATABLE);
  lua_pushfstring (L, "Pool (%p)", *s);
  return 1;
}

static int pool_ptr(lua_State * L) {
	pool_t * s = luaL_checkudata (L, 1, LSTAGE_POOL_METATABLE);
	lua_pushlightuserdata(L,*s);
	return 1;
}

static int pool_addthread(lua_State * L) {
	pool_t s=lstage_topool(L, 1);
	int size=luaL_optint(L, 2, 1);
	int i;
	for(i=0;i<size;i++) {
		lstage_newthread(L,s);
		_DEBUG("pool_addthread pool:%p\n",s);
	}
	s->size+=size;
	return size;
}

static int pool_size(lua_State * L) {
	pool_t pool = lstage_topool(L, 1);
	lua_pushinteger(L,pool->size);
	return 1;
}

static int pool_killthread(lua_State * L) {
	pool_t pool=lstage_topool(L, 1);
	lstage_pqueue_push(pool->ready,NULL);
	return 0;
}


static int pool_eq(lua_State * L) {
	pool_t p1=lstage_topool(L, 1);
	pool_t p2=lstage_topool(L, 2);
	lua_pushboolean(L,p1==p2);
	return 1;
}


static void get_metatable(lua_State * L) {
	luaL_getmetatable(L,LSTAGE_POOL_METATABLE);
   if(lua_isnil(L,-1)) {
   	lua_pop(L,1);
  		luaL_newmetatable(L,LSTAGE_POOL_METATABLE);
  		lua_pushvalue(L,-1);
  		lua_setfield(L,-2,"__index");
		lua_pushcfunction (L, pool_tostring);
		lua_setfield (L, -2,"__tostring");
		luaL_loadstring(L,"local ptr=(...):ptr() return function() return require'lstage.pool'.get(ptr) end");
		lua_setfield (L, -2,"__wrap");
		lua_pushcfunction (L, pool_eq);
		lua_setfield (L, -2,"__eq");
		lua_pushcfunction(L,pool_ptr);
  		lua_setfield(L,-2,"ptr");
		lua_pushcfunction(L,pool_size);
  		lua_setfield(L,-2,"size");
  		lua_pushcfunction(L,pool_addthread);
  		lua_setfield(L,-2,"add");
 		lua_pushcfunction(L,pool_killthread);
  		lua_setfield(L,-2,"kill");
  	}
}

static int pool_get(lua_State * L) {
	pool_t p=lua_touserdata(L,1);
	if(p) {
		_DEBUG("pool_get %p\n",p);
		lstage_buildpool(L,p);
		return 1;
	}
	lua_pushnil(L);
	lua_pushliteral(L,"Pool is null");
	return 2;
}

/*
 *********************************************************************************
 [POOL] INTERFACE MODEL
 *********************************************************************************
*/

// Create a new pool
static int pool_new(lua_State *L) {
	int size=lua_tointeger(L,1);

	_DEBUG("pool_new %d\n",size);
	if(size<0) {
		luaL_error(L,"Initial pool size must be greater than zero");
	}

	pool_t p=malloc(sizeof(struct pool_s));
	p->size=0;	
	p->lock=0;

	p->ready=lstage_pqueue_new();
	p->stealing_queue=lstage_lfqueue_new();

	lstage_buildpool(L,p);
	return 1;
}

// Set a new pool to a stage
static int pool_setPool(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Add more threads
static int pool_addThreads(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Kill threads
static int pool_killThreads(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get stage's pool
static int pool_getPool(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

// Get threads count
static int pool_getThreadsCount(lua_State * L) {
	lua_pushinteger(L,400);
	return 1;
}

static const struct luaL_Reg LuaExportFunctions[] = {
		{"get",pool_get},

		// Interface model
		{"new",pool_new},
		{"setPool",pool_setPool},
		{"addThreads",pool_addThreads},
		{"killThreads",pool_killThreads},
		{"getPool",pool_getPool},
		{"getThreadsCount",pool_getThreadsCount},
		{NULL,NULL}
};

LSTAGE_EXPORTAPI int luaopen_lstage_pool(lua_State *L) {
	get_metatable(L);
	lua_pop(L,1);
	lua_newtable(L);
	lua_newtable(L);
	luaL_loadstring(L,"return function() return require'lstage.pool' end");
	lua_setfield (L, -2,"__persist");
	lua_setmetatable(L,-2);
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, LuaExportFunctions);
#else
	luaL_setfuncs(L, LuaExportFunctions, 0);
#endif        
	return 1;
};

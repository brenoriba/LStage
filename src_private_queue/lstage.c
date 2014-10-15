#include <unistd.h> 
#include <errno.h>
#include <string.h>  
#include <event2/event.h>
#include <event2/thread.h>
#include <unistd.h>
#include <time.h>

// To measure CPU usage
#include <stdint.h>
#include <sys/time.h>
#include <sys/resource.h>

#include "lstage.h"
#include "marshal.h"
#include "stage.h"
#include "pool.h"
#include "threading.h"

struct event_base *lstage_event_base=NULL;

/*
 * Event system callbacks
 */
static lua_State * L_main;

// Used to measure CPU usage
static struct timeval wall_start;
static clock_t cpu_start;
static int cpus_count;

#ifdef DEBUG
//can be found here  http://www.lua.org/pil/24.2.3.html
void stackDump (lua_State *L, const char *text) {
      int i;
      int top = lua_gettop(L);
	  if (text == NULL)
		printf("--------Start Dump------------\n");
	  else
	    printf("--------Start %s------------\n", text);
      for (i = 1; i <= top; i++) {  /* repeat for each level */
        int t = lua_type(L, i);
        switch (t) {
    
          case LUA_TSTRING:  /* strings */
            printf("`%s'", lua_tostring(L, i));
            break;
    
          case LUA_TBOOLEAN:  /* booleans */
            printf(lua_toboolean(L, i) ? "true" : "false");
            break;
    
          case LUA_TNUMBER:  /* numbers */
            printf("%g", lua_tonumber(L, i));
            break;
    
          default:  /* other values */
            printf("%s", lua_typename(L, t));
            break;
    
        }
        printf("  ");  /* put a separator */
      }
      printf("\n");  /* end the listing */
	  printf("--------End Dump------------\n");
    }

void tableDump(lua_State *L, int idx, const char* text)
{
	lua_pushvalue(L, idx);		// copy target table
	lua_pushnil(L);
	  if (text == NULL)
		printf("--------Table Dump------------\n");
	  else
	    printf("--------Table dump: %s------------\n", text);
	while (lua_next(L,-2) != 0) {
		printf("%s - %s\n",
			lua_typename(L, lua_type(L, -2)),
			lua_typename(L, lua_type(L, -1)));
		lua_pop(L, 1);
	}
	lua_pop(L, 1);	// remove table copy
    printf("--------End Table dump------------\n");
}
#endif

// Get LSTAGE version
static int lstage_version(lua_State * L) {
	lua_pushliteral(L,LSTAGE_VERSION);
	return 1;
}

// Get current system time
static int lstage_gettime(lua_State * L) {
   lua_pushnumber(L,now_secs());
   return 1;
}

static int lstage_getself(lua_State *L) {
	lua_pushliteral(L,LSTAGE_INSTANCE_KEY);
	lua_gettable(L, LUA_REGISTRYINDEX);	
	if(!lua_isnil(L,-1)) {
		instance_t i=lua_touserdata(L,-1);
		lua_pop(L,1);
		lstage_buildstage(L,i->stage);
	}
	return 1;
}

static int get_cpus() {
   #ifdef _WIN32
      #ifndef _SC_NPROCESSORS_ONLN
         SYSTEM_INFO info;
         GetSystemInfo(&info);
         #define sysconf(a) info.dwNumberOfProcessors
         #define _SC_NPROCESSORS_ONLN
      #endif
   #endif
   #ifdef _SC_NPROCESSORS_ONLN
	   long nprocs = -1;
      nprocs = sysconf(_SC_NPROCESSORS_ONLN);
      if (nprocs >= 1) 
      	return nprocs;
   #endif
   return 0;
}

// Callback call - "on_timer" function
static void lstage_timer_event (evutil_socket_t fd, short events, void *arg) {
	lua_getglobal(L_main, "on_timer");

	if(lua_type(L_main,-1)==LUA_TFUNCTION) {
      		lua_pushinteger(L_main,((long int)arg));
      		lua_call(L_main,1,0);
   	} else {	
		printf("Lost on_timer callback\n");
      		lua_pop(L_main,1);
	}
 }

// Insert timer event
static int add_timer(lua_State * L) {
	// Creating new event
	if (lstage_event_base == NULL)
		lstage_event_base = event_base_new();

	// Failed to create
	if (!lstage_event_base) {
		printf("Error while creating new event base");
	   	return 0;
	}

	if (L_main == NULL)
		L_main = L;

   	double t = lua_tonumber(L,1);
   	int n = lua_tointeger(L,2);

	// Configuring "on_timer" event
   	struct event *listener_event = event_new(lstage_event_base, -1, EV_READ|EV_PERSIST, lstage_timer_event, (void *)(long int)n);

   	struct timeval to={t,(t-((int) t))*1000000L};
   	event_add(listener_event, &to);
   	return 0;
}

// Dispatch on_timer events
static int dispatch_events(lua_State * L) {
	if (lstage_event_base != NULL)
		event_base_dispatch(lstage_event_base);
	return 0;
}

static int lstage_setmetatable(lua_State *L) {
   lua_pushvalue(L,2);
   lua_setmetatable(L,1);
   lua_pushvalue(L,1);
   return 1;
}

int lstage_getmetatable(lua_State *L) {
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

static int lstage_cpus(lua_State *L) {
   lua_pushnumber(L,get_cpus());
   return 1;
}

// Get CPU usage in percentage
static int lstage_cpu_usage(lua_State *L) {
	struct timeval wall_now;
	gettimeofday(&wall_now, NULL);

	// Wall time
	double start = wall_start.tv_sec + wall_start.tv_usec / 1000000;
	double stop = wall_now.tv_sec + wall_now.tv_usec / 1000000;
	double wall_time = stop - start;

	// CPU time
	double cpu_time = ((double) (clock() - cpu_start)) / cpus_count / CLOCKS_PER_SEC;
	double percentage = cpu_time / wall_time;

	lua_pushnumber(L,percentage * 100);
	return 1;
}

static void lstage_require(lua_State *L, const char *lib, lua_CFunction func) {
#if LUA_VERSION_NUM < 502 
	lua_getglobal(L,"require");
	lua_pushstring(L, lib);
	lua_call(L,1,1);
#else
 	luaL_requiref(L, lib, func, 0); 
#endif
}

LSTAGE_EXPORTAPI int luaopen_lstage_event(lua_State *L);
LSTAGE_EXPORTAPI int luaopen_lstage_scheduler(lua_State *L);
LSTAGE_EXPORTAPI int luaopen_lstage_stage(lua_State *L);
LSTAGE_EXPORTAPI int luaopen_lstage_pool(lua_State *L);
LSTAGE_EXPORTAPI int luaopen_lstage_channel(lua_State *L);

static const struct luaL_Reg LuaExportFunctions[] = {
	{"_VERSION",lstage_version},
	{"now",lstage_gettime},
	{"cpus",lstage_cpus},
	{"cpu_usage",lstage_cpu_usage},
	{"getmetatable",lstage_getmetatable},
	{"setmetatable",lstage_setmetatable},
	{"self",lstage_getself},
	{"add_timer", add_timer},
	{"dispatchevents", dispatch_events},
	{NULL,NULL}
	};

pool_t lstage_defaultpool=NULL;

LSTAGE_EXPORTAPI int luaopen_lstage(lua_State *L) {
        // To measure CPU usage
	gettimeofday(&wall_start, NULL);
	cpu_start = clock();
	cpus_count = get_cpus();

	lua_newtable(L);
	lstage_require(L,"lstage.pool",luaopen_lstage_pool);	
	lua_getfield(L,-1,"new");
	if(!lstage_defaultpool) {
		lua_pushvalue(L,-1);
		lua_call(L,0,1);
		lstage_defaultpool=lstage_topool(L,-1);
		lua_getfield(L,-1,"add");
		lua_pushvalue(L,-2);
		lua_call(L,1,0);
	} else {
		lstage_buildpool(L,lstage_defaultpool);
	}
	lua_setfield(L,-4,"pool");
	//lua_setfield(L,-3,"pool");
	lua_pop(L,2);
	lstage_require(L,"lstage.event",luaopen_lstage_event);
	lua_getfield(L,-1,"encode");
	lua_setfield(L,-3,"encode");
	lua_getfield(L,-1,"decode");
	lua_setfield(L,-3,"decode");
	lua_setfield(L,-2,"event");
	lstage_require(L,"lstage.scheduler",luaopen_lstage_scheduler);
	lua_setfield(L,-2,"scheduler");
	lstage_require(L,"lstage.channel",luaopen_lstage_channel);
	lua_getfield(L,-1,"new");
	lua_setfield(L,-3,"channel");
	lua_pop(L,1);
	lstage_require(L,"lstage.stage",luaopen_lstage_stage);
	lua_getfield(L,-1,"new");
	lua_setfield(L,-3,"stage");
	lua_pop(L,1);
	lua_newtable(L);
	luaL_loadstring(L,"return function() return require'lstage' end");
	lua_setfield (L, -2,"__persist");
	lua_setmetatable(L,-2);
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, LuaExportFunctions);
#else
	luaL_setfuncs(L, LuaExportFunctions, 0);
#endif
	return 1;
};



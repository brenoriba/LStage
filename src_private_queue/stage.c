#include "stage.h"
#include "marshal.h"
#include "event.h"
#include "scheduler.h"
#include "instance.h"

#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#define DEFAULT_I_IDLE_CAPACITY 10
#define DEFAULT_QUEUE_CAPACITY -1

static void get_metatable(lua_State * L);
extern pool_t lstage_defaultpool;
static pthread_mutex_t lock;

// Used to build polling table
stage_t firstStage = NULL;
stage_t priorStage = NULL;
stage_t currentStage = NULL;
int stagesCount = 0;

stage_t lstage_tostage(lua_State *L, int i) {
	stage_t * s = luaL_checkudata (L, i, LSTAGE_STAGE_METATABLE);
	luaL_argcheck (L, s != NULL, i, "Stage expected");
	return *s;
}

// Return event queue capacity
static int get_queue_capacity(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	lua_pushnumber(L,lstage_lfqueue_getcapacity(s->event_queue));
	return 1;
}

// Set queue capacity
static int set_queue_capacity(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	luaL_checktype (L, 2, LUA_TNUMBER);
	int capacity=lua_tointeger(L,2);
	lstage_lfqueue_setcapacity(s->event_queue,capacity);
	return 0;
}

// Max number of instances to run in parallel
static int get_max_instances(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	lua_pushnumber(L,lstage_lfqueue_getcapacity(s->instances));
	return 1;
}

static int stage_getenv(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	if(s->env==NULL)
		lua_pushnil(L);
	else
		lua_pushlstring(L,s->env,s->env_len);
	return 1;
}

static int stage_eq(lua_State * L) {
	stage_t s1=lstage_tostage(L,1);
	stage_t s2=lstage_tostage(L,2);
	lua_pushboolean(L,s1==s2);
	return 1;
}

static int stage_instantiate(lua_State * L);

static int stage_wrap(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	if(s->env!=NULL) luaL_error(L,"Enviroment of stage is already set");

	luaL_checktype (L, 2, LUA_TFUNCTION);	
	lua_pushcfunction(L,mar_encode);
   lua_pushvalue(L,2);
   lua_call(L,1,1);
	
	const char *env=NULL;
	size_t len=0; 
	env=lua_tolstring(L,-1,&len);
   char *envcp=malloc(len+1);
   envcp[len]='\0';
   memcpy(envcp,env,len+1);
   s->env=envcp;
   s->env_len=len;
   lua_pop(L,1);
   
   lua_pushcfunction(L,stage_instantiate);
   lua_pushvalue(L,1);
   lua_pushnumber(L,1);
   lua_call(L,2,0);
   
   lua_pushvalue(L,1);
	return 1;
}

// Insert a new event into event queue
static int stage_push(lua_State *L) {
   stage_t s=lstage_tostage(L,1);

   // Check if the stage is enabled to receive new events
   int enabled = s->enabled;
   if (enabled == 0) {
      lua_pushnil(L);
      lua_pushliteral(L,"Stage is disabled");
      return 2;
   }

   int top=lua_gettop(L);
   lua_pushcfunction(L,mar_encode);
   lua_newtable(L);
   int i;
   for(i=2;i<=top;i++) {
      lua_pushvalue(L,i);
      lua_rawseti(L,-2,i-1);
   }

   lua_call(L,1,1);
   size_t len;
   const char * str=lua_tolstring(L,-1,&len);
   lua_pop(L,1);
   event_t ev=lstage_newevent(str,len);   
   instance_t ins=NULL;

   // Check if we have instances to execute event
   if (lstage_lfqueue_try_pop (s->instances,&ins)) {
   	ins->ev=ev;
	ins->flags=I_READY;

	lstage_pushinstance(ins);

	lua_pushvalue(L,1);
	return 1;
   
   // If not, put the event in event queue
   } else if (lstage_lfqueue_try_push(s->event_queue,&ev)) {
      lua_pushvalue(L,1);
      return 1;
   }

   // Ignore event - queue is full
   lstage_destroyevent(ev);
   lua_pushnil(L);
   lua_pushliteral(L,"Event queue is full");
   return 2;
}

// Enable or disable a stage (used in functions "stage_enable" and "stage_disable")
static int stage_stage_status(lua_State *L, int enable) {
	stage_t s = lstage_tostage(L, 1);
	s->enabled=enable;
	lua_pushvalue(L,1);
	return 1;
}

// Enable a stage to receive new events
static int stage_enable(lua_State *L) {
	return stage_stage_status(L, 1);
}

// Disable stage - won't receive new events
static int stage_disable(lua_State *L) {
	return stage_stage_status(L, 0);
}

// Check stage status
static int stage_active(lua_State *L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushinteger(L,s->enabled);
	return 1;
}

/*tostring method*/
static int stage_tostring (lua_State *L) {
  stage_t * s = luaL_checkudata (L, 1, LSTAGE_STAGE_METATABLE);
  lua_pushfstring (L, "Stage (%p)", *s);
  return 1;
}

// Get stage unique ID
static int stage_getid (lua_State *L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushlstring(L,(const char *)&s,sizeof(void*));
	return 1;
}

// Number of events on the events queue at the moment
static int stage_queue_size (lua_State *L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushnumber(L,lstage_lfqueue_size(s->event_queue));
	return 1;
}

// Number of instances on the instance queue at the moment
static int stage_instance_size (lua_State *L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushnumber(L,lstage_lfqueue_size(s->instances));
	return 1;
}

static int stage_destroyinstances(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	int n=lua_tointeger(L,2);
	int i;
	instance_t in;
	if(n<=0) luaL_error(L,"Argument must be grater than zero");

	// Lock process
	pthread_mutex_lock(&lock);
	if(lstage_lfqueue_getcapacity(s->instances)<0) {
		int cur=0;
			while(!lstage_lfqueue_try_pop(s->instances,&in)) {
				lstage_destroyinstance(in); //should not longjmp
				cur++;
			}
			lua_pushinteger(L,cur);
			return 1;
	}
	else if(lstage_lfqueue_getcapacity(s->instances)==0)
		luaL_error(L,"Cannot destroy this number of instances");
	for(i=0;i<n;i++) {
		if(!lstage_lfqueue_try_pop(s->instances,&in)) break;
		lstage_destroyinstance(in); //should not longjmp
	}
	if(lstage_lfqueue_getcapacity(s->instances)>0) 
		lstage_lfqueue_setcapacity(s->instances,lstage_lfqueue_getcapacity(s->instances)-i);

	pthread_mutex_unlock(&lock);
	lua_pushnumber(L,i);
	return 1;
}

// Create list of instances for each stage
static int stage_instantiate(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	if(s->pool==NULL) luaL_error(L,"Stage must be associated to a pool");
	if(s->env==NULL) luaL_error(L,"Stage must have an environment");
	int n=lua_tointeger(L,2);
	int i;
	if(n<=0) luaL_error(L,"Argument must be grater than zero");

	// Lock until create a new instance (use pthread)
	pthread_mutex_lock(&lock);
	if(lstage_lfqueue_getcapacity(s->instances)>=0) {
		lstage_lfqueue_setcapacity(s->instances,lstage_lfqueue_getcapacity(s->instances)+n);
        }
	pthread_mutex_unlock(&lock);

	// Creating new instances
	for(i=0;i<n;i++) {
		(void)lstage_newinstance(s);
	}

	/*unlock mutex */
	lua_pushvalue(L,1);
	return 1;
}

static int stage_ptr(lua_State * L) {
	stage_t * s = luaL_checkudata (L, 1, LSTAGE_STAGE_METATABLE);
	lua_pushlightuserdata(L,*s);
	return 1;
}

void lstage_buildstage(lua_State * L,stage_t t) {
	stage_t *s=lua_newuserdata(L,sizeof(stage_t *));
	*s=t;
	get_metatable(L);
   lua_setmetatable(L,-2);
}

// Get stage thread pool
static int stage_getpool(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	if(s->pool)
		lstage_buildpool(L,s->pool);
	else
		lua_pushnil(L);
	return 1;
}

// Set a new pool to the stage
static int stage_setpool(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	pool_t p=lstage_topool(L, 2);
	s->pool=p;
	return 0;
}

// Get stage throughput
static int stage_throughput (lua_State * L) {
	stage_t s           = lstage_tostage(L, 1);
	int     elapsedTime = now_secs() - s->init_time;
	int     avg 	    = 0;

	if (elapsedTime > 0) {
		avg = (s->processed / elapsedTime);
	}

	lua_pushinteger(L,avg);
	return 1;
}

// Set stage priority
static int stage_setpriority(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	int p=lua_tointeger(L,2);
	s->priority=p;
	lua_pushvalue(L,1);

	// Reorganize linked list
	

	return 1;
}

// Get stage priority
static int stage_getpriority(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushinteger(L,s->priority);
	return 1;
}

static int stage_getparent(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	if(s->parent)
		lstage_buildstage(L,s->parent);
	else
		lua_pushnil(L);
	return 1;
}

static const struct luaL_Reg StageMetaFunctions[] = {
		{"__eq",stage_eq},
		{"__tostring",stage_tostring},
		{"__call",stage_push},
		{"instances",get_max_instances},
		{"capacity",get_queue_capacity},
		{"setcapacity",set_queue_capacity},
		{"id",stage_getid},
		{"getenv",stage_getenv},
		{"wrap",stage_wrap},
		{"push",stage_push},
		{"size",stage_queue_size},
		{"instancesize",stage_instance_size},
		{"instantiate",stage_instantiate},
		{"free",stage_destroyinstances},
		{"ptr",stage_ptr},
		{"parent",stage_getparent},
		{"pool",stage_getpool},
		{"setpool",stage_setpool},
		{"getpriority",stage_getpriority},
		{"setpriority",stage_setpriority},
		{"disable",stage_disable},
		{"enable",stage_enable},
		{"active",stage_active},
		{"throughput",stage_throughput},
		{NULL,NULL}
};

static void get_metatable(lua_State * L) {
	luaL_getmetatable(L,LSTAGE_STAGE_METATABLE);
   if(lua_isnil(L,-1)) {
   	lua_pop(L,1);
  		luaL_newmetatable(L,LSTAGE_STAGE_METATABLE);
		LUA_REGISTER(L, StageMetaFunctions);
  		lua_pushvalue(L,-1);
  		lua_setfield(L,-2,"__index");
		luaL_loadstring(L,"local ptr=(...):ptr() return function() return require'lstage.stage'.get(ptr) end");
		lua_setfield (L, -2,"__wrap");
  	}
}


static int stage_isstage(lua_State * L) {
	lua_getmetatable(L,1);
	get_metatable(L);
	int has=0;
   #if LUA_VERSION_NUM > 501
	if(lua_compare(L,-1,-2,LUA_OPEQ)) has=1;
	#else
	if(lua_equal(L,-1,-2)) has=1;
	#endif
	lua_pop(L,2);
   lua_pushboolean(L,has);
	return 1;
}

// Add stage into polling table
static void stage_addintopollingtable (stage_t s) {
	stagesCount++;

	// First stage
	if (firstStage == NULL)
	{
		firstStage = s;
		priorStage = NULL;
		currentStage = s;
		return;
	}
	
	// Set prior and next stage
	currentStage->prior=priorStage;
	currentStage->next=s;

	// Update cursor
	priorStage = currentStage;
	currentStage = s;
}

// Creates new stage
static int lstage_newstage(lua_State * L) {
	int idle=0;
	stage_t * stage=NULL;

 	if(!lua_gettop(L)) {
 	   stage=lua_newuserdata(L,sizeof(stage_t *));
	   (*stage)=malloc(sizeof(struct lstage_Stage));   
	   (*stage)->instances=lstage_lfqueue_new();
	   lstage_lfqueue_setcapacity((*stage)->instances,0);
	   (*stage)->event_queue=lstage_lfqueue_new();
	   lstage_lfqueue_setcapacity((*stage)->event_queue,DEFAULT_QUEUE_CAPACITY);

	   // Events combined with instances - ready to be processed
	   (*stage)->ready_queue=lstage_pqueue_new();

	   (*stage)->env=NULL;
	   (*stage)->env_len=0;

	} else {
	   luaL_checktype (L, 1, LUA_TFUNCTION);
      	   idle=luaL_optint(L, 2, 1);
   	   int capacity=luaL_optint(L, 3, DEFAULT_QUEUE_CAPACITY);
   	   lua_pushcfunction(L,mar_encode);
   	   lua_pushvalue(L,1);
   	   lua_call(L,1,1);   
   	   const char *env=NULL;
	   size_t len=0; 
	   env=lua_tolstring(L,-1,&len);
	   lua_pop(L,1);
	   stage=lua_newuserdata(L,sizeof(stage_t *));
	   (*stage)=calloc(1,sizeof(struct lstage_Stage));   
	   (*stage)->instances=lstage_lfqueue_new();
	   lstage_lfqueue_setcapacity((*stage)->instances,0);

	   (*stage)->event_queue=lstage_lfqueue_new();
	   lstage_lfqueue_setcapacity((*stage)->event_queue,capacity);

	   (*stage)->ready_queue=lstage_pqueue_new();

	   char *envcp=malloc(len+1);
	   envcp[len]='\0';
	   memcpy(envcp,env,len+1);
	   (*stage)->env=envcp;
	   (*stage)->env_len=len;
	}

	(*stage)->init_time=now_secs();
	(*stage)->processed=0;
	(*stage)->pool=lstage_defaultpool;
	(*stage)->priority=0;
	(*stage)->enabled=1;

  	get_metatable(L);

   lua_setmetatable(L,-2);
   if(idle>0) {
	   lua_pushcfunction(L,stage_instantiate);
	   lua_pushvalue(L,-2);
	   lua_pushnumber(L,idle);
	   lua_call(L,2,0);
   } 
   (*stage)->parent=NULL;
   lua_pushliteral(L,LSTAGE_INSTANCE_KEY);
   lua_gettable(L, LUA_REGISTRYINDEX);	
	if(lua_type(L,-1)==LUA_TLIGHTUSERDATA) {
		instance_t i=lua_touserdata(L,-1);
	   (*stage)->parent=i->stage;
	}
	lua_pop(L,1);

   (*stage)->next=NULL;
   (*stage)->prior=NULL;

   // Add stage into polling table
   stage_addintopollingtable((*stage));
   return 1;
}

static int lstage_destroystage(lua_State * L) {
	stage_t * s_ptr = luaL_checkudata (L, 1, LSTAGE_STAGE_METATABLE);
	if(!s_ptr) return 0;
	if(!(*s_ptr)) return 0;
	stage_t s=*s_ptr;
	if(s->env!=NULL)
		free(s->env);
	instance_t i=NULL;
	while(lstage_lfqueue_try_pop(s->instances,&i)) 
		lstage_destroyinstance(i);
	lstage_lfqueue_free(s->instances);
	event_t e;
	while(lstage_lfqueue_try_pop(s->event_queue,&e)) 
		lstage_destroyevent(e);
	lstage_lfqueue_free(s->event_queue);

	*s_ptr=0;
	return 0;
}

static int lstage_getstage(lua_State * L) {
	stage_t s=lua_touserdata(L,1);
	if(s) {
		lstage_buildstage(L,s);
		return 1;
	}
	lua_pushnil(L);
	lua_pushliteral(L,"Stage not found");
	return 2;
}

static const struct luaL_Reg LuaExportFunctions[] = {
		{"new",lstage_newstage},
		{"get",lstage_getstage},
		{"destroy",lstage_destroystage},
		{"is_stage",stage_isstage},
		{NULL,NULL}
};

LSTAGE_EXPORTAPI	int luaopen_lstage_stage(lua_State *L) {
	lua_newtable(L);
	lua_newtable(L);
	luaL_loadstring(L,"return function() return require'lstage.stage' end");
	lua_setfield (L, -2,"__persist");
	lua_setmetatable(L,-2);
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, LuaExportFunctions);
#else
	luaL_setfuncs(L, LuaExportFunctions, 0);
#endif        
	return 1;
};
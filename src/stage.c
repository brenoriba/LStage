#include "stage.h"
#include "marshal.h"
#include "event.h"
#include "scheduler.h"
#include "instance.h"

#include <stdlib.h>
#include <string.h>

#define DEFAULT_I_IDLE_CAPACITY 10
#define DEFAULT_QUEUE_CAPACITY -1

static void get_metatable(lua_State * L);
extern pool_t lstage_defaultpool;

stage_t lstage_tostage(lua_State *L, int i) {
	stage_t * s = luaL_checkudata (L, i, LSTAGE_STAGE_METATABLE);
	luaL_argcheck (L, s != NULL, i, "Stage expected");
	return *s;
}

// Retorna a capacidade máxima da fila de evento
static int get_queue_capacity(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	lua_pushnumber(L,lstage_lfqueue_getcapacity(s->event_queue));
	return 1;
}

// Configura capacidade da fila de evento
static int set_queue_capacity(lua_State * L) {
	stage_t s=lstage_tostage(L,1);
	luaL_checktype (L, 2, LUA_TNUMBER);
	int capacity=lua_tointeger(L,2);
	lstage_lfqueue_setcapacity(s->event_queue,capacity);
	return 0;
}

// Capacidade máximo de instâncias rodando paralelamente
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

// Método de insere um evento na fila de entrada de um estágio
static int stage_push(lua_State *L) {
   stage_t s=lstage_tostage(L,1);

   // Verificando se o estágio está ativo
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

   if(lstage_lfqueue_try_pop(s->instances,&ins)) {
   	ins->ev=ev;
		ins->flags=I_READY;
		lstage_pushinstance(ins);
		lua_pushvalue(L,1);
		return 1;
   } else if(lstage_lfqueue_try_push(s->event_queue,&ev)) {
      lua_pushvalue(L,1);
      return 1;
   } 
   lstage_destroyevent(ev);
   lua_pushnil(L);
   lua_pushliteral(L,"Event queue is full");
   return 2;
}

// Habilita ou desabilita um estágio (utilizado nas funções "stage_enable" e "stage_disable")
static int stage_stage_status(lua_State *L, int enable) {
	stage_t s = lstage_tostage(L, 1);
	s->enabled=enable;
	lua_pushvalue(L,1);
	return 1;
}

// Habilita eventos de um certo estágio
static int stage_enable(lua_State *L) {
	return stage_stage_status(L, 1);
}

// Desabilita eventos de um certo estágio
static int stage_disable(lua_State *L) {
	return stage_stage_status(L, 0);
}

// Verifica se um estágio está ativo
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

static int stage_getid (lua_State *L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushlstring(L,(const char *)&s,sizeof(void*));
	return 1;
}

// Total de eventos na fila de entrada de um determinado estágio
static int stage_queue_size (lua_State *L) {
	stage_t s = lstage_tostage(L, 1);
	lua_pushnumber(L,lstage_lfqueue_size(s->event_queue));
	return 1;
}

// Total de instâncias livres para um determinado estágio
static int stage_instances_size (lua_State *L) {
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
	/* TODO warning thread_unsafe, mutex needed (use it serially for now) */
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

	/*unlock mutex */
	lua_pushnumber(L,i);
	return 1;
}

static int stage_instantiate(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	if(s->pool==NULL) luaL_error(L,"Stage must be associated to a pool");
	if(s->env==NULL) luaL_error(L,"Stage must have an environment");
	int n=lua_tointeger(L,2);
	int i;
	if(n<=0) luaL_error(L,"Argument must be grater than zero");
	/*TODO warning thread_unsafe, mutex needed (or use it in only one thread)*/
	if(lstage_lfqueue_getcapacity(s->instances)>=0) 
		lstage_lfqueue_setcapacity(s->instances,lstage_lfqueue_getcapacity(s->instances)+n);
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

static int stage_getpool(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	if(s->pool)
		lstage_buildpool(L,s->pool);
	else
		lua_pushnil(L);
	return 1;
}

static int stage_setpool(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	pool_t p=lstage_topool(L, 2);
	s->pool=p;
	return 0;
}

// Modifica a prioridade de um estágio
static int stage_setpriority(lua_State * L) {
	stage_t s = lstage_tostage(L, 1);
	int p=lua_tointeger(L,2);
	s->priority=p;
	lua_pushvalue(L,1);
	return 1;
}

// Configura a prioridade de um estágio
// Inicialmente todos tem prioridade 0
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
		{"instancesize", stage_instances_size},
		{"instantiate",stage_instantiate},
		{"free",stage_destroyinstances},
		{"ptr",stage_ptr},
		{"parent",stage_getparent},
		{"pool",stage_getpool},
		{"setpool",stage_setpool},
		{"priority",stage_getpriority},
		{"setpriority",stage_setpriority},
		{"disable",stage_disable},
		{"enable",stage_enable},
		{"active",stage_active},
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
	   /*if(idle<0) lstage_lfqueue_setcapacity((*stage)->instances,-1);
	   else */lstage_lfqueue_setcapacity((*stage)->instances,0);
	   (*stage)->event_queue=lstage_lfqueue_new();
	   lstage_lfqueue_setcapacity((*stage)->event_queue,capacity);
	   char *envcp=malloc(len+1);
	   envcp[len]='\0';
	   memcpy(envcp,env,len+1);
	   (*stage)->env=envcp;
	   (*stage)->env_len=len;
	}

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

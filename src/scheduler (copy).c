#include "lstage.h"
#include "scheduler.h"
#include "instance.h"
#include "threading.h"
#include "event.h"
#include "marshal.h"
#include "p_queue.h"
#include <event2/event.h>

#include <time.h>
#include <pthread.h>

// Define LOCK and UNLOCK
#define LOCK(q) while (__sync_lock_test_and_set(&(q)->lock,1)) {}
#define UNLOCK(q) __sync_lock_release(&(q)->lock);

// Used in thread_main_loop to count processed events in private ready queue
static pthread_mutex_t lock;

static int thread_tostring (lua_State *L) {
  thread_t * t = luaL_checkudata (L, 1, LSTAGE_THREAD_METATABLE);
  lua_pushfstring (L, "Thread (%p)", *t);
  return 1;
}

thread_t lstage_tothread(lua_State *L, int i) {
	thread_t * t = luaL_checkudata (L, i, LSTAGE_THREAD_METATABLE);
	luaL_argcheck (L, *t != NULL, i, "not a Thread");
	return *t;
}

static int thread_join (lua_State *L) {
	thread_t t=lstage_tothread(L,1);
	int timeout=lua_tointeger(L,2);
	if(timeout>0) {
		struct timespec to;
		clock_gettime(CLOCK_REALTIME, &to);
		to.tv_sec += timeout;
	   pthread_timedjoin_np(*t->th,NULL,&to);
   } else {
	   pthread_join(*t->th,NULL);
   }
   return 0;
}

static int thread_rawkill (lua_State *L) {
   thread_t t=lstage_tothread(L,1);
   THREAD_KILL(t->th);
   return 0;
}

static int thread_state (lua_State *L) {
   thread_t t=lstage_tothread(L,1);
   lua_pushnumber(L,t->state);
   return 1;
}

static int thread_ptr (lua_State *L) {
	thread_t t=lstage_tothread(L,1);
	lua_pushlightuserdata(L,t);
	return 1;
}

static int thread_eq(lua_State * L) {
	thread_t t1=lstage_tothread(L,1);
	thread_t t2=lstage_tothread(L,2);
	lua_pushboolean(L,t1==t2);
	return 1;
}

static const struct luaL_Reg StageMetaFunctions[] = {
		{"__tostring",thread_tostring},
		{"__eq",thread_eq},
		{"join",thread_join},
		{"__ptr",thread_ptr},
		{"state",thread_state},
		{"rawkill",thread_rawkill},
		{NULL,NULL}
};

static void get_metatable(lua_State * L) {
	luaL_getmetatable(L,LSTAGE_THREAD_METATABLE);
   if(lua_isnil(L,-1)) {
   	lua_pop(L,1);
  		luaL_newmetatable(L,LSTAGE_THREAD_METATABLE);
  		lua_pushvalue(L,-1);
  		lua_setfield(L,-2,"__index");
		LUA_REGISTER(L,StageMetaFunctions);
		luaL_loadstring(L,"local th=(...):ptr() return function() return require'lstage.scheduler'.build(th) end");
		lua_setfield (L, -2,"__wrap");
  	}
}

static void thread_resume_instance(instance_t i) {
	_DEBUG("Resuming instance: %p %d lua_State (%p)\n",i,i->flags,i->L);
	lua_State * L=i->L;
	
	switch(i->flags) {
		case I_CREATED:
			lstage_initinstance(i);
			break;
		case I_WAITING_IO:
			i->flags=I_READY;

			lua_pushliteral(L,STAGE_HANDLER_KEY);
			lua_gettable(L,LUA_REGISTRYINDEX);
			lua_pushboolean(L,1);
			stackDump(L,"teste");
			if(lua_pcall(i->L,1,0,0)) {
		      		const char * err=lua_tostring(L,-1);
				fprintf(stderr,"[I_WAITING_IO] Error resuming instance: %s\n",err);
		   	}
		   break;
		case I_TIMEOUT_IO:
			i->flags=I_READY;
			lua_pushliteral(L,STAGE_HANDLER_KEY);
			lua_gettable(L,LUA_REGISTRYINDEX);
			lua_pushboolean(L,0);
			if(lua_pcall(i->L,1,0,0)) {
		      const char * err=lua_tostring(L,-1);
		      fprintf(stderr,"[I_TIMEOUT_IO] Error resuming instance: %s\n",err);
		   }
		   break;
		   
		// Ready to execute event
		case I_READY:
			if(i->ev) {				
				lua_pushliteral(L,STAGE_HANDLER_KEY);
				lua_gettable(L,LUA_REGISTRYINDEX);
				lua_pushcfunction(L,mar_decode);
				lua_pushlstring(L,i->ev->data,i->ev->len);
		      
				lstage_destroyevent(i->ev);
				i->ev=NULL;
				
				if(lua_pcall(L,1,1,0)) {
					const char * err=lua_tostring(L,-1);
					fprintf(stderr,"[I_READY] Error decoding event: %s\n",err);
					break;
				}
				
				int n=
				#if LUA_VERSION_NUM < 502
					luaL_getn(L,2);
				#else
					luaL_len(L,2);
				#endif
				
				int j;
				for(j=1;j<=n;j++) 
					lua_rawgeti(L,2,j);

				lua_remove(L,2);
				i->args=n;
				
				// Increment processed count - used to build statistics
				LOCK(i->stage);
				i->stage->processed++;
				UNLOCK(i->stage);

			} else {
				lua_pushliteral(L,STAGE_HANDLER_KEY);
				lua_gettable(L,LUA_REGISTRYINDEX);
				i->args=0;
			}
			
			if(lua_pcall(L,i->args,0,0)) {
				const char * err=lua_tostring(L,-1);
				fprintf(stderr,"[I_READY] Error resuming instance: %s\n",err);
			} 
			break;
		case I_WAITING_EVENT:
			return;
		case I_WAITING_CHANNEL:
			return;
		case I_IDLE:
			break;
	}

	_DEBUG("Instance Yielded: %p %d lua_State (%p)\n",i,i->flags,i->L);
	if(i->flags==I_WAITING_CHANNEL) {
		//lua_settop(i->L,0);
		lstage_lfqueue_try_push(i->channel->wait_queue,&i);
		return;
	}

	else if(i->flags==I_READY || i->flags==I_IDLE) {
	   lstage_putinstance(i);
	}
}

// Thread main loop - called when a new thread is created
// pool.c - "pool_addthread"
static THREAD_RETURN_T THREAD_CALLCONV thread_mainloop(void *t_val) {
   // lstage.c [lstage_build_polling_table - linked list to use polling tables]
   extern stageCell_t firstCell;

   instance_t i		= NULL;
   steal_t    stealFrom = NULL;
   thread_t   self	= (thread_t)t_val;

   int processedEvents = 0;
   //int maxSteps = 0;
   //int lastStageId = 0;

   // Queue type
   enum lstage_private_queue_flag queueFlag = lstage_get_ready_queue_type ();
   int maxQueueSteps = 0;
   stageCell_t currentCell = NULL;

   while(1) {
   	_DEBUG("Thread %p wating for ready instaces\n",self);
   	self->state=THREAD_IDLE;

	i=NULL;

	// [Workstealing] If we have to stole a thread
	// *** Works only with pool per stage ***
	stealFrom = NULL;
        if (lstage_lfqueue_try_pop (self->pool->stealing_queue,&stealFrom)) {
		LOCK(self->pool);

		// Update counter
		stealFrom->stealCount--;

		// Update pool sizes
		self->pool->size--;
		stealFrom->toPool->size++;

		// Point thread to another pool
		self->pool=stealFrom->toPool;

		// We still have to stole threads [put at the end of the queue]
        	if (stealFrom->stealCount > 0) {
		        lstage_lfqueue_try_push (self->pool->stealing_queue,&stealFrom);
		// We don have to steal anymore [destroy object]
        	} else {
			free(stealFrom);
			stealFrom=NULL;
		}

		UNLOCK(self->pool);
        }

	// Get ready instance
	if (queueFlag == I_GLOBAL_QUEUE)
		lstage_pqueue_pop(self->pool->ready,&i);
	// Private queue with no turning back
	// Private queue with turning back
	else {
		// We don't have our polling table yet
		if (firstCell == NULL) {
			continue;
		}
		else if (currentCell== NULL) {
			currentCell = firstCell;
		}

		// Time to change stage (we already processed max number of events)
		if (currentCell->stage->max_events > 0 && 
		    processedEvents > currentCell->stage->max_events) 
		{						
			processedEvents = 0;
			maxQueueSteps = maxQueueSteps + 1;
			//lastStageId = currentCell->stage->id;

			// Update cursor
			currentCell = currentCell->nextCell;
			if (currentCell == NULL) {
				currentCell = firstCell;
			}
		}

		// Check if we reached max queue steps - we must fire an event
		//if (processedEvents == 1 && lastStageId != currentCell->stage->id) {
			//maxSteps = lstage_get_queue_steps ();

			//if (maxSteps > 0 && maxQueueSteps > maxSteps) {
				//printf("[maxQueueSteps] %d\n",maxQueueSteps);
				// Fire [max_steps_reached] event
				//maxQueueSteps = 0;
				//lstage_fire_max_queue_steps ();
			//}
		//}
		lstage_pqueue_pop(currentCell->stage->ready_queue,&i);
	}

	// Instance found
        if(i!=NULL) {
	     	_DEBUG("Thread %p got a ready instance %p\n",self,i);
	     	self->state=THREAD_RUNNING;
		processedEvents = 1;

		// Update new event
		if (queueFlag == I_PRIVATE_QUEUE || queueFlag == I_RESTART_PRIVATE_QUEUE) {
			processedEvents++;
		}

      		thread_resume_instance(i);

	// No instance (wait for the next instance)
	} else {
		switch(queueFlag) {
			// Public queue
			case I_GLOBAL_QUEUE:
				lstage_pqueue_lock_and_wait(self->pool->ready);	
				break;
			// Private queue with no turning back
			case I_PRIVATE_QUEUE:
				// No instance (get next stage)
				currentCell = currentCell->nextCell;
				if (currentCell == NULL) {
					currentCell = firstCell;
				}

				processedEvents = 0;
				maxQueueSteps   = maxQueueSteps + 1;
				//lastStageId = currentCell->stage->id;

				// Fire event because priority has changed
				//if (currentCell->stage->fire_priority == 1) {
					//lstage_stage_was_focused();
			        //}

				break;
			// Private queue with turning back
			case I_RESTART_PRIVATE_QUEUE:
				// One more step				
				maxQueueSteps = maxQueueSteps + 1;
				//lastStageId = currentCell->stage->id;

				// Get next stage (we get first if at least one event was processed)
				if (processedEvents > 0) {
					currentCell     = firstCell;
				// No event was processed - get next
				} else {
					currentCell = currentCell->nextCell;
					if (currentCell == NULL) {
						currentCell = firstCell;
					}
				}
				processedEvents = 0;

				//LOCK(currentCell->stage);
				// Fire event because priority has changed
				//if (currentCell->stage->fire_priority == 1) {
					//lstage_stage_was_focused();
			        //}
				//UNLOCK(currentCell->stage);

				break;
		};
	}
   }

   printf("Thread destruída!\n");
   self->state=THREAD_DESTROYED;
   _DEBUG("Thread %p quitting\n",self);
   self->pool->size--; //TODO atomic

   return t_val;
}

int lstage_newthread(lua_State *L,pool_t pool) {
	_DEBUG("Creating new thread for pool %p\n",pool);
	thread_t * thread=lua_newuserdata(L,sizeof(thread_t));
	thread_t t=malloc(sizeof(struct thread_s));
	t->th=calloc(1,sizeof(THREAD_T));
	t->pool=pool;
	t->state=THREAD_IDLE;
	*thread=t;
   get_metatable(L);
   lua_setmetatable(L,-2);
   THREAD_CREATE(t->th, thread_mainloop, t, 0 );
   return 1;
}

static int thread_from_ptr (lua_State *L) {
	thread_t * ptr=lua_touserdata(L,1);
	thread_t ** thread=lua_newuserdata(L,sizeof(thread_t));
	*thread=ptr;
   get_metatable(L);
   lua_setmetatable(L,-2);
//   THREAD_CREATE(*thread, thread_mainloop, *thread, 0 );
   return 1;
}

void lstage_pushinstance(instance_t i) {	
   	// Queue type   
	enum lstage_private_queue_flag queueFlag = lstage_get_ready_queue_type ();

	// Push from global queue
	if (queueFlag == I_GLOBAL_QUEUE)
		return lstage_pqueue_push(i->stage->pool->ready,(void **) &(i));
	// Push from stage's private queue
	else 
		return lstage_pqueue_push(i->stage->ready_queue,(void **) &(i));
}

static const struct luaL_Reg LuaExportFunctions[] = {
	{"build",thread_from_ptr},
	{NULL,NULL}
};

LSTAGE_EXPORTAPI	int luaopen_lstage_scheduler(lua_State *L) {

//	if(!ready_queue) ready_queue=lstage_lfqueue_new();
	get_metatable(L);
	lua_pop(L,1);
	lua_newtable(L);
	lua_newtable(L);
	luaL_loadstring(L,"return function() return require'lstage.scheduler' end");
	lua_setfield (L, -2,"__persist");
	lua_setmetatable(L,-2);
#if LUA_VERSION_NUM < 502
	luaL_register(L, NULL, LuaExportFunctions);
#else
	luaL_setfuncs(L, LuaExportFunctions, 0);
#endif        
	return 1;
};

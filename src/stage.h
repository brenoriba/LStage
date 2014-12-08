/*Adapted from https://github.com/Tieske/Lua_library_template/*/

/*
** ===============================================================
** Leda is a parallel and concurrent framework for Lua.
** Copyright 2014: Tiago Salmito
** License MIT
** ===============================================================
*/

#ifndef stage_h
#define stage_h

typedef struct lstage_Stage * stage_t;
typedef struct lstage_StageCell * stageCell_t;

#define STAGE_HANDLER_KEY "stage-handler"

#include "lstage.h"
#include "lf_queue.h"
#include "pool.h"

enum stage_flag_t {
	DESTROYED=0x01
};

// Stage struct
struct lstage_Stage {
   int id;		   // Stage unique ID
   LFqueue_t instances;    // Instances queue
   LFqueue_t event_queue;  // Events queue (when we don't have instances to run)
   Pqueue_t ready_queue;   // Events combined with instances
   pool_t pool; 	   // Stage pool
   int init_time; 	   // Stage creation time to measure throughput (processed_count / now - init_time)
   int processed; 	   // Number of events processed
   int enabled; 	   // If the stage is enabled or disabled to receive new queries
   int fire_priority;	   // Fire event new priority changes
   int max_events; 	   // Max events to run when stage is focused using private ready queues
   int processed_in_focus; // How many events was processed when focused (used in private queues)
   char * env;
   size_t env_len;
   volatile unsigned int flags;
   volatile int priority;
   stage_t parent;

   int lock;
};

struct lstage_StageCell {
   stage_t stage;
   stageCell_t nextCell;
};

stage_t lstage_tostage(lua_State *L, int i);
void lstage_buildstage(lua_State * L,stage_t t);

#endif

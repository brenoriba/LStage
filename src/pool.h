#ifndef POOL_H
#define POOL_H

#include <lua.h>

#include "lstage.h"
#include "p_queue.h"

typedef struct pool_s * pool_t;
typedef struct steal_s * steal_t;

struct steal_s {
	int    stealCount;
	pool_t toPool;
};

struct pool_s {
	volatile size_t size;
	Pqueue_t ready;

	LFqueue_t stealing_queue;
	int lock;
};

pool_t lstage_topool(lua_State *L, int i);
void lstage_buildpool(lua_State * L,pool_t t);

#endif

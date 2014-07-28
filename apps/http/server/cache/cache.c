#include "hashtable.h"

#include <string.h>
#include <pthread.h>
#include <stdlib.h>
#include <lua.h>

static hashtable ht=NULL;
pthread_rwlock_t rwlock;

#define NUMBER 1024

static int cache_put(lua_State * L) {
	size_t len1,len2;
	const char * key_l=lua_tolstring(L,1,&len1);
	char * key=malloc(len1+1);
	memcpy(key,key_l,len1);
	key[len1]='\0';
	const char * val_l=lua_tolstring(L,2,&len2);
	char * val=malloc(len2);
	memcpy(val,val_l,len2);
	//printf("%s %s %u\n",val,val_l,len2);
	pthread_rwlock_wrlock(&rwlock);
	hashtable_set(ht,key,val,len2);
	pthread_rwlock_unlock(&rwlock);
	return 0;
}

static int cache_get(lua_State * L) {
	size_t len1,len2;
	const char * key_l=lua_tolstring(L,1,&len1);
	char * val=NULL;
	pthread_rwlock_rdlock(&rwlock);
	val=hashtable_get(ht,key_l,&len2);
	//printf("%p %s %u\n",val,val,len2);
	if(val==NULL) {
		pthread_rwlock_unlock(&rwlock);
		return 0;
	}
	lua_pushlstring(L,val,len2);
	pthread_rwlock_unlock(&rwlock);
	return 1;
}

static int cache_has(lua_State * L) {
	size_t len1,len2;
	const char * key_l=lua_tolstring(L,1,&len1);
	char * val=NULL;
	pthread_rwlock_rdlock(&rwlock);
	//printf("%p\n",val);
	val=hashtable_get(ht,key_l,&len2);
	//printf("%p\n",val);
	pthread_rwlock_unlock(&rwlock);
	if(val==NULL) {
		lua_pushboolean(L,0);
		return 1;
	}
	lua_pushboolean(L,1);
	return 1;
}


int luaopen_cache(lua_State * L) {
	if(ht==NULL) {
		pthread_rwlock_init(&rwlock,NULL);
		ht=create_hashtable(NUMBER);
	}
	lua_newtable(L);
	lua_pushcfunction(L,cache_get);
	lua_setfield(L,-2,"get");
	lua_pushcfunction(L,cache_put);
	lua_setfield(L,-2,"put");
	lua_pushcfunction(L,cache_has);
	lua_setfield(L,-2,"has");
	return 1;
}

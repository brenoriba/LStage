#ifndef HASHTABLE_H
#define HASHTABLE_H

#include "list.h"
#include <stdio.h>

typedef struct entry_t * entry;
typedef struct hashtable_t * hashtable;

struct entry_t {
	char * key;
	char * value;
	size_t size;
};

struct hashtable_t {
	size_t size;
	list * table;
};

hashtable create_hashtable(size_t size);
void hashtable_set(hashtable h,char *key, char*value,size_t size);
int hashtable_hash(hashtable h, char * key);
char * hashtable_get(hashtable h,char *key, size_t * size);
#endif

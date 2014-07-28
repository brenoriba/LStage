#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "hashtable.h"

hashtable create_hashtable(size_t size) {
	hashtable h=malloc(sizeof(struct hashtable_t));
	h->size=size;
	size_t i;
	h->table=malloc(size*sizeof(list));
	for(i=0;i<size;i++)
		h->table[i]=create_list();
	return h;
}


int hashtable_hash(hashtable h, char * key) {
	size_t hashval=0;
	int i;
	for(i=0;i<strlen(key);i++) {
		hashval<<8;
		hashval+=key[i];
	}
	return (hashval%h->size);
}

int entrycmp(void * e1, void * e2) {
	return !strcmp(((entry) e1)->key,((entry) e2)->key);
}

void hashtable_set(hashtable h,char *key, char*value,size_t size) {
	int bin=hashtable_hash(h,key);
	struct entry_t e_t={key,value,size};	
	entry e=list_remove(h->table[bin],&e_t,(*entrycmp));
	if(e) {
		e->value=value;
		e->size=size;
		list_push(h->table[bin],e);
	} else {
		entry new=malloc(sizeof(struct entry_t));
		new->key=key;
		new->value=value;
		new->size=size;
		list_push(h->table[bin],new);
	}
}

char * hashtable_get(hashtable h,char *key, size_t * size) {
	int bin=hashtable_hash(h,key);
	element cur=h->table[bin]->head;
	while(cur) {
		if(!strcmp(((entry)cur->ptr)->key,key))
			*size=((entry)cur->ptr)->size;
			return ((entry)cur->ptr)->value;
		cur=cur->next;
	}
	return NULL;
}

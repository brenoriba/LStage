#ifndef LIST_H
#define LIST_H

#include <stdio.h>

typedef struct list_t * list;
typedef struct element_t * element;

struct element_t {
	void * ptr;
	struct element_t * next;
	struct element_t * prev;
};

struct list_t {
	struct element_t * head;
	struct element_t * tail;
	size_t size;
};

list create_list();
void list_push(list l, void * e);
void * list_pop(list l);
void dump_int_list(list l);
void dump_string_list(list l);
void * list_remove(list l,void * elem,int (*functionPtrCmp)(void*,void*));

#endif

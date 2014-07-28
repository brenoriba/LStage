#include <stdlib.h>
#include <stdio.h>

#include "list.h"


list create_list() {
	return calloc(1,sizeof(struct list_t));	
}

void list_push(list l, void * e) {
	struct element_t * el=calloc(1,sizeof(struct element_t));
	el->ptr=e;
	if(l->size==0) {
		l->head=l->tail=el;
	} else {
		el->prev=l->tail;
		l->tail->next=el;
		l->tail=el;
	}
	l->size++;
}

void * list_pop(list l) {
	struct element_t * el=l->tail;
	if(!el) 
		return NULL;
	void * ret=el->ptr;
	if(el->prev==NULL)
		l->head=NULL;
	l->tail=el->prev;
	free(el);
	l->size--;
	return ret;
}

void * list_remove(list l,void * elem,int (*functionPtrCmp)(void*,void*)) {
	struct element_t * cur=l->head;
	while(cur) {
		if(functionPtrCmp) {
		if(functionPtrCmp(cur->ptr,elem)) {
			if(cur->prev==NULL) //the first element
				l->head=cur->next;
			else
				cur->prev->next=cur->next;
			if(cur->next==NULL)
				l->tail=cur->prev; //the last element
		   else
		   	cur->next->prev=cur->prev;
			l->size--;
			void * ret=cur->ptr;
			free(cur);
			return ret; //elem removed
		}}
		else if(cur->ptr==elem) {
			if(cur->prev==NULL) //the first element
				l->head=cur->next;
			else
				cur->prev->next=cur->next;
			if(cur->next==NULL)
				l->tail=cur->prev; //the last element
		   else
		   	cur->next->prev=cur->prev;
			l->size--;
			void * ret=cur->ptr;
			free(cur);
			return ret; //elem removed
		}
		cur=cur->next;
	}
	return NULL; //element not found
}

void dump_int_list(list l) {
	struct element_t * cur=l->head;
	printf("Numer of elements on the list: %zu\n",l->size);
	int i=1;
	while(cur) {
		printf("Element %d: %d\n",i,(int)cur->ptr);
		i++;
		cur=cur->next;
	}
}

void dump_string_list(list l) {
	struct element_t * cur=l->head;
	printf("Numer of elements on the list: %zu\n",l->size);
	int i=1;
	while(cur) {
		printf("Element %d: %s\n",i,(char*)cur->ptr);
		i++;
		cur=cur->next;
	}
}

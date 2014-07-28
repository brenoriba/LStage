LUAINC=/usr/include/lua5.1

CFLAGS=-Wall -O2 -fPIC -I$(LUAINC)
LDFLAGS=-Wall -O2 
BIN=cache.so

all: $(BIN)

%o: %.c %.h
	$(CC) -c -o $@ $<

$(BIN): cache/hashtable.o cache/list.o cache/cache.o
	$(CC) -shared -o $@ $^ $(LDFLAGS) -lpthread
	
clean:
	rm -f cache/*.o $(BIN)

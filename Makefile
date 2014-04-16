LUA_VER=5.1

LUA_LIBDIR=/usr/local/lib/lua/$(LUA_VER)

CONTROLLERS_DIR=controllers/
UTILS_DIR=utils/
SRC_DIR=src/
MODULE=lstage
_SO=.so

BIN=$(MODULE)$(_SO)
all:
	cd $(SRC_DIR) && make LUA_VER=$(LUA_VER) all 

install: all
	mkdir -p $(LUA_LIBDIR)
	mkdir -p $(LUA_LIBDIR)/lstage/controllers
	mkdir -p $(LUA_LIBDIR)/lstage/utils
	install $(SRC_DIR)/$(BIN) $(LUA_LIBDIR)
	install $(CONTROLLERS_DIR)/*.lua $(LUA_LIBDIR)/lstage/controllers/
	install $(UTILS_DIR)/*.lua $(LUA_LIBDIR)/lstage/utils/

install-both: clean
	cd $(SRC_DIR) && make LUA_VER=5.1 all && cd - && make LUA_VER=5.1 install
	make clean
	cd $(SRC_DIR) && make LUA_VER=5.2 all && cd - && make LUA_VER=5.2 install

uninstall:
	rm -f $(LUA_LIBDIR)/$(BIN)
	rm -f $(LUA_LIBDIR)/lstage/controllers
	rm -f $(LUA_LIBDIR)/lstage/utils
	
uninstall-both:
	make LUA_VER=5.1 uninstall && make LUA_VER=5.2 uninstall

%:
	cd $(SRC_DIR) && make $@

ultraclean:
	cd $(SRC_DIR) && make ultraclean
	rm -f `find -iname *~`

tar tgz: ultraclean
ifeq "$(VERSION)" ""
	echo "Usage: make tar VERSION=x"; false
else
	rm -rf $(MODULE)-$(VERSION)
	mkdir $(MODULE)-$(VERSION)
	tar c * --exclude="*.tar.gz" --exclude=".git" --exclude="$(MODULE)-$(VERSION)*" | (cd $(MODULE)-$(VERSION) && tar x)
	tar czvf $(MODULE)-$(VERSION).tar.gz $(MODULE)-$(VERSION)
	rm -rf $(MODULE)-$(VERSION)
	md5sum $(MODULE)-$(VERSION).tar.gz > $(MODULE)-$(VERSION).md5
endif


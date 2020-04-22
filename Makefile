PREFIX ?= /usr/local

install:
	cp -f bin/git-nubs.sh $(PREFIX)/bin

uninstall:
	rm -f $(PREFIX)/bin/git-nubs.sh


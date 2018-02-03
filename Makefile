PROGNM = aurutils
PREFIX ?= /usr/local
SHRDIR ?= $(PREFIX)/share
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib

.PHONY: check install

check:
	@bash -n bin/aur
	@bash -n lib/build
	@bash -n lib/build-nspawn
	@bash -n lib/fetch
	@bash -n lib/pkglist
	@bash -n lib/rfilter
	@bash -n lib/rpc-deps
	@bash -n lib/search
	@bash -n lib/src-deps
	@bash -n lib/src-ver
	@bash -n lib/sync
	@bash -n lib/updates

shellcheck:
	@shellcheck -x lib/* bin/*

install:
	@install -Dm755 bin/*   -t $(DESTDIR)$(BINDIR)
	@install -Dm755 lib/*   -t $(DESTDIR)$(LIBDIR)/$(PROGNM)
	@install -Dm644 man1/*  -t $(DESTDIR)$(SHRDIR)/man/man1
	@install -Dm644 LICENSE -t $(DESTDIR)$(SHRDIR)/licenses/$(PROGNM)
	@install -Dm644 THANKS README.md -t $(DESTDIR)$(SHRDIR)/doc/$(PROGNM)

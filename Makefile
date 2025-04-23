PROGNM = aurutils
PREFIX ?= /usr
SHRDIR ?= $(PREFIX)/share
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
ETCDIR ?= /etc
AURUTILS_LIB_DIR ?= $(LIBDIR)/$(PROGNM)
AURUTILS_VERSION ?= $(shell git describe --tags || true)
ifeq ($(AURUTILS_VERSION),)
AURUTILS_VERSION := 20.5
endif
AURUTILS_LIB = $(shell find lib/ -name 'aur-*')

.PHONY: shellcheck install build completion aur

build: aur completion

aur: aur.in
	sed -e 's|AURUTILS_LIB_DIR|$(AURUTILS_LIB_DIR)|' \
	    -e 's|AURUTILS_VERSION|$(AURUTILS_VERSION)|' $< >$@

completion:
	@$(MAKE) -C completions bash zsh

shellcheck: aur
	@shellcheck -x -f gcc -e 1071 $(AURUTILS_LIB)

test: aur shellcheck
	@tests/parseopt-consistency
	@$(MAKE) -C perl test

install-aur: aur
	@install -Dm755 aur       -t '$(DESTDIR)$(BINDIR)'

install: install-aur
	@install -Dm755 $(AURUTILS_LIB) -t '$(DESTDIR)$(AURUTILS_LIB_DIR)'
	@install -Dm644 man1/*     -t '$(DESTDIR)$(SHRDIR)/man/man1'
	@install -Dm644 man7/*     -t '$(DESTDIR)$(SHRDIR)/man/man7'
	@install -Dm644 LICENSE    -t '$(DESTDIR)$(SHRDIR)/licenses/$(PROGNM)'
	@install -Dm644 README.md  -t '$(DESTDIR)$(SHRDIR)/doc/$(PROGNM)'
	@install -Dm644 examples/* -t '$(DESTDIR)$(SHRDIR)/doc/$(PROGNM)/examples'
	@install -dm755 aurutils '$(DESTDIR)$(ETCDIR)/$(PROGNM)'
	@$(MAKE) -C completions DESTDIR='$(DESTDIR)' install-bash install-zsh
	@$(MAKE) -C perl DESTDIR='$(DESTDIR)' install-perl

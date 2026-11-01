PROGNM = aurutils
PREFIX ?= /usr
SHRDIR ?= $(PREFIX)/share
BINDIR ?= $(PREFIX)/bin
LIBDIR ?= $(PREFIX)/lib
ETCDIR ?= /etc
AURUTILS_LIB_DIR ?= $(LIBDIR)/$(PROGNM)
AURUTILS_VERSION ?= $(shell git describe --tags || true)
ifeq ($(AURUTILS_VERSION),)
AURUTILS_VERSION := 21
endif
AURUTILS_LIB := $(shell find lib/ -type f -name 'aur-*')
TEST_EXEC_PATH := $(CURDIR)/lib:$(CURDIR)/lib/pacman:$(CURDIR)/lib/aurweb:$(CURDIR)/lib/util
# unset AUR_* variables of the caller, e.g. AUR_LOCATION
TEST_ENV = env $(addprefix -u ,$(filter AUR_%,$(.VARIABLES))) \
	AUR_ENV=/dev/null AUR_EXEC_PATH='$(TEST_EXEC_PATH)' PERL5LIB='$(CURDIR)/perl'
# use the built aur instead of the one in PATH:
TEST_ENV += PATH="$(CURDIR):$$PATH"

.PHONY: shellcheck install build completion aur

build: aur completion

aur: aur.in
	sed -e 's|AURUTILS_LIB_DIR|$(AURUTILS_LIB_DIR)|' \
	    -e 's|AURUTILS_VERSION|$(AURUTILS_VERSION)|' $< >$@
	chmod +x $@

completion:
	@$(MAKE) -C completions bash zsh

shellcheck: aur
	@shellcheck -x -f gcc -e 1071 $(AURUTILS_LIB)

test: aur shellcheck
# tests which run the source tree's aur and lib/ (TEST_ENV), ignoring
# ~/.config/aurutils/env and AUR_* variables of the caller
	@$(TEST_ENV) tests/run tests/lib

# tests which use script paths directly
	@tests/parseopt-consistency
	@tests/completion-bash

# tests run with prove (1perl)
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

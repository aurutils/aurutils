PREFIX ?= /usr
SHRDIR ?= $(PREFIX)/share
PRLDIR ?= $(SHRDIR)/perl5/vendor_perl
.PHONY = install-perl

test:
	@prove -I.

install-perl:
	@install -Dm644 AUR/*.pm -t '$(DESTDIR)$(PRLDIR)/AUR'
	@install -Dm644 AUR.pm   -t '$(DESTDIR)$(PRLDIR)'

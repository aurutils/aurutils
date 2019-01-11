PREFIX ?= /usr
SHRDIR ?= $(PREFIX)/share
.PHONY = bash install-bash zsh install-zsh

bash: bash/aur
zsh: zsh/_aur

bash/aur: command_opts.m4 bash/aurutils.in ../lib/*
	m4 $(wordlist 1,2,$^) >$@

zsh/_aur: command_opts.m4 zsh/aurutils.in ../lib/*
	m4 $(wordlist 1,2,$^) >$@

install-bash: bash/aur
	@install -Dm644 bash/aur -t $(DESTDIR)$(SHRDIR)/bash-completion/completions

install-zsh: zsh/_aur
	@install -Dm644 zsh/_aur -t $(DESTDIR)$(SHRDIR)/zsh/site-functions
	@install -Dm755 zsh/run-help-aur -t $(DESTDIR)$(SHRDIR)/zsh/functions/Misc

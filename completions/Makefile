PREFIX ?= /usr
SHRDIR ?= $(PREFIX)/share
.PHONY = bash fish install-bash install-fish install-zsh

ZSH_SITE_FUNCTIONS = \
	zsh/_aur \
	zsh/_aur_local_packages \
	zsh/_aur_packages \
	zsh/_aur_repositories

AURUTILS_LIB := $(shell find ../lib -type f -name 'aur-*')

bash: bash/aur

bash/aur: bash/aurutils.in $(AURUTILS_LIB)
	bash $< >$@

fish: fish/aur.fish

fish/aur.fish: fish/aurutils.in zsh/_aur
	zsh $< >$@

install-bash: bash/aur
	@install -Dm644 bash/aur -t '$(DESTDIR)$(SHRDIR)/bash-completion/completions'

install-fish: fish/aur.fish
	@install -Dm644 fish/aur.fish -t '$(DESTDIR)$(SHRDIR)/fish/vendor_completions.d'

install-zsh: zsh/run-help-aur $(ZSH_SITE_FUNCTIONS)
	@install -Dm644 zsh/run-help-aur -t '$(DESTDIR)$(SHRDIR)/zsh/functions/Misc'

	@install -d '$(DESTDIR)$(SHRDIR)/zsh/site-functions/'
	@install -m644 -t '$(DESTDIR)$(SHRDIR)/zsh/site-functions/' $(ZSH_SITE_FUNCTIONS)

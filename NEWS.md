## 2.3.0

* `aur-build`
  + add `--holdver` to makepkg with `--pkgver`
  + exit 2 if `db_path` is not found
* `aur-repo-filter`
  + support versioned packages (#404)
  + remove `--repo` alias to `--database`
* `aur-srcver`
  + remove `--noprepare` from default makepkg options
  + add `--noprepare` option (#523)
* `aur-sync`
  + wrap repo-add `-R` (#521)
  + add `--no-graph` (workaround for #516)
* `aur-vercmp`
  + add `-q`/`--quiet`
  + rename `--equal` to `--current`
* `completions`
  + group options by type (#520)
  + complete `aur-depends` options (#526)
  
## 2.2.1

* `aur-build`
  + add `--holdver` to `makepkg` options if `--pkgver` is enabled
* `aur-repo`
  + do not include `repo:` in error messages
  + `--all` implies `--upgrades`
* `aur-sync`
  + `cd` before invoking `$PAGER` (#518)
* `aur-repo-filter`
  + if `stdin` is connected to a terminal, mention this on `stderr`
* `aur-rpc`
  + if `stdin` is connected to a terminal, mention this on `stderr`
* `aur-vercmp`
  + if `stdin` is connected to a terminal, mention this on `stderr`

## 2.2.0

* `aur`
  + update `CacheDir` instructions in `aur(1)`
* `aur-build`
  + rename `--run-pkgver` to `--pkgver`, remove `LANG=C` from `makepkg -od`
  + remove `~` package backup on `--force` (#444)
  + propagate `--pacman-conf` to `pacman-conf` (local builds)
  + unset `PKGDEST` prior to running `makepkg` (#513)
  + remove `--rmdeps` from default options (#508)
* `aur-fetch`
  + expose AUR URL through `AUR_LOCATION` environment variable
* `aur-sync`
  + add `--pkgver` (`aur-build --pkgver`)
  + remove `--rmdeps` from default options (#508)
* `aur-pkglist`
  + do not require `-P` for regex match
  + Expose AUR URL through `AUR_LOCATION` environment variable
* `aur-rpc`
  + add `--rpc-ver`, `--rpc-url`
  + Expose AUR URL through `AUR_LOCATION` environment variable
* `aur-search`
  + exit 1 on no results
  + exit 2 on AUR error (e.g. "too many results")
  + Expose AUR URL through `AUR_LOCATION` environment variable
* `completion`
  + allow `zsh run-help` to display the correct man page (#506)

**Note:** `aur-vercmp-devel` will be removed on the next point-release, see issue #511.

## 2.1.0

This release restores some of the behavior from the 1.5 branch.

* `aur-sync`
  + add `--ignore-file` (same as `aursync --ignore`)
  + check the (`.SRCINFO`) dependency graph before file inspection
* `aur-depends`
  + now takes input as arguments, instead from `stdin`
  + add `--table`, `--pkgbase`, `--pkgname` and `--pkgname-all` (defaults to `--pkgname`)
* `aur-build` 
  + `--build-command` now works correctly
  + add `--run-pkgver` to run `makepkg -od` before `makepkg --pkglist` (relevant to VCS packages)
* `aur-search`
  + add `--raw` to display JSON output
* `aur-fetch-git` and `aur-fetch-snapshot` were removed and merged to `aur-fetch`

## 2.0.1

* `aur-sync`
  + add --keep-order for parallel aur-fetch
* `aur-build`
  + do not export PKGDEST for non-chroot builds (#498)                               
  + add --build-command (#498)
  + man page updates (#217)

## 2.0.0

Major changes:

* A new design based on `git(1)`. Programs are now run with the `aur` wrapper. For example, instead of `/usr/bin/aursync` you would run `/usr/bin/aur sync`, which calls `/usr/lib/aurutils/aur-sync`.
* Support for `repose` was removed. See https://bbs.archlinux.org/viewtopic.php?pid=1707649#p1707649 for migration instructions.
* VCS packages are now supported through the `aur-vercmp-devel` program.
* Packages can now be built in a container without using a local repository. The relevant functionality was moved to `aur-chroot`.
* Support for `bash` completion. `zsh` completions are not yet supported; see #458.
* `aurcheck` was replaced by `aur-repo`, a general tool to handle local repositories. 
* `aurqueue` was expanded to support virtual and versioned dependencies, and moved to `aur-graph`.
* Support for `aria2` and `curl` was removed, using `wget` as replacement.
* The `officer` program was removed; see `aur(1)` for a replacement.

Other changes:

* `aur-sync`
  + set the default value for `AURDEST` to `$XDG_CACHE_HOME/aurutils/sync`
  + fetch sources in parallel
  + support any file manager for file review through the `AUR_PAGER` environment variable
  + support `makepkg -A`
  + support diffs for `tar` snapshots
* `aur-search` 
  + more colorful output in the "brief" format
* Fixes for known issues in `1.5.3`.

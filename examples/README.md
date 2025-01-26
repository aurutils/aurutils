This directory contains simple examples which combine `aur(1)` programs. They
typically have fixed options, are expected to be modified by the user, and are
documented line-by-line.

## sync-devel

The aim of this script is to take all VCS (version control) packages in a local
repository, update the source files to the latest upstream revision, and build
them if there are any changes. VCS packages typically have `pkgver` set to the
upstream revision at the time of AUR package submission, and so are not
automatically updated by commands such as `aur-sync -u`.

The sample script retrieves the contents of the local repository with `aur-repo
--list`, and performs two updates:

1. Retrieve new AUR revisions with `aur-fetch(1)` and inspect them with
   `aur-view(1)`
2. Retrieve new upstream revisions with `aur-srcver(1)`

If PKGBUILD directories are not available in `AURDEST`, they are cloned anew
with `aur-fetch -e`. If the local repository exclusively contains AUR packages,
`aur-fetch` can be used without `--existing`.

The full version (`epoch:pkgver-pkgrel`) is then compared to the contents of the
local repository with `aur-vercmp(1)`. If there is an update, the package is
built with `aur-build(1)`.

## vercmp-devel

A simplified version of `sync-devel` which does only runs `aur-srcver` and
`aur-vercmp` on targets in the local repository.

Note: `aur-fetch` is not run in this script, and it is assumed all PKGBUILD
directories are available. This suggests to use a persistent directory for
`AURDEST`, instead of the default `$XDG_CACHE_HOME/aurutils/sync` used by
`aur-sync(1)`.

## sync-asroot

`aur-build` operates as a regular user, with the following exceptions:

* installation of package dependencies with `makepkg -s`;
* updating the local repository with `pacman -S`;
* interacting with an nspawn container with `aur-chroot`.

Instead of elevating to the root user for these tasks, `aur-build` can be run as
root, dropping privileges where necessary. `sync-asroot` does this by running
`makepkg`, `gpg`, `repo-add` and `aur-build--pkglist` with `runuser -u <user>`.
Sources are also retrieved this way with `runuser -u <user> aur sync`.

Other possible agents are `runuser`, `setpriv`, and `systemd-run`.

> **Note**
> Dropping privileges allows to restrict elevated commands during the build process.
>
> For example, if `sudo` is run in the same session as `makepkg` (for example through 
> `makepkg --syncdeps`), commands in the PKGBUILD or upstream sources may run `sudo` 
> without authorization for a period of `timeout_timestamp`. This defaults to 5 minutes.
>
> The following steps can be taken to avoid this:
>
> 1. specify a build user without `sudoers` access;
> 2. set `timeout_timestamp` to 0;
> 3. disable the `setuid` bit with `setpriv --no-new-privs`.
>
> **Warning**
> The considerations above do _not_ apply to chroot builds. Building packages with `makechrootpkg`
> gives the build process unfettered access to the host, regardless of how the build user is configured:
> 
> 1. `makechrootpkg` executes any commands contained in the user's `makepkg.conf(5)` as root;
> 2. arbitrary paths on the host can be overwritten with `makechrootpkg --bind`;
> 3. any pacman commands inside the nspawn container can be run with `sudo`, including `pacman -U`.

## sync-list

When using `aur-sync(1)` or `aur-build(1)`, packages accumulate in (one or
several) local repositories. To avoid unused packages, a list of packages can be
created such that the local repository only contains this list (and any
dependencies).

The script `sync-list` creates a copy of the local repository, and removes any
entries that are not part of the list or its dependencies with
`repo-remove`. Existing packages are symlinked in the temporary
directory. Targets are then passed to `aur-sync(1)`, with a temporary
`pacman.conf` file pointing to the temporary directory. Finally, the state is
transfered to the local repository with `rsync --delete`.

Other approaches include:

1. Only update the desired targets, e.g. `xargs -a list.txt aur sync` instead of
   `aur sync -u`
2. Recreate the local repository on every build
3. Use a "secondary" repository (e.g. `custom-testing`), moving packages to the
   "primary" repository after a certain time.

The second approach implies running `repo-add` for each package, which may be
slow for a large set of packages. The first alternative is sufficient to avoid
unused upgrades with `aur-sync -u`. Cleanups can then be done periodically:

```bash
$ grep -Fxvf list.txt <(aur repo --list | cut -f1) | xargs -r repo-purge -f custom
```

## sync-rebuild

Package rebuilds are commonly done when package dependencies are updated in an
incompatible way, such that the original package is no longer functional.
`pkgrel` increments ensure that the rebuilt packages are propagated to all
clients of the local repository.

Assuming a list of rebuild targets is known, `sync-rebuild` performs the
following steps:

1. Retrieve and inspect all source files with `aur sync`
2. Retrieve all versions of packages in the local repository
3. If `pkgver` matches the local repository version, set `pkgrel` in the
   `PKGBUILD` to the local repository version, incremented by `0.1`. Otherwise,
   leave the `PKGBUILD` unmodified.
4. Build the package with `aur-build`. If the build fails, restore the original
   `PKGBUILD`
5. Print any targets which are cached by `pacman` but not available in the local
   repository.

In step 3, the local repository version is written explicitly to the `PKGBUILD`
in case the incremented version is lost, or otherwise restored (e.g. with
`git-reset`). The fractional part is always increased; for example, a `pkgrel`
of `35.9` is increased to `35.10`, not `36`.

`aur-repo` can be used to retrieve a list of packages that depend on specific
package. For example:

```bash
aur repo --search '^python.*' --search-by depends --list
```

> **Note**
> By default, AUR packages are rebuilt in dependency order. When using
> `--no-sync` or non-AUR packages, targets are rebuilt in sequential order. In
> this case, `arch-rebuild-order` can be used as follows:
>
> `$ arch-rebuild-order --repos=custom <targets...>`
>
> If one dependency fails to build, `sync-rebuild` will try rebuilding the package
> that depends on it anyway. To avoid this, use the `--fail-fast` option.

## view-delta

`aur-view(1)` uses `vifm(1)` or a comparable file manager set in
`AUR_PAGER` to inspect and edit build files. 

`view-delta` assumes that files are not edited before the build process,
and takes the following approach:

1. display diffs side-by side with `git-delta`;
2. display remaining files with `bat` for syntax highlighting.

A pager (defaults to `less`) is used for navigation. To allow aborting
the inspection process with a non-zero exit code, a confirmation prompt
is displayed.

`view-delta` can be used as any other file manager taking a directory
argument:

```bash
view-delta <path to build files>  # directly
AUR_PAGER=view-delta aur view ... # with aur-view
AUR_PAGER=view-delta aur sync ... # with aur-view wrappers
```

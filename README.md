[![license](https://img.shields.io/github/license/aladw/aurutils)](LICENSE)
[![aur](https://img.shields.io/aur/version/aurutils)](https://aur.archlinux.org/packages/aurutils)

## SYNOPSIS

__aurutils__ is a collection of scripts to automate usage of the [Arch
User Repository](https://wiki.archlinux.org/index.php/Arch_User_Repository), 
with different tasks such as package searching, update checks, or computing 
dependencies kept separate.

The chosen approach for managing packages is local pacman
repositories, rather than foreign (installed by `pacman -U`)
packages.
  
## INSTALLATION

Install one of the following packages:

* [`aurutils`](https://aur.archlinux.org/packages/aurutils) for the
release version _(recommended)_.
* [`aurutils-git`](https://aur.archlinux.org/packages/aurutils-git)
for the master branch.

Upgrade notices are posted to the 
[Arch forums](https://bbs.archlinux.org/viewtopic.php?id=210621).
[(RSS)](https://bbs.archlinux.org/extern.php?action=feed&tid=210621&type=atom)

## USAGE

Documentation is included as [man pages](https://wiki.archlinux.org/title/Man_page)
with groff typesetting. They provide a general overview of the various utilities
with several examples.
Detailed instructions on how to set up a local repository can be found in the
section `CREATING A LOCAL REPOSITORY` of the [`aur(1)`](man1/aur.1) man page.

## TROUBLESHOOTING

__Verify the following in order when experiencing issues:__

1. Do you use the latest release of aurutils and its dependencies? If so, is the issue reproducible from the master branch?
2. Does the package conform to 
[`PKGBUILD(5)`](https://www.archlinux.org/pacman/PKGBUILD.5.html) and the 
[AUR package guidelines](https://wiki.archlinux.org/index.php/Arch_User_Repository#Submitting_packages)?
3. Does the package provide the correct metadata on the 
[AUR RPC interface](https://aur.archlinux.org/rpc.php)?
4. Does the package build with `makepkg -s` or `extra-x86_64-build` ?
5. Does the package use internal `makepkg` functions? (see [FS#43502](https://bugs.archlinux.org/task/43502))
6. Is the problem reproducible, and not due to a misconfiguration of
`pacman`, `makepkg`, `sudoers`, `gpg` or others?

__If yes to all, create a debug log:__

```
AUR_DEBUG=1 aur <name> <arguments> >aurutils.log 2>&1
```
and attach `aurutils.log` to a new [GitHub issue](https://github.com/aurutils/aurutils/issues).

For informal discussion, see the `#aurutils` channel on [Libera Chat](https://libera.chat/).
  

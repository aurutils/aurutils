## SYNOPSIS
  
![logo](06Nitori1.png)

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

The main binary is `aur`.

All further capabilities are called as commands of 
```sh
$ aur <command>
```

See:

```
[user@machine ~]$ aur
usage: aur [command]

available commands:
build		fetch		pkglist		rpc		sync
chroot		graph		repo		search		vercmp
depends		jobs		repo-filter	srcver		vercmp-devel

available user commands:

```

For most complete documentation check the [manual](https://github.com/JhonnyJason/aurutils/blob/master/man1/aur.1) ;-)

```sh
$ man aur
```

## VERSIONING

|Code changes||
|----|----|
|*Major changes*|Result in a bump of major version (`x.0.0`). Upgrades to a new major version may require a rewrite of interfacing software, or significant changes in workflow.|
|*Minor changes* (incompatible)|Result in a bump of minor version (`x.y.0`). Typically used when application names or command-line options change in a minor way.|
|*Minor changes* (compatible)|Result in a bump of maintenance version (`x.y.z`). Typically used for bug fixes or new, compatible features.|

## TROUBLESHOOTING

See [ISSUE_TEMPLATE.md](ISSUE_TEMPLATE.md). For informal discussion, see the 
`#aurutils` channel on [freenode](https://freenode.net/kb/answer/chat).

## SEE ALSO

The following (third-party) projects may be used together with `aurutils`:

* [aur-talk](https://aur.archlinux.org/packages/aur-talk-git/) - fetch and display AUR package comments (requires: [hq](https://www.archlinux.org/packages/community/x86_64/hq/))
* [aur-out-of-date](https://aur.archlinux.org/packages/aur-out-of-date/) - compare AUR to upstream version
* [aurto](https://aur.archlinux.org/packages/aurto/) - automatically update a local repository with trust management
* [rebuild-detector](https://aur.archlinux.org/packages/rebuild-detector/) - detects which packages need to be rebuilt

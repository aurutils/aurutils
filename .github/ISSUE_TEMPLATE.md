__Before filing a bug, check the following:__

1) Do you use the latest release of aurutils and its dependencies? If so,
is the issue reproducible from the master branch?
2) Does the package conform to 
[`PKGBUILD(5)`](https://www.archlinux.org/pacman/PKGBUILD.5.html) and the 
[AUR package guidelines](https://wiki.archlinux.org/index.php/Arch_User_Repository#Submitting_packages)?
3) Does the package provide the correct metadata on the 
[AUR RPC interface](https://aur.archlinux.org/rpc.php)?
4) Does the package build with `makepkg -s` or `extra-x86_64-build` ?
5) Does the package use internal `makepkg` functions? (see [FS#43502](https://bugs.archlinux.org/task/43502))
6) Is the problem reproducible, and not due to a misconfiguration of
`pacman`, `makepkg`, `sudoers`, `gpg` or others?

__If yes to all, create a debug log:__

```
AUR_DEBUG=1 aur <name> <arguments> >aurutils.log 2>&1
```

and attach aurutils.log to this issue.

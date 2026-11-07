# TODO: standalone aur-chroot

## Open issues

- **Mirrorlist bind mount on `--update`.** The host `/etc/pacman.d/mirrorlist`
  is bind-mounted over the container's. If the host file is byte-identical to
  the stock file, pacman replaces it when upgrading `pacman-mirrorlist`, which
  fails on a mount target. Low risk (host mirrorlists are usually edited);
  `arch-nspawn` copies the file instead.
- **Lock conversion is not atomic.** `-U -B` in one call converts the exclusive
  lock on `root.lock` to shared before building; another `--update` can run in
  between. The build then uses the newer container, which is harmless.
- **Stale comment.** The comment above the default config paths in
  `aur-chroot` refers to `$db_name` and `AUR_REPO`. Predates standalone mode.
- **PGP and SSH sources.** `GNUPGHOME` and `SSH_AUTH_SOCK` are not available
  inside the container, so `validpgpkeys` and git+ssh sources fail. Documented
  under BUGS in aur-chroot(1). Sources must not be retrieved on the host.
- **`aur-build` and `--run`.** `aur-build` still runs `makepkg --packagelist`
  (and `makepkg -od` with `--pkgver`) on the host. Switching to
  `aur chroot --run` requires mapping `/pkgdest/...` paths back to the host
  `PKGDEST`.

## To verify on Arch

- End-to-end standalone run (`AUR_CHROOT_DEVTOOLS=0`): `--create`, `-U`,
  `-B`, `-B -N`, `--run makepkg --packagelist`.
- Two concurrent builds plus an `--update`: builds run in parallel, the update
  waits, and `/root` is unchanged after the builds.
- Elevation through run0 (`AUR_PACMAN_AUTH=run0`), including preserved
  variables and the working directory.

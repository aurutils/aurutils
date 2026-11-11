# TODO: standalone aur-chroot

## Open issues

- **Mirrorlist bind mount on `--update`.** The host `/etc/pacman.d/mirrorlist`
  is bind-mounted over the container's. If the host file is byte-identical to
  the stock file, pacman replaces it when upgrading `pacman-mirrorlist`, which
  fails on a mount target. Low risk (host mirrorlists are usually edited);
  `arch-nspawn` copies the file instead.
  The same applies to `pacman.conf`, `makepkg.conf` and `makepkg.conf.d` files
  of the same name as a packaged one. Since builds run `pacman -Syuu` in the
  overlay, `--build` is affected as well.
- **Lock conversion is not atomic.** `-U -B` in one call converts the exclusive
  lock on `root.lock` to shared before building; another `--update` can run in
  between. The build then uses the newer container, which is harmless.
- **Stale comment.** The comment above the default config paths in
  `aur-chroot` refers to `$db_name` and `AUR_REPO`. Predates standalone mode.
- **PGP and SSH sources.** `GNUPGHOME` and `SSH_AUTH_SOCK` are not available
  inside the container, so `validpgpkeys` and git+ssh sources fail. Documented
  under BUGS in aur-chroot(1). Sources must not be retrieved on the host.
  Both variables are still passed with `--setenv` on re-exec, without use.
- **`--run` detection is literal.** Option parsing only stops at the command
  if an argument equals `--run`. An abbreviation accepted by getopt (`--ru`)
  is missed, and options of the command are parsed as `aur-chroot` options.
  `--run` as option argument (`-D --run`) is detected falsely.
- **Colons in bind mount paths.** `$PWD`, `PKGDEST`, `LOGDEST`, `SRCDEST`,
  `SRCPKGDEST`, `CacheDir` and `file://` paths are passed to `--bind` and
  `--bind-ro` unescaped. systemd-nspawn requires `\:` for a colon in a path.
- **makepkg directories override `makepkg.conf`.** `PKGDEST`, `LOGDEST`,
  `SRCDEST` and `SRCPKGDEST` are set to `$PWD` in the container if unset on
  the host. The environment takes precedence, so values in the `makepkg.conf`
  of the container are ignored. Not documented in aur-chroot(1).
- **`--holdver` is not documented** in aur-chroot(1). (`--nocheck` and
  `--ignorearch` are not either, which predates standalone mode.)
- **`aur-build` and `--run`.** `aur-build` still runs `makepkg --packagelist`
  (and `makepkg -od` with `--pkgver`) on the host. `aur chroot --run` prints
  host paths, since `PKGDEST` is mounted to the same path in the container.

## To verify on Arch

- End-to-end standalone run (`AUR_CHROOT_DEVTOOLS=0`): `--create`, `-U`,
  `-B`, `-B -N`, `--run makepkg --packagelist`.
- Two concurrent builds plus an `--update`: builds run in parallel, the update
  waits, and `/root` is unchanged after the builds.
- `--register=no --machine=aur-chroot-$$` allows two containers at once.
  Builds take the shared tree lock of systemd-nspawn (`--volatile` implies
  `--read-only`), `--create` and `--update` the exclusive one.
- A failed `--create` (e.g. interrupted pacstrap) leaves a tree without
  `.arch-chroot`, which is rejected with a diagnostic.
- Links in the build directory point to the host `PKGDEST` after a build
  with `PKGDEST` set.
- `--setenv` on re-exec with sudo (without `SETENV` in sudoers), run0 and
  doas; `AUR_DEBUG` traces the root process.
- Elevation through run0 (`AUR_PACMAN_AUTH=run0`), including preserved
  variables and the working directory. The root process uses `$PWD` as
  `BUILDDIR`, for `--chdir` and as bind mount; if run0 does not keep the
  working directory, builds run in the wrong directory. A relative
  `${BASH_SOURCE[0]}` on re-exec fails in the same case.

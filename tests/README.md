# Tests

* `lib/`: tests for `lib/` scripts, run through `aur` with `make test`
* `issue/`: regression tests named after GitHub issues; most require the
  live AUR, `0085` builds and installs a package 10 times
* `json/`: AUR responses and other input for `lib/` tests (see `json/README.md`)
* `bin/`: stand-ins for external commands, e.g. `curl` answering AUR
  requests from a file in `json/` set with `AUR_TEST_FIXTURE`
* `run`: run tests or directories of tests, print `OK` or `FAIL` and the
  output of failed tests, exit 1 on any failure:

      tests/run tests/lib tests/issue/0378

* `parseopt-consistency`: `--dump-options` matches each script's option loop
* `completion-bash`: bash completion offers every command and option

## Packages

AUR packages for manual testing of `aur depends` and `aur sync`:

```
# split packages - independent
python-pyalsaaudio 

# split packages - pkgbase does not match pkgname
fasm-linux-git 
hnwatch

# empty make/depends
ros-build-tools

# dependency order (#414)
curr

# dependency order
pyneighborhood

# special characters
c++utilities

# split package - multiple packages from same package base
clion

# split package - depends on package from same package base
jellyfin

# make/depends_arch
openrct2-git

# cyclic dependencies - required removal of makedeps
#mingw-w64-gcc-base

# 200+ depends 
ros-noetic-desktop

# contain dependency cycles if checkdepends is considered
ruby-activemodel

# equality constraint in checkdepends
python2-cryptography
```

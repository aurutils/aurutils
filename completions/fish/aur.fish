# Fish completion for aurutils (aur wrapper)
#
# Transcribed from the zsh completion with parity as close as
# fish's model allows. Third-party aur-<subcommand> extensions
# are expected to ship their own completions.

# ---- helpers ----------------------------------------------------

function __aur_list_packages
    aur pkglist --ttl 86400 --systime --plain 2>/dev/null
end

function __aur_list_pkgbases
    aur pkglist --ttl 86400 --systime --plain --pkgbase 2>/dev/null
end

function __aur_list_repos
    aur repo --repo-list 2>/dev/null
end

function __aur_list_all_repos
    pacconf --repo-list 2>/dev/null
end

function __aur_list_local_packages
    for repo in (aur repo --list-repo 2>/dev/null)
        aur repo -lq -d $repo 2>/dev/null | cut -f1
    end
end

function __aur_list_attributes
    aur repo --list-attr 2>/dev/null
end

# ---- subcommands ------------------------------------------------

complete -c aur -f -n __fish_use_subcommand -a build       -d "build packages to a local repository"
complete -c aur -f -n __fish_use_subcommand -a chroot      -d "build pacman packages with systemd-nspawn"
complete -c aur -f -n __fish_use_subcommand -a depends     -d "retrieve dependencies using aurweb"
complete -c aur -f -n __fish_use_subcommand -a fetch       -d "fetch packages from a location"
complete -c aur -f -n __fish_use_subcommand -a format      -d "parse JSON input"
complete -c aur -f -n __fish_use_subcommand -a graph       -d "print package/dependency directed graph"
complete -c aur -f -n __fish_use_subcommand -a pkglist     -d "print the AUR package list"
complete -c aur -f -n __fish_use_subcommand -a query       -d "send requests to the aurweb RPC interface"
complete -c aur -f -n __fish_use_subcommand -a repo-parse  -d "parse contents of pacman repositories"
complete -c aur -f -n __fish_use_subcommand -a repo-filter -d "filter packages in the Arch Linux repositories"
complete -c aur -f -n __fish_use_subcommand -a repo        -d "manage local repositories"
complete -c aur -f -n __fish_use_subcommand -a search      -d "search for AUR packages"
complete -c aur -f -n __fish_use_subcommand -a srcver      -d "list version of VCS packages"
complete -c aur -f -n __fish_use_subcommand -a sync        -d "download and build AUR packages automatically"
complete -c aur -f -n __fish_use_subcommand -a vercmp      -d "check packages for AUR updates"
complete -c aur -f -n __fish_use_subcommand -a view        -d "inspect git repositories"
complete -c aur -f -n __fish_use_subcommand -l version     -d "display version"

# ---- shared build/sync flags ------------------------------------

set -l build_sync "__fish_seen_subcommand_from build sync"

complete -c aur -n $build_sync -l margs          -d "extra makepkg arguments (comma-sep)" -x
complete -c aur -n $build_sync -l makepkg-args   -d "extra makepkg arguments (comma-sep)" -x
complete -c aur -n $build_sync -l makepkg-conf   -d "makepkg.conf to use" -r
complete -c aur -n $build_sync -s A -l ignore-arch -d "ignore arch field"
complete -c aur -n $build_sync -s c -l chroot    -d "build inside systemd-nspawn"
complete -c aur -n $build_sync -s D -l directory -d "base directory for containers" -xa "(__fish_complete_directories)"
complete -c aur -n $build_sync -s f -l force     -d "continue if package already exists"
complete -c aur -n $build_sync -s L -l log       -d "enable logging to build directory"
complete -c aur -n $build_sync -s n -l no-confirm -d "do not wait for user input"
complete -c aur -n $build_sync -s r -l rmdeps    -d "remove deps installed by makepkg"
complete -c aur -n $build_sync -s S -l sign      -d "sign packages and database with gpg"
complete -c aur -n $build_sync -l gpg-sign       -d "sign packages and database with gpg"
complete -c aur -n $build_sync -s T -l temp      -d "build in a temporary container"
complete -c aur -n $build_sync -s U -l user      -d "run makepkg as user" -xa "(__fish_complete_users)"
complete -c aur -n $build_sync -l bind-rw        -d "bind dir read-write to container" -xa "(__fish_complete_directories)"
complete -c aur -n $build_sync -l bind           -d "bind dir read-only to container"  -xa "(__fish_complete_directories)"
complete -c aur -n $build_sync -l new                   -d "only add packages not in DB"
complete -c aur -n $build_sync -l prevent-downgrade     -d "do not downgrade existing packages"
complete -c aur -n $build_sync -s R -l remove           -d "remove old package files from disk"
complete -c aur -n $build_sync -s v -l verify           -d "verify PGP signature of the database"
complete -c aur -n $build_sync -l pacman-conf     -d "pacman.conf for syncing" -r
complete -c aur -n $build_sync -l root            -d "repository root directory" -xa "(__fish_complete_directories)"
complete -c aur -n $build_sync -s d -l database   -d "name of the pacman database" -xa "(__aur_list_repos)"

# ---- aur-build --------------------------------------------------

set -l build "__fish_seen_subcommand_from build"
complete -c aur -n $build -s a -l arg-file   -d "file listing PKGBUILD directories" -r
complete -c aur -n $build -l dry-run         -d "display package names without building"
complete -c aur -n $build -l no-sync         -d "do not sync local repository after building"
complete -c aur -n $build -l pkgver          -d "run makepkg -od before checking existing packages"
complete -c aur -n $build -s N -l namcap     -d "run namcap on build package"
complete -c aur -n $build -l checkpkg        -d "run checkpkg on build package"
complete -c aur -n $build -l no-check        -d "skip check() in PKGBUILD"
complete -c aur -n $build -s s -l syncdeps   -d "install missing deps via pacman"
complete -c aur -n $build -s C -l clean      -d "clean leftover files after success"
complete -c aur -n $build -l buildscript     -d "use an alternate build script" -r

# ---- aur-chroot -------------------------------------------------

set -l chroot "__fish_seen_subcommand_from chroot"
complete -c aur -n $chroot -s B -l build     -d "build inside container with makechrootpkg"
complete -c aur -n $chroot -s U -l update    -d "update /root copy with arch-nspawn"
complete -c aur -n $chroot -l create         -d "create new container with mkarchroot"
complete -c aur -n $chroot -l bind-rw        -d "bind dir read-write" -xa "(__fish_complete_directories)"
complete -c aur -n $chroot -l bind           -d "bind dir read-only" -xa "(__fish_complete_directories)"
complete -c aur -n $chroot -s D -l directory -d "base directory for containers" -xa "(__fish_complete_directories)"
complete -c aur -n $chroot -l makechrootpkg-args -d "extra makechrootpkg args (comma-sep)" -x
complete -c aur -n $chroot -l cargs              -d "extra makechrootpkg args (comma-sep)" -x
complete -c aur -n $chroot -l makepkg-args       -d "extra makepkg args (comma-sep)" -x
complete -c aur -n $chroot -l margs              -d "extra makepkg args (comma-sep)" -x
complete -c aur -n $chroot -s M -l makepkg-conf  -d "makepkg.conf inside container" -r
complete -c aur -n $chroot -l path               -d "print container template path"
complete -c aur -n $chroot -s C -l pacman-conf   -d "pacman.conf inside container" -r
complete -c aur -n $chroot -s x -l suffix        -d "path SUFFIX in pacman config" -x
complete -c aur -n $chroot -xa "(__aur_list_packages)"

# ---- aur-depends ------------------------------------------------

set -l depends "__fish_seen_subcommand_from depends"
complete -c aur -n $depends -l no-checkdepends -d "ignore checkdepends"
complete -c aur -n $depends -l no-depends      -d "ignore depends"
complete -c aur -n $depends -l no-makedepends  -d "ignore makedepends"
complete -c aur -n $depends -l optdepends      -d "include optdepends"
complete -c aur -n $depends -s G -l graph      -d "print edges to stdout"
complete -c aur -n $depends -s b -l pkgbase    -d "print pkgbase in total order"
complete -c aur -n $depends -s n -l pkgname    -d "print pkgname in total order"
complete -c aur -n $depends -s a -l pkgname-all -d "print pkgname in total order (incl. foreign)"
complete -c aur -n $depends -s t -l table      -d "output as tab-separated table"
complete -c aur -n $depends -xa "(__aur_list_packages)"

# ---- aur-fetch --------------------------------------------------

set -l fetch "__fish_seen_subcommand_from fetch"
complete -c aur -n $fetch -l existing        -d "skip packages missing on AUR"
complete -c aur -n $fetch -s r -l recurse    -d "also fetch dependencies"
complete -c aur -n $fetch -l results         -d "write colon-delimited output to FILE" -r
complete -c aur -n $fetch -l discard         -d "discard uncommitted changes on rebase/merge"
complete -c aur -n $fetch -l rebase          -d "alias for --sync=rebase"
complete -c aur -n $fetch -l reset           -d "alias for --sync=reset"
complete -c aur -n $fetch -l fetch-only      -d "alias for --sync=fetch"
complete -c aur -n $fetch -l sync            -d "sync mode" -xa "reset merge rebase fetch"
complete -c aur -n $fetch -xa "(__aur_list_pkgbases)"

# ---- aur-graph --------------------------------------------------

complete -c aur -n "__fish_seen_subcommand_from graph" -r

# ---- aur-pkglist ------------------------------------------------

set -l pkglist "__fish_seen_subcommand_from pkglist"
complete -c aur -n $pkglist -s b -l pkgbase      -d "retrieve pkgbase.gz"
complete -c aur -n $pkglist -l users             -d "retrieve users.gz"
complete -c aur -n $pkglist -s i -l info         -d "retrieve AUR metadata (info)"
complete -c aur -n $pkglist -s s -l search       -d "retrieve AUR metadata (search)"
complete -c aur -n $pkglist -s F -l fixed-strings -d "treat pattern as fixed-string list"
complete -c aur -n $pkglist -s P -l perl-regexp  -d "treat pattern as PCRE"
complete -c aur -n $pkglist -l plain             -d "print the list to stdout (default)"
complete -c aur -n $pkglist -s J -l json         -d "treat pattern as jq expression"
complete -c aur -n $pkglist -s q -l quiet        -d "update list, print only its path"
complete -c aur -n $pkglist -s t -l ttl          -d "seconds before list is refreshed" -x
complete -c aur -n $pkglist -s v -l verify       -d "verify checksums with sha256sum"

# ---- aur-query --------------------------------------------------

set -l query "__fish_seen_subcommand_from query"
complete -c aur -n $query -s b -l by   -d "search field" -xa "name name-desc maintainer depends makedepends optdepends checkdepends"
complete -c aur -n $query -s r -l raw  -d "do not process results"
complete -c aur -n $query -s t -l type -d "request type" -xa "search info"
complete -c aur -n $query -xa "(__aur_list_packages)"

# ---- aur-repo ---------------------------------------------------

set -l repo "__fish_seen_subcommand_from repo"
complete -c aur -n $repo -s F -l attr       -d "list attribute ATTR" -xa "(__aur_list_attributes)"
complete -c aur -n $repo -s l -l list       -d "list contents of local repository"
complete -c aur -n $repo -s t -l table      -d "list contents with more detail"
complete -c aur -n $repo -s J -l json       -d "list in JSON format"
complete -c aur -n $repo -s f -l format     -d "format output by key" -xa "%a %b %c %C %d %D %e %f %F %g %M %n %O %P %U %v"
complete -c aur -n $repo -l list-path       -d "list paths of configured repositories"
complete -c aur -n $repo -l list-repo       -d "list names of configured repositories"
complete -c aur -n $repo -l list-attr       -d "list valid repo-add attributes"
complete -c aur -n $repo -l path            -d "list resolved path of selected repo"
complete -c aur -n $repo -s u -l upgrades   -d "check updates with aur-vercmp"
complete -c aur -n $repo -s a -l all        -d "use aur-vercmp --all when checking upgrades"
complete -c aur -n $repo -l status          -d "print status to stdout"
complete -c aur -n $repo -s c -l config     -d "alternate pacman.conf" -r
complete -c aur -n $repo -s d -l database   -d "name of pacman repository" -xa "(__aur_list_repos)"
complete -c aur -n $repo -l repo            -d "name of pacman repository" -xa "(__aur_list_repos)"
complete -c aur -n $repo -s q -l quiet      -d "only print package names"
complete -c aur -n $repo -s r -l root       -d "root of local repository" -xa "(__fish_complete_directories)"
complete -c aur -n $repo -s S -l sync       -d "query repositories in DBPATH/sync"

# ---- aur-repo-filter --------------------------------------------

set -l repofilter "__fish_seen_subcommand_from repo-filter"
complete -c aur -n $repofilter -s a -l all     -d "query all pacman repositories"
complete -c aur -n $repofilter -l sync         -d "query all pacman repositories"
complete -c aur -n $repofilter -l config       -d "alternate pacman.conf" -r
complete -c aur -n $repofilter -s d -l database -d "restrict to pacman repository" -xa "(__aur_list_all_repos)"
complete -c aur -n $repofilter -l sysroot      -d "alternate system root" -xa "(__fish_complete_directories)"

# ---- aur-search -------------------------------------------------

set -l search "__fish_seen_subcommand_from search"
complete -c aur -n $search -s i -l info        -d "use the info interface"
complete -c aur -n $search -s s -l search      -d "use the searchby interface (default)"
complete -c aur -n $search -s f -l format      -d "format output by key" -xa "%b %c %C %d %D %e %g %K %L %m %M %n %o %O %p %P %S %U %v %w"
complete -c aur -n $search -s q -l short       -d "display only name, version, description"
complete -c aur -n $search -s v -l verbose     -d "display more package information"
complete -c aur -n $search -l table            -d "display output in tsv format"
complete -c aur -n $search -s a -l any         -d "union of results, not intersection"
complete -c aur -n $search -s r -l json        -d "display results as json"
complete -c aur -n $search -s k -l key         -d "sort results by key" -xa "Name Version NumVotes Description PackageBase URL Popularity OutOfDate Maintainer FirstSubmitted LastModified"
complete -c aur -n $search -s d -l desc        -d "search by name and description"
complete -c aur -n $search -s m -l maintainer  -d "search by maintainer"
complete -c aur -n $search -s n -l name        -d "search by name"
complete -c aur -n $search -l depends          -d "search in depends"
complete -c aur -n $search -l makedepends      -d "search in makedepends"
complete -c aur -n $search -l optdepends       -d "search in optdepends"
complete -c aur -n $search -l checkdepends     -d "search in checkdepends"

# ---- aur-srcver -------------------------------------------------

set -l srcver "__fish_seen_subcommand_from srcver"
complete -c aur -n $srcver -l buildscript  -d "use an alternate build script" -r
complete -c aur -n $srcver -s j -l jobs    -d "number of parallel makepkg processes" -x
complete -c aur -n $srcver -l no-prepare   -d "do not run prepare()"
complete -c aur -n $srcver -xa "(__aur_list_pkgbases)"

# ---- aur-sync ---------------------------------------------------

set -l sync "__fish_seen_subcommand_from sync"
complete -c aur -n $sync -l continue       -d "do not download package files"
complete -c aur -n $sync -l format         -d "diff view mode" -xa "diff log"
complete -c aur -n $sync -l ignore-file    -d "FILE listing package upgrades to ignore" -r
complete -c aur -n $sync -l no-check       -d "do not handle checkdepends"
complete -c aur -n $sync -l no-graph       -d "do not verify AUR dependency graph"
complete -c aur -n $sync -l no-view        -d "do not present build files for inspection"
complete -c aur -n $sync -l pkgver         -d "run makepkg -od --noprepare before build"
complete -c aur -n $sync -l provides-from  -d "directories listing virtual deps" -xa "(__fish_complete_directories)"
complete -c aur -n $sync -l no-provides    -d "ignore virtual deps in pacman repos"
complete -c aur -n $sync -s o -l no-build  -d "print target packages and paths only"
complete -c aur -n $sync -s u -l upgrades  -d "update all obsolete AUR packages"
complete -c aur -n $sync -l ignore         -d "package to ignore" -xa "(__aur_list_local_packages)"
complete -c aur -n $sync -l no-ver         -d "disable version checking"
complete -c aur -n $sync -l no-ver-argv    -d "disable version checking for argv / --upgrades"
complete -c aur -n $sync -l rebuild        -d "alias for -f --no-ver-argv"
complete -c aur -n $sync -l rebuild-all    -d "alias for -f --no-ver"
complete -c aur -n $sync -l rebuild-tree   -d "rebuild-all + all repo packages as targets"
complete -c aur -n $sync -xa "(__aur_list_packages)"

# ---- aur-vercmp -------------------------------------------------

set -l vercmp "__fish_seen_subcommand_from vercmp"
complete -c aur -n $vercmp -s a -l all     -d "show older-or-equal AUR versions"
complete -c aur -n $vercmp -s c -l current -d "print equal-or-newer packages to stdout"
complete -c aur -n $vercmp -s p -l path    -d "read package versions from FILE" -r
complete -c aur -n $vercmp -s q -l quiet   -d "only print package names"
complete -c aur -n $vercmp -s u -l upair   -d "print unpairable lines from file NUM" -xa "1 2"

# ---- aur-view ---------------------------------------------------

set -l view "__fish_seen_subcommand_from view"
complete -c aur -n $view -l format         -d "diff mode" -xa "diff log"
complete -c aur -n $view -s a -l arg-file  -d "file listing git repositories" -r
complete -c aur -n $view -l revision       -d "revision used for comparison" -x
complete -c aur -n $view -l no-patch       -d "suppress patch, show only summary"

#!/bin/bash

have_optdump=('build' 'chroot' 'fetch' 'pkglist' 'repo' 'repo-filter'
              'srcver' 'sync' 'vercmp' 'view')
no_optdump=('graph' 'format' 'repo-parse' 'query' 'depends' 'search')

default_opts() {
    local cmd corecommands=() opts=()

    for cmd in "${have_optdump[@]}"; do
        mapfile -t opts < <(find ../lib -type f -name "aur-$cmd" -exec bash -- {} --dump-options ';' | LC_ALL=C sort)
        corecommands+=("default_cmds[${cmd}]='${opts[*]}'")
    done

    for cmd in "${no_optdump[@]}"; do
        corecommands+=("default_cmds[${cmd}]=''")
    done

    printf '    %s\n' "${corecommands[@]}"

    emit_metadata
}

# Metadata tables, transcribed from the zsh completion so the bash
# template can dispatch typed completers and static choice sets.
# Keys are "$cmd,$flag". Types: file, dir, repo, pkgname, pkgbase,
# local_pkg, user, attr. Missing entries fall back to file completion.
emit_metadata() {
    local data=(
        # aur-build
        "arg_types[build,--arg-file]='file'"
        "arg_types[build,-a]='file'"
        "arg_types[build,--database]='repo'"
        "arg_types[build,-d]='repo'"
        "arg_types[build,--root]='dir'"
        "arg_types[build,--makepkg-conf]='file'"
        "arg_types[build,--pacman-conf]='file'"
        "arg_types[build,--directory]='dir'"
        "arg_types[build,-D]='dir'"
        "arg_types[build,--user]='user'"
        "arg_types[build,-U]='user'"
        "arg_types[build,--bind]='dir'"
        "arg_types[build,--bind-rw]='dir'"
        "arg_types[build,--buildscript]='file'"

        # aur-chroot
        "arg_types[chroot,--bind]='dir'"
        "arg_types[chroot,--bind-rw]='dir'"
        "arg_types[chroot,--directory]='dir'"
        "arg_types[chroot,-D]='dir'"
        "arg_types[chroot,--makepkg-conf]='file'"
        "arg_types[chroot,-M]='file'"
        "arg_types[chroot,--pacman-conf]='file'"
        "arg_types[chroot,-C]='file'"
        "positional[chroot]='pkgname'"

        # aur-depends
        "positional[depends]='pkgname'"

        # aur-fetch
        "arg_types[fetch,--results]='file'"
        "choices[fetch,--sync]='reset merge rebase fetch'"
        "positional[fetch]='pkgbase'"

        # aur-pkglist: no typed args, positional is a free pattern

        # aur-query
        "choices[query,--by]='name name-desc maintainer depends makedepends optdepends checkdepends'"
        "choices[query,-b]='name name-desc maintainer depends makedepends optdepends checkdepends'"
        "choices[query,--type]='search info'"
        "choices[query,-t]='search info'"
        "positional[query]='pkgname'"

        # aur-repo
        "arg_types[repo,--attr]='attr'"
        "arg_types[repo,-F]='attr'"
        "arg_types[repo,--config]='file'"
        "arg_types[repo,-c]='file'"
        "arg_types[repo,--database]='repo'"
        "arg_types[repo,-d]='repo'"
        "arg_types[repo,--repo]='repo'"
        "arg_types[repo,--root]='dir'"
        "arg_types[repo,-r]='dir'"
        "choices[repo,--format]='%a %b %c %C %d %D %e %f %F %g %M %n %O %P %U %v'"
        "choices[repo,-f]='%a %b %c %C %d %D %e %f %F %g %M %n %O %P %U %v'"

        # aur-repo-filter
        "arg_types[repo-filter,--config]='file'"
        "arg_types[repo-filter,--database]='repo'"
        "arg_types[repo-filter,-d]='repo'"
        "arg_types[repo-filter,--sysroot]='dir'"

        # aur-search
        "choices[search,--format]='%b %c %C %d %D %e %g %K %L %m %M %n %o %O %p %P %S %U %v %w'"
        "choices[search,-f]='%b %c %C %d %D %e %g %K %L %m %M %n %o %O %p %P %S %U %v %w'"
        "choices[search,--key]='Name Version NumVotes Description PackageBase URL Popularity OutOfDate Maintainer FirstSubmitted LastModified'"
        "choices[search,-k]='Name Version NumVotes Description PackageBase URL Popularity OutOfDate Maintainer FirstSubmitted LastModified'"

        # aur-srcver
        "arg_types[srcver,--buildscript]='file'"
        "positional[srcver]='pkgbase'"

        # aur-sync (inherits build-shared args)
        "arg_types[sync,--arg-file]='file'"
        "arg_types[sync,-a]='file'"
        "arg_types[sync,--database]='repo'"
        "arg_types[sync,-d]='repo'"
        "arg_types[sync,--root]='dir'"
        "arg_types[sync,--makepkg-conf]='file'"
        "arg_types[sync,--pacman-conf]='file'"
        "arg_types[sync,--directory]='dir'"
        "arg_types[sync,-D]='dir'"
        "arg_types[sync,--user]='user'"
        "arg_types[sync,-U]='user'"
        "arg_types[sync,--bind]='dir'"
        "arg_types[sync,--bind-rw]='dir'"
        "arg_types[sync,--ignore-file]='file'"
        "delim_types[sync,--ignore]=',:local_pkg'"
        "delim_types[sync,--provides-from]=',:dir'"
        "choices[sync,--format]='diff log'"
        "positional[sync]='pkgname'"

        # aur-vercmp
        "arg_types[vercmp,--path]='file'"
        "arg_types[vercmp,-p]='file'"
        "choices[vercmp,--upair]='1 2'"
        "choices[vercmp,-u]='1 2'"

        # aur-view
        "arg_types[view,--arg-file]='file'"
        "arg_types[view,-a]='file'"
        "choices[view,--format]='diff log'"
        "positional[view]='dir'"
    )
    printf '    %s\n' "${data[@]}"
}

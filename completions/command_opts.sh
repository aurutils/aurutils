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
}

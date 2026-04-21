#!/bin/bash

have_optdump=('build' 'chroot' 'depends' 'fetch' 'format' 'pkglist'
              'query' 'repo' 'repo-filter' 'repo-parse' 'search'
              'srcver' 'sync' 'vercmp' 'view')
no_optdump=('graph')

default_opts() {
    local cmd corecommands=() opts=() script

    for cmd in "${have_optdump[@]}"; do
        script=$(find ../lib -type f -name "aur-$cmd" | head -1)
        [[ -f $script ]] || continue
        mapfile -t opts < <(PERL5LIB=../perl "$script" --dump-options 2>/dev/null | LC_ALL=C sort)
        corecommands+=("default_cmds[${cmd}]='${opts[*]}'")
    done

    for cmd in "${no_optdump[@]}"; do
        corecommands+=("default_cmds[${cmd}]=''")
    done

    printf '    %s\n' "${corecommands[@]}"
}

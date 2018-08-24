source /usr/share/makepkg/util/message.sh

db_namever() {
    awk '/%NAME%/ {
        getline
        printf("%s\t", $1)
    }
    /%VERSION%/ {
        getline
        printf("%s\n", $1)
    }'
}

db_fill_empty() {
    awk '{print} END {
        if (!NR)
            printf("%s\t%s\n", "(none)", "(none)")
    }'
}


conf_file_repo() {
    awk -F'= ' '
        $1 ~ /^\[.+\]$/ {
            repo = substr($1, 2, length($1)-2)
        }
        $1 ~ /^Server/ && $2 ~ /^file:/ {
            printf("%s\n%s\n", repo, $2)
        }'
}

autodetect_db() {
    local conf
    mapfile -t conf < <(pacconf | conf_file_repo)

    case ${#conf[@]} in
        2) export AUR_REPO=${conf[0]}
           export AUR_DBROOT=${conf[1]#*://} ;;
        0) error "$argv0: no file:// repository found"
           exit 2 ;;
        *) error "$argv0: repository choice is ambiguous (use --repo to specify)"
           printf '%s\n' "${conf[@]}" | paste - - | column -t >&2
           exit 2 ;;
    esac
}

get_db() {
    if [[ -n "$AUR_REPO" && -z "$AUR_DBROOT" ]]; then
        AUR_DBROOT=$(pacconf --repo="$repo" Server | grep -Em1 '^file://' || true)
        AUR_DBROOT=${AUR_DBROOT#file://}
        if [[ -z "$AUR_DBROOT" ]]; then
            error "$argv0: could not autodetect the root of repo $AUR_REPO"
            exit 2
        fi
    elif [[ -z "$AUR_REPO" && -z "$AUR_DBROOT" ]]; then
        autodetect_db
    elif [[ -z "$AUR_REPO" && -n "$AUR_DBROOT" ]]; then
        error "$argv0: cannot set the repo root without setting the repo name"
        exit 2
    fi
    export AUR_REPO AUR_DBROOT
}

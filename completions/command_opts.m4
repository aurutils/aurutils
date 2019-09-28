divert(-1)dnl
dnl List of commands to be completed
dnl
define(`CORECOMMANDS',
HAVE_OPTDUMP(build,depends,fetch,pkglist,repo,repo-filter,query,search,srcver,sync,vercmp)dnl
NO_OPTDUMP(graph,vercmp-devel))

dnl recursively print all elements
dnl How the element is ultimately printed depends on the
dnl wrap_has_dump and wrap_no_dump macros
dnl
define(`HAVE_OPTDUMP',`ifelse(`$#',`0', ,`$#',`1',`wrap_has_dump(`$1') ',`wrap_has_dump($1)' `HAVE_OPTDUMP(shift($@))')')
define(`NO_OPTDUMP',`ifelse(`$#',`0', ,`$#',`1',`wrap_no_dump(`$1') ',`wrap_no_dump($1)' `NO_OPTDUMP(shift($@))')')

dnl override how elements are printed for the DEFAULT_OPTS
dnl which is a simple function that returns the options available for a
dnl subcommand using case statement construct.
dnl
pushdef(`wrap_has_dump',`
    default_cmds[$1]=GET_OPTS($1)')
pushdef(`wrap_no_dump',`
    default_cmds[$1]=""')
define(DEFAULT_OPTS,
`typeset -A default_cmds
CORECOMMANDS')

dnl Helper macro to retrieves options from subcommand --dump-options
dnl
define(GET_OPTS,'`translit(esyscmd(bash -c "../lib/aur-$1 --dump-options | LC_ALL=C sort"),`
',` ')'')
divert(0)dnl

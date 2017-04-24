_run() {
    local cur=${COMP_WORDS[COMP_CWORD]}
    COMPREPLY=()
    case $COMP_CWORD in
        1)
            COMPREPLY=(`compgen -c "$cur"`)
            ;;
        *)
            COMPREPLY=(`compgen -o default "$cur"`)
            ;;
    esac
}

complete -o filenames -F _run run

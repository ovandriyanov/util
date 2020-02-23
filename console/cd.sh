#!/bin/bash

function cd() {
    builtin cd "$@" || return $?
    [ -z "${VIM_TERMINAL}" ] && return
    printf "\\e]51;[\"call\", \"Tapi_Chdir\", \"${PWD}\"]\\x07"
}

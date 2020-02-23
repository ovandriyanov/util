#!/bin/bash

function c() {
    if [ -z ${1} ]; then
        cd
        return
    fi

    EXPANDED_PATH="`EP_CONFIG_PATH=${HOME}/.vim/path_aliases ${HOME}/bin/expand-path ${1}`"
    [ -n "${EXPANDED_PATH}" ] && cd ${EXPANDED_PATH}
}

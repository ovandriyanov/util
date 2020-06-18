#!/bin/bash

function c() {
    if [ -z ${1} ]; then
        cd
        return
    fi

    EXPANDED_PATH="`${HOME}/bin/expand-path ${1}`"
    EXPANDED_PATH="`bash -c \"echo ${EXPANDED_PATH}\"`"
    [ -n "${EXPANDED_PATH}" ] && cd ${EXPANDED_PATH}
}

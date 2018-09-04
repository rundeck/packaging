# Wraps bash command in code folding and timing "stamps"
script_block() {
    local NAME="${1}"; shift;
    local COMMAND="${@}"

    # Return from 
    local ret

    travis_fold start "${NAME}"
        travis_time_start
            eval "${COMMAND}"
            ret=$?
            echo "Command [${COMMAND}] returned ${ret}"
        travis_time_finish
    travis_fold end "${NAME}"
    return $ret
}

export -f script_block
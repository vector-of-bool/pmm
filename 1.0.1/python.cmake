function(_pmm_find_python3 ovar)
    find_program(
        _ret
        NAMES
            python3.8
            python3.7
            python3.6
            python3.5
            python3.4
            python3.3
            python3.2
            python3.1
            python3.0
            python3
        PATHS
            C:/Python38
            C:/Python37
            C:/Python36
            C:/Python35
            C:/Python34
            C:/Python33
            C:/Python32
            C:/Python31
            C:/Python30
            C:/Python3
        )
    set("${ovar}" "${_ret}" PARENT_SCOPE)
    unset(_ret CACHE)
endfunction()

function(_pmm_find_python2 ovar)
    find_program(
        _ret
        NAMES
            python2.8 # ... Just in case
            python2.7
        PATHS
            C:/Python27
            C:/Python2
            C:/Python
        )
    set("${ovar}" "${_ret}" PARENT_SCOPE)
    unset(_ret CACHE)
endfunction()

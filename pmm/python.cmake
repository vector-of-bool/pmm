cmake_minimum_required(VERSION 3.13)

function(_pmm_find_py_py3_launcher ovar)
    set("${ovar}" py-NOTFOUND PARENT_SCOPE)
    find_program(_ret "py")
    set(py "${_ret}")
    unset(_ret CACHE)
    if(NOT py)
        return()
    endif()
    set(versions 3.12 3.11 3.10 3.9 3.8 3.7 3.6 3.5)
    foreach(version IN LISTS versions)
        execute_process(
            COMMAND "${py}" "-${version}" "-m" "this"
            OUTPUT_VARIABLE out
            ERROR_VARIABLE out
            RESULT_VARIABLE retc
            )
        if(NOT retc)
            _pmm_log("Found Python ${version} launcher: ${py} -${version}")
            set("${ovar}" "${py};-${version}" PARENT_SCOPE)
            return()
        endif()
    endforeach()
endfunction()

function(_pmm_find_python3 ovar)
    set(pyenv_root_env "$ENV{PYENV_ROOT}")
    set(pyenv_dirs)
    if(pyenv_root_env)
        file(GLOB pyenv_dirs "${pyenv_root_env}/versions/3.*/")
    else()
        file(GLOB pyenv_dirs "$ENV{HOME}/.pyenv/versions/3.*/")
    endif()
    list(SORT pyenv_dirs COMPARE FILE_BASENAME ORDER DESCENDING)
    file(GLOB c_python_dirs "C:/Python3*")
    _pmm_find_py_py3_launcher(py)
    if(py)
        set("${ovar}" "${py}" PARENT_SCOPE)
        return()
    endif()
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
            python
        HINTS
            ${pyenv_dirs}
            ${c_python_dirs}
        PATH_SUFFIXES
            bin
            Scripts
        NAMES_PER_DIR
        )
    if(_ret)
        execute_process(COMMAND "${_ret}" --version OUTPUT_VARIABLE out ERROR_VARIABLE out)
        if(NOT out MATCHES "^Python 3")
            set(_ret NOTFOUND CACHE INTERNAL "")
        endif()
    endif()
    set("${ovar}" "${_ret}" PARENT_SCOPE)
    unset(_ret CACHE)
endfunction()


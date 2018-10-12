cmake_minimum_required(VERSION 3.8)

if(NOT "$ENV{HOME}" STREQUAL "")
    set(_PMM_USER_HOME "$ENV{HOME}")
else()
    set(_PMM_USER_HOME "$ENV{PROFILE}")
endif()

if(WIN32)
    set(_PMM_USER_DATA_DIR "$ENV{AppData}/pmm/${PMM_VERSION}")
elseif("$ENV{XDG_DATA_HOME}")
    set(_PMM_USER_DATA_DIR "$ENV{XDG_DATA_HOME}/pmm/${PMM_VERSION}")
else()
    set(_PMM_USER_DATA_DIR "${_PMM_USER_HOME}/.local/share/pmm/${PMM_VERSION}")
endif()

# The main function.
function(pmm)
    _pmm_parse_args(+ CONAN)

    if(DEFINED ARG_CONAN OR "CONAN" IN_LIST ARGV)
        _pmm_conan(${ARG_CONAN})
        _pmm_lift(CMAKE_MODULE_PATH)
        _pmm_lift(CMAKE_PREFIX_PATH)
    endif()
endfunction()


function(_pmm_script_main)
    _pmm_parse_script_args(
        -nocheck
        . /Conan /Help
        )
    if(ARG_/Help)
        message([[
Available options:

/Help
    Display this help message

/Conan
    Perform a Conan action

    /Version
        Print the Conan version

    /Create /Ref <ref>
        Run `conan create . <ref>`.
]])
        return()
    endif()

    if(ARG_/Conan)
        _pmm_script_main_conan(${ARG_UNPARSED_ARGUMENTS})
    else()
        message(FATAL_ERROR "PMM did not recognise the given argument list")
    endif()
endfunction()

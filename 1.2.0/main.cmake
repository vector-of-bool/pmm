cmake_minimum_required(VERSION 3.8)

if(NOT "$ENV{HOME}" STREQUAL "")
    set(_PMM_USER_HOME "$ENV{HOME}")
else()
    set(_PMM_USER_HOME "$ENV{PROFILE}")
endif()

if(WIN32)
    set(_PMM_USER_DATA_DIR "$ENV{LocalAppData}/pmm/${PMM_VERSION}")
elseif("$ENV{XDG_DATA_HOME}")
    set(_PMM_USER_DATA_DIR "$ENV{XDG_DATA_HOME}/pmm/${PMM_VERSION}")
else()
    set(_PMM_USER_DATA_DIR "${_PMM_USER_HOME}/.local/share/pmm/${PMM_VERSION}")
endif()

# The main function.
function(_pmm)
    _pmm_parse_args(
        . DEBUG VERBOSE
        + CONAN VCPKG CMakeCM
        )

    if(ARG_DEBUG)
        set(PMM_DEBUG TRUE)
    endif()
    if(ARG_VERBOSE)
        set(PMM_VERBOSE TRUE)
    endif()

    if(DEFINED ARG_CONAN OR "CONAN" IN_LIST ARGV)
        _pmm_conan(${ARG_CONAN})
        _pmm_lift(CMAKE_MODULE_PATH CMAKE_PREFIX_PATH)
    endif()
    if(DEFINED ARG_VCPKG OR "VCPKG" IN_LIST ARGV)
        _pmm_vcpkg(${ARG_VCPKG})
    endif()
    if(DEFINED ARG_CMakeCM OR "CMakeCM" IN_LIST ARGV)
        _pmm_cmcm(${ARG_CMakeCM})
        _pmm_lift(CMAKE_MODULE_PATH)
    endif()
    _pmm_lift(_PMM_INCLUDE)
endfunction()

macro(pmm)
    unset(_PMM_INCLUDE)
    _pmm(${ARGV})
    foreach(inc IN LISTS _PMM_INCLUDE)
        include(${inc})
    endforeach()
endmacro()

function(_pmm_script_main)
    _pmm_parse_script_args(
        -nocheck
        . /Conan /Help
        )
    if(ARG_/Help)
        message([===[
Available options:

/Help
    Display this help message

/Conan
    Perform a Conan action

    /Version
        Print the Conan version

    /Export /Ref <ref> [/Upload [/Remote <remote>]]
        Run `conan export . <ref>`.

        With `/Upload`, will also upload the package after export.

    /Create /Ref <ref> [/Upload [/Remote <remote>]]
        Run `conan create . <ref>`.

        With `/Upload`, will also upload the package after creation.

    /Upload /Ref <ref> [/Remote <remote>]
        Upload the current package (should have already been exported).

        `<ref>` may be a partial `user/channel` reference. In this case the full
        ref will be obtained using the project in the current directory.
]===])
        return()
    endif()

    if(ARG_/Conan)
        _pmm_script_main_conan(${ARG_UNPARSED_ARGUMENTS})
    else()
        message(FATAL_ERROR "PMM did not recognise the given argument list")
    endif()
endfunction()

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
function(_pmm_project_fn)
    _pmm_parse_args(
        . DEBUG VERBOSE
        + CONAN VCPKG CMakeCM DDS
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
    if(DEFINED ARG_DDS OR "DDS" IN_LIST ARGV)
        _pmm_dds(${ARG_DDS})
    endif()
    _pmm_lift(_PMM_INCLUDE)
endfunction()

macro(pmm)
    unset(_PMM_INCLUDE)
    _pmm_project_fn(${ARGV})
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
    Perform a Conan action. None of the actions are mutually exclusive, and
    they will be evaluated in the order they are listed below.

    For example, you may specify both `/Create` and `/Upload` to perform
    a build and an upload in a single go.

    Most of the actions require a Conan installation be present, and will not
    install it on-the-fly themselves. Add `/Install` to the command line to
    make sure that Conan is present.

    /Uninstall
        Remove the Conan installation that PMM may have created
        (necessary for Conan upgrades)

    /Install [/Upgrade]
        Ensure that a Conan executable is installed. If `/Upgrade` is provided,
        will attempt to upgrade an existing installation

    /Where <cookie>
        Print the path to the Conan executable with the given <cookie>
        prepended to the path on the same line.

    /Version
        Print the Conan version

    /EnsureRemotes [<name>[::no_verify] <url> [...]]
        Ensure the given Conan remotes are defined.

    /Profile <path>
        Specify the path to a Conan profile. Used with /GenProfile and /Create.

        It must either already exist, or you may pass `/GenProfile` to create it
        on-the-fly.



    /GenProfile [/Lazy]
        Use PMM's Conan-profile generation to write a profile file to the
        path specified by the /Profile argument using the current environment
        to configure a simple CMake project.

        If `/Lazy` is specified, performs a no-op if the file already exists.

        This can be combined with `/Create` to generate a profile on-the-fly
        for `conan create` to use.

    /Ref <ref>
        Specify a `<ref>`. Required for `/Export`, `/Create`, and `/Upload`.

    /Export
        Run `conan export . <ref>`.

        With `/Upload`, will also upload the package after export.

    /Create [/Settings ...]
            [/Options ...]
            [/BuildPolicy [<policy> ...]]]
        Run `conan create . <ref>`.

        `/Settings` will add `--settings` arguments to the Conan command line,
        and `/Options` will add `--options` arguments to the Conan command line.

        `/BuildPolicy` will specify `--build` arguments to the create command.

        Use `/Profile` to specify a profile to be used by `conan create`.

    /Upload [/Remote <remote>] [/All] [/NoOverwrite]
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

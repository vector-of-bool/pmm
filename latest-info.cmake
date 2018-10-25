function(_pmm_changes version)
    if(PMM_VERSION VERSION_LESS version)
        _pmm_log(" - Changes in ${version}:")
        foreach(change IN LISTS ARGN)
            _pmm_log("    - ${change}")
        endforeach()
    endif()
endfunction()

set(PMM_LATEST_VERSION 1.0.1)

if(PMM_VERSION VERSION_LESS PMM_LATEST_VERSION AND NOT PMM_IGNORE_NEW_VERSION)
    _pmm_log("You are using PMM version ${PMM_VERSION}. The latest is ${PMM_LATEST_VERSION}.")
    _pmm_log("Changes since ${PMM_VERSION} include the following:")
    _pmm_changes(0.2.0
        "Automatic update checks"
        "CONAN uses the `cmake` generator and automatically defines imported targets"
        "SETTINGS for Conan"
        "OPTIONS for Conan"
        "BUILD for setting the Conan install '--build' option"
        )
    _pmm_changes(0.3.0
        "MSVC Support and Fixes"
        )
    _pmm_changes(0.3.1
        "Install virtualenv in a user-local path"
        )
    _pmm_changes(0.4.0
        "Some utilities when running as `cmake -P pmm.cmake`"
        "Pass `build_type` setting to Conan"
        "[Windows] Install to Local AppData instead of Roaming"
        )
    _pmm_changes(1.0.0
        "Support for vcpkg"
        )
    _pmm_changes(1.0.1
        "Fixes for building a CMake project inside of the Conan local cache"
        )
    _pmm_changes(1.0.2
        "DEBUG and VERBOSE logging options."
        )
    _pmm_log("To update, simply change the value of PMM_VERSION_INIT in pmm.cmake")
    _pmm_log("You can disable these messages by setting PMM_IGNORE_NEW_VERSION to TRUE before including pmm.cmake")
endif()

if(NOT DEFINED _PMM_BOOTSTRAP_VERSION OR _PMM_BOOTSTRAP_VERSION LESS 1)
    _pmm_log("NOTE: pmm.cmake has changed! Please download a new pmm.cmake from the PMM repository.")
endif()

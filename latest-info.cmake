function(_pmm_changes version)
    if(PMM_VERSION VERSION_LESS version)
        message(STATUS "[pmm]  - Changes in ${version}:")
        foreach(change IN LISTS ARGN)
            message(STATUS "[pmm]     - ${change}")
        endforeach()
    endif()
endfunction()

set(PMM_LATEST_VERSION 1.4.0)

if(PMM_VERSION VERSION_LESS PMM_LATEST_VERSION AND NOT PMM_IGNORE_NEW_VERSION)
    message(STATUS "[pmm] You are using PMM version ${PMM_VERSION}. The latest is ${PMM_LATEST_VERSION}.")
    message(STATUS "[pmm] Changes since ${PMM_VERSION} include the following:")
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
    _pmm_changes(1.0.3
        "Fix using Conan with a too-new GCC version: Only use the major version on GCC 5 and later"
        )
    _pmm_changes(1.1.0
        "Support a REMOTES argument in Conan mode to add remotes before performing installation"
        )
    _pmm_changes(1.1.1
        "[experimental] Preliminary support for libman"
        "Now installs latest supported version of Conan rather than a specific version"
        )
    _pmm_changes(1.2.0
        "Fix issues with finding Python in some Windows setups"
        "CMakeCM support"
        )
    _pmm_changes(1.3.0
        "/Install, /Upgrade, and /Uninstall arguments to the script to support controlling PMM's Conan installation"
        "pmm(CONAN) args: BINCRAFTERS and COMMUNITY to enable the Bincrafters and conan-community repositories, respectively"
        "Generate a Conan profile file in the build directory for use by the user, instead of passing all command line args"
        "Don't try to re-download already obtained files"
        "Respect PYENV_ROOT when looking for Python"
        "PMM DEBUG mode now prints all external commands that it executes"
        "PMM DEBUG prints debugging information from vcpkg bootstrap"
        )
    _pmm_changes(1.4.0
        "NOTE: This includes a change for the pmm.cmake bootstrap script, which will require a manual update."
        "New: INSTALL_DEPENDS argument for pmm(CONAN), tells PMM about files that can affect the `conan install` result"
        "New: /GenProfile argument to /Conan will generate a profile on-the-fly based on CMake platform detection."
        "New: /BuildPolicy, /Where, /Settings, /Options, and /EnsureRemotes for /Conan"
        "New: /All and /Overwrite for /Conan /Upload"
        "Improve: More fine-grained control over Conan installation by setting the arguments passed to Pip"
        "Improve: Set the os_build and arch_build profile settings"
        "Improve: Better URL normalization for Conan remotes"
        "Improve: Recognize VS 2019 for Conan auto-detection"
        "Improve: PMM_CONAN_IGNORE_EXTERNAL_CONAN to force PMM to always install its own copy"
        "Improve: PMM_CONAN_PIP_ALWAYS_INSTALL to force PMM to always re-run the Pip install of Conan"
        "Fix: changes to build settings and options not triggering a Conan installation"
        "Fix: Honor the `PYENV_ROOT` environment variable"
        "Fix: Don't race to update Conan remotes"
        "Fix: Parse Conan output when finding the package ref with no user/channel"
        "Fix: CONAN_IN_LOCAL_CACHE isn't necessarily set when being exported"
        )
    _pmm_changes(1.4.1
        "New: Experimental DDS mode is now available."
        )
    _pmm_changes(1.4.2
        "Improve: Update to DDS alpha.3"
        )
    _pmm_changes(1.4.3
        "Improve: Update to DDS alpha.4"
        )
    _pmm_changes(1.5.0
        "New: Support the 'cmake_multi' generator with Conan"
        "New: /Conan /Clean to run 'conan remove -fsb *'"
        "New: IMPORT argument to pmm(DDS) will automatically call import_packages() in some cases"
        "New: Running pmm() will generate pmm-cli.bat and pmm-cli.sh shell scripts to manage PMM"
        "New: pmm(VCPKG) supports a PORTS argument, to provide custom vcpkg port files."
        "Improve: Update to DDS alpha.5"
        "Improve: Automatically propagate the MSVC_RUNTIME_LIBRARY for dds dependency builds"
        "Improve: CMAKE_CXX_COMPILER_LAUNCHER sets 'compiler_launcher' in the toolchain"
        "         (Can be overridden with PMM_DDS_COMPILER_LAUNCHER)"
        "Fix: Generated CMakeCM paths using bad path separators"
        "Fix: Multiple calls to pmm(DDS) are allowed, and accumulate deps rather than overriding them"
        )
    _pmm_changes(1.5.1
        "Fix: Unable to run in script mode due to define_property() calls"
        "Fix: Generated Conan profiles without respecting the CMAKE_BUILD_TYPE"
        )
    message(STATUS "[pmm] To update, simply change the value of PMM_VERSION_INIT in pmm.cmake")
    message(STATUS "[pmm] You can disable these messages by setting PMM_IGNORE_NEW_VERSION to TRUE before including pmm.cmake")
endif()

if(NOT DEFINED _PMM_BOOTSTRAP_VERSION OR _PMM_BOOTSTRAP_VERSION LESS 3)
    message(STATUS "[pmm] NOTE: pmm.cmake has changed! Please download a new pmm.cmake from the PMM repository.")
endif()

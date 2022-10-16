pmm_option(PMM_CONAN_PIP_INSTALL_ARGS   "conan<2")
pmm_option(PMM_CONAN_MANAGED            TRUE)
pmm_option(PMM_CONAN_FORCE_REINSTALL    FALSE)
pmm_option(PMM_CONAN_MANAGED_NO_INSTALL FALSE)
option(PMM_CMAKE_MULTI "Use the cmake_multi generator for Conan" ON)

# Get Conan in a new virtualenv using the Python interpreter specified by the
# py_name and py_exe arguments
function(_pmm_conan_venv_install py_name py_exe)
    set(msg "Get Conan with ${py_name}")
    _pmm_log("${msg}")
    _pmm_log("${msg} - Using Python: ${py_exe} ")

    # Try to find a virtualenv module
    unset(venv_mod)
    foreach(cand IN ITEMS venv virtualenv)
        _pmm_log(DEBUG "${msg} - Checking for executable Python module '${cand}'")
        _pmm_exec("${py_exe}" -m ${cand} --help)
        if(NOT _PMM_RC)
            set(venv_mod ${cand})
            break()
        endif()
    endforeach()
    if(NOT DEFINED venv_mod)
        _pmm_log("${msg} - Fail: No virtualenv module")
        return()
    endif()
    _pmm_log(VERBOSE "${msg} using Python virtualenv module '${venv_mod}'")

    # Now create a new virtualenv
    file(REMOVE_RECURSE "${_PMM_CONAN_MANAGED_VENV_DIR}")
    # Create the parent of the virtualenv directory.
    get_filename_component(pardir "${_PMM_CONAN_MANAGED_VENV_DIR}" DIRECTORY)
    file(MAKE_DIRECTORY "${pardir}")
    _pmm_log("${msg} - Create virtualenv")
    _pmm_exec("${py_exe}" -m ${venv_mod} "${_PMM_CONAN_MANAGED_VENV_DIR}")
    if(_PMM_RC)
        _pmm_log(WARNING "Error while trying to create virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        _pmm_log("${msg} - Fail: Could not create virtualenv")
        return()
    endif()
    _pmm_log(VERBOSE "Created Conan virtualenv in ${_PMM_CONAN_MANAGED_VENV_DIR}")

    # Get the Python installed therein
    unset(_venv_py CACHE)
    find_program(_venv_py
        NAMES python
        NO_DEFAULT_PATH
        PATHS "${_PMM_CONAN_MANAGED_VENV_DIR}"
        PATH_SUFFIXES bin Scripts
        )
    set(venv_py "${_venv_py}")
    unset(_venv_py CACHE)

    # Upgrade pip installation
    _pmm_log("${msg} - Upgrade Pip")
    _pmm_exec("${venv_py}" -m pip install -qU pip setuptools)
    if(_PMM_RC)
        _pmm_log(WARNING "Failed while upgrading Pip in the virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        _pmm_log("${msg} - Fail: Pip could not be upgraded")
        return()
    endif()

    # Finally, install Conan inside the virtualenv.
    _pmm_log("${msg} - Install Conan")
    _pmm_exec("${venv_py}" -m pip install -Uq ${PMM_CONAN_PIP_INSTALL_ARGS})
    if(_PMM_RC)
        _pmm_log(WARNING "Failed to install Conan in virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        _pmm_log("${msg} - Fail: Could not install Conan in virtualenv")
        return()
    endif()

    # Conan is installed! Set PMM_CONAN_EXECUTABLE
    unset(PMM_CONAN_EXECUTABLE CACHE)
    find_program(
        PMM_CONAN_EXECUTABLE conan
        NO_DEFAULT_PATH
        PATHS "${_PMM_CONAN_MANAGED_VENV_DIR}"
        PATH_SUFFIXES bin Scripts
        DOC "Path to the PMM-managed Conan executable"
        )
    if(NOT PMM_CONAN_EXECUTABLE)
        _pmm_log(WARNING "Conan executable was not found after Conan installation. Huh??")
        _pmm_log("${msg} - Fail: No conan executable in Conan installation?")
    else()
        _pmm_log("${msg} - Installed: ${PMM_CONAN_EXECUTABLE}")
    endif()
endfunction()


function(_pmm_conan_vars)
    string(MD5 inst_cmd_hash "${PMM_CONAN_PIP_INSTALL_ARGS}")
    string(SUBSTRING "${inst_cmd_hash}" 0 6 inst_cmd_hash)
    get_filename_component(_PMM_CONAN_MANAGED_VENV_DIR "${_PMM_USER_DATA_DIR}/conan/venvs/${inst_cmd_hash}" ABSOLUTE)
    _pmm_lift(_PMM_CONAN_MANAGED_VENV_DIR)
endfunction()


function(_pmm_conan_managed_ensure_installed)
    set(must_reinstall FALSE)
    if(NOT PMM_CONAN_EXECUTABLE)
        _pmm_log(DEBUG "No PMM_CONAN_EXECUTABLE set while in managed-mode")
    elseif(NOT EXISTS "${PMM_CONAN_EXECUTABLE}")
        _pmm_log("Conan executable from previous run '${PMM_CONAN_EXECUTABLE}' is missing. "
                 "A new Conan virtualenv must be created")
        set(must_reinstall TRUE)
    endif()

    # Before we continue, lock access to the virtualenv
    _pmm_log(DEBUG "PMM Conan venv directory is [${_PMM_CONAN_MANAGED_VENV_DIR}]")
    _pmm_verbose_lock(
        "${_PMM_CONAN_MANAGED_VENV_DIR}" DIRECTORY
        FIRST_MESSAGE "Anohter CMake instance is installing Conan. Please wait..."
        FAIL_MESSAGE "Unable to obtain the virtualenv lock. Check if there is a stuck process holding it open."
        RESULT_VARIABLE did_lock
        )
    if(NOT did_lock)
        message(FATAL_ERROR "Unable to obtain exclusive lock on directory ${_PMM_CONAN_MANAGED_VENV_DIR}. Abort.")
    endif()

    if(NOT must_reinstall)
        if(NOT EXISTS "${_PMM_CONAN_MANAGED_VENV_DIR}")
            _pmm_log(DEBUG "Virtualenv does not exist")
        else()
            unset(_found CACHE)
            _pmm_log(DEBUG "Searching for Conan executable in existing virtualenv")
            find_program(
                _found
                NAMES conan
                PATHS "${_PMM_CONAN_MANAGED_VENV_DIR}"
                PATH_SUFFIXES
                    Scripts/
                    bin/
                NO_DEFAULT_PATH
                )
            if(NOT _found)
                _pmm_log("Need to re-install Conan in a new virtualenv")
                set(must_reinstall TRUE)
            else()
                set(PMM_CONAN_EXECUTABLE "${_found}" CACHE FILEPATH "Managed Conan executable" FORCE)
                _pmm_log(VERBOSE "Managed Conan [${PMM_CONAN_EXECUTABLE}] is up-to-date")
            endif()
            unset(_found CACHE)
        endif()
    endif()

    if(NOT must_reinstall AND PMM_CONAN_FORCE_REINSTALL)
        _pmm_log("Reinstalling Conan because PMM_CONAN_FORCE_REINSTALL is '${PMM_CONAN_FORCE_REINSTALL}'")
        set(must_reinstall TRUE)
    endif()

    if(NOT must_reinstall)
        file(LOCK "${_PMM_CONAN_MANAGED_VENV_DIR}" DIRECTORY RELEASE)
        return()
    endif()

    if(PMM_CONAN_MANAGED_NO_INSTALL)
        # Caller has requested that we do not run an install.
        file(LOCK "${_PMM_CONAN_MANAGED_VENV_DIR}" DIRECTORY RELEASE)
        return()
    endif()

    _pmm_log("Installing a Conan binary...")

    # Let's get Conan. Let's try to get it using Python
    _pmm_find_python3(py3_exe)
    if(py3_exe)
        _pmm_conan_venv_install("Python 3" "${py3_exe}")
    else()
        message(FATAL_ERROR "No Python 3 was found, which is required to install Conan.")
    endif()
    if(NOT PMM_CONAN_EXECUTABLE)
        message(FATAL_ERROR "We failed to install Conan in a new virtualenv.")
    endif()
    file(LOCK "${_PMM_CONAN_MANAGED_VENV_DIR}" DIRECTORY RELEASE)
endfunction()


function(_pmm_conan_ensure_sys_present)
    if(PMM_CONAN_EXECUTABLE)
        if(EXISTS "${PMM_CONAN_EXECUTABLE}")
            # We have a cached binary, and it exists: Okay.s
            return()
        endif()
        _pmm_log(WARNING
                "Conan executable '${PMM_CONAN_EXECUTABLE}' from a previous "
                "execution is missing. We'll try to find a new one.")
    endif()

    # No cached conan location. We will now try to find an existing Conan installation

    # Clear the previous setting
    unset(PMM_CONAN_EXECUTABLE)
    unset(PMM_CONAN_EXECUTABLE CACHE)
    unset(PMM_CONAN_EXECUTABLE PARENT_SCOPE)

    # Load any pyenv locations that might be on the system
    set(pyenv_root_env "$ENV{PYENV_ROOT}")
    if(pyenv_root_env)
        file(GLOB pyenv_versions "${pyenv_root_env}/versions/*/")
    else()
        file(GLOB pyenv_versions "$ENV{HOME}/.pyenv/versions/*/")
    endif()
    _pmm_log(VERBOSE "Found pyenv installations: ${pyenv_versions}")

    file(GLOB py_installs C:/Python*)
    find_program(
        PMM_CONAN_EXECUTABLE conan
        HINTS
            ${pyenv_versions}
        PATHS
            "$ENV{HOME}/.local"
            ${py_installs}
        PATH_SUFFIXES
            .
            bin
            Scripts
        DOC "Path to the Conan executable"
        )

    if(PMM_CONAN_EXECUTABLE)
        # We found an executable
        if(NOT _prev)
            _pmm_log("Found Conan: ${PMM_CONAN_EXECUTABLE}")
        endif()
        return()
    endif()

    # We never found anything...
    message(FATAL_ERROR
            "No Conan executable could be found on the system. "
            "Set PMM_CONAN_MANAGED to TRUE and PMM will install one for you.")
endfunction()

# Ensure the presence of a `PMM_CONAN_EXECUTABLE` program
function(_pmm_ensure_conan)
    _pmm_conan_vars()

    if(PMM_CONAN_MANAGED)
        _pmm_conan_managed_ensure_installed()
    else()
        _pmm_conan_ensure_sys_present()
    endif()
endfunction()


function(_pmm_vs_version out)
    set(ver ${MSVC_VERSION})
    if(ver GREATER_EQUAL 1940)
        _pmm_log(WARNING "PMM doesn't yet recognize this MSVC version (${ver}). You may need to upgrade PMM.")
    elseif(ver GREATER_EQUAL 1930)
        set(ret 17)
    elseif(ver GREATER_EQUAL 1920)
        set(ret 16)
    elseif(ver GREATER_EQUAL 1910)
        set(ret 15)
    elseif(ver GREATER_EQUAL 1900)
        set(ret 14)
    elseif(ver GREATER_EQUAL 1800)
        set(ret 12)
    elseif(ver GREATER_EQUAL 1700)
        set(ret 11)
    elseif(ver GREATER_EQUAL 1600)
        set(ret 10)
    elseif(ver GREATER_EQUAL 1500)
        set(ret 9)
    elseif(ver GREATER_EQUAL 1400)
        set(ret 8)
    else()
        _pmm_log(WARNING "Unknown MSVC version: ${ver}.")
        set(ret 8)
    endif()
    _pmm_log(DEBUG "Calculated MSVC version to be ${ret}")
    set(${out} ${ret} PARENT_SCOPE)
endfunction()


function(_pmm_conan_uninstall)
    _pmm_ensure_conan()
    if(NOT PMM_CONAN_EXECUTABLE)
        _pmm_log("No Conan executable found to uninstall")
        return()
    endif()

    _pmm_conan_vars()
    if(NOT EXISTS "${_PMM_CONAN_MANAGED_VENV_DIR}")
        message(FATAL_ERROR "Conan executable '${PMM_CONAN_EXECUTABLE}' was not installed by PMM. We will not uninstall it.")
    endif()

    _pmm_log("Removing Conan virtualenv ${_PMM_CONAN_MANAGED_VENV_DIR}")
    file(REMOVE_RECURSE "${_PMM_CONAN_MANAGED_VENV_DIR}")
endfunction()


function(_pmm_conan_upgrade)
    _pmm_conan_vars()
    find_program(venv_py
        NAMES python
        NO_DEFAULT_PATH
        PATHS "${_PMM_CONAN_MANAGED_VENV_DIR}"
        PATH_SUFFIXES bin Scripts
        )
    _pmm_log("Upgrading Conan...")
    unset(PMM_CONAN_EXECUTABLE CACHE)
    _pmm_exec("${venv_py}" -m pip install --quiet --upgrade ${PMM_CONAN_PIP_INSTALL_ARGS} NO_EAT_OUTPUT)
    if(_PMM_RC)
        message(FATAL_ERROR "Conan upgrade failed [${_PMM_RC}]")
    endif()
    _pmm_ensure_conan()
    _pmm_log("Conan upgrade successful")
endfunction()


function(_pmm_conan_get_settings out)
    _pmm_log(DEBUG "Calculating Conan settings values")
    set(ret)
    get_cmake_property(langs ENABLED_LANGUAGES)
    set(lang CXX)
    if(NOT "CXX" IN_LIST langs)
        set(lang C)
        if(NOT "C" IN_LIST langs)
            message(FATAL_ERROR "pmm(CONAN) requires that either C or C++ languages be enabled.")
        endif()
    endif()
    set(comp_id "${CMAKE_${lang}_COMPILER_ID}")
    set(comp_version "${CMAKE_${lang}_COMPILER_VERSION}")

    _pmm_log(DEBUG "Using language ${lang} compiler information (ID is ${comp_id}, version is ${comp_version})")

    set(majmin_ver_re "^([0-9]+\\.[0-9]+)")

    # Check if the user is mixing+matching compilers.
    if("C" IN_LIST langs AND "CXX" IN_LIST langs)
        if(NOT CMAKE_C_COMPILER_ID STREQUAL CMAKE_CXX_COMPILER_ID)
            _pmm_log(WARNING "Mixing compiler vendors for C and C++ may produce unexpected results.")
        else()
            if(NOT CMAKE_C_COMPILER_VERSION STREQUAL CMAKE_CXX_COMPILER_VERSION)
                _pmm_log(WARNING "Mixing compiler versions for C and C++ may produce unexpected results.")
            endif()
        endif()
    endif()

    # Detect the OS information
    set(sysname "${CMAKE_SYSTEM_NAME}")
    if(NOT sysname AND CMAKE_HOST_SYSTEM_NAME)
        set(sysname "${CMAKE_HOST_SYSTEM_NAME}")
    endif()
    if(sysname MATCHES "^Windows(Store|Phone)$")
        set(os WindowsStore)
    elseif(sysname STREQUAL "Linux")
        set(os Linux)
    elseif(sysname STREQUAL "Darwin")
        set(os Macos)
    elseif(sysname STREQUAL "Windows")
        set(os Windows)
    elseif(sysname STREQUAL "FreeBSD")
        set(os FreeBSD)
    endif()
    if(NOT ARG_SETTINGS MATCHES ";?os=")
        _pmm_log(DEBUG "Using os=${os}")
        list(APPEND ret os=${os})
    endif()
    if(NOT ARG_SETTINGS MATCHES ";?os_build=")
        _pmm_log(DEBUG "Using os_build=${os}")
        list(APPEND ret os_build=${os})
    endif()

    ## Check for GNU (GCC)
    if(comp_id STREQUAL GNU)
        # Use 'gcc'
        _pmm_log(DEBUG "Using compiler=gcc")
        list(APPEND ret compiler=gcc)
        # Parse out the version
        if(NOT comp_version MATCHES "${majmin_ver_re}")
            message(FATAL_ERROR "Unable to parse compiler version string: ${comp_version}")
        endif()
        set(use_version "${CMAKE_MATCH_1}")
        if(use_version VERSION_GREATER_EQUAL 5.0)
            string(REGEX REPLACE "^([0-9]+)\\..*" "\\1" use_version "${use_version}")
        endif()
        _pmm_log(DEBUG "Using compiler.version=${use_version}")
        list(APPEND ret compiler.version=${use_version})
        # Detect what libstdc++ ABI are likely using.
        if(lang STREQUAL "CXX")
            if(comp_version VERSION_GREATER_EQUAL 5.1)
                _pmm_log(DEBUG "Using compiler.libcxx=libstdc++11")
                list(APPEND ret compiler.libcxx=libstdc++11)
            else()
                _pmm_log(DEBUG "Using compiler.libcxx=libstdc++")
                list(APPEND ret compiler.libcxx=libstdc++)
            endif()
        else()
            _pmm_log(DEBUG "Not setting a compiler.libcxx value (Not using C++ compiler for settings detection)")
        endif()
    ## Apple's Clang is a bit of a goob.
    elseif(comp_id STREQUAL AppleClang)
        # Use apple-clang
        _pmm_log(DEBUG "Using compiler=apple-clang")
        list(APPEND ret compiler=apple-clang)
        if(lang STREQUAL "CXX")
            _pmm_log(DEBUG "Using compiler.libcxx=libc++")
            list(APPEND ret compiler.libcxx=libc++)
        endif()
        # Get that version. Same as with Clang
        if(NOT comp_version MATCHES "${majmin_ver_re}")
            message(FATAL_ERROR "Unable to parse compiler version string: ${comp_version}")
        endif()
        _pmm_log(DEBUG "Using compiler.version=${CMAKE_MATCH_1}")
        list(APPEND ret "compiler.version=${CMAKE_MATCH_1}")
    # Non-Appley Clang.
    elseif(comp_id STREQUAL Clang)
        # Regular clang
        _pmm_log(DEBUG "Using compiler=clang")
        list(APPEND ret compiler=clang)
        # Get that version. Same as with AppleClang
        if(NOT comp_version MATCHES "${majmin_ver_re}")
            message(FATAL_ERROR "Unable to parse compiler version string: ${comp_version}")
        endif()

        set(comp_version_val ${CMAKE_MATCH_1})
        if(comp_version_val VERSION_GREATER_EQUAL 8)
            # Conan uses major version only for clang 8+
            if(NOT comp_version MATCHES "^([0-9]+)\\.")
                message(FATAL_ERROR "Unable to parse compiler version string, but we already parsed it: ${comp_version}")
            endif()
            set(comp_version_val ${CMAKE_MATCH_1})
        endif()

        _pmm_log(DEBUG "Using compiler.version=${comp_version_val}")
        list(APPEND ret "compiler.version=${comp_version_val}")
        # TODO: Support libc++ with regular Clang. Plz.
        if(lang STREQUAL "CXX")
            _pmm_log(DEBUG "Using compiler.libcxx=libstdc++")
            list(APPEND ret compiler.libcxx=libstdc++)
        endif()
    elseif(comp_id STREQUAL "MSVC")
        _pmm_vs_version(vs_version)
        _pmm_log(DEBUG "Using compiler=Visual Studio")
        _pmm_log(DEBUG "Using compiler.version=${vs_version}")
        list(APPEND ret "compiler=Visual Studio" compiler.version=${vs_version})
        if(CMAKE_GENERATOR_TOOLSET)
            _pmm_log(DEBUG "Using compiler.toolset=${CMAKE_GENERATOR_TOOLSET}")
            list(APPEND ret compiler.toolset=${CMAKE_GENERATOR_TOOLSET})
        elseif(CMAKE_VS_PLATFORM_TOOLSET AND (CMAKE_GENERATOR STREQUAL "Ninja"))
            _pmm_log(DEBUG "Using compiler.toolset=${CMAKE_VS_PLATFORM_TOOLSET}")
            list(APPEND ret compiler.toolset=${CMAKE_VS_PLATFORM_TOOLSET})
        endif()
    else()
        message(FATAL_ERROR "Unable to detect compiler setting for Conan from CMake. (Unhandled compiler ID ${comp_id}).")
    endif()

    # Todo: Cross compiling
    if(NOT ARG_SETTINGS MATCHES ";?arch=")
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            _pmm_log(DEBUG "Using arch=${x86_64}")
            list(APPEND ret arch=x86_64)
        else()
            _pmm_log(DEBUG "Using arch=${x86}")
            list(APPEND ret arch=x86)
        endif()
    endif()
    if(NOT ARG_SETTINGS MATCHES ";?arch_build=")
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            _pmm_log(DEBUG "Using arch_build=${x86_64}")
            list(APPEND ret arch_build=x86_64)
        else()
            _pmm_log(DEBUG "Using arch_build=${x86}")
            list(APPEND ret arch_build=x86)
        endif()
    endif()

    if(NOT (ARG_SETTINGS MATCHES ";?(compiler\\.)?cppstd="))
        if(CMAKE_CXX_STANDARD)
            list(APPEND ret compiler.cppstd=${CMAKE_CXX_STANDARD})
        endif()
    endif()

    if(CMAKE_CROSSCOMPILING)
        _pmm_log(WARNING "Cross compiling isn't supported yet. Be careful.")
    endif()

    set("${out}" "${ret}" PARENT_SCOPE)
endfunction()


function(_pmm_conan_create_profile _build_type)
    set(profile_lines "[settings]")

    # Get the settings for the profile
    _pmm_conan_get_settings(settings_lines)
    list(APPEND profile_lines "${settings_lines}")
    foreach(setting IN LISTS ARG_SETTINGS)
        list(APPEND profile_lines "${setting}")
    endforeach()
    list(APPEND profile_lines "build_type=${_build_type}")

    # Add the options to the profile
    list(APPEND profile_lines "" "[options]")
    foreach(arg IN LISTS ARG_OPTIONS)
        list(APPEND profile_lines "${arg}")
    endforeach()

    list(APPEND profile_lines "" "[env]")
    if(CMAKE_C_COMPILER)
        list(APPEND profile_lines "CC=${CMAKE_C_COMPILER}")
    endif()
    if(CMAKE_CXX_COMPILER)
        list(APPEND profile_lines "CXX=${CMAKE_CXX_COMPILER}")
    endif()
    foreach(env IN LISTS ARG_ENV)
        list(APPEND profile_lines "${env}")
    endforeach()

    string(REPLACE ";" "\n" profile_content "${profile_lines}")
    get_filename_component(_profile_file "${CMAKE_CURRENT_BINARY_DIR}/pmm-conan-${_build_type}.profile" ABSOLUTE)
    _pmm_write_if_different("${_profile_file}" "${profile_content}")
    set(profile_changed "${_PMM_DID_WRITE}" PARENT_SCOPE)
    set(profile_file ${_profile_file} PARENT_SCOPE)
endfunction()

function(_pmm_conan_run_install _build_type _generator_name )
    # Install the thing
    # Do the regular install logic
    get_filename_component(conan_timestamp_file "${CMAKE_CURRENT_BINARY_DIR}/conaninfo.txt" ABSOLUTE)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${conanfile}")

    _pmm_conan_create_profile(${_build_type})

    pmm_option(ARG_BUILD missing)
    set(conan_args --profile "${profile_file}")
    list(APPEND conan_args --generator ${_generator_name} --build ${ARG_BUILD})
    set(conan_install_cmd
        "${CMAKE_COMMAND}" -E env CONAN_LIBMAN_FOR=cmake
        "${PMM_CONAN_EXECUTABLE}" install "${CMAKE_CURRENT_SOURCE_DIR}" ${conan_args}
        )
    set(prev_cmd_file "${PMM_DIR}/_prev_conan_install_cmd_${_build_type}.txt")
    # Check if we need to re-run the conan install
    set(do_install FALSE)
    # Check if any "install inputs" are newer
    set(more_inputs)
    if(__install_depends)
        file(GLOB_RECURSE more_inputs CONFIGURE_DEPENDS ${__install_depends})
    endif()
    set(install_inputs "${__conanfile}" ${more_inputs})
    foreach(inp IN LISTS install_inputs)
        set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${inp}")
        if(EXISTS "${conan_timestamp_file}" AND "${inp}" IS_NEWER_THAN "${conan_timestamp_file}")
            _pmm_log(DEBUG "Need to run conan install: ${inp} is newer than the last install run")
            set(do_install TRUE)
        endif()
    endforeach()
    # Check if the install has never occurred
    if(NOT EXISTS "${prev_cmd_file}")
        _pmm_log(DEBUG "Need to run conan install: Never been run")
        set(do_install TRUE)
    # Or if the profile has changed
    elseif(profile_changed)
        _pmm_log(DEBUG "Need to run conan install: Profile has changed")
        set(do_install TRUE)
    # Or if the install command has changed
    else()
        file(READ "${prev_cmd_file}" prev_cmd)
        if(NOT prev_cmd STREQUAL conan_install_cmd)
            _pmm_log(DEBUG "Need to run conan install: Install command changed from prior run.")
            set(do_install TRUE)
        endif()
    endif()
    if(NOT do_install)
        _pmm_log(VERBOSE "Conan installation is up-to-date. Not running Conan.")
    else()
        _pmm_log("Installing Conan requirements from ${__conanfile}")
        _pmm_exec(${conan_install_cmd}
            WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
            NO_EAT_OUTPUT
            )
        if(_PMM_RC)
            message(FATAL_ERROR "Conan install failed [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        else()
            file(WRITE "${prev_cmd_file}" "${conan_install_cmd}")
        endif()
    endif()
endfunction()


macro(_pmm_conan_do_setup)
    _pmm_log(VERBOSE "Run conan_define_targets() and conan_set_find_paths()")
    conan_define_targets()
    conan_set_find_paths()
endmacro()


macro(_pmm_conan_install)
    if(CONAN_EXPORTED)
        # When we are being built by conan in the local cache directory we don't need
        # to do an actual conan install: It has already been done for us.
        set(__conan_inc "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake")
        _pmm_log("We are being built by Conan, so we won't run the install step.")
        _pmm_log("Assuming ${__conan_inc} is present.")
    else()
        if(CMAKE_CONFIGURATION_TYPES AND NOT CMAKE_BUILD_TYPE AND PMM_CMAKE_MULTI)
            get_filename_component(__conan_inc "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo_multi.cmake" ABSOLUTE)
            _pmm_log(WARNING "Using cmake-multi generator, this generator is experimental")
            _pmm_conan_run_install("Debug"   "cmake_multi")
            _pmm_conan_run_install("Release" "cmake_multi")
        else()
            set(bt "${CMAKE_BUILD_TYPE}")
            if(NOT bt)
                _pmm_log("WARNING: CMAKE_BUILD_TYPE was not set explicitly. We'll install your dependencies as 'Debug'")
                set(bt "Debug")
            endif()
            get_filename_component(__conan_inc "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake" ABSOLUTE)
            _pmm_conan_run_install("${bt}" "cmake")
        endif()
    endif()

    get_filename_component(libman_inc "${CMAKE_CURRENT_BINARY_DIR}/libman.cmake" ABSOLUTE)
    set(__libman_inc "${libman_inc}")

    _pmm_log(VERBOSE "Including Conan generated file ${__conan_inc}")
    include("${__conan_inc}" OPTIONAL RESULT_VARIABLE __was_included)
    if(NOT __was_included)
        message(SEND_ERROR
            "Conan dependencies were not imported (Expected file ${__conan_inc}). "
            "You may need to run Conan manually (from the build directory). "
            "Ensure you are using the 'cmake' generator."
            )
    else()
        _pmm_conan_do_setup()
    endif()
    set(_prev_index "${LIBMAN_INDEX}")
    include("${__libman_inc}" OPTIONAL)
    if(LIBMAN_INDEX AND NOT _prev_index)
        _pmm_log("Libman import_packages() is available")
    endif()
    unset(__conan_inc)
    unset(__was_included)
endmacro()


function(_pmm_conan_norm_url_var varname)
    set(url "${${varname}}")
    while(url MATCHES "(.*)/+$")
        set(url "${CMAKE_MATCH_1}")
    endwhile()
    set("${varname}" "${url}" PARENT_SCOPE)
endfunction()


function(_pmm_conan_ensure_remotes remotes)
    file(
        LOCK "${_PMM_CONAN_MANAGED_VENV_DIR}/.pmm-remotes-lk" DIRECTORY
        GUARD FUNCTION
        TIMEOUT 60
        )
    _pmm_exec("${PMM_CONAN_EXECUTABLE}" remote list)
    string(STRIP "${_PMM_OUTPUT}" out)
    string(REPLACE "\n" ";" lines "${out}")
    set_property(GLOBAL PROPERTY CONAN_REMOTES "")
    set(all_urls)
    foreach(line IN LISTS lines)
        if(line MATCHES "^(WARN|DEBUG): ")
            # Ignore this line
        elseif(NOT line MATCHES "^([^:]+): (.*) \\[Verify SSL: (.+)\]")
            message(WARNING "Unparseable `conan remote list` line: ${line}")
        else()
            set(name "${CMAKE_MATCH_1}")
            set(url "${CMAKE_MATCH_2}")
            _pmm_conan_norm_url_var(url)
            set(ssl_verify "${CMAKE_MATCH_3}")
            string(TOUPPER "${ssl_verify}" ssl_verify)
            _pmm_log(DEBUG "Found conan remote ${name} at ${url} (Verify SSL: ${ssl_verify})")
            set_property(GLOBAL APPEND PROPERTY CONAN_REMOTES ${name})
            set_property(GLOBAL PROPERTY CONAN_REMOTE/${name}/URL ${url})
            set_property(GLOBAL PROPERTY CONAN_REMOTE/${name}/SSL_VERIFY ${ssl_verify})
            list(APPEND all_urls "${url}")
        endif()
    endforeach()
    while(TRUE)
        list(LENGTH remotes len)
        if(len EQUAL 1)
            message(FATAL_ERROR "REMOTES list of pmm(CONAN) must be pairs of name and value")
        elseif(len EQUAL 0)
            break()
        endif()
        list(GET remotes 0 1 head)
        list(REMOVE_AT remotes 0 1)
        if(NOT head MATCHES "(.+);(.+)")
            message(FATAL_ERROR "Bad remote arguments? ${head}")
        endif()
        set(name "${CMAKE_MATCH_1}")
        set(url "${CMAKE_MATCH_2}")
        _pmm_conan_norm_url_var(url)
        set(verify_ssl True)
        if(name MATCHES "(.+)(::no_verify)")
            set(verify_ssl False)
            set(name "${CMAKE_MATCH_1}")
        endif()
        if(NOT (url IN_LIST all_urls))
            _pmm_log("Add Conan remote '${name}' for ${url}")
            _pmm_exec("${PMM_CONAN_EXECUTABLE}" remote add "${name}" "${url}" "${verify_ssl}" --force)
            if(_PMM_RC)
                message(FATAL_ERROR "Failed to add Conan remote ${name} [${_PMM_RC}]: ${_PMM_OUTPUT}")
            endif()
        endif()
    endwhile()
endfunction()

# Implement the `CONAN` subcommand
function(_pmm_conan)
    _pmm_parse_args(
        . BINCRAFTERS COMMUNITY
        - BUILD
        + SETTINGS OPTIONS ENV REMOTES INSTALL_DEPENDS
        )

    get_cmake_property(__was_setup _PMM_CONAN_WAS_SETUP)
    if(__was_setup)
        _pmm_log(WARNING "pmm(CONAN) ran more than once during configure. This is not supported.")
    endif()

    _pmm_conan_vars()

    if(ARG_BINCRAFTERS)
        list(APPEND ARG_REMOTES bincrafters https://bincrafters.jfrog.io/artifactory/api/conan/public-conan)
    endif()
    if(ARG_COMMUNITY)
        message(AUTHOR_WARNING "The conan-community repository is deprecated. Requesting it has no effect.")
    endif()

    # Ensure that we have Conan
    _pmm_ensure_conan()
    if(NOT PMM_CONAN_EXECUTABLE)
        message(SEND_ERROR "Cannot use Conan with PMM because we were unable to find/obtain a Conan executable.")
        return()
    endif()
    if(NOT CONAN_PREV_EXE STREQUAL PMM_CONAN_EXECUTABLE)
        # Enter this branch if the path to the Conan executable has been changed.
        # Check that we are actually able to run this executable:
        _pmm_exec("${PMM_CONAN_EXECUTABLE}" --version)
        if(_PMM_RC)
            # We failed to run it. Drop the bad exe path from the cache and
            # display an error message
            set(exe "${PMM_CONAN_EXECUTABLE}")
            unset(PMM_CONAN_EXECUTABLE CACHE)
            message(FATAL_ERROR "Conan executable (${exe}) seems invalid [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        endif()
        # Detect the Conan version
        set(_prev "${PMM_CONAN_VERSION}")
        if(_PMM_OUTPUT MATCHES "Conan version ([0-9]+\\.[0-9]+\\.[0-9]+)")
            set(PMM_CONAN_VERSION "${CMAKE_MATCH_1}" CACHE INTERNAL "Conan version")
            if(PMM_CONAN_VERSION VERSION_GREATER "2")
                _pmm_log(WARNING "PMM does not yet support Conan 2+")
            endif()
            if(NOT _prev)
                _pmm_log("Conan version: ${PMM_CONAN_VERSION}")
            endif()
        else()
            _pmm_log(WARNING "Command (${PMM_CONAN_EXECUTABLE} --version) did not produce parseable output:\n${_PMM_OUTPUT}")
            set(PMM_CONAN_VERSION "Unknown" CACHE INTERNAL "Conan version")
        endif()
    endif()
    # Keep track of what exe we just found
    set(CONAN_PREV_EXE "${PMM_CONAN_EXECUTABLE}" CACHE INTERNAL "Previous known-good Conan executable" FORCE)
    _pmm_generate_shim(conan "${PMM_CONAN_EXECUTABLE}")

    # Find the conanfile for the project
    unset(conanfile)
    foreach(fname IN ITEMS conanfile.txt conanfile.py)
        set(cand "${PROJECT_SOURCE_DIR}/${fname}")
        if(EXISTS "${cand}")
            set(conanfile "${cand}")
        endif()
    endforeach()

    # Enable the remote repositories that the user may want to use
    _pmm_conan_ensure_remotes("${ARG_REMOTES}")

    # Check that there is a Conanfile, or we might be otherwise building in the
    # local cache.
    if(NOT DEFINED conanfile AND NOT CONAN_EXPORTED)
        message(FATAL_ERROR "pf(CONAN) requires a Conanfile in your project source directory")
    endif()
    # Go!
    set(__conanfile "${conanfile}")
    set(__install_depends "${ARG_INSTALL_DEPENDS}")
    _pmm_conan_install()
    # Lift these env vars so that they are visible after pmm() returns
    _pmm_lift(CMAKE_MODULE_PATH)
    _pmm_lift(CMAKE_PREFIX_PATH)
    # Mark that we successfully ran Conan
    set_property(GLOBAL PROPERTY _PMM_CONAN_WAS_SETUP TRUE)
endfunction()


function(_pmm_conan_gen_profile destpath be_lazy)
    if(EXISTS "${destpath}" AND be_lazy)
        return()
    endif()
    set(tmpdir "${PMM_DIR}/_gen-profile-project")
    set(tmpdir_build "${tmpdir}/_build")
    file(REMOVE_RECURSE "${tmpdir}")
    file(REMOVE_RECURSE "${tmpdir_build}")
    # Detect if we have Ninja
    find_program(_ninja_exe NAMES ninja-build ninja)
    # Generate a small project
    file(MAKE_DIRECTORY "${tmpdir}")
    string(CONFIGURE [[
        cmake_minimum_required(VERSION 3.13.0)
        project(Dummy)
        set(PMM_DIR "@PMM_DIR@")
        include("@CMAKE_SCRIPT_MODE_FILE@")
        pmm(CONAN)
    ]] cml @ONLY)
    file(WRITE "${tmpdir}/conanfile.txt" "")
    file(WRITE "${tmpdir}/CMakeLists.txt" "${cml}")
    set(more_args)
    if(_ninja_exe)
        list(APPEND more_args "-GNinja")
    endif()
    # Configure the project
    _pmm_log("Generating Conan profile ...")
    execute_process(
        COMMAND "${CMAKE_COMMAND}" "-H${tmpdir}" "-B${tmpdir_build}" ${more_args}
        RESULT_VARIABLE retc
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out
        )
    if(retc)
        message(FATAL_ERROR "Failed to configure project to generate Conan profile [${retc}]:\n${out}")
    endif()
    file(GLOB profile_file "${tmpdir_build}/pmm-conan*.profile")
    file(RENAME "${profile_file}" "${destpath}")
    _pmm_log("Conan profile written to file: ${destpath}")
endfunction()


function(_pmm_print_conan_where cookie)
    message("${cookie}${PMM_CONAN_EXECUTABLE}")
endfunction()


function(_pmm_script_main_conan)
    _pmm_parse_args(
        -hardcheck
        .
            /NotManaged
            /Version
            /Create
            /Upload
            /All
            /NoOverwrite
            /Clean
            /Export
            /Install
            /Uninstall
            /GenProfile
            /Lazy  # For /GenProfile
            /Upgrade  # [deprecated]
        - /Ref /Remote /Profile /Where
        + /Settings /Options /BuildPolicy /EnsureRemotes
        )

    _pmm_conan_vars()

    if(ARG_/Upgrade)
        _pmm_log("The /Upgrade option is deprecated and has no effect.")
    endif()

    set(PMM_CONAN_MANAGED_NO_INSTALL TRUE)

    if(ARG_/Uninstall)
        _pmm_conan_uninstall()
    endif()

    if(ARG_/Install)
        set(PMM_CONAN_MANAGED_NO_INSTALL FALSE)
        _pmm_ensure_conan()
        if(NOT PMM_CONAN_EXECUTABLE)
            message(FATAL_ERROR "Failed to install a Conan executable")
        endif()
    endif()

    if(ARG_/NotManaged)
        set(PMM_CONAN_MANAGED FALSE)
    else()
        set(PMM_CONAN_MANAGED TRUE)
    endif()

    if(DEFINED ARG_/Where)
        _pmm_ensure_conan()
        if(NOT PMM_CONAN_EXECUTABLE)
            message(FATAL_ERROR "/Where may only be used after Conan has been installed. Try passing /Install")
        endif()
        _pmm_print_conan_where("${ARG_/Where}")
    endif()

    if(ARG_/Version)
        _pmm_ensure_conan()
        execute_process(COMMAND "${PMM_CONAN_EXECUTABLE}" --version)
    endif()

    if(ARG_/EnsureRemotes)
        _pmm_ensure_conan()
        if(NOT PMM_CONAN_EXECUTABLE)
            message(FATAL_ERROR "/EnsureRemotes may only be used after Conan has been installed. Try passing /Install")
        endif()
        _pmm_conan_ensure_remotes("${ARG_/EnsureRemotes}")
    endif()

    if(ARG_/Create AND ARG_/Export)
        message(FATAL_ERROR "/Export and /Create can not be specified together")
    endif()

    if(ARG_/GenProfile)
        if(NOT ARG_/Profile)
            message(FATAL_ERROR "Specify `/Profile <path>` when using /GenProfile")
        endif()
        get_filename_component(pr_dest "${ARG_/Profile}" ABSOLUTE)
        _pmm_conan_gen_profile("${pr_dest}" "${ARG_/Lazy}")
    endif()

    set(profile_args)
    if(ARG_/Profile)
        set(profile_args --profile "${ARG_/Profile}")
    endif()
    set(settings_args)
    foreach(s IN LISTS ARG_/Settings)
        list(APPEND settings_args --settings "${s}")
    endforeach()
    set(options_args)
    foreach(o IN LISTS ARG_/Options)
        list(APPEND options_args --options "${o}")
    endforeach()
    # All args used for package install/create/info etc.:
    set(all_config_args ${profile_args} ${settings_args} ${options_args})

    set(create_args ${all_config_args})

    if(ARG_/Create)
        if(NOT ARG_/Ref)
            message(FATAL_ERROR "Pass a /Ref for /Create")
        endif()
        _pmm_ensure_conan()
        foreach(policy IN LISTS ARG_/BuildPolicy)
            list(APPEND create_args "--build=${policy}")
        endforeach()
        execute_process(
            COMMAND "${PMM_CONAN_EXECUTABLE}" create ${create_args} "${CMAKE_SOURCE_DIR}" "${ARG_/Ref}"
            RESULT_VARIABLE retc
            )
        if(retc)
            message(FATAL_ERROR "Create failed [${retc}]")
        endif()
    endif()

    if(ARG_/Export)
        if(NOT ARG_/Ref)
            message(FATAL_ERROR "Pass /Ref when for /Export")
        endif()
        _pmm_ensure_conan()
        execute_process(
            COMMAND "${PMM_CONAN_EXECUTABLE}" export "${CMAKE_SOURCE_DIR}" "${ARG_/Ref}"
            RESULT_VARIABLE retc
            )
        if(retc)
            message(FATAL_ERROR "Export failed [${retc}]")
        endif()
    endif()

    if(ARG_/Clean)
        _pmm_ensure_conan()
        execute_process(COMMAND "${PMM_CONAN_EXECUTABLE}" remove * -fsb)
    endif()

    if(ARG_/Upload)
        _pmm_ensure_conan()
        if(ARG_/Ref MATCHES ".+@.+")
            set(full_ref "${ARG_/Ref}")
        else()
            _pmm_exec("${PMM_CONAN_EXECUTABLE}" info ${all_config_args} "${CMAKE_SOURCE_DIR}")
            if(_PMM_RC)
                message(FATAL_ERROR "Failed to get package info [${_PMM_RC}]:\n${_PMM_OUTPUT}")
            endif()
            if(NOT _PMM_OUTPUT MATCHES "([^\n]+)@PROJECT.*")
                if(NOT _PMM_OUTPUT MATCHES "conanfile[^\n]+ \\(([^\n]+)@None/None")
                    message(FATAL_ERROR "Can't parse Conan output [${_PMM_RC}]:\n${_PMM_OUTPUT}")
                endif()
            endif()
            set(full_ref "${CMAKE_MATCH_1}@${ARG_/Ref}")
        endif()
        set(cmd "${PMM_CONAN_EXECUTABLE}" upload --confirm --check)
        if(ARG_/Remote)
            list(APPEND cmd --remote "${ARG_/Remote}")
        endif()
        if(ARG_/All)
            list(APPEND cmd --all)
        endif()
        if(ARG_/NoOverwrite)
            list(APPEND cmd --no-overwrite all)
        endif()
        list(APPEND cmd "${full_ref}")
        execute_process(
            COMMAND ${cmd}
            RESULT_VARIABLE retc
            )
        if(retc)
            message(FATAL_ERROR "Upload failed [${retc}]")
        endif()
    endif()
endfunction()

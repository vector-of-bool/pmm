set(PMM_CONAN_MIN_VERSION 1.8.0     CACHE INTERNAL "Minimum Conan version we support")
set(PMM_CONAN_MAX_VERSION 1.99999.0 CACHE INTERNAL "Maximum Conan version we support")


# Get Conan in a new virtualenv using the Python interpreter specified by the
# package of the `python_pkg` arg (Python3 or Python2)
function(_pmm_get_conan_venv py_name py_exe)
    set(msg "Get Conan with ${py_name}")
    _pmm_log("${msg}")
    _pmm_log("${msg} - Candidate Python: ${py_exe} ")

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
    file(REMOVE_RECURSE "${_PMM_CONAN_VENV_DIR}")
    _pmm_log("${msg} - Create virtualenv")
    _pmm_exec("${py_exe}" -m ${venv_mod} "${_PMM_CONAN_VENV_DIR}")
    if(_PMM_RC)
        _pmm_log(WARNING "Error while trying to create virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        _pmm_log("${msg} - Fail: Could not create virtualenv")
        return()
    endif()
    _pmm_log(VERBOSE "Created Conan virtualenv in ${_PMM_CONAN_VENV_DIR}")

    # Get the Python installed therein
    unset(_venv_py CACHE)
    find_program(_venv_py
        NAMES python
        NO_DEFAULT_PATH
        PATHS "${_PMM_CONAN_VENV_DIR}"
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
    _pmm_exec("${venv_py}" -m pip install -q conan<${PMM_CONAN_MAX_VERSION})
    if(_PMM_RC)
        _pmm_log(WARNING "Failed to install Conan in virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        _pmm_log("${msg} - Fail: Could not install Conan in virtualenv")
        return()
    endif()

    # Conan is installed! Set PMM_CONAN_EXECUTABLE
    find_program(
        PMM_CONAN_EXECUTABLE conan
        NO_DEFAULT_PATH
        PATHS "${_PMM_CONAN_VENV_DIR}"
        PATH_SUFFIXES bin Scripts
        )
    if(NOT PMM_CONAN_EXECUTABLE)
        _pmm_log(WARNING "Conan executbale was not found acter Conan installation. Huh??")
        _pmm_log("${msg} - Fail: No conan executable in Conan installation?")
    else()
        _pmm_log("${msg} - Installed: ${PMM_CONAN_EXECUTABLE}")
    endif()
endfunction()

macro(_pmm_conan_vars)
    get_filename_component(_PMM_CONAN_VENV_DIR "${_PMM_USER_DATA_DIR}/_conan_venv" ABSOLUTE)
endmacro()

# Ensure the presence of a `PMM_CONAN_EXECUTABLE` program
function(_pmm_ensure_conan)
    if(PMM_CONAN_EXECUTABLE)
        if(NOT EXISTS "${PMM_CONAN_EXECUTABLE}")
            _pmm_log(WARNING "Conan executable '${PMM_CONAN_EXECUTABLE}' from a prior configuration is gone. Looking for a new one.")
            unset(PMM_CONAN_EXECUTABLE CACHE)
        else()
            _pmm_log(DEBUG "Conan executable already set: ${PMM_CONAN_EXECUTABLE}")
            return()
        endif()
    endif()

    _pmm_conan_vars()
    _pmm_log(DEBUG "Lock access to virtualenv directory ${_PMM_CONAN_VENV_DIR}")

    file(
        LOCK "${_PMM_CONAN_VENV_DIR}" DIRECTORY
        GUARD FUNCTION
        TIMEOUT 3
        RESULT_VARIABLE lock_res
        )
    if(lock_res)
        _pmm_log("Another CMake instance is installing Conan. Please wait...")
        file(
            LOCK "${_PMM_CONAN_VENV_DIR}" DIRECTORY
            GUARD FUNCTION
            TIMEOUT 60
            )
    endif()

    # Try to find an existing Conan installation
    file(GLOB pyenv_versions "$ENV{HOME}/.pyenv/versions/*")
    _pmm_log(VERBOSE "Found pyenv installations: ${pyenv_versions}")
    set(_prev "${PMM_CONAN_EXECUTABLE}")
    file(GLOB py_installs C:/Python*)
    find_program(
        PMM_CONAN_EXECUTABLE conan
        HINTS
            "${_PMM_CONAN_VENV_DIR}"
            ${pyenv_versions}
        PATHS
            "$ENV{HOME}/.local"
            ${py_installs}
        PATH_SUFFIXES
            .
            bin
            Scripts
        DOC "Path to Conan executable"
        )
    if(PMM_CONAN_EXECUTABLE)
        if(NOT _prev)
            _pmm_log("Found Conan: ${PMM_CONAN_EXECUTABLE}")
        endif()
        return()
    endif()

    if(_PMM_ENSURE_CONAN_NO_INSTALL)
        # Parent scope asks that we do not try to install a Conan executable
        return()
    endif()

    _pmm_log("No existing Conan installation found. We'll try to obtain one.")

    # No conan. Let's try to get it using Python
    _pmm_find_python3(py3_exe)
    if(py3_exe)
        _pmm_get_conan_venv("Python 3" "${py3_exe}")
    else()
        _pmm_log(VERBOSE "No Python 3 candidate found. We'll check Python 2.")
    endif()
    if(PMM_CONAN_EXECUTABLE)
        return()
    endif()
    _pmm_find_python2(py2_exe)
    if(py2_exe)
        _pmm_get_conan_venv("Python 2" "${py2_exe}")
    else()
        _pmm_log(VERBOSE "No Python 2 candidate found.")
    endif()
    if(NOT py3_exe AND NOT py2_exe)
        message(FATAL_ERROR "No conan executable found, and no Python was found to install it.")
    endif()
endfunction()


function(_pmm_vs_version out)
    set(ver ${MSVC_VERSION})
    if(ver GREATER_EQUAL 1920)
        _pmm_log(WARNING "PMM doesn't yet recognize this MSVC version. You may need to upgrade PMM.")
        set(ret 15)
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
    set(_PMM_ENSURE_CONAN_NO_INSTALL TRUE)
    _pmm_ensure_conan()
    if(NOT PMM_CONAN_EXECUTABLE)
        _pmm_log("No Conan executable found to uninstall")
        return()
    endif()

    _pmm_conan_vars()
    if(NOT EXISTS "${_PMM_CONAN_VENV_DIR}")
        message(FATAL_ERROR "Conan executable '${PMM_CONAN_EXECUTABLE}' was not installed by PMM. We will not uninstall it.")
    endif()

    _pmm_log("Removing Conan virtualenv ${_PMM_CONAN_VENV_DIR}")
    file(REMOVE_RECURSE "${_PMM_CONAN_VENV_DIR}")
endfunction()


function(_pmm_conan_upgrade)
    _pmm_conan_vars()
    find_program(venv_py
        NAMES python
        NO_DEFAULT_PATH
        PATHS "${_PMM_CONAN_VENV_DIR}"
        PATH_SUFFIXES bin Scripts
        )
    _pmm_log("Upgrading Conan...")
    _pmm_exec("${venv_py}" -m pip install --quiet --upgrade "conan<${PMM_CONAN_MAX_VERSION}" NO_EAT_OUTPUT)
    if(_PMM_RC)
        message(FATAL_ERROR "Conan upgrade failed [${_PMM_RC}]")
    endif()
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
        _pmm_log(DEBUG "Using compiler.version=${CMAKE_MATCH_1}")
        list(APPEND ret "compiler.version=${CMAKE_MATCH_1}")
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
        if (CMAKE_GENERATOR_TOOLSET)
            _pmm_log(DEBUG "Using compiler.toolset=${CMAKE_GENERATOR_TOOLSET}")
            list(APPEND ret compiler.toolset=${CMAKE_GENERATOR_TOOLSET})
        elseif(CMAKE_VS_PLATFORM_TOOLSET AND (CMAKE_GENERATOR STREQUAL "Ninja"))
            _pmm_log(DEBUG "Using compiler.toolset=${CMAKE_VS_PLATFORM_TOOLSET}")
            list(APPEND ret compiler.toolset=${CMAKE_VS_PLATFORM_TOOLSET})
        endif()
    else()
        message(FATAL_ERROR "Unable to detect compiler setting for Conan from CMake. (Unhandled compiler ID ${comp_id}).")
    endif()

    if(NOT CMAKE_CONFIGURATION_TYPES)
        set(bt "${CMAKE_BUILD_TYPE}")
        if(NOT bt)
            _pmm_log("WARNING: CMAKE_BUILD_TYPE was not set explicitly. We'll install your dependencies as 'Debug'")
            set(bt Debug)
        endif()
        _pmm_log(DEBUG "Using build_type=${bt}")
        list(APPEND ret build_type=${bt})
    endif()

    # Todo: Cross compiling
    if(NOT ARG_SETTINGS MATCHES ";?arch=")
        if(CMAKE_SIZEOF_VOID_P EQUAL 8)
            _pmm_log(DEBUG "Using arch=${x86_64}")
            list(APPEND ret arch=x86_64)
            list(APPEND ret arch_build=x86_64)
        else()
            _pmm_log(DEBUG "Using arch=${x86}")
            list(APPEND ret arch=x86)
            list(APPEND ret arch_build=x86)
        endif()
    endif()

    if(NOT ARG_SETTINGS MATCHES ";?cppstd=")
        if(CMAKE_CXX_STANDARD)
            list(APPEND ret cppstd=${CMAKE_CXX_STANDARD})
        endif()
    endif()

    if(CMAKE_CROSSCOMPILING)
        _pmm_log(WARNING "Cross compiling isn't supported yet. Be careful.")
    endif()

    set("${out}" "${ret}" PARENT_SCOPE)
endfunction()


function(_pmm_conan_install_1)
    set(src "${CMAKE_CURRENT_SOURCE_DIR}")
    set(bin "${CMAKE_CURRENT_BINARY_DIR}")
    # Install the thing
    # Do the regular install logic
    get_filename_component(conan_inc "${bin}/conanbuildinfo.cmake" ABSOLUTE)
    get_filename_component(conan_timestamp_file "${bin}/conaninfo.txt" ABSOLUTE)
    get_filename_component(libman_inc "${bin}/libman.cmake" ABSOLUTE)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${conanfile}")

    get_filename_component(profile_file "${bin}/pmm-conan.profile" ABSOLUTE)
    set(profile_lines "[settings]")

    # Get the settings for the profile
    _pmm_conan_get_settings(settings_lines)
    list(APPEND profile_lines "${settings_lines}")
    foreach(setting IN LISTS ARG_SETTINGS)
        list(APPEND profile_lines "${setting}")
    endforeach()

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
    _pmm_write_if_different("${profile_file}" "${profile_content}")
    set(profile_changed "${_PMM_DID_WRITE}")

    _pmm_set_if_undef(ARG_BUILD missing)
    set(conan_args --profile "${profile_file}")
    list(APPEND conan_args --generator cmake --build ${ARG_BUILD})
    set(conan_install_cmd
        "${CMAKE_COMMAND}" -E env CONAN_LIBMAN_FOR=cmake
        "${PMM_CONAN_EXECUTABLE}" install "${src}" ${conan_args}
        )
    set(prev_cmd_file "${PMM_DIR}/_prev_conan_install_cmd.txt")
    set(do_install FALSE)
    if(EXISTS "${conan_timestamp_file}" AND "${conanfile}" IS_NEWER_THAN "${conan_timestamp_file}")
        _pmm_log(DEBUG "Need to run conan install: ${conanfile} is newer than the last install run")
        set(do_install TRUE)
    endif()
    if(NOT EXISTS "${prev_cmd_file}")
        _pmm_log(DEBUG "Need to run conan install: Never been run")
        set(do_install TRUE)
    elseif(profile_changed)
        _pmm_log(DEBUG "Need to run conan install: Profile has changed")
        set(do_install TRUE)
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
        _pmm_log("Installing Conan requirements from ${conanfile}")
        _pmm_exec(${conan_install_cmd}
            WORKING_DIRECTORY "${bin}"
            NO_EAT_OUTPUT
            )
        if(_PMM_RC)
            message(SEND_ERROR "Conan install failed [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        else()
            file(WRITE "${prev_cmd_file}" "${conan_install_cmd}")
        endif()
    endif()
    set(__conan_inc "${conan_inc}" PARENT_SCOPE)
    set(__libman_inc "${libman_inc}" PARENT_SCOPE)
endfunction()


macro(_pmm_conan_do_setup)
    _pmm_log(VERBOSE "Run conan_define_targets() and conan_set_find_paths()")
    conan_define_targets()
    conan_set_find_paths()
endmacro()


macro(_pmm_conan_install)
    if(CONAN_EXPORTED AND CONAN_IN_LOCAL_CACHE)
        # When we are being built by conan in the local cache directory we don't need
        # to do an actual conan install: It has already been done for us.
        set(__conan_inc "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake")
        _pmm_log("We are being built by Conan, so we won't run the install step.")
        _pmm_log("Assuming ${__conan_inc} is present.")
    else()
        _pmm_conan_install_1()
    endif()
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


function(_conan_ensure_remotes remotes)
    _pmm_exec("${PMM_CONAN_EXECUTABLE}" remote list)
    string(STRIP "${_PMM_OUTPUT}" out)
    string(REPLACE "\n" ";" lines "${out}")
    set_property(GLOBAL PROPERTY CONAN_REMOTES "")
    set(all_urls)
    foreach(line IN LISTS lines)
        if(NOT line MATCHES "^([^:]+): (.*) \\[Verify SSL: (.+)\]")
            message(WARNING "Unparseable `conan remote list` line: ${line}")
        else()
            set(name "${CMAKE_MATCH_1}")
            set(url "${CMAKE_MATCH_2}")
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
        set(verify_ssl True)
        if(name MATCHES "(.+)(::no_verify)")
            set(verify_ssl False)
            set(name "${CMAKE_MATCH_1}")
        endif()
        if(NOT (url IN_LIST all_urls))
            _pmm_log("Add Conan remote '${name}' for ${url}")
            _pmm_exec("${PMM_CONAN_EXECUTABLE}" remote add "${name}" "${url}" "${verify_ssl}")
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
        + SETTINGS OPTIONS ENV REMOTES
        )

    get_cmake_property(__was_setup _PMM_CONAN_WAS_SETUP)
    if(__was_setup)
        _pmm_log(WARNING "pmm(CONAN) ran more than once during configure. This is not supported.")
    endif()

    if(ARG_BINCRAFTERS)
        list(APPEND ARG_REMOTES bincrafters https://api.bintray.com/conan/bincrafters/public-conan)
    endif()
    if(ARG_COMMUNITY)
        list(APPEND ARG_REMOTES conan-community https://api.bintray.com/conan/conan-community/conan)
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
            if(PMM_CONAN_VERSION VERSION_LESS PMM_CONAN_MIN_VERSION)
                _pmm_log(WARNING "Conan version ${PMM_CONAN_VERSION} is older than the minimum supported version ${PMM_CONAN_MIN_VERSION}")
            elseif(PMM_CONAN_VERSION VERSION_GREATER PMM_CONAN_MAX_VERSION)
                _pmm_log(WARNING "Conan version ${PMM_CONAN_VERSION} is newer than the maximum supported version ${PMM_CONAN_MAX_VERSION}")
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

    # Find the conanfile for the project
    unset(conanfile)
    foreach(fname IN ITEMS conanfile.txt conanfile.py)
        set(cand "${PROJECT_SOURCE_DIR}/${fname}")
        if(EXISTS "${cand}")
            set(conanfile "${cand}")
        endif()
    endforeach()

    # Enable the remote repositories that the user may want to use
    _conan_ensure_remotes("${ARG_REMOTES}")

    # Check that there is a Conanfile, or we might be otherwise building in the
    # local cache.
    if(NOT DEFINED conanfile AND NOT (CONAN_EXPORTED AND CONAN_IN_LOCAL_CACHE))
        message(FATAL_ERROR "pf(CONAN) requires a Conanfile in your project source directory")
    endif()
    # Go!
    _pmm_conan_install()
    # Lift these env vars so that they are visible after pmm() returns
    _pmm_lift(CMAKE_MODULE_PATH)
    _pmm_lift(CMAKE_PREFIX_PATH)
    # Mark that we successfully ran Conan
    set_property(GLOBAL PROPERTY _PMM_CONAN_WAS_SETUP TRUE)
endfunction()


function(_pmm_script_main_conan)
    _pmm_parse_args(
        .
            /Version
            /Create
            /Upload
            /Export
            /Install
            /Upgrade
            /Uninstall
        - /Ref /Remote
        )

    if(ARG_/Uninstall)
        _pmm_conan_uninstall()
        return()
    endif()

    if(ARG_/Install)
        set(_PMM_ENSURE_CONAN_NO_INSTALL TRUE)
        _pmm_ensure_conan()
        unset(_PMM_ENSURE_CONAN_NO_INSTALL)
        if(NOT PMM_CONAN_EXECUTABLE)
            _pmm_ensure_conan()
        elseif(ARG_/Upgrade)
            _pmm_conan_upgrade()
        else()
            _pmm_log("Not upgrading the existing installation. Use `/Upgrade` to upgrade")
        endif()
        return()
    endif()

    if(ARG_/Version)
        _pmm_ensure_conan()
        execute_process(COMMAND "${PMM_CONAN_EXECUTABLE}" --version)
        return()
    endif()

    if(ARG_/Create AND ARG_/Export)
        message(FATAL_ERROR "/Export and /Create can not be specified together")
    endif()

    if(ARG_/Create)
        if(NOT ARG_/Ref)
            message(FATAL_ERROR "Pass a /Ref for /Create")
        endif()
        _pmm_ensure_conan()
        execute_process(
            COMMAND "${PMM_CONAN_EXECUTABLE}" create "${CMAKE_SOURCE_DIR}" "${ARG_/Ref}"
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

    if(ARG_/Upload)
        _pmm_ensure_conan()
        if(ARG_/Ref MATCHES ".+@.+")
            set(full_ref "${ARG_/Ref}")
        else()
            _pmm_exec("${PMM_CONAN_EXECUTABLE}" info "${CMAKE_SOURCE_DIR}")
            if(_PMM_RC)
                message(FATAL_ERROR "Failed to get package info [${_PMM_RC}]:\n${_PMM_OUTPUT}")
            endif()
            if(NOT _PMM_OUTPUT MATCHES "([^\n]+)@PROJECT.*")
                message(FATAL_ERROR "Can't parse Conan output [${_PMM_RC}]:\n${_PMM_OUTPUT}")
            endif()
            set(full_ref "${CMAKE_MATCH_1}@${ARG_/Ref}")
        endif()
        set(cmd "${PMM_CONAN_EXECUTABLE}" upload --confirm --check)
        if(ARG_/Remote)
            list(APPEND cmd --remote "${ARG_/Remote}")
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

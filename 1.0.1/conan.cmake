set(PMM_CONAN_MIN_VERSION 1.8.0     CACHE INTERNAL "Minimum Conan version we support")
set(PMM_CONAN_MAX_VERSION 1.8.9999  CACHE INTERNAL "Maximum Conan version we support")

# Get Conan in a new virtualenv using the Python interpreter specified by the
# package of the `python_pkg` arg (Python3 or Python2)
function(_pmm_get_conan_venv py_name py_exe)
    set(msg "[pmm] Get Conan with ${py_name}")
    message(STATUS "${msg}")
    message(STATUS "${msg} - Candidate Python: ${py_exe} ")

    # Try to find a virtualenv module
    unset(venv_mod)
    foreach(cand IN ITEMS venv virtualenv)
        _pmm_exec("${py_exe}" -m ${cand} --help)
        if(NOT _PMM_RC)
            set(venv_mod ${cand})
            break()
        endif()
    endforeach()
    if(NOT DEFINED venv_mod)
        message(STATUS "${msg} - Fail: No virtualenv module")
        return()
    endif()

    # Now create a new virtualenv
    file(REMOVE_RECURSE "${_PMM_CONAN_VENV_DIR}")
    message(STATUS "${msg} - Create virtualenv")
    _pmm_exec("${py_exe}" -m ${venv_mod} "${_PMM_CONAN_VENV_DIR}")
    if(_PMM_RC)
        message(WARNING "Error while trying to create virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        message(STATUS "${msg} - Fail: Could not create virtualenv")
        return()
    endif()

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
    message(STATUS "${msg} - Upgrade Pip")
    _pmm_exec("${venv_py}" -m pip install -qU pip setuptools)
    if(_PMM_RC)
        message(WARNING "Failed while upgrading Pip in the virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        message(STATUS "${msg} - Fail: Pip could not be upgraded")
        return()
    endif()

    # Finally, install Conan inside the virtualenv.
    message(STATUS "${msg} - Install Conan")
    _pmm_exec("${venv_py}" -m pip install -q conan==1.8.2)
    if(_PMM_RC)
        message(WARNING "Failed to install Conan in virtualenv [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        message(STATUS "${msg} - Fail: Could not install Conan in virtualenv")
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
        message(WARNING "Conan executbale was not found acter Conan installation. Huh??")
        message(STATUS "${msg} - Fail: No conan executable in Conan installation?")
    else()
        message(STATUS "${msg} - Installed: ${PMM_CONAN_EXECUTABLE}")
    endif()
endfunction()

# Ensure the presence of a `PMM_CONAN_EXECUTABLE` program
function(_pmm_ensure_conan)
    if(PMM_CONAN_EXECUTABLE)
        return()
    endif()

    get_filename_component(_PMM_CONAN_VENV_DIR "${_PMM_USER_DATA_DIR}/_conan_venv" ABSOLUTE)

    file(
        LOCK "${_PMM_CONAN_VENV_DIR}" DIRECTORY
        GUARD FUNCTION
        TIMEOUT 3
        RESULT_VARIABLE lock_res
        )
    if(lock_res)
        message(STATUS "Another CMake instance is installing Conan. Please wait...")
        file(
            LOCK "${_PMM_CONAN_VENV_DIR}" DIRECTORY
            GUARD FUNCTION
            TIMEOUT 60
            )
    endif()

    # Try to find an existing Conan installation
    file(GLOB pyenv_versions "$ENV{HOME}/.pyenv/versions/*")
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
            message(STATUS "[pmm] Found Conan: ${PMM_CONAN_EXECUTABLE}")
        endif()
        return()
    endif()

    message(STATUS "[pmm] No existing Conan installation found. We'll try to obtain one.")

    # No conan. Let's try to get it using Python
    _pmm_find_python3(py3_exe)
    if(py3_exe)
        _pmm_get_conan_venv("Python 3" "${py3_exe}")
    endif()
    if(PMM_CONAN_EXECUTABLE)
        return()
    endif()
    _pmm_find_python2(py2_exe)
    if(py2_exe)
        _pmm_get_conan_venv("Python 2" "${py2_exe}")
    endif()
endfunction()

function(_pmm_vs_version out)
    set(ver ${MSVC_VERSION})
    if(ver GREATER_EQUAL 1920)
        message(WARNING "PMM doesn't yet recognize this MSVC version. You may need to upgrade PMM.")
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
        message(WARNING "Unknown MSVC version: ${ver}.")
        set(ret 8)
    endif()
    set(${out} ${ret} PARENT_SCOPE)
endfunction()

function(_pmm_conan_calc_settings_args out)
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

    set(majmin_ver_re "^([0-9]+\\.[0-9]+)")

    # Check if the user is mixing+matching compilers.
    if("C" IN_LIST langs AND "CXX" IN_LIST langs)
        if(NOT CMAKE_C_COMPILER_ID STREQUAL CMAKE_CXX_COMPILER_ID)
            message(WARNING "Mixing compiler vendors for C and C++ may produce unexpected results.")
        else()
            if(NOT CMAKE_C_COMPILER_VERSION STREQUAL CMAKE_CXX_COMPILER_VERSION)
                message(WARNING "Mixing compiler versions for C and C++ may produce unexpected results.")
            endif()
        endif()
    endif()

    ## Check for GNU (GCC)
    if(comp_id STREQUAL GNU)
        # Use 'gcc'
        list(APPEND ret --setting compiler=gcc)
        # Parse out the version
        if(NOT comp_version MATCHES "${majmin_ver_re}")
            message(FATAL_ERROR "Unable to parse compiler version string: ${comp_version}")
        endif()
        set(use_version "${CMAKE_MATCH_1}")
        if(use_version VERSION_GREATER_EQUAL 4)
            string(REGEX REPLACE "^([0-9]+)" "\\1" use_version "${use_version}")
        endif()
        list(APPEND ret --setting compiler.version=${use_version})
        # Detect what libstdc++ ABI are likely using.
        if(lang STREQUAL "CXX")
            if(comp_version VERSION_GREATER_EQUAL 5.1)
                list(APPEND ret --setting compiler.libcxx=libstdc++11)
            else()
                list(APPEND ret --setting compiler.libcxx=libstdc++)
            endif()
        endif()
    ## Apple's Clang is a bit of a goob.
    elseif(comp_id STREQUAL AppleClang)
        # Use apple-clang
        list(APPEND ret --setting compiler=apple-clang)
        if(lang STREQUAL "CXX")
            list(APPEND ret --setting compiler.libcxx=libc++)
        endif()
        # Get that version. Same as with Clang
        if(NOT comp_version MATCHES "${majmin_ver_re}")
            message(FATAL_ERROR "Unable to parse compiler version string: ${comp_version}")
        endif()
        list(APPEND ret --setting "compiler.version=${CMAKE_MATCH_1}")
    # Non-Appley Clang.
    elseif(comp_id STREQUAL Clang)
        # Regular clang
        list(APPEND ret --setting compiler=clang)
        # Get that version. Same as with AppleClang
        if(NOT comp_version MATCHES "${majmin_ver_re}")
            message(FATAL_ERROR "Unable to parse compiler version string: ${comp_version}")
        endif()
        list(APPEND ret --setting "compiler.version=${CMAKE_MATCH_1}")
        # TODO: Support libc++ with regular Clang. Plz.
        if(lang STREQUAL "CXX")
            list(APPEND ret --setting compiler.libcxx=libstdc++)
        endif()
    elseif(comp_id STREQUAL "MSVC")
        _pmm_vs_version(vs_version)
        list(APPEND ret --setting "compiler=Visual Studio" --setting compiler.version=${vs_version})
        if (CMAKE_GENERATOR_TOOLSET)
            list(APPEND ret --setting compiler.toolset=${CMAKE_GENERATOR_TOOLSET})
        elseif(CMAKE_VS_PLATFORM_TOOLSET AND (CMAKE_GENERATOR STREQUAL "Ninja"))
            list(APPEND ret --setting compiler.toolset=${CMAKE_VS_PLATFORM_TOOLSET})
        endif()
    else()
        message(FATAL_ERROR "Unable to detect compiler setting for Conan from CMake. (Unhandled compiler ID ${comp_id}).")
    endif()

    if(NOT CMAKE_CONFIGURATION_TYPES)
        set(bt "${CMAKE_BUILD_TYPE}")
        if(NOT bt)
            message(STATUS "[pmm] WARNING: CMAKE_BUILD_TYPE was not set explicitly. We'll install your dependencies as 'Debug'")
            set(bt Debug)
        endif()
        list(APPEND ret --setting build_type=${bt})
    endif()

    # Todo: Cross compiling
    if(CMAKE_SIZEOF_VOID_P EQUAL 8)
        list(APPEND ret --setting arch=x86_64)
    else()
        list(APPEND ret --setting arch=x86)
    endif()

    if(CMAKE_CROSSCOMPILING)
        message(WARNING "[pmm] Cross compiling isn't supported yet. Be careful.")
    endif()

    foreach(setting IN LISTS ARG_SETTINGS)
        list(APPEND ret --setting ${setting})
    endforeach()

    set("${out}" "${ret}" PARENT_SCOPE)
endfunction()

function(_pmm_conan_install_1)
    set(src "${CMAKE_CURRENT_SOURCE_DIR}")
    set(bin "${CMAKE_CURRENT_BINARY_DIR}")
    # Install the thing
    # Do the regular install logic
    get_filename_component(conan_inc "${bin}/conanbuildinfo.cmake" ABSOLUTE)
    get_filename_component(conan_timestamp_file "${bin}/conaninfo.txt" ABSOLUTE)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${conanfile}")

    _pmm_conan_calc_settings_args(more_args)
    foreach(arg IN LISTS ARG_OPTIONS)
        list(APPEND more_args --options ${arg})
    endforeach()

    if(CMAKE_C_COMPILER)
        list(APPEND more_args --env CC=${CMAKE_C_COMPILER})
    endif()
    if(CMAKE_CXX_COMPILER)
        list(APPEND more_args --env CXX=${CMAKE_CXX_COMPILER})
    endif()

    _pmm_set_if_undef(ARG_BUILD missing)
    set(conan_install_cmd
        "${PMM_CONAN_EXECUTABLE}" install "${src}"
            ${more_args}
            --generator cmake
            --build ${ARG_BUILD}
        )
    set(prev_cmd_file "${PMM_DIR}/_prev_conan_install_cmd.txt")
    set(do_install FALSE)
    if("${conanfile}" IS_NEWER_THAN "${conan_timestamp_file}")
        set(do_install TRUE)
    endif()
    if(NOT EXISTS "${prev_cmd_file}")
        set(do_install TRUE)
    else()
        file(READ "${prev_cmd_file}" prev_cmd)
        if(NOT prev_cmd STREQUAL conan_install_cmd)
            set(do_install TRUE)
        endif()
    endif()
    if(do_install)
        message(STATUS "[pmm] Installing Conan requirements from ${conanfile}")
        execute_process(
            COMMAND ${conan_install_cmd}
            WORKING_DIRECTORY "${bin}"
            RESULT_VARIABLE retc
            )
        if(retc)
            message(SEND_ERROR "Conan install failed [${retc}]:\n${out}")
        else()
            file(WRITE "${prev_cmd_file}" "${conan_install_cmd}")
        endif()
    endif()
    set(__conan_inc "${conan_inc}" PARENT_SCOPE)
endfunction()

macro(_pmm_conan_do_setup)
    conan_define_targets()
    conan_set_find_paths()
endmacro()

macro(_pmm_conan_install)
    if(CONAN_EXPORTED AND CONAN_IN_LOCAL_CACHE)
        # When we are being built by conan in the local cache directory we don't need
        # to do an actual conan install: It has already been done for us.
        set(__conan_inc "${CMAKE_CURRENT_BINARY_DIR}/conanbuildinfo.cmake")
        message(STATUS "[pmm] We are being built by Conan, so we won't run the install step.")
        message(STATUS "[pmm] Assuming ${__conan_inc} is present.")
    else()
        _pmm_conan_install_1()
    endif()
    include("${__conan_inc}" OPTIONAL RESULT_VARIABLE __was_included)
    if(NOT __was_included)
        message(SEND_ERROR
            "Conan dependencies were not imported (Expected file ${__conan_inc}). "
            "You may need to run Conan manually (from the build directory). "
            "Ensure you are using the 'cmake' generator.")
    else()
        _pmm_conan_do_setup()
    endif()
    unset(__conan_inc)
    unset(__was_included)
endmacro()

# Implement the `CONAN` subcommand
function(_pmm_conan)
    _pmm_parse_args(
        - BUILD
        + SETTINGS OPTIONS
        )

    # Ensure that we have Conan
    _pmm_ensure_conan()
    if(NOT PMM_CONAN_EXECUTABLE)
        message(SEND_ERROR "Cannot use Conan with PMM because we were unable to find/obtain a Conan executable.")
        return()
    endif()
    if(NOT CONAN_PREV_EXE STREQUAL PMM_CONAN_EXECUTABLE)
        _pmm_exec("${PMM_CONAN_EXECUTABLE}" --version)
        if(_PMM_RC)
            set(exe "${PMM_CONAN_EXECUTABLE}")
            unset(PMM_CONAN_EXECUTABLE CACHE)
            message(FATAL_ERROR "Conan executable (${exe}) seems invalid [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        endif()
        set(_prev "${PMM_CONAN_VERSION}")
        if(_PMM_OUTPUT MATCHES "Conan version ([0-9]+\\.[0-9]+\\.[0-9]+)")
            set(PMM_CONAN_VERSION "${CMAKE_MATCH_1}" CACHE INTERNAL "Conan version")
            if(PMM_CONAN_VERSION VERSION_LESS PMM_CONAN_MIN_VERSION)
                message(WARNING "Conan version ${PMM_CONAN_VERSION} is older than the minimum supported version ${PMM_CONAN_MIN_VERSION}")
            elseif(PMM_CONAN_VERSION VERSION_GREATER PMM_CONAN_MAX_VERSION)
                message(WARNING "Conan version ${PMM_CONAN_VERSION} is newer than the maximum supported version ${PMM_CONAN_MAX_VERSION}")
            endif()
            if(NOT _prev)
                message(STATUS "[pmm] Conan version: ${PMM_CONAN_VERSION}")
            endif()
        else()
            message(WARNING "Command (${PMM_CONAN_EXECUTABLE} --version) did not produce parseable output:\n${_PMM_OUTPUT}")
            set(PMM_CONAN_VERSION "Unknown" CACHE INTERNAL "Conan version")
        endif()
    endif()
    set(CONAN_PREV_EXE "${PMM_CONAN_EXECUTABLE}" CACHE INTERNAL "Previous known-good Conan executable")

    unset(conanfile)
    foreach(fname IN ITEMS conanfile.txt conanfile.py)
        set(cand "${PROJECT_SOURCE_DIR}/${fname}")
        if(EXISTS "${cand}")
            set(conanfile "${cand}")
        endif()
    endforeach()

    if(NOT DEFINED conanfile AND NOT (CONAN_EXPORTED AND CONAN_IN_LOCAL_CACHE))
        message(FATAL_ERROR "pf(CONAN) requires a Conanfile in your project source directory")
    endif()
    _pmm_conan_install()
    _pmm_lift(CMAKE_MODULE_PATH)
    _pmm_lift(CMAKE_PREFIX_PATH)
endfunction()


function(_pmm_script_main_conan)
    _pmm_parse_args(
        . /Version /Create /Upload /Export
        - /Ref /Remote
        )

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

set(PMM_CONAN_MIN_VERSION 1.7.4     CACHE INTERNAL "Minimum Conan version we support")
set(PMM_CONAN_MAX_VERSION 1.7.9999  CACHE INTERNAL "Maximum Conan version we support")

# Get Conan in a new virtualenv using the Python interpreter specified by the
# package of the `python_pkg` arg (Python3 or Python2)
function(_pmm_get_conan_venv python_pkg)
    set(msg "[pmm] Get Conan with ${python_pkg}")
    message(STATUS "${msg}")
    find_package(${python_pkg} COMPONENTS Interpreter QUIET)
    if(NOT TARGET ${python_pkg}::Interpreter)
        # No good
        message(STATUS "${msg} - Fail: No ${python_pkg} interpreter")
        return()
    endif()
    get_target_property(py_exe "${python_pkg}::Interpreter" LOCATION)

    # Try to find a virtualenv module
    unset(venv_mod)
    foreach(cand IN ITEMS venv virtualenv)
        execute_process(
            COMMAND "${py_exe}" -m ${cand} --help
            OUTPUT_VARIABLE out
            ERROR_VARIABLE out
            RESULT_VARIABLE rc
            )
        if(NOT rc)
            set(venv_mod ${cand})
            break()
        endif()
    endforeach()
    if(NOT DEFINED venv_mod)
        message(STATUS "${msg} - Fail: No virtualenv module")
        return()
    endif()

    # Now create a new virtualenv
    set(venv_dir "${PMM_DIR}/_conan_venv")
    set(venv_stamp "${venv_dir}/good.stamp")
    if(NOT EXISTS "${venv_stamp}")
        file(REMOVE_RECURSE "${venv_dir}")
        message(STATUS "${msg} - Create virtualenv")
        execute_process(
            COMMAND "${py_exe}" -m ${venv_mod} "${venv_dir}"
            OUTPUT_VARIABLE out
            ERROR_VARIABLE out
            RESULT_VARIABLE rc
            )
        if(rc)
            message(WARNING "Error while trying to create virtualenv [${rc}]:\n${out}")
            message(STATUS "${msg} - Fail: Could not create virtualenv")
            return()
        endif()
    endif()

    # Get the Python installed therein
    unset(_venv_py CACHE)
    find_program(_venv_py
        NAMES python
        NO_DEFAULT_PATH
        PATHS "${venv_dir}"
        PATH_SUFFIXES bin Scripts
        )
    set(venv_py "${_venv_py}")
    unset(_venv_py CACHE)

    # Upgrade pip installation
    message(STATUS "${msg} - Upgrade Pip")
    execute_process(
        COMMAND "${venv_py}" -m pip install -qU pip setuptools
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out
        RESULT_VARIABLE rc
        )
    if(rc)
        message(WARNING "Failed while upgrading Pip in the virtualenv [${rc}]:\n${out}")
        message(STATUS "${msg} - Fail: Pip could not be upgraded")
        return()
    endif()

    # Finally, install Conan inside the virtualenv.
    message(STATUS "${msg} - Install Conan")
    execute_process(
        COMMAND "${venv_py}" -m pip install -q conan==1.7.4
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out
        RESULT_VARIABLE rc
        )
    if(rc)
        message(WARNING "Failed to install Conan in virtualenv [${rc}]:\n${out}")
        message(STATUS "${msg} - Fail: Could not install Conan in virtualenv")
        return()
    endif()

    # Conan is installed! Set CONAN_EXECUTABLE
    find_program(
        CONAN_EXECUTABLE conan
        NO_DEFAULT_PATH
        PATHS "${venv_dir}"
        PATH_SUFFIXES bin Scripts
        )
    if(NOT CONAN_EXECUTABLE)
        message(WARNING "Conan executbale was not found acter Conan installation. Huh??")
        message(STATUS "${msg} - Fail: No conan executable in Conan installation?")
    else()
        message(STATUS "${msg} - Installed: ${CONAN_EXECUTABLE}")
    endif()
endfunction()

# Ensure the presence of a `CONAN_EXECUTABLE` program
function(_pmm_ensure_conan)
    if(CONAN_EXECUTABLE)
        return()
    endif()

    # Try to find an existing Conan installation
    file(GLOB pyenv_versions "$ENV{HOME}/.pyenv/versions/*")
    set(_prev "${CONAN_EXECUTABLE}")
    find_program(
        CONAN_EXECUTABLE conan
        HINTS
            ${pyenv_versions}
        PATHS
            "$ENV{HOME}/.local"
            C:/Python36
            C:/Python27
            C:/Python
        PATH_SUFFIXES
            bin
            Scripts
        DOC "Path to Conan executable"
        )
    if(CONAN_EXECUTABLE)
        if(NOT _prev)
            message(STATUS "[pmm] Found Conan: ${CONAN_EXECUTABLE}")
        endif()
        return()
    endif()

    message(STATUS "[pmm] No existing Conan installation found. We'll try to obtain one.")

    # No conan. Let's try to get it using Python
    _pmm_get_conan_venv(Python3)
    if(CONAN_EXECUTABLE)
        return()
    endif()
    _pmm_get_conan_venv(Python2)
endfunction()

function(_pmm_conan_install_1)
    set(src "${CMAKE_CURRENT_SOURCE_DIR}")
    set(bin "${CMAKE_CURRENT_BINARY_DIR}")
    # Install the thing
    get_filename_component(conan_paths conan_paths.cmake ABSOLUTE)
    # Do the regular install logic
    get_filename_component(conan_paths "${bin}/conan_paths.cmake" ABSOLUTE)
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${conanfile}")

    if(EXISTS "${conanfile}")
        if("${conanfile}" IS_NEWER_THAN "${conan_paths}")
            message(STATUS "Installing Conan requirements from ${conanfile}")
            execute_process(
                COMMAND "${CONAN_EXECUTABLE}" install "${src}"
                    -e "C=${CMAKE_C_COMPILER}"
                    -e "CXX=${CMAKE_CXX_COMPILER}"
                    -g cmake_paths
                    -b missing
                WORKING_DIRECTORY "${bin}"
                RESULT_VARIABLE retc
                )
            if(retc)
                message(SEND_ERROR "Conan install failed [${retc}]:\n${out}")
            endif()
        endif()
    endif()
    set(__conan_paths "${conan_paths}" PARENT_SCOPE)
endfunction()

macro(_pmm_conan_install)
    _pmm_conan_install_1()
    include("${__conan_paths}" OPTIONAL RESULT_VARIABLE __was_included)
    if(NOT __was_included)
        message(SEND_ERROR "Conan dependencies were not imported (Expected file ${__conan_paths}). You may need to run Conan manually (from the build directory).")
    endif()
    unset(__conan_paths)
    unset(__was_included)
endmacro()

# Implement the `CONAN` subcommand
function(_pmm_conan)
    _pmm_parse_args()

    # Ensure that we have Conan
    _pmm_ensure_conan()
    if(NOT CONAN_EXECUTABLE)
        message(SEND_ERROR "Cannot use Conan with PMM because we were unable to find/obtain a Conan executable.")
        return()
    endif()
    if(NOT CONAN_PREV_EXE STREQUAL CONAN_EXECUTABLE)
        execute_process(
            COMMAND "${CONAN_EXECUTABLE}" --version
            OUTPUT_VARIABLE out
            ERROR_VARIABLE out
            RESULT_VARIABLE retc
            )
        if(retc)
            set(exe "${CONAN_EXECUTABLE}")
            unset(CONAN_EXECUTABLE CACHE)
            message(FATAL_ERROR "Conan executable (${exe}) seems invalid [${retc}]:\n${out}")
        endif()
        set(_prev "${PMM_CONAN_VERSION}")
        if(out MATCHES "Conan version ([0-9]+\\.[0-9]+\\.[0-9]+)")
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
            message(WARNING "Command (${CONAN_EXECUTABLE} --version) did not produce parseable output:\n${out}")
            set(PMM_CONAN_VERSION "Unknown" CACHE INTERNAL "Conan version")
        endif()
    endif()
    set(CONAN_PREV_EXE "${CONAN_EXECUTABLE}" CACHE INTERNAL "Previous known-good Conan executable")

    unset(conanfile)
    foreach(fname IN ITEMS conanfile.txt conanfile.py)
        set(cand "${PROJECT_SOURCE_DIR}/${fname}")
        if(EXISTS "${cand}")
            set(conanfile "${cand}")
        endif()
    endforeach()

    if(NOT DEFINED conanfile)
        message(FATAL_ERROR "pf(CONAN) requires a Conanfile in your project source directory")
    endif()
    _pmm_conan_install()
    _pmm_lift(CMAKE_MODULE_PATH)
    _pmm_lift(CMAKE_PREFIX_PATH)
endfunction()

# Get Conan in a new virtualenv using the Python interpreter specified by the
# package of the `python_pkg` arg (Python3 or Python2)
function(_pmm_get_conan_venv python_pkg)
    set(msg "Get Conan with ${python_pkg}")
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
        COMMAND "${venv_py}" -m pip install -U pip
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

function(_pmm_ensure_conan)
    if(CONAN_EXECUTABLE)
        return()
    endif()

    # Try to find an existing Conan installation
    file(GLOB pyenv_versions "$ENV{HOME}/.pyenv/versions/*")
    set(_prev "${CONAN_EXECUTABLE}")
    find_program(
        CONAN_EXECUTABLE conan
        PATHS
            ${pyenv_versions}
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
            message(STATUS "Found Conan: ${CONAN_EXECUTABLE}")
        endif()
        return()
    endif()

    message(STATUS "No existing Conan installation found. We'll try to obtain one.")

    # No conan. Let's try to get it using Python
    _pmm_get_conan_venv(Python3)
    if(CONAN_EXECUTABLE)
        return()
    endif()
    _pmm_get_conan_venv(Python2)
endfunction()

function(_pmm_conan args)
    set(options)
    set(args)
    set(list_args)
    cmake_parse_arguments(ARG "${options}" "${args}" "${list_args}" "${args}")

    # Ensure that we have Conan
    _pmm_ensure_conan()
    if(NOT CONAN_EXECUTABLE)
        message(SEND_ERROR "Cannot use Conan with PMM because we were unable to find/obtain a Conan executable.")
        return()
    endif()
endfunction()

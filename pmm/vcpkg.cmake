# Download vcpkg at revision `rev` and place the built result in `dir`
function(_pmm_ensure_vcpkg dir rev)
    # The final executable is deterministically placed:
    set(PMM_VCPKG_EXECUTABLE "${dir}/vcpkg${CMAKE_EXECUTABLE_SUFFIX}"
        CACHE FILEPATH
        "Path to vcpkg for this project"
        FORCE
        )
    # Check if the given directory already exists, which means we've already
    # bootstrapped and installed it
    if(IS_DIRECTORY "${dir}")
        return()
    endif()
    # We do the build in a temporary directory, then rename that temporary dir
    # to the final dir
    set(tmp_dir "${_PMM_USER_DATA_DIR}/vcpkg-tmp")
    # Ignore any existing temporary files. They shouldn't be there unless there
    # was an error
    file(REMOVE_RECURSE "${tmp_dir}")
    # Download the Zip archive from GitHub
    get_filename_component(vcpkg_zip "${dir}/../vcpkg-tmp.zip" ABSOLUTE)
    set(url "https://github.com/Microsoft/vcpkg/archive/${rev}.zip")
    message(STATUS "[pmm] Downloading vcpkg at ${rev} ...")
    file(
        DOWNLOAD "${url}" "${vcpkg_zip}"
        STATUS st
        SHOW_PROGRESS
        TLS_VERIFY ON
        )
    list(GET st 0 rc)
    list(GET st 1 msg)
    if(rc)
        message(FATAL_ERROR "Failed to download vcpkg [${rc}]: ${msg}")
    endif()
    # Extract the vcpkg archive into the temporary directory
    message(STATUS "[pmm] Extracting vcpkg archive...")
    file(MAKE_DIRECTORY "${tmp_dir}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -E tar xf "${vcpkg_zip}"
        WORKING_DIRECTORY "${tmp_dir}"
        )
    # There should be one root directory that was extracted.
    file(GLOB vcpkg_root "${tmp_dir}/*")
    list(LENGTH vcpkg_root len)
    if(NOT len EQUAL 1)
        message(FATAL_ERROR "More than one directory extracted from downloaded vcpkg [??]")
    endif()
    # Remove the zip file since we don't need it any more
    file(REMOVE "${vcpkg_zip}")
    if(CMAKE_HOST_WIN32)
        set(bootstrap_ext bat)
    else()
        set(bootstrap_ext sh)
    endif()
    # Run the bootstrap script to prepare the tool
    message(STATUS "[pmm] Bootstrapping the vcpkg tool...")
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -E env
                CC=${CMAKE_C_COMPILER}
                CXX=${CMAKE_CXX_COMPILER}
            "${vcpkg_root}/bootstrap-vcpkg.${bootstrap_ext}"
        OUTPUT_VARIABLE out
        ERROR_VARIABLE out
        RESULT_VARIABLE retc
        )
    if(retc)
        message(FATAL_ERROR "Failed to Bootstrap the vcpkg tool [${retc}]:\n${out}")
    endif()
    # Move the temporary directory to the final directory path
    file(REMOVE_RECURSE "${dir}")
    file(RENAME "${vcpkg_root}" "${dir}")
endfunction()

function(_pmm_vcpkg)
    _pmm_parse_args(
        - REVISION
        + REQUIRES
        )

    if(NOT DEFINED ARG_REVISION)
        message(FATAL_ERROR "Using pmm(VCPKG) requires a REVISION argument. Try `REVISION 43deeaf0c8b6086310ee753be2e93c941f7ffd75`")
    endif()
    get_filename_component(vcpkg_inst_dir "${_PMM_USER_DATA_DIR}/vcpkg-${ARG_REVISION}" ABSOLUTE)
    set(prev "${PMM_VCPKG_EXECUTABLE}")
    _pmm_ensure_vcpkg("${vcpkg_inst_dir}" "${ARG_REVISION}")
    if(NOT prev STREQUAL PMM_VCPKG_EXECUTABLE)
        message(STATUS "[pmm] Using vcpkg executable: ${PMM_VCPKG_EXECUTABLE}")
    endif()
    if(ARG_REQUIRES)
        message(STATUS "[pmm] Installing requirements with vcpkg")
        _pmm_exec(
            ${CMAKE_COMMAND} -E env
                CC=${CMAKE_C_COMPILER}
                CXX=${CMAKE_CXX_COMPILER}
            "${PMM_VCPKG_EXECUTABLE}" install ${ARG_REQUIRES}
            )
        if(_PMM_RC)
            message(FATAL_ERROR "Failed to install requirements with vcpkg [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        endif()
    endif()
    set(_PMM_INCLUDE "${vcpkg_inst_dir}/scripts/buildsystems/vcpkg.cmake" PARENT_SCOPE)
endfunction()

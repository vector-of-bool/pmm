# Regular include_guard() doesn't work because this file may be downloaded and
# replaced within a single CMake config run.
get_cmake_property(_was_included _PMM_BPT_CMAKE_INCLUDED)
if(_was_included)
    return()
endif()
set_property(GLOBAL PROPERTY _PMM_BPT_INCLUDED TRUE)

_pmm_check_and_include_file(dds.cmake)

pmm_option(PMM_BPT_VERSION "1.0.0-beta.1")
pmm_option(PMM_BPT_URL_BASE "https://github.com/vector-of-bool/bpt/releases/download/${PMM_BPT_VERSION}")

if(NOT CMAKE_SCRIPT_MODE_FILE)
    # Script-mode doesn't like calling define_property()
    define_property(GLOBAL PROPERTY BPT_DEPENDENCIES
        BRIEF_DOCS "Dependencies for bpt"
        FULL_DOCS "The accumulated list of dependencies that have been requested via pmm(BPT) with the DEPENDENCIES argument"
        )
    define_property(GLOBAL PROPERTY BPT_DEP_FILES
        BRIEF_DOCS "Dependency files for bpt"
        FULL_DOCS "The accumulated list of dependency JSON5 files that have been requested via pmm(BPT) with the DEP_FILES argument"
        )
endif()

set_property(GLOBAL PROPERTY BPT_DEPENDS "")
set_property(GLOBAL PROPERTY BPT_DEP_FILES "")


function(_pmm_get_bpt_exe out)
    if(DEFINED PMM_BPT_EXECUTABLE)
        _pmm_log("Using user-specified BPT executable: ${PMM_BPT_EXECUTABLE}")
        set("${out}" "${PMM_BPT_EXECUTABLE}" PARENT_SCOPE)
        return()
    endif()
    get_cmake_property(bpt_exe _PMM_BPT_EXE)
    if(bpt_exe)
        set("${out}" "${bpt_exe}" PARENT_SCOPE)
        return()
    endif()
    set(sysname "${CMAKE_HOST_SYSTEM_NAME}")
    if(sysname MATCHES "^Windows")
        set(bpt_dest "${PMM_DIR}/bpt.exe")
        set(bpt_fname "bpt-win-x64.exe")
    elseif(sysname STREQUAL "Linux")
        set(bpt_dest "${PMM_DIR}/bpt")
        set(bpt_fname "bpt-linux-x64")
    elseif(sysname STREQUAL "Darwin")
        set(bpt_dest "${PMM_DIR}/bpt")
        set(bpt_fname "bpt-macos-x64")
    elseif(sysname STREQUAL "FreeBSD")
        set(bpt_dest "${PMM_DIR}/bpt")
        set(bpt_fname "bpt-freebsd-x64")
    else()
        message(FATAL_ERROR "We are unnable to automatically download a bpt executable for this system.")
    endif()
    pmm_option(PMM_BPT_FILENAME "${bpt_fname}")
    pmm_option(PMM_BPT_URL "${PMM_BPT_URL_BASE}/${PMM_BPT_FILENAME}")
    if(NOT EXISTS "${bpt_dest}")
        # Download to a temporary location
        set(bpt_tempfile "${PMM_DIR}/tmp")
        get_filename_component(bpt_fname "${bpt_dest}" NAME)
        set(bpt_tempfile "${bpt_tempfile}/${bpt_fname}")
        _pmm_log(VERBOSE "Downloading bpt from [${bpt_url}]")
        _pmm_download("${PMM_BPT_URL}" "${bpt_tempfile}")
        # Copy the file to its destination with the execute permission bits
        get_filename_component(bpt_dest_dir "${bpt_dest}" DIRECTORY)
        file(
            COPY "${bpt_tempfile}"
            DESTINATION "${bpt_dest_dir}"
            FILE_PERMISSIONS
                OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE
                WORLD_READ WORLD_EXECUTE
            )
    endif()
    set_property(GLOBAL PROPERTY _PMM_BPT_EXE "${bpt_dest}")
    _pmm_log(DEBUG "Local bpt executable: [${bpt_dest}]")
    set("${out}" "${bpt_dest}" PARENT_SCOPE)
endfunction()


function(_pmm_bpt)
    _pmm_log(WARNING "bpt support is experimental! Don't rely on this for critical systems!")
    _pmm_parse_args(
        -hardcheck
        - TOOLCHAIN
        + DEP_FILES DEPENDENCIES
        )
    _pmm_get_bpt_exe(bpt_exe)
    _pmm_generate_shim(bpt "${bpt_exe}")

    # The user may call pmm(BPT) multiple times, in which case we append to the
    # dependencies as we import them, rather than replacing the libman index
    # with the new set of dependencies.
    set_property(GLOBAL APPEND PROPERTY BPT_DEPENDENCIES ${ARG_DEPENDENCIES})
    set_property(GLOBAL APPEND PROPERTY BPT_DEP_FILES ${ARG_DEP_FILES})

    # Get the total accumulated set of dependencies/dep-files
    get_cmake_property(acc_depends BPT_DEPENDENCIES)
    get_cmake_property(acc_dep_files BPT_DEP_FILES)

    # Build the command-line arguments to use with build-deps
    set(bdeps_args ${acc_depends})
    foreach(fname IN LISTS acc_dep_files)
        get_filename_component(deps_fpath "${fname}" ABSOLUTE)
        list(APPEND bdeps_args "--deps-file=${deps_fpath}")
    endforeach()

    if(NOT ARG_TOOLCHAIN)
        # If the user didn't specify a toolchain, generate one now based on the
        # CMake environment
        _pmm_dds_generate_toolchain(ARG_TOOLCHAIN)
    endif()

    set(inc_file "${PROJECT_BINARY_DIR}/_bpt-deps.cmake")
    list(APPEND bdeps_args "--cmake=${inc_file}")
    list(APPEND bdeps_args "--toolchain=${ARG_TOOLCHAIN}")

    _pmm_exec(
        "${bpt_exe}" build-deps ${bdeps_args}
        NO_EAT_OUTPUT
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        )
    if(_PMM_RC)
        message(FATAL_ERROR "bpt failed to build our dependencies [${_PMM_RC}]")
    endif()
    include("${inc_file}")
endfunction()

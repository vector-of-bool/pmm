_pmm_set_if_undef(PMM_DDS_VERSION "0.1.0-alpha.5")
_pmm_set_if_undef(PMM_DDS_URL_BASE "https://github.com/vector-of-bool/dds/releases/download/${PMM_DDS_VERSION}")

if(NOT CMAKE_SCRIPT_MODE_FILE)
    # Script-mode doesn't like calling define_property()
    define_property(GLOBAL PROPERTY DDS_DEPENDS
        BRIEF_DOCS "Dependencies for dds"
        FULL_DOCS "The accumulated list of dependencies that have been requested via pmm(DDS) with the DEPENDS argument"
        )
    define_property(GLOBAL PROPERTY DDS_DEP_FILES
        BRIEF_DOCS "Dependency files for dds"
        FULL_DOCS "The accumulated list of dependency JSON5 files that have been requested via pmm(DDS) with the DEP_FILES argument"
        )
endif()

set_property(GLOBAL PROPERTY DDS_DEPENDS "")
set_property(GLOBAL PROPERTY DDS_DEP_FILES "")

function(_pmm_get_dds_exe out)
    if(DEFINED PMM_DDS_EXECUTABLE)
        _pmm_log("Using user-specified DDS executable: ${PMM_DDS_EXECUTABLE}")
        set("${out}" "${PMM_DDS_EXECUTABLE}" PARENT_SCOPE)
        return()
    endif()
    get_cmake_property(dds_exe _PMM_DDS_EXE)
    if(dds_exe)
        set("${out}" "${dds_exe}" PARENT_SCOPE)
        return()
    endif()
    set(sysname "${CMAKE_HOST_SYSTEM_NAME}")
    if(sysname MATCHES "^Windows")
        set(dds_dest "${PMM_DIR}/dds.exe")
        set(dds_fname "dds-win-x64.exe")
    elseif(sysname STREQUAL "Linux")
        set(dds_dest "${PMM_DIR}/dds")
        set(dds_fname "dds-linux-x64")
    elseif(sysname STREQUAL "Darwin")
        set(dds_dest "${PMM_DIR}/dds")
        set(dds_fname "dds-macos-x64")
    elseif(sysname STREQUAL "FreeBSD")
        set(dds_dest "${PMM_DIR}/dds")
        set(dds_fname "dds-freebsd-x64")
    else()
        message(FATAL_ERROR "We are unnable to automatically download a DDS executable for this system.")
    endif()
    _pmm_set_if_undef(PMM_DDS_FILENAME "${dds_fname}")
    _pmm_set_if_undef(PMM_DDS_URL "${PMM_DDS_URL_BASE}/${PMM_DDS_FILENAME}")
    if(NOT EXISTS "${dds_dest}")
        # Download to a temporary location
        set(dds_tempfile "${PMM_DIR}/tmp")
        get_filename_component(dds_fname "${dds_dest}" NAME)
        set(dds_tempfile "${dds_tempfile}/${dds_fname}")
        _pmm_log(VERBOSE "Downloading DDS from ${dds_url}")
        _pmm_download("${PMM_DDS_URL}" "${dds_tempfile}")
        # Copy the file to its destination with the execute permission bits
        get_filename_component(dds_dest_dir "${dds_dest}" DIRECTORY)
        file(
            COPY "${dds_tempfile}"
            DESTINATION "${dds_dest_dir}"
            FILE_PERMISSIONS
                OWNER_READ OWNER_WRITE OWNER_EXECUTE
                GROUP_READ GROUP_EXECUTE
                WORLD_READ WORLD_EXECUTE
            )
    endif()
    set_property(GLOBAL PROPERTY _PMM_DDS_EXE "${dds_dest}")
    _pmm_log(DEBUG "Local DDS executable: ${dds_dest}")
    set("${out}" "${dds_dest}" PARENT_SCOPE)
endfunction()

function(_pmm_dds_json5_flags_array out)
    set(flags_arr)
    foreach(flag IN LISTS ARGN)
        string(GENEX_STRIP "${flag}" stripped)
        if(NOT stripped STREQUAL flag)
            # The option contained a generator expression. We aren't able to handle those yet...
            # This will be especially useful with multiconf builds
            _pmm_log(WARNING "'dds' toolchain will not include compiler option/definition containing a generator expression: ${flag}")
            continue()
        endif()
        string(REPLACE "'" "\\'" flag "${flag}")
        string(APPEND flags_arr "'${flag}', ")
    endforeach()
    set("${out}" "[${flags_arr}]" PARENT_SCOPE)
endfunction()

function(_pmm_dds_generate_toolchain out)
    get_filename_component(toolchain_dest "${PMM_DIR}/dds-toolchain.json5" ABSOLUTE)

    # First, determine the compiler_id
    if(DEFINED CMAKE_CXX_COMPILER_ID)
        set(comp_id "${CMAKE_CXX_COMPILER_ID}")
    elseif(DEFINED CMAKE_C_COMPILER_ID)
        set(comp_id "${CMAKE_C_COMPILER_ID}")
    else()
        message(FATAL_ERROR "We couldn't determine the compiler ID. Are the C and C++ languages enabled?")
    endif()

    # Check that we recognize the compiler ID
    if(NOT comp_id MATCHES "^(AppleClang|Clang|GNU|MSVC)$")
        _pmm_log(WARNING "We don't recognize the compiler ID '${comp_id}'")
        _pmm_log(WARNING "It is likely that you will need to write your own toolchain file by hand...")
    endif()

    string(TOLOWER "${comp_id}" comp_id)

    # Determine the cxx_version to pass through the toolchain
    get_directory_property(std CXX_STANDARD)
    if(NOT std)
        set(std "${CMAKE_CXX_STANDARD}")
    endif()
    if(std EQUAL 98)
        set(cxx_version_line "cxx_version: 'c++98',")
    elseif(std EQUAL 11)
        set(cxx_version_line "cxx_version: 'c++11',")
    elseif(std EQUAL 14)
        set(cxx_version_line "cxx_version: 'c++14',")
    elseif(std EQUAL 17)
        set(cxx_version_line "cxx_version: 'c++17',")
    elseif(std EQUAL 20)
        set(cxx_version_line "cxx_version: 'c++20',")
    elseif(std)
        _pmm_log(WARNING "We don't recognize the CXX_STANDARD version '${std}'.")
        _pmm_log(WARNING "You may want to specify a standard version when calling pmm()")
    else()
        # No standard was set. We'll leave it unspecified and allow the compiler's default
    endif()

    set(c_compiler_line)
    if(CMAKE_C_COMPILER)
        set(c_compiler_line "c_compiler: '${CMAKE_C_COMPILER}',")
    endif()

    set(cxx_compiler_line)
    if(CMAKE_CXX_COMPILER)
        set(cxx_compiler_line "cxx_compiler: '${CMAKE_CXX_COMPILER}',")
    endif()

    # Multi-conf builds are *possible*, but will require a significant amount of
    # work.
    if(CMAKE_CONFIGURATION_TYPES)
        _pmm_log(WARNING "Using pmm+dds with multi-conf builds is not yet fully supported.")
        set(gen_debug TRUE)
        set(optimize true)
    endif()

    set(rt_option "${CMAKE_MSVC_RUNTIME_LIBRARY}")
    if(NOT rt_option)
        set(rt_option "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    endif()

    # Enable debug info:
    if(CMAKE_BUILD_TYPE MATCHES "^(Debug|RelWithDebInfo|)$")
        set(gen_debug TRUE)
        string(REPLACE "$<CONFIG:Debug>" 1 rt_option "${rt_option}")
    else()
        set(gen_debug FALSE)
        string(REPLACE "$<CONFIG:Debug>" 0 rt_option "${rt_option}")
    endif()

    # Enable optimizations:
    if(CMAKE_BUILD_TYPE MATCHES "^(Release|RelWithDebInfo|MinSizeRel)$")
        set(optimize true)
    else()
        set(optimize false)
    endif()

    # Determine the runtime options
    string(REPLACE "$<1:Debug>" Debug rt_option "${rt_option}")
    string(REPLACE "$<0:Debug>" "" rt_option "${rt_option}")
    set(rt_obj "{}")
    if(MSVC)
        set(rt_debug false)
        if(rt_option MATCHES "^MultiThreadedDebug")
            set(rt_debug true)
        endif()
        set(rt_static true)
        if(rt_option MATCHES "DLL$")
            set(rt_static false)
        endif()
        set(rt_obj "{debug: ${rt_debug}, static: ${rt_static}}")
    endif()

    # Pass in language flags for the current config
    string(TOUPPER "${CMAKE_BUILD_TYPE}" bt_upper)
    set(c_bt_flags "${CMAKE_C_FLAGS} ${CMAKE_C_FLAGS_${bt_upper}}")
    set(cxx_bt_flags "${CMAKE_CXX_FLAGS} ${CMAKE_CXX_FLAGS_${bt_upper}}")
    separate_arguments(c_opts NATIVE_COMMAND "${c_bt_flags}")
    separate_arguments(cxx_opts NATIVE_COMMAND "${cxx_bt_flags}")
    _pmm_dds_json5_flags_array(c_flags_arr ${c_opts})
    _pmm_dds_json5_flags_array(cxx_flags_arr ${cxx_opts})

    # Pass thru compile flags and definitions from the enclosing source directory
    get_directory_property(compile_flags COMPILE_OPTIONS)
    get_directory_property(defs COMPILE_DEFINITIONS)
    foreach(def IN LISTS defs)
        list(APPEND compile_flags "-D${def}")
    endforeach()
    _pmm_dds_json5_flags_array(flags_arr ${compile_flags})

    if(NOT gen_debug)
        set(debug_str "none")
    elseif(MSVC AND ("/Zi" IN_LIST cxx_opts
                     OR "/ZI" IN_LIST cxx_opts))
        # Set flags for doing split debug info
        set(debug_str "split")
    elseif("/Z7" IN_LIST cxx_opts)
        # Don't pass an additional /Z7
        set(debug_str "none")
    else()
        set(debug_str "embedded")
    endif()

    # Detect a compiler launcher (i.e. `ccache`)
    if(DEFINED PMM_DDS_COMPILER_LAUNCHER)
        set(launcher "${PMM_DDS_COMPILER_LAUNCHER}")
    else()
        get_directory_property(launcher CXX_COMPILER_LAUNCHER)
        if(NOT launcher)
            set(launcher "${CMAKE_CXX_COMPILER_LAUNCHER}")
        endif()
    endif()
    _pmm_dds_json5_flags_array(launcher ${launcher})

    string(CONFIGURE [[
        {
            compiler_id: '@comp_id@',
            @c_compiler_line@
            @cxx_compiler_line@
            @cxx_version_line@
            flags: @flags_arr@,
            c_flags: @c_flags_arr@,
            cxx_flags: @cxx_flags_arr@,
            debug: '@debug_str@',
            optimize: @optimize@,
            runtime: @rt_obj@,
            compiler_launcher: @launcher@,
        }
    ]] toolchain_content @ONLY)
    file(WRITE "${toolchain_dest}" "${toolchain_content}")
    set("${out}" "${toolchain_dest}" PARENT_SCOPE)
    _pmm_log(DEBUG "Generated dds toolchain at ${toolchain_dest} with content: ${toolchain_content}")
endfunction()

function(_pmm_dds)
    _pmm_log(WARNING "dds support is experimental! Don't rely on this for critical systems!")
    _pmm_parse_args(
        -hardcheck
        - TOOLCHAIN CATALOG
        + DEP_FILES DEPENDS IMPORT
        )

    _pmm_get_dds_exe(dds_exe)

    # The user may call pmm(DDS) multiple times, in which case we append to the
    # dependencies as we import them, rather than replacing the libman index
    # with the new set of dependencies.
    set_property(GLOBAL APPEND PROPERTY DDS_DEPENDS ${ARG_DEPENDS})
    set_property(GLOBAL APPEND PROPERTY DDS_DEP_FILES ${ARG_DEP_FILES})

    # Get the total accumulated set of dependencies/dep-files
    get_cmake_property(acc_depends DDS_DEPENDS)
    get_cmake_property(acc_dep_files DDS_DEP_FILES)

    # Build the command-line arguments to use with build-deps
    set(bdeps_args ${acc_depends})
    foreach(fname IN LISTS acc_dep_files)
        get_filename_component(deps_fpath "${fname}" ABSOLUTE)
        list(APPEND bdeps_args "--deps=${deps_fpath}")
    endforeach()

    # The user may specify a catalog file that should be imported for the build.
    # Otherwise, we'll use the user-local catalog
    if(ARG_CATALOG)
        set(catalog_path "${PMM_DIR}/dds-catalog.db")
        set(catalog_arg "--catalog=${catalog_path}")
        list(APPEND bdeps_args "${catalog_arg}")
        get_filename_component(catalog_json_path "${ARG_CATALOG}" ABSOLUTE)
        _pmm_exec("${dds_exe}" catalog import --json ${catalog_json_path} ${catalog_arg} NO_EAT_OUTPUT)
        if(_PMM_RC)
            message(FATAL_ERROR "dds catalog-import of [${ARG_CATALOG}] failed [${_PMM_RC}]")
        endif()
    endif()

    if(NOT ARG_TOOLCHAIN)
        # If the user didn't specify a toolchain, generate one now based on the
        # CMake environment
        _pmm_dds_generate_toolchain(ARG_TOOLCHAIN)
    endif()

    list(APPEND bdeps_args "--toolchain=${ARG_TOOLCHAIN}")

    _pmm_exec(
        "${dds_exe}" build-deps ${bdeps_args}
        NO_EAT_OUTPUT
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
        )
    if(_PMM_RC)
        message(FATAL_ERROR "DDS failed to build our dependencies [${_PMM_RC}]")
    endif()

    if(IMPORT IN_LIST ARGV)
        if(NOT COMMAND import_packages)
            include(libman OPTIONAL RESULT_VARIABLE did_import)
            if(NOT did_import)
                message(FATAL_ERROR "pmm(DDS IMPORT): No 'import_packages' command is defined, and no 'libman' module is available")
            endif()
        endif()
        if(ARG_IMPORT STREQUAL "AUTO")
            if(ARG_DEP_FILES)
                message(WARNING "DDS IMPORT AUTO does not work properly with DEP_FILES. Packages from the given dep-files will not be imported.")
            endif()
            foreach(dep IN LISTS ARG_DEPENDS)
                if(NOT dep MATCHES "^(.+)[@=\\+\\^~]")
                    message(SEND_ERROR "Cannot auto-import dependency statement: ${dep}")
                    continue()
                endif()
                import_packages("${CMAKE_MATCH_1}")
            endforeach()
        else()
            foreach(import IN LISTS ARG_IMPORT)
                import_packages("${import}")
            endforeach()
        endif()
    endif()
endfunction()

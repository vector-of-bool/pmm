# Download vcpkg at revision `rev` and place the built result in `dir`
function(_pmm_ensure_vcpkg dir rev)
    _pmm_verbose_lock(
        "${dir}.lock"
        FIRST_MESSAGE "Another CMake instance is bootstrapping vcpkg. Please wait..."
        FAIL_MESSAGE "Unable to obtain vcpkg bootstrapping lock. Check if there is a stuck process holding it open."
        RESULT_VARIABLE did_lock
        LAST_WAIT_DURATION 240
        )
    if(NOT did_lock)
        message(FATAL_ERROR "Unable to obtain exclusive lock on directory ${_PMM_CONAN_MANAGED_VENV_DIR}. Abort.")
    endif()
    # The final executable is deterministically placed:
    set(PMM_VCPKG_EXECUTABLE "${dir}/vcpkg${CMAKE_EXECUTABLE_SUFFIX}"
        CACHE FILEPATH
        "Path to vcpkg for this project"
        FORCE
        )
    _pmm_log(DEBUG "Expecting vcpkg executable at ${PMM_VCPKG_EXECUTABLE}")
    # Check if the vcpkg exe already exists, which means we've already
    # bootstrapped and installed it
    if(EXISTS "${PMM_VCPKG_EXECUTABLE}")
        file(LOCK "${dir}.lock" RELEASE)
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
    _pmm_log("Downloading vcpkg at ${rev} ...")
    _pmm_log(VERBOSE "vcpkg ZIP archive lives at ${url}")
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
    _pmm_log("Extracting vcpkg archive...")
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
    _pmm_log("Bootstrapping the vcpkg tool (This may take a minute)...")
    set(no_eat)
    if(PMM_DEBUG)
        set(no_eat NO_EAT_OUTPUT)
    endif()
    _pmm_exec(
            ${CMAKE_COMMAND} -E env
                CC=${CMAKE_C_COMPILER}
                CXX=${CMAKE_CXX_COMPILER}
            "${vcpkg_root}/bootstrap-vcpkg.${bootstrap_ext}"
            ${no_eat}
        )
    if(_PMM_RC)
        message(FATAL_ERROR "Failed to Bootstrap the vcpkg tool [${_PMM_RC}]:\n${_PMM_OUTPUT}")
    endif()
    _pmm_log("Testing bootstrapped vcpkg")
    _pmm_exec("${vcpkg_root}/vcpkg${CMAKE_EXECUTABLE_SUFFIX}" version)
    if(_PMM_RC)
        message(FATAL_ERROR "Failed to execute generated vcpkg tool [${_PMM_RC}]:\n:${_PMM_OUTPUT}")
    endif()
    # Move the temporary directory to the final directory path
    file(REMOVE_RECURSE "${dir}")
    file(RENAME "${vcpkg_root}" "${dir}")
    _pmm_log("vcpkg successfully bootstrapped to ${dir}")
    # Fix for "Could not detect vcpkg-root."
    execute_process(COMMAND ${CMAKE_COMMAND} -E sleep 1)
    # Release the exclusive lock on the directory we obtained at the top of this fn
    file(LOCK "${dir}.lock" RELEASE)
endfunction()

function(_pmm_vcpkg_default_triplet out)
    string(TOLOWER "${CMAKE_GENERATOR_PLATFORM}" plat)
    string(TOLOWER "${CMAKE_GENERATOR}" gen)
    set(compiler "${CMAKE_CXX_COMPILER}")
    if(NOT compiler)
        set(compiler "${CMAKE_C_COMPILER}")
    endif()
    # Determine that thing!
    if(FALSE)
        # Just for alignment
    elseif(plat STREQUAL "win32")
        set(arch x86)
    elseif(plat STREQUAL "x64")
        set(arch x64)
    elseif(plat STREQUAL "arm")
        set(arch arm)
    elseif(plat STREQUAL "arm64")
        set(arch arm64)
    else()
        if(gen MATCHES "^Visual Studio 1. 20.. Win64$")
            set(arch x64)
        elseif(gen MATCHES "^Visual Studio 1. 20.. ARM$")
            set(arch arm)
        elseif(gen MATCHES "^Visual Studio 1. 20..$")
            set(arch x86)
        else()
            if(compiler MATCHES "(amd64|x64)/cl.exe$")
                set(arch x64)
            elseif(compiler MATCHES "arm/cl.exe$")
                set(arch arm)
            elseif(compiler MATCHES "arm64/cl.exe$")
                set(arch arm64)
            elseif(compiler MATCHES "(bin|x86)/cl.exe$")
                set(arch x86)
            elseif(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "x86_64")
                set(arch x64)
            elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
                set(arch x86)
            elseif(CMAKE_SIZEOF_VOID_P EQUAL 8)
                set(arch x64)
            else()
                message(FATAL_ERROR "Unable to determine target triple for vcpkg.")
            endif()
        endif()
    endif()

    set(sysname "${CMAKE_SYSTEM_NAME}")
    if(NOT sysname AND CMAKE_HOST_SYSTEM_NAME)
        set(sysname "${CMAKE_HOST_SYSTEM_NAME}")
    endif()
    if(sysname MATCHES "^Windows(Store|Phone)$")
        set(platform uwp)
    elseif(sysname STREQUAL "Linux")
        set(platform linux)
    elseif(sysname STREQUAL "Darwin")
        set(platform osx)
    elseif(sysname STREQUAL "Windows")
        set(platform windows)
    elseif(sysname STREQUAL "FreeBSD")
        set(platform freebsd)
    endif()
    set(${out} "${arch}-${platform}" PARENT_SCOPE)
endfunction()

function(_pmm_vcpkg_copy_custom_ports ports_list)
    foreach(port IN LISTS ports_list)
        # Port name is based on the directory name
        get_filename_component(port_name ${port} NAME)
        if(NOT EXISTS "${port}/portfile.cmake")
            message(FATAL_ERROR "Failed find portfile in ${port}!")
        endif()

        # Prepare a directory for this port
        set(port_dest_dir "${__vcpkg_inst_dir}/ports/${port_name}")
        if(EXISTS "${port_dest_dir}" AND NOT EXISTS "${port_dest_dir}/CUSTOM_PORT_FROM_PMM.txt")
            message(WARNING "Portfile already included by default!")
        elseif(NOT EXISTS "${port_dest_dir}/CUSTOM_PORT_FROM_PMM.txt")
            file(MAKE_DIRECTORY "${port_dest_dir}")
            # Use this stamp file to tell others/ourself this is a Port copied by PMM
            file(WRITE "${port_dest_dir}/CUSTOM_PORT_FROM_PMM.txt" "This is a custom port copied by PMM")
        endif()

        # Copy all files from the port:
        file(GLOB port_files "${port}/*")
        foreach(port_file_src IN LISTS port_files)
          get_filename_component(port_file_name ${port_file_src} NAME)
          set(port_file_dest "${port_dest_dir}/${port_file_name}")
          file(TIMESTAMP ${port_file_dest} port_file_location_ts)
          file(TIMESTAMP ${port_file_src} port_file_ts)
          _pmm_log(DEBUG "Timestamp: ${port_file_location_ts} for ${port_file_dest}")
          _pmm_log(DEBUG "Timestamp: ${port_file_ts} for ${port_file_src}")
          if(NOT "${port_file_ts}" STREQUAL "${port_file_location_ts}")
              _pmm_log(VERBOSE "${port_name}: Copying ${port_file_src} to ${port_file_dest}")
              file(COPY "${port_file_src}" DESTINATION "${__vcpkg_inst_dir}/ports/${port_name}/")
          else()
              _pmm_log(VERBOSE "${port_name}: ${port_file_name} is up to date")
          endif()
        endforeach()
    endforeach()
endfunction()

function(_pmm_vcpkg)
    _pmm_parse_args(
        - REVISION TRIPLET
        + REQUIRES PORTS OVERLAY_PORTS OVERLAY_TRIPLETS
        )

    if(NOT DEFINED ARG_REVISION)
        message(FATAL_ERROR "Using pmm(VCPKG) requires a REVISION argument. Try `REVISION 2022.05.10`")
    endif()
    if(NOT DEFINED ARG_TRIPLET)
        _pmm_vcpkg_default_triplet(ARG_TRIPLET)
    endif()

    _pmm_log(VERBOSE "Using vcpkg target triplet ${ARG_TRIPLET}")
    get_filename_component(__vcpkg_inst_dir "${_PMM_USER_DATA_DIR}/vcpkg-${ARG_REVISION}" ABSOLUTE)
    _pmm_log(DEBUG "vcpkg directory is ${__vcpkg_inst_dir}")
    set(prev "${PMM_VCPKG_EXECUTABLE}")

    _pmm_ensure_vcpkg("${__vcpkg_inst_dir}" "${ARG_REVISION}")
    if(NOT prev STREQUAL PMM_VCPKG_EXECUTABLE)
        _pmm_log("Using vcpkg executable: ${PMM_VCPKG_EXECUTABLE}")
    endif()

    if(DEFINED ARG_PORTS)
        _pmm_vcpkg_copy_custom_ports("${ARG_PORTS}")
    endif()

    set(vcpkg_install_args
        --triplet "${ARG_TRIPLET}"
        --recurse
        ${ARG_REQUIRES}
        )

    foreach(overlay IN LISTS ARG_OVERLAY_PORTS)
        get_filename_component(overlay "${overlay}" ABSOLUTE)
        list(APPEND vcpkg_install_args "--overlay-ports=${overlay}")
    endforeach()

    foreach(triplet IN LISTS ARG_OVERLAY_TRIPLETS)
        get_filename_component(triplet "${triplet}" ABSOLUTE)
        list(APPEND vcpkg_install_args "--overlay-triplets=${triplet}")
    endforeach()

    if(ARG_REQUIRES)
        _pmm_log("Installing requirements with vcpkg")
        set(cmd ${CMAKE_COMMAND} -E env
                VCPKG_ROOT=${__vcpkg_inst_dir}
                CC=${CMAKE_C_COMPILER}
                CXX=${CMAKE_CXX_COMPILER}
            "${PMM_VCPKG_EXECUTABLE}" install ${vcpkg_install_args}
            )
        set(install_lock "${PMM_VCPKG_EXECUTABLE}.install-lock")
        _pmm_verbose_lock(
            "${install_lock}"
            FIRST_MESSAGE "Another 'vcpkg install' process is running. Wait..."
            FAIL_MESSAGE "Unable to obtain an exclusive lock on the install process. Will continue anyway, but may fail spuriously"
            )
        _pmm_exec(${cmd} NO_EAT_OUTPUT)
        file(LOCK "${install_lock}" RELEASE)
        if(_PMM_RC)
            message(FATAL_ERROR "Failed to install requirements with vcpkg [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        else()
            _pmm_log(DEBUG "vcpkg output:\n${_PMM_OUTPUT}")
        endif()
    endif()
    set(_PMM_INCLUDE "${__vcpkg_inst_dir}/scripts/buildsystems/vcpkg.cmake" PARENT_SCOPE)
    _pmm_generate_shim(vcpkg "${PMM_VCPKG_EXECUTABLE}")
endfunction()

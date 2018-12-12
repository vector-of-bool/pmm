# Download vcpkg at revision `rev` and place the built result in `dir`
function(_pmm_ensure_vcpkg dir rev)
    # The final executable is deterministically placed:
    set(PMM_VCPKG_EXECUTABLE "${dir}/vcpkg${CMAKE_EXECUTABLE_SUFFIX}"
        CACHE FILEPATH
        "Path to vcpkg for this project"
        FORCE
        )
    _pmm_log(DEBUG "Expecting vcpkg executable at ${PMM_VCPKG_EXECUTABLE}")
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
            elseif(compiler MATCHES "(bin|x64)/cl.exe$")
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

function(_pmm_vcpkg)
    _pmm_parse_args(
        - REVISION TRIPLET
        + REQUIRES
        )

    if(NOT DEFINED ARG_REVISION)
        # This is just a random revision people can plop down in for the REVISION
        # argument. There isn't anything significant about this particular
        # revision, other than being the revision of the `master` branch at the
        # time I typed this comment. If you are modifying PMM, feel free to
        # change this revision number to whatever is the latest in the vcpkg
        # repository. (https://github.com/Microsoft/vcpkg)
        message(FATAL_ERROR "Using pmm(VCPKG) requires a REVISION argument. Try `REVISION cf7e2f3906f78dcb89f320a642428b54c00e4e0b`")
    endif()
    if(NOT DEFINED ARG_TRIPLET)
        _pmm_vcpkg_default_triplet(ARG_TRIPLET)
    endif()
    _pmm_log(VERBOSE "Using vcpkg target triplet ${ARG_TRIPLET}")
    get_filename_component(vcpkg_inst_dir "${_PMM_USER_DATA_DIR}/vcpkg-${ARG_REVISION}" ABSOLUTE)
    _pmm_log(DEBUG "vcpkg directory is ${vcpkg_inst_dir}")
    set(prev "${PMM_VCPKG_EXECUTABLE}")
    _pmm_ensure_vcpkg("${vcpkg_inst_dir}" "${ARG_REVISION}")
    if(NOT prev STREQUAL PMM_VCPKG_EXECUTABLE)
        _pmm_log("Using vcpkg executable: ${PMM_VCPKG_EXECUTABLE}")
    endif()
    if(ARG_REQUIRES)
        _pmm_log("Installing requirements with vcpkg")
        set(cmd ${CMAKE_COMMAND} -E env
                CC=${CMAKE_C_COMPILER}
                CXX=${CMAKE_CXX_COMPILER}
            "${PMM_VCPKG_EXECUTABLE}" install
                --triplet "${ARG_TRIPLET}"
                ${ARG_REQUIRES}
            )
        _pmm_exec(${cmd})
        if(_PMM_RC)
            message(FATAL_ERROR "Failed to install requirements with vcpkg [${_PMM_RC}]:\n${_PMM_OUTPUT}")
        else()
            _pmm_log(DEBUG "vcpkg output:\n${_PMM_OUTPUT}")
        endif()
    endif()
    set(_PMM_INCLUDE "${vcpkg_inst_dir}/scripts/buildsystems/vcpkg.cmake" PARENT_SCOPE)
endfunction()

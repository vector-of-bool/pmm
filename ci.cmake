function(exec_checked message)
    execute_process(COMMAND ${ARGN} RESULT_VARIABLE retc)
    if(retc)
        message(FATAL_ERROR "Step '${message}' failed [${retc}]")
    endif()
endfunction()

if(WIN32)
    exec_checked("Install ninja-build" choco install ninja)
    find_program(NINJA_EXECUTABLE ninja)
endif()

if(NOT NINJA_EXECUTABLE)
    message(FATAL_ERROR "No ninja executable for building")
endif()

if(APPLE)
    exec_checked("Install GCC 6 for the C++ FS TS" brew install gcc6)
    file(GLOB gcc_exe /usr/local/Cellar/gcc@6/*/*/gcc)
    list(GET gcc_exe 0 gcc_exe)
    get_filename_component(gcc_bindir "${gcc_exe}" DIRECTORY)
    set(env_params "CC=${gcc_exe}" "CXX=${gcc_bindir}/g++")
endif()

set(src "${CMAKE_CURRENT_LIST_DIR}")
set(bin "${src}/ci-build")

file(REMOVE_RECURSE "${bin}")

exec_checked("Configure project"
    "${CMAKE_COMMAND}" -E env ${env_params}
        "${CMAKE_COMMAND}" -GNinja "-H${src}" "-B${bin}"
    )

exec_checked("Build project"
    "${CMAKE_COMMAND}" -E env ${env_params}
        "${CMAKE_COMMAND}" --build "${bin}"
    )

get_filename_component(cm_dir "${CMAKE_COMMAND}" DIRECTORY)
find_program(ctest_exe NAMES ctest HINTS "${cm_dir}")

exec_checked("Run CTest"
    "${CMAKE_COMMAND}" -E env ${env_params}
        "${ctest_exe}" -j6 --output-on-failure
    WORKING_DIRECTORY "${bin}"
    )

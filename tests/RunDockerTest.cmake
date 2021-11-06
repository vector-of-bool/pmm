include(${CMAKE_CURRENT_LIST_DIR}/../pmm/util.cmake)
_pmm_parse_script_args(
    . /Verbose
    - /Docker /ContainerName /ProjectDir
    )

find_program(ARG_/Docker docker)

set(test_pr_dir "${ARG_/ProjectDir}")

if(NOT ARG_/Verbose)
    set(OUTPUT_EAT_ARGS ERROR_VARIABLE out OUTPUT_VARIABLE out)
endif()

function(run_checked)
    execute_process(
        ${OUTPUT_EAT_ARGS}
        RESULT_VARIABLE retc
        COMMAND ${ARGN}
        )
    if(retc)
        string(REPLACE ";" " " cmd "${ARGN}")
        message(FATAL_ERROR "Running command (${cmd}) failed [${retc}]: ${out}")
    endif()
endfunction()

message(STATUS "Configuring project")
get_filename_component(pmm_dir "${CMAKE_CURRENT_LIST_DIR}/../pmm" ABSOLUTE)
set(mount_args
    -v "${test_pr_dir}:/host/source"
    -v "${CMAKE_CURRENT_LIST_DIR}/../pmm:/host/pmm"
    -v "${CMAKE_CURRENT_LIST_DIR}/../pmm.cmake:/host/pmm.cmake"
    )
run_checked(${ARG_/Docker} run --rm -t ${mount_args} ${ARG_/ContainerName}
    ctest
        --build-and-test /host/source /tmp/build
        --build-generator "Unix Makefiles"
        -VV
        --build-options
            -DPMM_URL=file:///host/pmm
            -DPMM_INCLUDE=/host/pmm.cmake
        --test-command
            ctest --output-on-failure -j4
    )

include(${CMAKE_CURRENT_LIST_DIR}/../pmm/util.cmake)
_pmm_parse_script_args(
    . /Verbose
    - /Docker /Test
    )

find_program(ARG_/Docker docker)

get_filename_component(test_dir "${CMAKE_CURRENT_LIST_DIR}/${ARG_/Test}.docker" ABSOLUTE)
set(test_pr_dir "${test_dir}/project")
if(NOT EXISTS "${test_pr_dir}")
    set(test_pr_dir "${CMAKE_CURRENT_LIST_DIR}/default-project")
endif()

if(NOT ARG_/Verbose)
    set(OUTPUT_EAT_ARGS ERROR_VARIABLE out out OUTPUT_VARIABLE out)
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

set(image_name pmm.test_container.${ARG_/Test})

message(STATUS "Building Docker container")
run_checked(${ARG_/Docker} build -t "${image_name}" "${test_dir}")

message(STATUS "Configuring project")
get_filename_component(pmm_dir "${CMAKE_CURRENT_LIST_DIR}/../pmm" ABSOLUTE)
set(mount_args
    -v "${test_pr_dir}:/host/source"
    -v "${CMAKE_CURRENT_LIST_DIR}/../pmm:/host/pmm"
    -v "${CMAKE_CURRENT_LIST_DIR}/../pmm.cmake:/host/pmm.cmake"
    )
run_checked(${ARG_/Docker} run --rm -t ${mount_args} ${image_name}
    cmake
        -H/host/source
        -B/tmp/build
        -DPMM_URL=file:///host/pmm
        -DPMM_INCLUDE=/host/pmm.cmake
    )

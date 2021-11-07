include(${CMAKE_CURRENT_LIST_DIR}/../pmm/util.cmake)
_pmm_parse_script_args(
    . /Verbose
    - /Docker /ContainerName /ProjectDir
    )

find_program(ARG_/Docker docker)

set(test_pr_dir "${ARG_/ProjectDir}")

function(run_checked)
    execute_process(
        RESULT_VARIABLE retc
        COMMAND ${ARGN}
        )
    if(retc)
        string(REPLACE ";" " " cmd "${ARGN}")
        message(FATAL_ERROR "Running command (${cmd}) failed [${retc}]: ${out}")
    endif()
endfunction()

get_filename_component(pmm_dir "${CMAKE_CURRENT_LIST_DIR}/../pmm" ABSOLUTE)
set(mount_args
    -v "${test_pr_dir}:/host/source:ro"
    -v "${CMAKE_CURRENT_LIST_DIR}/../pmm:/host/pmm:ro"
    -v "${CMAKE_CURRENT_LIST_DIR}/../pmm.cmake:/host/pmm.cmake:ro"
    -v "${CMAKE_CURRENT_LIST_DIR}/..:/host/pmm-repo:ro"
    )
run_checked(${ARG_/Docker} run --rm -t ${mount_args} ${ARG_/ContainerName}
    cmake -P /host/pmm-repo/tests/BuildTestProject.cmake
        /SourceDir /host/source
        /BinaryDir /tmp/build
        /Generator "Unix Makefiles"
    )

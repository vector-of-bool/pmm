include(${CMAKE_CURRENT_LIST_DIR}/../pmm/util.cmake)
_pmm_parse_script_args(
    . /Verbose
    - /Docker /ContainerName /DockerBuildDir
    )

find_program(ARG_/Docker docker)

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

message(STATUS "Building Docker container")
run_checked(${ARG_/Docker} build -t "${ARG_/ContainerName}" "${ARG_/DockerBuildDir}")

file(REMOVE_RECURSE "${BUILD_DIR}")

execute_process(
    COMMAND ${CMAKE_COMMAND}
        -D PMM_URL=${PMM_URL}
        -D PMM_INCLUDE=${PMM_INCLUDE}
        -D PMM_DEBUG=TRUE
        -G ${GENERATOR}
        "-H${SOURCE_DIR}"
        "-B${BUILD_DIR}"
    RESULT_VARIABLE retc
    )

if(retc)
    message(FATAL_ERROR "Configure failed [${retc}]")
endif()

exec_program(
    COMMAND ${CMAKE_COMMAND} --build ${BUILD_DIR}
    RESULT_VARIABLE retc
    )

if(retc)
    message(FATAL_ERROR "Build failed [${retc}]")
endif()

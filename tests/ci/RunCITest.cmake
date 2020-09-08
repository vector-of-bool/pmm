file(REMOVE_RECURSE "${BUILD_DIR}")

function(_build config)
    message(STATUS "Building config '${config}'")
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -D CMAKE_BUILD_TYPE=${config}
            -D PMM_URL=${PMM_URL}
            -D PMM_INCLUDE=${PMM_INCLUDE}
            -D PMM_DEBUG=TRUE
            -D PMM_ALWAYS_DOWNLOAD=TRUE
            -G ${GENERATOR}
            "-H${SOURCE_DIR}"
            "-B${BUILD_DIR}"
        RESULT_VARIABLE retc
        )

    if(retc)
        message(FATAL_ERROR "Configure failed [${retc}]")
    endif()

    execute_process(
        COMMAND ${CMAKE_COMMAND} --build ${BUILD_DIR}
        RESULT_VARIABLE retc
        )

    if(retc)
        message(FATAL_ERROR "Build failed [${retc}]")
    endif()
endfunction()

_build(Debug)
_build(Release)

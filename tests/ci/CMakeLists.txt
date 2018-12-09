foreach(subdir
        conan
        vcpkg
        )
    get_filename_component(fulldir ${subdir} ABSOLUTE)
    add_test(
        NAME "pmm.test.ci.${subdir}"
        COMMAND "${CMAKE_COMMAND}"
            -D "PMM_URL=file://${PROJECT_SOURCE_DIR}/pmm"
            -D "PMM_INCLUDE=${PROJECT_SOURCE_DIR}/pmm.cmake"
            -D GENERATOR=${CMAKE_GENERATOR}
            -D "BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}/${subdir}"
            -D SOURCE_DIR=${fulldir}
            -P "${CMAKE_CURRENT_SOURCE_DIR}/RunCITest.cmake"
        )
endforeach()

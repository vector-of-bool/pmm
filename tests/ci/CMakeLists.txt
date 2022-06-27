set(common_test_args)

function(add_pmm_ci_test name)
    _pmm_parse_args(
        -hardcheck
        - GENERATOR SOURCE_DIR
    )
    get_filename_component(dirpath "${ARG_SOURCE_DIR}" ABSOLUTE)
    pmm_option(ARG_GENERATOR "${CMAKE_GENERATOR}")
    add_test(
        NAME "pmm.test.ci.${name}"
        COMMAND "${CMAKE_COMMAND}"
            -D "PMM_URL=file://${PROJECT_SOURCE_DIR}/pmm"
            -D "PMM_INCLUDE=${PROJECT_SOURCE_DIR}/pmm.cmake"
            -D "GENERATOR=${ARG_GENERATOR}"
            -D "BUILD_DIR=${CMAKE_CURRENT_BINARY_DIR}/${name}"
            -D "SOURCE_DIR=${dirpath}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/RunCITest.cmake"
        )
endfunction()

foreach(subdir conan vcpkg cmcm vcpkg-overlay)
    add_pmm_ci_test("${subdir}" SOURCE_DIR "${subdir}")
endforeach()

set(common_test_args)

function(add_pmm_ci_test name)
    _pmm_parse_args(
        -hardcheck
        - GENERATOR SOURCE_DIR
    )
    get_filename_component(dirpath "${ARG_SOURCE_DIR}" ABSOLUTE)
    _pmm_set_if_undef(ARG_GENERATOR "${CMAKE_GENERATOR}")
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
    if(name MATCHES "vcpkg")
        set_property(TEST "pmm.test.ci.${name}" PROPERTY RESOURCE_LOCK vcpkg-build)
    endif()
endfunction()

foreach(subdir conan vcpkg cmcm dds vcpkg-overlay)
    add_pmm_ci_test("${subdir}" SOURCE_DIR "${subdir}")
endforeach()

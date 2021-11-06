find_program(DOCKER_EXECUTABLE docker DOC "Path to Docker")

file(GLOB docker_dirs
    CONFIGURE_DEPENDS
    *.docker/
    LIST_DIRECTORIES true
    )

file(GLOB test_project_dirs
    CONFIGURE_DEPENDS
    *.test-project/
    LIST_DIRECTORIES true
    )

get_filename_component(DOCKER_TEST_SCRIPT RunDockerTest.cmake ABSOLUTE)
get_filename_component(BUILD_CONTAINER_SCRIPT BuildContainer.cmake ABSOLUTE)

option(RUN_DOCKER_TESTS "Should we run the Docker tests?" TRUE)
if(DOCKER_EXECUTABLE AND RUN_DOCKER_TESTS)
    foreach(dir IN LISTS docker_dirs)
        get_filename_component(env "${dir}" NAME_WE)
        set(container "pmm.test_container.${env}")
        set(fixture_name pmm.docker.${env})
        add_test(
            NAME ${fixture_name}/setup
            COMMAND ${CMAKE_COMMAND}
                -P ${BUILD_CONTAINER_SCRIPT}
                /ContainerName ${container}
                /Docker ${DOCKER_EXECUTABLE}
                /DockerBuildDir "${dir}"
            )
        set_property(TEST "${fixture_name}/setup" PROPERTY FIXTURES_SETUP "${fixture_name}")
        foreach(project IN LISTS test_project_dirs)
            get_filename_component(case "${project}" NAME_WE)
            set(test pmm.docker.${env}.${case})
            add_test(
                NAME "${test}"
                COMMAND ${CMAKE_COMMAND}
                    -P ${DOCKER_TEST_SCRIPT}
                    /ContainerName ${container}
                    /Docker ${DOCKER_EXECUTABLE}
                    /ProjectDir "${project}"
                )
            set_tests_properties("${test}" PROPERTIES
                FIXTURES_REQUIRED "${fixture_name}"
                SKIP_REGULAR_EXPRESSION "@ctest-skip@"
                )
            if(case MATCHES "vcpkg")
                # Prevent multiple vcpkg tests from running simultaneously, as the bootstrap
                # process is extremely resource intensive. Find a better way to reduce resource
                # consumption?
                set_property(TEST "${test}" PROPERTY RESOURCE_LOCK vcpkg-build)
            endif()
        endforeach()
    endforeach()
endif()

if(NOT NO_CI_TEST_DIR)
    add_subdirectory(ci)
endif()

add_test(
    NAME pmm.cli.conan.generate-profile
    COMMAND
        ${CMAKE_COMMAND}
        -DPMM_URL=file://${PROJECT_SOURCE_DIR}/pmm
        -DPMM_ALWAYS_DOWNLOAD=1
        -P "${PROJECT_SOURCE_DIR}/pmm.cmake"
        /Conan
        /GenProfile
        /Profile ${PROJECT_BINARY_DIR}/dummy-test.profile
    )

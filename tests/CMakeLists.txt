find_program(DOCKER_EXECUTABLE docker DOC "Path to Docker")

set(DOCKER_TESTS
    u18-vcpkg
    u16
    u14
    u12
    )

get_filename_component(DOCKER_TEST_SCRIPT RunDockerTest.cmake ABSOLUTE)

if(DOCKER_EXECUTABLE)
    foreach(test IN LISTS DOCKER_TESTS)
        add_test(
            NAME docker.${test}
            COMMAND ${CMAKE_COMMAND}
                -P ${DOCKER_TEST_SCRIPT}
                /Test ${test}
                /Docker ${DOCKER_EXECUTABLE}
            )
    endforeach()
endif()

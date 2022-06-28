cmake_minimum_required(VERSION 3.12)
project(TestProject)

include(CTest)

if("$ENV{PMM_VCPKG_TEST_SKIP}")
    message("@ctest-skip@")
    return()
endif()

include(${PMM_INCLUDE})
pmm(
    DEBUG
    VCPKG
        REVISION 2022.05.10
        REQUIRES fmt
    )

find_package(fmt REQUIRED)
add_executable(my-exe main.cpp)
target_link_libraries(my-exe fmt::fmt)

add_test(my-exe my-exe)

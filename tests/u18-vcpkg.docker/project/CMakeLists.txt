cmake_minimum_required(VERSION 3.12)
project(TestProject)

include(${PMM_INCLUDE})
pmm(
    DEBUG
    VCPKG
        REVISION cf7e2f3906f78dcb89f320a642428b54c00e4e0b
        REQUIRES fmt
    )

find_package(fmt REQUIRED)
add_executable(my-exe main.cpp)
target_link_libraries(my-exe fmt::fmt)

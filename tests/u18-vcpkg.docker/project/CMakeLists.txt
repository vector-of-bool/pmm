cmake_minimum_required(VERSION 3.12)
project(TestProject)

include(${PMM_INCLUDE})
pmm(
    DEBUG
    VCPKG
        REVISION 2020.06
        REQUIRES fmt
    )

find_package(fmt REQUIRED)
add_executable(my-exe main.cpp)
target_link_libraries(my-exe fmt::fmt)

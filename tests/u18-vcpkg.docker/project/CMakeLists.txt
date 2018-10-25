cmake_minimum_required(VERSION 3.12)
project(TestProject)

include(${PMM_INCLUDE})
pmm(
    DEBUG
    VCPKG
        REVISION 43deeaf0c8b6086310ee753be2e93c941f7ffd75
        REQUIRES fmt
    )

find_package(fmt REQUIRED)
add_executable(my-exe main.cpp)
target_link_libraries(my-exe fmt::fmt)

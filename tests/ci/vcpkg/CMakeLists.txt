cmake_minimum_required(VERSION 3.10)
project(TestProject)

message(STATUS "PMM URL is ${PMM_URL}")
include(${PMM_INCLUDE})
pmm(VCPKG
        REVISION 2022.05.10
        REQUIRES spdlog
    DEBUG
    )

find_package(spdlog REQUIRED CONFIG)

add_executable(dummy main.cpp)
target_link_libraries(dummy PRIVATE spdlog::spdlog fmt::fmt)

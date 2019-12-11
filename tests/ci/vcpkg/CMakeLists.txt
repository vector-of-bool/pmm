cmake_minimum_required(VERSION 3.10)
project(TestProject)

message(STATUS "PMM URL is ${PMM_URL}")
include(${PMM_INCLUDE})
pmm(VCPKG
        REVISION cf7e2f3906f78dcb89f320a642428b54c00e4e0b
        REQUIRES spdlog
    DEBUG
    )

find_package(spdlog REQUIRED CONFIG)

add_executable(dummy main.cpp)
target_link_libraries(dummy PRIVATE spdlog::spdlog)

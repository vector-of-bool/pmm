cmake_minimum_required(VERSION 3.10)
project(TestProject)

message(STATUS "PMM URL is ${PMM_URL}")
include(${PMM_INCLUDE})
pmm(VCPKG
        REVISION 2021.05.12
        REQUIRES spdlog-pmm[test-feature]
        OVERLAY custom-ports/ custom-ports2/
    DEBUG
    )

find_package(spdlog REQUIRED CONFIG)

add_executable(dummy main.cpp)
target_link_libraries(dummy PRIVATE spdlog::spdlog fmt::fmt)

cmake_minimum_required(VERSION 3.10)
project(TestProject)

message(STATUS "PMM URL is ${PMM_URL}")
include(${PMM_INCLUDE})
pmm(VCPKG
        REVISION 2022.05.10
        REQUIRES nlohmann-json[test-feature]
        OVERLAY_PORTS custom-ports/ custom-ports2/
    DEBUG
    )

find_package(nlohmann_json REQUIRED CONFIG)

add_executable(dummy main.cpp)
target_link_libraries(dummy PRIVATE nlohmann_json::nlohmann_json)

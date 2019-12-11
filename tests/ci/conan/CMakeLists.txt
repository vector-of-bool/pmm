cmake_minimum_required(VERSION 3.10)
project(TestProject)

message(STATUS "PMM URL is ${PMM_URL}")
include(${PMM_INCLUDE})
pmm(CONAN DEBUG)

add_executable(dummy main.cpp)
target_link_libraries(dummy PRIVATE CONAN_PKG::spdlog)

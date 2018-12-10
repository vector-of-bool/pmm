cmake_minimum_required(VERSION 3.10)
project(TestProject)

include(${PMM_INCLUDE})
pmm(CMakeCM)

include(CMakeRC)

cmrc_add_resource_library(dummy-rc CMakeLists.txt)
add_executable(dummy-program main.cpp)
target_link_libraries(dummy-program PRIVATE dummy-rc)

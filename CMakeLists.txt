cmake_minimum_required(VERSION 3.13)
project(pmm VERSION 2.1.0)

include(latest-info.cmake)

set(PMM_ALWAYS_DOWNLOAD TRUE)
set(PMM_URL "file://${PROJECT_SOURCE_DIR}/pmm")
set(PMM_DEBUG TRUE)
include(pmm.cmake)
pmm(CONAN BINCRAFTERS)

file(GLOB_RECURSE pmm_sources CONFIGURE_DEPENDS pmm/*)
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${pmm_sources})

option(BUILD_TESTING "Build the testing tree" ON)
if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(tests)
endif()

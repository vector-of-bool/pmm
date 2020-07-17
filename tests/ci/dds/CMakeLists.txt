cmake_minimum_required(VERSION 3.15)
project(DDSTest VERSION 0.1.0)

include(${PMM_INCLUDE})

set(CMAKE_CXX_STANDARD 17)

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded$<$<CONFIG:Debug>:Debug>DLL)
pmm(CMakeCM ROLLING
    DDS CATALOG test-catalog.jsonc
        DEP_FILES deps.jsonc
    )

include(libman)
import_packages(spdlog fmt)

if(NOT EXISTS "${PROJECT_BINARY_DIR}/INDEX.lmi")
    message(FATAL_ERROR "No INDEX.lmi was generated")
endif()

add_executable(test-spdlog test.cpp)
add_test(test-spdlog test-spdlog)

target_link_libraries(test-spdlog PRIVATE spdlog::spdlog)

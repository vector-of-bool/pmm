cmake_minimum_required(VERSION 3.10)
project(DDSTest VERSION 0.1.0)

include(${PMM_INCLUDE})

if(MSVC)
    add_compile_options(/FS)
endif()
set(CMAKE_CXX_STANDARD 17)

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

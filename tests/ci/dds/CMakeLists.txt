cmake_minimum_required(VERSION 3.15)
project(DDSTest VERSION 0.1.0)

include(${PMM_INCLUDE})

set(CMAKE_CXX_STANDARD 17)

# Set a compiler launch that doesn't do anything, but we can check for later.
set(CMAKE_CXX_COMPILER_LAUNCHER ${CMAKE_COMMAND} -E env FOO=BAR)

set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreaded$<$<CONFIG:Debug>:Debug>DLL)
pmm(DDS DEP_FILES deps.jsonc)

# Call it a second time, this will *append* the fmt+1.0.0 to our requirements, not
# replace the original one from deps.jsonc
pmm(DDS DEPENDS fmt+1.0.0)

if(NOT EXISTS "${PROJECT_BINARY_DIR}/INDEX.lmi")
    message(FATAL_ERROR "No INDEX.lmi was generated")
endif()

# Check that our compiler-launch prefix made it into the toolchain file.
file(READ "${PMM_DIR}/dds-toolchain.json5" tc_content)
if(NOT tc_content MATCHES "'-E', 'env', 'FOO=BAR'")
    message(FATAL_ERROR "Toolchain file did not receive the compiler launcher")
endif()

add_executable(test-spdlog test.cpp)
add_test(test-spdlog test-spdlog)

target_link_libraries(test-spdlog PRIVATE spdlog::spdlog)

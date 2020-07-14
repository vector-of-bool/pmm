cmake_minimum_required(VERSION 3.10)
project(DDSTest VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
add_compile_options($<$<COMPILER_ID:Never>:fooasdofasdf>)
include(${PMM_INCLUDE})
pmm(DDS
    CATALOG test-catalog.jsonc
    DEP_FILES deps.jsonc
    )

if(NOT EXISTS "${PROJECT_BINARY_DIR}/INDEX.lmi")
    message(FATAL_ERROR "No INDEX.lmi was generated")
endif()

cmake_minimum_required(VERSION 3.10)
project(DDSTest VERSION 0.1.0)

include(${PMM_INCLUDE})
pmm(DDS DEP_FILES deps.jsonc)

if(NOT EXISTS "${PROJECT_BINARY_DIR}/INDEX.lmi")
    message(FATAL_ERROR "No INDEX.lmi was generated")
endif()

cmake_minimum_required(VERSION 3.12)
project(TestProject)

include(CTest)

include(${PMM_INCLUDE})
pmm(DEBUG
    CMakeCM ROLLING
    DDS DEPENDS fmt^8.0.1
    )

add_executable(my-exe main.cpp)
target_link_libraries(my-exe fmt::fmt)
add_test(my-exe my-exe)
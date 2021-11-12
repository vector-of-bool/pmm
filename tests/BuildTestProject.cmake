include(${CMAKE_CURRENT_LIST_DIR}/../pmm/util.cmake)
_pmm_parse_script_args(
    - /SourceDir /BinaryDir /Generator
    )

get_filename_component(root "${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(pmm_dir "${root}/pmm")

# Configure
execute_process(
    COMMAND "${CMAKE_COMMAND}"
        "-H${ARG_/SourceDir}"
        "-B${ARG_/BinaryDir}"
        "-DPMM_URL=file://${pmm_dir}"
        "-DPMM_INCLUDE=${root}/pmm.cmake"
    RESULT_VARIABLE retc
    )
if(retc)
    message(FATAL_ERROR "Project configuration failed [${retc}]")
endif()

# Build
execute_process(
    COMMAND "${CMAKE_COMMAND}" --build "${ARG_/BinaryDir}"
    RESULT_VARIABLE retc
    )
if(retc)
    message(FATAL_ERROR "Project build failed [${retc}]")
endif()

# Test
execute_process(
    COMMAND "${CMAKE_CTEST_COMMAND}"
    WORKING_DIRECTORY "${ARG_/BinaryDir}"
    RESULT_VARIABLE retc
    )
if(retc)
    message(FATAL_ERROR "Project test failed [${retc}]")
endif()

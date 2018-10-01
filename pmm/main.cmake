cmake_minimum_required(VERSION 3.8)

# The main function.
function(pmm)
    _pmm_parse_args(+ CONAN)

    if(DEFINED ARG_CONAN OR "CONAN" IN_LIST ARGV)
        _pmm_conan(${ARG_CONAN})
        _pmm_lift(CMAKE_MODULE_PATH)
        _pmm_lift(CMAKE_PREFIX_PATH)
    endif()
endfunction()

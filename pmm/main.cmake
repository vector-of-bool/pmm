function(pmm)
    set(options)
    set(args)
    set(list_args CONAN)
    cmake_parse_arguments(ARG "${options}" "${args}" "${list_args}" "${ARGV}")

    foreach(arg IN LISTS ARG_UNPARSED_ARGUMENTS)
        message(WARNING "Unknown argument to pmm(): `${arg}`")
    endforeach()

    if(DEFINED ARG_CONAN OR "CONAN" IN_LIST ARGV)
        _pmm_conan("${ARG_CONAN}")
    endif()
endfunction()

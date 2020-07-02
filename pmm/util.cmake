cmake_minimum_required(VERSION 3.10)

function(_pmm_read_script_argv var)
    set(got_p FALSE)
    set(got_script FALSE)
    set(ret)
    foreach(i RANGE "${CMAKE_ARGC}")
        set(arg "${CMAKE_ARGV${i}}")
        if(got_p)
            if(got_script)
                list(APPEND ret "${arg}")
            else()
                set(got_script TRUE)
            endif()
        elseif(arg STREQUAL "-P")
            set(got_p TRUE)
        endif()
    endforeach()
    set("${var}" "${ret}" PARENT_SCOPE)
endfunction()

# Argument parser helper. This may look like magic, but it is pretty simple:
# - Call this at the top of a function
# - It takes three "list" arguments: `.`, `-` and `+`.
# - The `.` arguments specify the "option/boolean" values to parse out.
# - The `-` arguments specify the one-value arguments to parse out.
# - The `+` argumenst specify mult-value arguments to parse out.
# - Specify `-nocheck` to disable warning on unparse arguments.
# - Parse values are prefixed with `ARG`
#
# This macro makes use of some very horrible aspects of CMake macros:
# - Values appear the caller's scope, so no need to set(PARENT_SCOPE)
# - The ${${}ARGV} eldritch horror evaluates to the ARGV *OF THE CALLER*, while
#   ${ARGV} evaluates to the macro's own ARGV value. This is because ${${}ARGV}
#   inhibits macro argument substitution. It is painful, but it makes this magic
#   work.
macro(_pmm_parse_args)
    cmake_parse_arguments(_ "-nocheck;-hardcheck" "" ".;-;+" "${ARGV}")
    set(__arglist "${${}ARGV}")
    _pmm_parse_arglist("${__.}" "${__-}" "${__+}")
endmacro()

macro(_pmm_parse_script_args)
    cmake_parse_arguments(_ "-nocheck;-hardcheck" "" ".;-;+" "${ARGV}")
    _pmm_read_script_argv(__arglist)
    _pmm_parse_arglist("${__.}" "${__-}" "${__+}")
endmacro()

macro(_pmm_parse_arglist opt args list_args)
    cmake_parse_arguments(ARG "${opt}" "${args}" "${list_args}" "${__arglist}")
    if(NOT __-nocheck)
        foreach(arg IN LISTS ARG_UNPARSED_ARGUMENTS)
            message(WARNING "Unknown argument: ${arg}")
        endforeach()
        if(__-hardcheck AND NOT ("${ARG_UNPARSED_ARGUMENTS}" STREQUAL ""))
            message(FATAL_ERROR "Unknown arguments provided.")
        endif()
    endif()
endmacro()

macro(_pmm_lift)
    foreach(varname IN ITEMS ${ARGN})
        set("${varname}" "${${varname}}" PARENT_SCOPE)
    endforeach()
endmacro()

function(_pmm_exec)
    if(PMM_DEBUG)
        set(acc)
        foreach(arg IN LISTS ARGN)
            if(arg MATCHES " |\\\"|\\\\")
                string(REPLACE "\"" "\\\"" arg "${arg}")
                string(REPLACE "\\" "\\\\" arg "${arg}")
                set(arg "\"${arg}\"")
            endif()
            string(APPEND acc "${arg} ")
        endforeach()
        _pmm_log(DEBUG "Executing command: ${acc}")
    endif()
    set(output_args)
    if(NOT NO_EAT_OUTPUT IN_LIST ARGN)
        set(output_args
            OUTPUT_VARIABLE out
            ERROR_VARIABLE out
            )
    endif()
    list(FIND ARGN WORKING_DIRECTORY wd_kw_idx)
    set(wd_arg)
    if(wd_kw_idx GREATER -1)
        math(EXPR wd_idx "${wd_kw_idx} + 1")
        list(GET ARGN "${wd_idx}" wd_dir)
        LIST(REMOVE_AT ARGN "${wd_idx}" "${wd_kw_idx}")
        set(wd_arg WORKING_DIRECTORY "${wd_dir}")
    endif()
    list(REMOVE_ITEM ARGN NO_EAT_OUTPUT)
    execute_process(
        COMMAND ${ARGN}
        ${output_args}
        RESULT_VARIABLE rc
        ${wd_arg}
        )
    set(_PMM_RC "${rc}" PARENT_SCOPE)
    set(_PMM_OUTPUT "${out}" PARENT_SCOPE)
endfunction()


function(_pmm_write_if_different filepath content)
    set(do_write FALSE)
    if(NOT EXISTS "${filepath}")
        set(do_write TRUE)
    else()
        file(READ "${filepath}" cur_content)
        if(NOT cur_content STREQUAL content)
            set(do_write TRUE)
        endif()
    endif()
    if(do_write)
        _pmm_log(DEBUG "Updating contents of file: ${filepath}")
        get_filename_component(pardir "${filepath}" DIRECTORY)
        file(MAKE_DIRECTORY "${pardir}")
        file(WRITE "${filepath}" "${content}")
    else()
        _pmm_log(DEBUG "Contents of ${filepath} are up-to-date")
    endif()
    set(_PMM_DID_WRITE "${do_write}" PARENT_SCOPE)
endfunction()

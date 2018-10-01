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
    cmake_parse_arguments(_ "-nocheck" "" ".;-;+" "${ARGV}")
    cmake_parse_arguments(ARG "${__.}" "${__-}" "${__+}" "${${}ARGV}")
    if(NOT __-nocheck)
        foreach(arg IN LISTS ARG_UNPARSED_ARGUMENTS)
            message(WARNING "Unknown argument: ${arg}")
        endforeach()
    endif()
endmacro()

macro(_pmm_lift varname)
    set("${varname}" "${${varname}}" PARENT_SCOPE)
endmacro()

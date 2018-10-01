macro(_pmm_set_if_undef varname)
    if(NOT DEFINED "${varname}")
        set("${varname}" "${ARGN}")
    endif()
endmacro()
_pmm_set_if_undef(PMM_VERSION 0.1.0)
_pmm_set_if_undef(PMM_URL_BASE "http://pmm.github.io")
_pmm_set_if_undef(PMM_URL "${PMM_URL_BASE}/${PMM_VERSION}")
_pmm_set_if_undef(PMM_DIR_BASE "${CMAKE_BINARY_DIR}/_pmm")
_pmm_set_if_undef(PMM_DIR "${PMM_DIR_BASE}/${PMM_VERSION}")

set(_PMM_ENTRY_FILE "${PMM_DIR}/entry.cmake")

if(NOT EXISTS "${_PMM_ENTRY_FILE}" OR PMM_ALWAYS_DOWNLOAD)
    file(
        DOWNLOAD "${PMM_URL}/entry.cmake"
        "${_PMM_ENTRY_FILE}.tmp"
        STATUS pair
        )
    list(GET pair 0 rc)
    list(GET pair 1 msg)
    if(rc)
        message(FATAL_ERROR "Failed to download PMM entry file")
    endif()
    file(RENAME "${_PMM_ENTRY_FILE}.tmp" "${_PMM_ENTRY_FILE}")
endif()

include("${_PMM_ENTRY_FILE}")

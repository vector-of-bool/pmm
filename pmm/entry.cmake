function(_pmm_download url dest)
    set(tmp "${dest}.tmp")
    file(
        DOWNLOAD "${url}"
        "${tmp}"
        STATUS st
        )
    list(GET st 0 rc)
    list(GET st 1 msg)
    if(rc)
        message(FATAL_ERROR "Error while downloading file ${dest} [${rc}]: ${msg}")
    endif()
    file(RENAME "${tmp}" "${dest}")
endfunction()

foreach(fname IN ITEMS util.cmake conan.cmake main.cmake)
    get_filename_component(_dest "${PMM_DIR}/${fname}" ABSOLUTE)
    _pmm_download("${PMM_URL}/${fname}" "${_dest}")
    include("${_dest}")
endforeach()

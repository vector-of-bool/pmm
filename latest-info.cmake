function(_pmm_changes version)
    if(PMM_VERSION VERSION_LESS version)
        foreach(change IN LISTS ARGN)
            message(STATUS "[pmm]   - ${change}")
        endforeach()
    endif()
endfunction()

set(PMM_LATEST_VERSION 0.1.1)

if(PMM_VERSION VERSION_LESS PMM_LATEST_VERSION AND NOT PMM_IGNORE_NEW_VERSION)
    message(STATUS "You are using PMM version ${PMM_VERSION}. The latest is ${PMM_LATEST_VERSION}.")
    message(STATUS "Changes since ${PMM_VERSION} include the following:")
    _pmm_changes(0.1.1
        "Automatic update checks"
        )
    message(STATUS "[pmm] To update, simply change the value of PMM_VERSION_INIT in pmm.cmake")
    message(STATUS "[pmm] You can disable these messages by setting PMM_IGNORE_NEW_VERSION to TRUE before including pmm.cmake")
endif()


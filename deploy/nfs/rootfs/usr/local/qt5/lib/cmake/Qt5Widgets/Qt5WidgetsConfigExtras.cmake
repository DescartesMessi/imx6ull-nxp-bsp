
if (NOT TARGET Qt5::uic)
    add_executable(Qt5::uic IMPORTED)

    set(imported_location "/home/pointer/imx6ull/projects/imx6ull-nxp-bsp/build/3rdparty/qt5-staging/host/bin/uic")
    _qt5_Widgets_check_file_exists(${imported_location})

    set_target_properties(Qt5::uic PROPERTIES
        IMPORTED_LOCATION ${imported_location}
    )
endif()

include("${CMAKE_CURRENT_LIST_DIR}/Qt5Widgets_AccessibleFactory.cmake" OPTIONAL)

set(Qt5Widgets_UIC_EXECUTABLE Qt5::uic)

include(FetchContent)

FetchContent_Declare(
    googletest
    GIT_REPOSITORY https://github.com/google/googletest.git
    GIT_TAG v1.15.2
)

# Prevent gtest from overriding our compiler/linker options on Windows
set(gtest_force_shared_crt ON CACHE BOOL "" FORCE)

FetchContent_MakeAvailable(googletest)

# backend_core unit tests
add_executable(backend_core_tests
    ${CMAKE_SOURCE_DIR}/native/backend_core/src/simulation/tests/simulation_tests.cpp
    ${CMAKE_SOURCE_DIR}/native/backend_core/src/massive_body/tests/massive_body_tests.cpp
    ${CMAKE_SOURCE_DIR}/native/backend_core/src/time/tests/duration_format_tests.cpp
)

target_link_libraries(backend_core_tests
    PRIVATE backend_core GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(backend_core_tests)

add_executable(godot_bridge_tests
    ${CMAKE_SOURCE_DIR}/native/godot_bridge/src/bridge/tests/bridge_state_builder_tests.cpp
)

target_link_libraries(godot_bridge_tests
    PRIVATE godot_bridge_support GTest::gtest_main
)

gtest_discover_tests(godot_bridge_tests)

# Godot writes editor and user data outside the repo by default. Redirect it
# into the build tree so headless runs work under sandboxed and portable installs.
set(GODOT_TEST_HOME "${CMAKE_BINARY_DIR}/godot_user")
set(GODOT_TEST_ROAMING "${GODOT_TEST_HOME}/Roaming")
set(GODOT_TEST_LOCAL "${GODOT_TEST_HOME}/Local")
set(GODOT_TEST_XDG_DATA "${GODOT_TEST_HOME}/xdg_data")
set(GODOT_TEST_XDG_CONFIG "${GODOT_TEST_HOME}/xdg_config")
set(GODOT_TEST_XDG_CACHE "${GODOT_TEST_HOME}/xdg_cache")

file(MAKE_DIRECTORY
    "${GODOT_TEST_HOME}"
    "${GODOT_TEST_ROAMING}"
    "${GODOT_TEST_LOCAL}"
    "${GODOT_TEST_XDG_DATA}"
    "${GODOT_TEST_XDG_CONFIG}"
    "${GODOT_TEST_XDG_CACHE}"
)

set(GODOT_TEST_ENV
    "GODOT_DISABLE_LEAK_CHECKS=1"
    "APPDATA=${GODOT_TEST_ROAMING}"
    "LOCALAPPDATA=${GODOT_TEST_LOCAL}"
    "USERPROFILE=${GODOT_TEST_HOME}"
    "HOME=${GODOT_TEST_HOME}"
    "XDG_DATA_HOME=${GODOT_TEST_XDG_DATA}"
    "XDG_CONFIG_HOME=${GODOT_TEST_XDG_CONFIG}"
    "XDG_CACHE_HOME=${GODOT_TEST_XDG_CACHE}"
)

# Godot headless smoke test (GUT)
# Prefer console/headless-friendly binaries on Windows because editor builds
# such as Scoop's `godot.exe` can crash when invoked with `--headless`.
set(GODOT_EXECUTABLE "")

if(WIN32)
    file(GLOB GODOT_WINGET_CONSOLE_EXECUTABLES
        "$ENV{LOCALAPPDATA}/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot*_console.exe"
    )

    if(GODOT_WINGET_CONSOLE_EXECUTABLES)
        list(SORT GODOT_WINGET_CONSOLE_EXECUTABLES COMPARE NATURAL ORDER DESCENDING)
        list(GET GODOT_WINGET_CONSOLE_EXECUTABLES 0 GODOT_EXECUTABLE)
    endif()
endif()

if(NOT GODOT_EXECUTABLE)
    find_program(GODOT_EXECUTABLE
        NAMES godot4_console godot_console godot4 godot
    )
endif()

if(GODOT_EXECUTABLE)
    add_test(
        NAME godot_bridge_smoke
        COMMAND ${GODOT_EXECUTABLE}
            --path ${CMAKE_SOURCE_DIR}/godot
            --headless
            --display-driver headless
            --audio-driver Dummy
            --import
            --quit
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )

    # Run GUT after import
    add_test(
        NAME godot_gut_tests
        COMMAND ${GODOT_EXECUTABLE}
            --path ${CMAKE_SOURCE_DIR}/godot
            --headless
            --display-driver headless
            --audio-driver Dummy
            -s res://addons/gut/gut_cmdln.gd
            -gdir=res://tests
            -ginclude_subdirs
            -gexit
        WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
    )

    set_tests_properties(godot_bridge_smoke PROPERTIES
        ENVIRONMENT "${GODOT_TEST_ENV}"
    )
    set_tests_properties(godot_gut_tests PROPERTIES
        DEPENDS godot_bridge_smoke
        ENVIRONMENT "${GODOT_TEST_ENV}"
    )
else()
    message(STATUS "Godot executable (godot4/godot) not found in PATH -- skipping headless GUT tests")
endif()

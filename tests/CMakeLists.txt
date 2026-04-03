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
)

target_link_libraries(backend_core_tests
    PRIVATE backend_core GTest::gtest_main
)

include(GoogleTest)
gtest_discover_tests(backend_core_tests)

# Godot headless smoke test (GUT)
find_program(GODOT_EXECUTABLE NAMES godot4 godot)

if(GODOT_EXECUTABLE)
    add_test(
        NAME godot_bridge_smoke
        COMMAND ${GODOT_EXECUTABLE}
            --headless
            --display-driver headless
            --audio-driver Dummy
            --import
            --quit
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/godot
    )

    # Run GUT after import
    add_test(
        NAME godot_gut_tests
        COMMAND ${GODOT_EXECUTABLE}
            --headless
            --display-driver headless
            --audio-driver Dummy
            -s res://addons/gut/gut_cmdln.gd
            -gdir=res://tests
            -ginclude_subdirs
            -gexit
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/godot
    )

    set_tests_properties(godot_gut_tests PROPERTIES
        DEPENDS godot_bridge_smoke
        ENVIRONMENT "GODOT_DISABLE_LEAK_CHECKS=1"
    )
else()
    message(STATUS "Godot executable (godot4/godot) not found in PATH -- skipping headless GUT tests")
endif()

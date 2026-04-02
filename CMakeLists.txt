cmake_minimum_required(VERSION 3.21)

project(solar_system_sim LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Pure C++ libraries (no Godot dependency)
add_subdirectory(native/backend_core)
add_subdirectory(native/protocol)

# godot-cpp bindings
add_subdirectory(native/third_party/godot-cpp)

# GDExtension bridge (depends on godot-cpp + backend_core + protocol)
add_subdirectory(native/godot_bridge)

# Tests
option(BUILD_TESTS "Build tests" ON)
if(BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()

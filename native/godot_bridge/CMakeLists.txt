set(TARGET_NAME godot_bridge)

add_library(${TARGET_NAME} SHARED
    src/register_types.cpp
    src/solar_system_bridge.cpp
)

target_include_directories(${TARGET_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_link_libraries(${TARGET_NAME}
    PRIVATE godot-cpp backend_core protocol
)

# Get the suffix from godot-cpp (e.g. .windows.template_debug.x86_64)
get_target_property(GODOTCPP_SUFFIX godot-cpp GODOTCPP_SUFFIX)

set(OUTPUT_DIR "${CMAKE_SOURCE_DIR}/godot/extensions/")

set_target_properties(${TARGET_NAME} PROPERTIES
    POSITION_INDEPENDENT_CODE ON

    LIBRARY_OUTPUT_DIRECTORY "$<1:${OUTPUT_DIR}>"
    RUNTIME_OUTPUT_DIRECTORY "$<1:${OUTPUT_DIR}>"
    PDB_OUTPUT_DIRECTORY     "$<1:${OUTPUT_DIR}>"

    PREFIX "lib"
    OUTPUT_NAME "game_client${GODOTCPP_SUFFIX}"

    FOLDER "solar-system"
)

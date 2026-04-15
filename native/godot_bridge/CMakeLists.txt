set(TARGET_NAME godot_bridge)
set(SUPPORT_TARGET godot_bridge_support)

add_library(${SUPPORT_TARGET} STATIC
    src/bridge/bridge_state_builder.cpp
)

target_include_directories(${SUPPORT_TARGET} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(${SUPPORT_TARGET}
    PUBLIC backend_core
)

set_target_properties(${SUPPORT_TARGET} PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    FOLDER "solar-system"
)

add_library(${TARGET_NAME} SHARED
    src/bridge/register_types.cpp
    src/bridge/solar_system_bridge.cpp
)

target_include_directories(${TARGET_NAME} PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(${TARGET_NAME}
    PRIVATE godot-cpp backend_core protocol ${SUPPORT_TARGET}
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

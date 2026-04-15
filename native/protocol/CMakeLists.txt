add_library(protocol STATIC
    src/messages/messages.cpp
)

set_target_properties(protocol PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

target_include_directories(protocol PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(protocol PUBLIC backend_core)

add_library(protocol STATIC
    src/messages/messages.cpp
)

target_include_directories(protocol PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

target_link_libraries(protocol PUBLIC backend_core)

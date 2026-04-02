add_library(backend_core STATIC
    src/simulation.cpp
)

target_include_directories(backend_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

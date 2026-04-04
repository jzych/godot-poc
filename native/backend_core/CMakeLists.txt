add_library(backend_core STATIC
    src/massive_body/default_bodies.cpp
    src/simulation/simulation.cpp
    src/time/duration_format.cpp
)

target_include_directories(backend_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

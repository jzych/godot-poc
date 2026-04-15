add_library(backend_core STATIC
    src/massive_body/default_bodies.cpp
    src/simulation/simulation.cpp
    src/time/duration_format.cpp
)

set_target_properties(backend_core PROPERTIES
    POSITION_INDEPENDENT_CODE ON
)

target_include_directories(backend_core PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

#pragma once

#include <cstdint>

namespace solar::protocol {

struct SimulationState {
    bool running = false;
    double time_seconds = 0.0;
};

} // namespace solar::protocol

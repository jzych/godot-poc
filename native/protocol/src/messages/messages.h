#pragma once

#include "massive_body/massive_body.h"
#include "simulation/simulation.h"

#include <string>
#include <vector>

namespace solar::protocol {

struct BodySnapshot {
    solar::MassiveBodyType type{};
    std::string name;
    solar::Vec3 position_km;
    solar::Color3 color;
};

struct SimulationSnapshot {
    bool running = false;
    double sim_time_seconds = 0.0;
    std::vector<BodySnapshot> bodies;
};

SimulationSnapshot make_snapshot(const solar::Simulation& sim);

} // namespace solar::protocol

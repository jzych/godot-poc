#include "messages/messages.h"

namespace solar::protocol {

SimulationSnapshot make_snapshot(const solar::Simulation& sim) {
    SimulationSnapshot snap;
    snap.running = sim.is_running();
    snap.sim_time_seconds = sim.sim_time();

    for (const auto& body : sim.bodies()) {
        snap.bodies.push_back(BodySnapshot{
            .type = body.type,
            .name = body.name,
            .position_km = body.position_km,
            .color = body.color,
        });
    }

    return snap;
}

} // namespace solar::protocol

#include "simulation/simulation.h"

#include <cmath>
#include <numbers>

namespace solar {

Simulation::Simulation() = default;
Simulation::~Simulation() = default;

bool Simulation::is_running() const { return running_; }

void Simulation::start() { running_ = true; }

void Simulation::stop() { running_ = false; }

void Simulation::add_body(MassiveBody body) {
    bodies_.push_back(std::move(body));
}

void Simulation::step(double delta_game_seconds) {
    if (!running_) return;

    sim_time_s_ += delta_game_seconds * TIME_SCALE;

    for (auto& body : bodies_) {
        if (body.orbital_period_s <= 0.0 || body.orbital_radius_km <= 0.0) {
            continue;
        }

        const double omega = 2.0 * std::numbers::pi / body.orbital_period_s;
        const double angle = omega * sim_time_s_;

        Vec3 parent_pos{};
        if (body.parent_index >= 0 &&
            body.parent_index < static_cast<int>(bodies_.size())) {
            parent_pos = bodies_[static_cast<size_t>(body.parent_index)].position_km;
        }

        body.position_km.x = parent_pos.x + body.orbital_radius_km * std::cos(angle);
        body.position_km.y = 0.0;
        body.position_km.z = parent_pos.z + body.orbital_radius_km * std::sin(angle);
    }
}

const std::vector<MassiveBody>& Simulation::bodies() const { return bodies_; }

size_t Simulation::body_count() const { return bodies_.size(); }

double Simulation::sim_time() const { return sim_time_s_; }

} // namespace solar

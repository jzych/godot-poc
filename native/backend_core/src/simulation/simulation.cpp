#include "simulation/simulation.h"

#include <cmath>
#include <numbers>

namespace solar {

namespace {

double phase_offset_for_orbit(const MassiveBody& body, double omega) {
    switch (body.orbit.anomaly_kind) {
    case OrbitalAnomalyKind::MeanAnomaly:
    case OrbitalAnomalyKind::TrueAnomaly:
        return body.orbit.anomaly_at_epoch;
    case OrbitalAnomalyKind::TimeOfPeriapsisPassage:
        return -omega * body.orbit.anomaly_at_epoch;
    case OrbitalAnomalyKind::None:
    default:
        return 0.0;
    }
}

} // namespace

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
        if (body.rotation.orbital_period_s <= 0.0 ||
            body.orbit.semi_major_axis_km <= 0.0) {
            continue;
        }

        const double omega =
            2.0 * std::numbers::pi / body.rotation.orbital_period_s;
        const double angle =
            phase_offset_for_orbit(body, omega) + (omega * sim_time_s_);

        Vec3 parent_pos{};
        if (body.orbit.central_body_index >= 0 &&
            body.orbit.central_body_index < static_cast<int>(bodies_.size())) {
            parent_pos =
                bodies_[static_cast<size_t>(body.orbit.central_body_index)].position_km;
        }

        body.position_km.x =
            parent_pos.x + body.orbit.semi_major_axis_km * std::cos(angle);
        body.position_km.y = 0.0;
        body.position_km.z =
            parent_pos.z + body.orbit.semi_major_axis_km * std::sin(angle);
    }
}

const std::vector<MassiveBody>& Simulation::bodies() const { return bodies_; }

size_t Simulation::body_count() const { return bodies_.size(); }

double Simulation::sim_time() const { return sim_time_s_; }

} // namespace solar

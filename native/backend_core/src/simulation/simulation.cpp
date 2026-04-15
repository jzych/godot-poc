#include "simulation/simulation.h"

#include <cmath>
#include <limits>
#include <numbers>

namespace solar {

namespace {

constexpr double NEWTON_TOLERANCE = 1e-10;
constexpr int MAX_KEPLER_ITERATIONS = 12;
constexpr double VECTOR_EPSILON = 1e-12;

Vec3 add(const Vec3& lhs, const Vec3& rhs) {
    return Vec3{
        .x = lhs.x + rhs.x,
        .y = lhs.y + rhs.y,
        .z = lhs.z + rhs.z,
    };
}

Vec3 scale(const Vec3& vector, double scalar) {
    return Vec3{
        .x = vector.x * scalar,
        .y = vector.y * scalar,
        .z = vector.z * scalar,
    };
}

Vec3 subtract(const Vec3& lhs, const Vec3& rhs) {
    return Vec3{
        .x = lhs.x - rhs.x,
        .y = lhs.y - rhs.y,
        .z = lhs.z - rhs.z,
    };
}

double dot(const Vec3& lhs, const Vec3& rhs) {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
}

Vec3 cross(const Vec3& lhs, const Vec3& rhs) {
    return Vec3{
        .x = lhs.y * rhs.z - lhs.z * rhs.y,
        .y = lhs.z * rhs.x - lhs.x * rhs.z,
        .z = lhs.x * rhs.y - lhs.y * rhs.x,
    };
}

double length_squared(const Vec3& vector) {
    return dot(vector, vector);
}

Vec3 normalize(const Vec3& vector, const Vec3& fallback) {
    const double vector_length_squared = length_squared(vector);
    if (vector_length_squared <= VECTOR_EPSILON) {
        return fallback;
    }

    const double inverse_length = 1.0 / std::sqrt(vector_length_squared);
    return scale(vector, inverse_length);
}

Vec3 rotate_around_axis(const Vec3& vector, const Vec3& axis, double angle_rad) {
    const Vec3 normalized_axis = normalize(axis, Vec3{.x = 1.0, .y = 0.0, .z = 0.0});
    const double cos_angle = std::cos(angle_rad);
    const double sin_angle = std::sin(angle_rad);

    return add(
        add(scale(vector, cos_angle),
            scale(cross(normalized_axis, vector), sin_angle)),
        scale(normalized_axis, dot(normalized_axis, vector) * (1.0 - cos_angle)));
}

double normalize_angle(double angle_rad) {
    angle_rad = std::fmod(angle_rad, 2.0 * std::numbers::pi);
    if (angle_rad < -std::numbers::pi) {
        angle_rad += 2.0 * std::numbers::pi;
    } else if (angle_rad > std::numbers::pi) {
        angle_rad -= 2.0 * std::numbers::pi;
    }
    return angle_rad;
}

double mean_motion_rad_per_s(const MassiveBody& body) {
    return 2.0 * std::numbers::pi / body.rotation.orbital_period_s;
}

double true_to_mean_anomaly(double true_anomaly_rad, double eccentricity) {
    if (eccentricity <= std::numeric_limits<double>::epsilon()) {
        return normalize_angle(true_anomaly_rad);
    }

    const double eccentric_anomaly = 2.0 * std::atan2(
        std::sqrt(1.0 - eccentricity) * std::sin(true_anomaly_rad / 2.0),
        std::sqrt(1.0 + eccentricity) * std::cos(true_anomaly_rad / 2.0));
    return eccentric_anomaly - eccentricity * std::sin(eccentric_anomaly);
}

double mean_anomaly_at_time(const MassiveBody& body, double sim_time_s) {
    const double omega = mean_motion_rad_per_s(body);
    switch (body.orbit.anomaly_kind) {
    case OrbitalAnomalyKind::MeanAnomaly:
        return body.orbit.anomaly_at_epoch + (omega * sim_time_s);
    case OrbitalAnomalyKind::TrueAnomaly:
        return true_to_mean_anomaly(
            body.orbit.anomaly_at_epoch,
            body.orbit.eccentricity) +
               (omega * sim_time_s);
    case OrbitalAnomalyKind::TimeOfPeriapsisPassage:
        return omega * (sim_time_s - body.orbit.anomaly_at_epoch);
    case OrbitalAnomalyKind::None:
    default:
        return omega * sim_time_s;
    }
}

double solve_eccentric_anomaly(double mean_anomaly_rad, double eccentricity) {
    if (eccentricity <= std::numeric_limits<double>::epsilon()) {
        return normalize_angle(mean_anomaly_rad);
    }

    const double normalized_mean_anomaly = normalize_angle(mean_anomaly_rad);
    double eccentric_anomaly =
        eccentricity < 0.8
            ? normalized_mean_anomaly
            : (normalized_mean_anomaly >= 0.0 ? std::numbers::pi : -std::numbers::pi);

    for (int iteration = 0; iteration < MAX_KEPLER_ITERATIONS; ++iteration) {
        const double sin_e = std::sin(eccentric_anomaly);
        const double cos_e = std::cos(eccentric_anomaly);
        const double residual =
            eccentric_anomaly - (eccentricity * sin_e) - normalized_mean_anomaly;
        const double derivative = 1.0 - (eccentricity * cos_e);
        const double step = residual / derivative;
        eccentric_anomaly -= step;

        if (std::abs(step) <= NEWTON_TOLERANCE) {
            break;
        }
    }

    return eccentric_anomaly;
}

double true_anomaly_from_eccentric(double eccentric_anomaly_rad, double eccentricity) {
    if (eccentricity <= std::numeric_limits<double>::epsilon()) {
        return normalize_angle(eccentric_anomaly_rad);
    }

    const double denominator =
        1.0 - (eccentricity * std::cos(eccentric_anomaly_rad));
    const double sin_true_anomaly =
        std::sqrt(1.0 - (eccentricity * eccentricity)) *
        std::sin(eccentric_anomaly_rad) / denominator;
    const double cos_true_anomaly =
        (std::cos(eccentric_anomaly_rad) - eccentricity) / denominator;
    return std::atan2(sin_true_anomaly, cos_true_anomaly);
}

double orbital_radius_km(
    double semi_major_axis_km,
    double eccentricity,
    double eccentric_anomaly_rad) {
    return semi_major_axis_km *
           (1.0 - (eccentricity * std::cos(eccentric_anomaly_rad)));
}

Vec3 ascending_node_direction(const OrbitParameters& orbit) {
    return normalize(
        Vec3{
            .x = std::cos(orbit.longitude_of_ascending_node_rad),
            .y = 0.0,
            .z = std::sin(orbit.longitude_of_ascending_node_rad),
        },
        Vec3{.x = 1.0, .y = 0.0, .z = 0.0});
}

Vec3 orbit_normal(const OrbitParameters& orbit) {
    return normalize(
        rotate_around_axis(
            Vec3{.x = 0.0, .y = 1.0, .z = 0.0},
            ascending_node_direction(orbit),
            orbit.inclination_rad),
        Vec3{.x = 0.0, .y = 1.0, .z = 0.0});
}

Vec3 periapsis_direction(const OrbitParameters& orbit, const Vec3& orbit_normal_direction) {
    return normalize(
        rotate_around_axis(
            ascending_node_direction(orbit),
            orbit_normal_direction,
            orbit.argument_of_periapsis_rad),
        Vec3{.x = 0.0, .y = 0.0, .z = 1.0});
}

Vec3 relative_orbit_position_km(const MassiveBody& body, double sim_time_s) {
    const double mean_anomaly = mean_anomaly_at_time(body, sim_time_s);
    const double eccentric_anomaly =
        solve_eccentric_anomaly(mean_anomaly, body.orbit.eccentricity);
    const double true_anomaly =
        true_anomaly_from_eccentric(eccentric_anomaly, body.orbit.eccentricity);
    const double radius_km =
        orbital_radius_km(
            body.orbit.semi_major_axis_km,
            body.orbit.eccentricity,
            eccentric_anomaly);

    const Vec3 orbit_normal_direction = orbit_normal(body.orbit);
    const Vec3 periapsis_direction_in_world =
        periapsis_direction(body.orbit, orbit_normal_direction);
    // Classical orbital elements use the prograde perifocal basis {p, q, h}
    // with q = h x p. For a zero-inclination prograde orbit, that means the
    // motion advances from +X toward -Z in this Y-up world, matching the
    // real-world counterclockwise direction when viewed from north of the
    // ecliptic.
    const Vec3 tangential_direction = normalize(
        cross(orbit_normal_direction, periapsis_direction_in_world),
        Vec3{.x = 0.0, .y = 0.0, .z = 1.0});

    return add(
        scale(periapsis_direction_in_world, radius_km * std::cos(true_anomaly)),
        scale(tangential_direction, radius_km * std::sin(true_anomaly)));
}

Vec3 relative_orbit_velocity_km_s(const MassiveBody& body, double sim_time_s) {
    constexpr double sample_dt_s = 1.0;
    return scale(
        subtract(
            relative_orbit_position_km(body, sim_time_s + sample_dt_s),
            relative_orbit_position_km(body, sim_time_s - sample_dt_s)),
        0.5 / sample_dt_s);
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

void Simulation::add_spacecraft(Spacecraft spacecraft) {
    spacecraft_.push_back(std::move(spacecraft));
}

void Simulation::step(double delta_game_seconds) {
    if (!running_) return;

    sim_time_s_ += delta_game_seconds * TIME_SCALE;

    for (auto& body : bodies_) {
        if (body.rotation.orbital_period_s <= 0.0 ||
            body.orbit.semi_major_axis_km <= 0.0) {
            continue;
        }

        Vec3 parent_pos{};
        if (body.orbit.central_body_index >= 0 &&
            body.orbit.central_body_index < static_cast<int>(bodies_.size())) {
            parent_pos =
                bodies_[static_cast<size_t>(body.orbit.central_body_index)].position_km;
        }

        Vec3 parent_velocity{};
        if (body.orbit.central_body_index >= 0 &&
            body.orbit.central_body_index < static_cast<int>(bodies_.size())) {
            parent_velocity =
                bodies_[static_cast<size_t>(body.orbit.central_body_index)].velocity_km_s;
        }

        body.position_km = add(parent_pos, relative_orbit_position_km(body, sim_time_s_));
        body.velocity_km_s =
            add(parent_velocity, relative_orbit_velocity_km_s(body, sim_time_s_));
    }

    for (auto& spacecraft : spacecraft_) {
        Vec3 reference_position{};
        Vec3 reference_velocity{};
        if (spacecraft.reference_body_index >= 0 &&
            spacecraft.reference_body_index < static_cast<int>(bodies_.size())) {
            const auto& reference_body =
                bodies_[static_cast<size_t>(spacecraft.reference_body_index)];
            reference_position = reference_body.position_km;
            reference_velocity = reference_body.velocity_km_s;
        }

        Vec3 relative_position = spacecraft.relative_position_km;
        Vec3 relative_velocity = spacecraft.relative_velocity_km_s;
        if (spacecraft.orbital_period_s > 0.0 &&
            spacecraft.orbit.semi_major_axis_km > 0.0) {
            MassiveBody orbiting_spacecraft{};
            orbiting_spacecraft.orbit = spacecraft.orbit;
            orbiting_spacecraft.rotation.orbital_period_s = spacecraft.orbital_period_s;
            relative_position =
                relative_orbit_position_km(orbiting_spacecraft, sim_time_s_);
            relative_velocity =
                relative_orbit_velocity_km_s(orbiting_spacecraft, sim_time_s_);
        }

        spacecraft.position_km = add(reference_position, relative_position);
        spacecraft.velocity_km_s = add(reference_velocity, relative_velocity);
    }
}

const std::vector<MassiveBody>& Simulation::bodies() const { return bodies_; }

const std::vector<Spacecraft>& Simulation::spacecraft() const { return spacecraft_; }

size_t Simulation::body_count() const { return bodies_.size(); }

size_t Simulation::spacecraft_count() const { return spacecraft_.size(); }

double Simulation::sim_time() const { return sim_time_s_; }

} // namespace solar

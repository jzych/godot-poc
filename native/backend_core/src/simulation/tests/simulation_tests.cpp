#include <gtest/gtest.h>

#include <cmath>
#include <numbers>

#include "massive_body/default_bodies.h"
#include "simulation/simulation.h"

namespace {

constexpr double KM_POSITION_TOLERANCE = 1.0;
constexpr double KM_DISTANCE_TOLERANCE = 1.0;

solar::MassiveBody make_sun() {
    return solar::make_default_bodies()[0];
}

solar::MassiveBody make_earth() {
    return solar::make_default_bodies()[1];
}

solar::MassiveBody make_moon() {
    return solar::make_default_bodies()[2];
}

solar::MassiveBody make_reference_plane_circular_body() {
    solar::MassiveBody body{};
    body.type = solar::MassiveBodyType::Earth;
    body.name = "Reference";
    body.orbit.central_body_index = 0;
    body.orbit.semi_major_axis_km = 1000.0;
    body.orbit.eccentricity = 0.0;
    body.orbit.inclination_rad = 0.0;
    body.orbit.longitude_of_ascending_node_rad = 0.0;
    body.orbit.argument_of_periapsis_rad = 0.0;
    body.orbit.apoapsis_km = 1000.0;
    body.orbit.anomaly_kind = solar::OrbitalAnomalyKind::MeanAnomaly;
    body.orbit.anomaly_at_epoch = 0.0;
    body.rotation.orbital_period_s = 1000.0;
    return body;
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

solar::Vec3 add(const solar::Vec3& lhs, const solar::Vec3& rhs) {
    return solar::Vec3{
        .x = lhs.x + rhs.x,
        .y = lhs.y + rhs.y,
        .z = lhs.z + rhs.z,
    };
}

solar::Vec3 subtract(const solar::Vec3& lhs, const solar::Vec3& rhs) {
    return solar::Vec3{
        .x = lhs.x - rhs.x,
        .y = lhs.y - rhs.y,
        .z = lhs.z - rhs.z,
    };
}

solar::Vec3 scale(const solar::Vec3& vector, double scalar) {
    return solar::Vec3{
        .x = vector.x * scalar,
        .y = vector.y * scalar,
        .z = vector.z * scalar,
    };
}

double dot(const solar::Vec3& lhs, const solar::Vec3& rhs) {
    return lhs.x * rhs.x + lhs.y * rhs.y + lhs.z * rhs.z;
}

solar::Vec3 cross(const solar::Vec3& lhs, const solar::Vec3& rhs) {
    return solar::Vec3{
        .x = lhs.y * rhs.z - lhs.z * rhs.y,
        .y = lhs.z * rhs.x - lhs.x * rhs.z,
        .z = lhs.x * rhs.y - lhs.y * rhs.x,
    };
}

double length(const solar::Vec3& vector) {
    return std::sqrt(dot(vector, vector));
}

double y_component_of_angular_momentum(
    const solar::Vec3& position,
    const solar::Vec3& next_position) {
    return cross(position, subtract(next_position, position)).y;
}

solar::Vec3 normalize(const solar::Vec3& vector, const solar::Vec3& fallback) {
    const double vector_length = length(vector);
    if (vector_length <= 1e-12) {
        return fallback;
    }

    return scale(vector, 1.0 / vector_length);
}

solar::Vec3 rotate_around_axis(
    const solar::Vec3& vector,
    const solar::Vec3& axis,
    double angle_rad) {
    const solar::Vec3 normalized_axis =
        normalize(axis, solar::Vec3{.x = 1.0, .y = 0.0, .z = 0.0});
    const double cos_angle = std::cos(angle_rad);
    const double sin_angle = std::sin(angle_rad);
    return add(
        add(scale(vector, cos_angle), scale(cross(normalized_axis, vector), sin_angle)),
        scale(normalized_axis, dot(normalized_axis, vector) * (1.0 - cos_angle)));
}

double mean_motion_rad_per_s(const solar::MassiveBody& body) {
    const double omega =
        2.0 * std::numbers::pi / body.rotation.orbital_period_s;
    return omega;
}

double true_to_mean_anomaly(double true_anomaly_rad, double eccentricity) {
    if (eccentricity <= 0.0) {
        return normalize_angle(true_anomaly_rad);
    }

    const double eccentric_anomaly = 2.0 * std::atan2(
        std::sqrt(1.0 - eccentricity) * std::sin(true_anomaly_rad / 2.0),
        std::sqrt(1.0 + eccentricity) * std::cos(true_anomaly_rad / 2.0));
    return eccentric_anomaly - eccentricity * std::sin(eccentric_anomaly);
}

double mean_anomaly_at_time(const solar::MassiveBody& body, double sim_time_seconds = 0.0) {
    const double omega = mean_motion_rad_per_s(body);
    switch (body.orbit.anomaly_kind) {
    case solar::OrbitalAnomalyKind::MeanAnomaly:
        return body.orbit.anomaly_at_epoch + (omega * sim_time_seconds);
    case solar::OrbitalAnomalyKind::TrueAnomaly:
        return true_to_mean_anomaly(body.orbit.anomaly_at_epoch, body.orbit.eccentricity) +
               (omega * sim_time_seconds);
    case solar::OrbitalAnomalyKind::TimeOfPeriapsisPassage:
        return omega * (sim_time_seconds - body.orbit.anomaly_at_epoch);
    case solar::OrbitalAnomalyKind::None:
    default:
        return omega * sim_time_seconds;
    }
}

double solve_eccentric_anomaly(double mean_anomaly_rad, double eccentricity) {
    if (eccentricity <= 0.0) {
        return normalize_angle(mean_anomaly_rad);
    }

    const double normalized_mean_anomaly = normalize_angle(mean_anomaly_rad);
    double eccentric_anomaly =
        eccentricity < 0.8
            ? normalized_mean_anomaly
            : (normalized_mean_anomaly >= 0.0 ? std::numbers::pi : -std::numbers::pi);

    for (int iteration = 0; iteration < 12; ++iteration) {
        const double sin_e = std::sin(eccentric_anomaly);
        const double cos_e = std::cos(eccentric_anomaly);
        const double residual =
            eccentric_anomaly - (eccentricity * sin_e) - normalized_mean_anomaly;
        const double derivative = 1.0 - (eccentricity * cos_e);
        const double step = residual / derivative;
        eccentric_anomaly -= step;
        if (std::abs(step) <= 1e-10) {
            break;
        }
    }

    return eccentric_anomaly;
}

double true_anomaly_from_eccentric(double eccentric_anomaly_rad, double eccentricity) {
    if (eccentricity <= 0.0) {
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
    const solar::MassiveBody& body,
    double sim_time_seconds = 0.0) {
    const double mean_anomaly = mean_anomaly_at_time(body, sim_time_seconds);
    const double eccentric_anomaly =
        solve_eccentric_anomaly(mean_anomaly, body.orbit.eccentricity);
    return body.orbit.semi_major_axis_km *
           (1.0 - (body.orbit.eccentricity * std::cos(eccentric_anomaly)));
}

solar::Vec3 ascending_node_direction(const solar::OrbitParameters& orbit) {
    return normalize(
        solar::Vec3{
            .x = std::cos(orbit.longitude_of_ascending_node_rad),
            .y = 0.0,
            .z = std::sin(orbit.longitude_of_ascending_node_rad),
        },
        solar::Vec3{.x = 1.0, .y = 0.0, .z = 0.0});
}

solar::Vec3 orbit_normal(const solar::OrbitParameters& orbit) {
    return normalize(
        rotate_around_axis(
            solar::Vec3{.x = 0.0, .y = 1.0, .z = 0.0},
            ascending_node_direction(orbit),
            orbit.inclination_rad),
        solar::Vec3{.x = 0.0, .y = 1.0, .z = 0.0});
}

solar::Vec3 periapsis_direction(
    const solar::OrbitParameters& orbit,
    const solar::Vec3& orbit_normal_direction) {
    return normalize(
        rotate_around_axis(
            ascending_node_direction(orbit),
            orbit_normal_direction,
            orbit.argument_of_periapsis_rad),
        solar::Vec3{.x = 0.0, .y = 0.0, .z = 1.0});
}

solar::Vec3 expected_relative_position(
    const solar::MassiveBody& body,
    double sim_time_seconds = 0.0) {
    const double mean_anomaly = mean_anomaly_at_time(body, sim_time_seconds);
    const double eccentric_anomaly =
        solve_eccentric_anomaly(mean_anomaly, body.orbit.eccentricity);
    const double true_anomaly =
        true_anomaly_from_eccentric(eccentric_anomaly, body.orbit.eccentricity);
    const double radius_km = orbital_radius_km(body, sim_time_seconds);

    const solar::Vec3 orbit_normal_direction = orbit_normal(body.orbit);
    const solar::Vec3 periapsis_direction_in_world =
        periapsis_direction(body.orbit, orbit_normal_direction);
    const solar::Vec3 tangential_direction =
        normalize(
            cross(orbit_normal_direction, periapsis_direction_in_world),
            solar::Vec3{.x = 0.0, .y = 0.0, .z = 1.0});

    return add(
        scale(periapsis_direction_in_world, radius_km * std::cos(true_anomaly)),
        scale(tangential_direction, radius_km * std::sin(true_anomaly)));
}

solar::Vec3 expected_relative_position(
    const solar::Spacecraft& spacecraft,
    double sim_time_seconds = 0.0) {
    solar::MassiveBody orbiting_body{};
    orbiting_body.orbit = spacecraft.orbit;
    orbiting_body.rotation.orbital_period_s = spacecraft.orbital_period_s;
    return expected_relative_position(orbiting_body, sim_time_seconds);
}

} // namespace

TEST(SimulationTest, CanInstantiate) {
    solar::Simulation sim;
    EXPECT_FALSE(sim.is_running());
}

TEST(SimulationTest, TimeScaleRunsAtHalfPreviousPrototypeRate) {
    EXPECT_DOUBLE_EQ(solar::Simulation::TIME_SCALE, 1080.0);
}

TEST(SimulationTest, StartStop) {
    solar::Simulation sim;
    sim.start();
    EXPECT_TRUE(sim.is_running());
    sim.stop();
    EXPECT_FALSE(sim.is_running());
}

TEST(SimulationTest, AddBodies) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    EXPECT_EQ(sim.body_count(), 2u);
}

TEST(SimulationTest, AddSpacecraft) {
    solar::Simulation sim;
    const auto spacecraft = solar::make_default_spacecraft();

    sim.add_spacecraft(spacecraft[0]);

    EXPECT_EQ(sim.spacecraft_count(), 1u);
    EXPECT_EQ(sim.spacecraft()[0].id, "demo_probe");
}

TEST(SimulationTest, SunRemainsAtOrigin) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.start();
    sim.step(1.0);
    const auto& sun = sim.bodies()[0];
    EXPECT_DOUBLE_EQ(sun.position_km.x, 0.0);
    EXPECT_DOUBLE_EQ(sun.position_km.y, 0.0);
    EXPECT_DOUBLE_EQ(sun.position_km.z, 0.0);
}

TEST(SimulationTest, EarthMovesAfterStep) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.start();

    auto pos_before = sim.bodies()[1].position_km;
    sim.step(1.0);
    auto pos_after = sim.bodies()[1].position_km;

    double dist_before = std::sqrt(pos_before.x * pos_before.x +
                                   pos_before.z * pos_before.z);
    double dist_after = std::sqrt(pos_after.x * pos_after.x +
                                  pos_after.z * pos_after.z);

    // Before first step, position is default (0,0,0), after step it should be at ~1 AU
    EXPECT_NEAR(dist_before, 0.0, 0.001);
    EXPECT_GT(dist_after, 0.0);
}

TEST(SimulationTest, InitialOrbitPositionHonorsAnomalyAtEpoch) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.start();
    sim.step(0.0);

    const auto& earth = sim.bodies()[1];
    const solar::Vec3 expected_position = expected_relative_position(earth);
    EXPECT_NEAR(earth.position_km.x, expected_position.x, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(earth.position_km.y, expected_position.y, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(earth.position_km.z, expected_position.z, KM_POSITION_TOLERANCE);
    EXPECT_GT(length(earth.velocity_km_s), 0.0);
}

TEST(SimulationTest, SpacecraftPositionFollowsReferenceBody) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    const auto spacecraft = solar::make_default_spacecraft();
    sim.add_spacecraft(spacecraft[0]);
    sim.start();
    sim.step(0.0);

    const auto& earth = sim.bodies()[1];
    const auto& probe = sim.spacecraft()[0];
    const solar::Vec3 expected_position =
        add(earth.position_km, expected_relative_position(probe));
    const solar::Vec3 relative_position = subtract(probe.position_km, earth.position_km);

    EXPECT_NEAR(probe.position_km.x, expected_position.x, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(probe.position_km.y, expected_position.y, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(probe.position_km.z, expected_position.z, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(length(relative_position), 6771.0, KM_DISTANCE_TOLERANCE);
    EXPECT_GT(length(subtract(probe.velocity_km_s, earth.velocity_km_s)), 0.0);
}

TEST(SimulationTest, SpacecraftLeoOrbitUsesSixtyDegreeInclination) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    const auto spacecraft = solar::make_default_spacecraft();
    sim.add_spacecraft(spacecraft[0]);
    sim.start();
    sim.step(spacecraft[0].orbital_period_s / (4.0 * solar::Simulation::TIME_SCALE));

    const auto relative_position =
        subtract(sim.spacecraft()[0].position_km, sim.bodies()[1].position_km);

    EXPECT_GT(std::abs(relative_position.y), 5000.0)
        << "A 60-degree LEO should rise well out of the ecliptic plane after a quarter orbit";
}

TEST(SimulationTest, ReferencePlaneOrbitUsesRealWorldProgradeDirection) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_reference_plane_circular_body());
    sim.start();
    sim.step(0.0);

    const auto initial_position = sim.bodies()[1].position_km;
    sim.step(1.0);
    const auto next_position = sim.bodies()[1].position_km;

    EXPECT_NEAR(initial_position.x, 1000.0, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(initial_position.y, 0.0, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(initial_position.z, 0.0, KM_POSITION_TOLERANCE);
    EXPECT_LT(next_position.z, initial_position.z)
        << "A prograde orbit should advance from +X toward -Z in the Y-up world frame";
    EXPECT_GT(y_component_of_angular_momentum(initial_position, next_position), 0.0)
        << "Reference-plane orbit angular momentum should point toward +Y";
}

TEST(SimulationTest, EarthOrbitalRadiusVariesAcrossOrbit) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.start();
    sim.step(0.0);

    const auto initial_radius_km = length(sim.bodies()[1].position_km);
    const double half_orbit_game_seconds =
        (sim.bodies()[1].rotation.orbital_period_s * 0.5) /
        solar::Simulation::TIME_SCALE;
    sim.step(half_orbit_game_seconds);

    const auto half_orbit_radius_km = length(sim.bodies()[1].position_km);
    EXPECT_GT(
        std::abs(half_orbit_radius_km - initial_radius_km),
        sim.bodies()[1].orbit.semi_major_axis_km * sim.bodies()[1].orbit.eccentricity);
}

TEST(SimulationTest, MoonOrbitsEarth) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.add_body(make_moon());
    sim.start();
    sim.step(0.0);

    const auto& earth = sim.bodies()[1];
    const auto& moon = sim.bodies()[2];
    const solar::Vec3 relative_position = subtract(moon.position_km, earth.position_km);
    const solar::Vec3 expected_relative = expected_relative_position(moon);
    const double distance_km = length(relative_position);

    EXPECT_NEAR(relative_position.x, expected_relative.x, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(relative_position.y, expected_relative.y, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(relative_position.z, expected_relative.z, KM_POSITION_TOLERANCE);
    EXPECT_GT(std::abs(relative_position.y), 1000.0);
    EXPECT_GE(
        distance_km,
        moon.orbit.semi_major_axis_km * (1.0 - moon.orbit.eccentricity) -
            KM_DISTANCE_TOLERANCE);
    EXPECT_LE(
        distance_km,
        moon.orbit.semi_major_axis_km * (1.0 + moon.orbit.eccentricity) +
            KM_DISTANCE_TOLERANCE);
}

TEST(SimulationTest, EarthAndMoonRemainProgradeRelativeToReferencePlaneNorth) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.add_body(make_moon());
    sim.start();
    sim.step(0.0);

    const auto earth_initial_position = sim.bodies()[1].position_km;
    const auto moon_initial_relative_position =
        subtract(sim.bodies()[2].position_km, sim.bodies()[1].position_km);

    sim.step(1.0);

    const auto earth_next_position = sim.bodies()[1].position_km;
    const auto moon_next_relative_position =
        subtract(sim.bodies()[2].position_km, sim.bodies()[1].position_km);

    EXPECT_GT(
        y_component_of_angular_momentum(earth_initial_position, earth_next_position),
        0.0) << "Earth orbit should be prograde relative to the reference-plane north";
    EXPECT_GT(
        y_component_of_angular_momentum(
            moon_initial_relative_position,
            moon_next_relative_position),
        0.0) << "Moon orbit should be prograde relative to the reference-plane north";
}

TEST(SimulationTest, StepDoesNothingWhenStopped) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    // Not started
    sim.step(1.0);
    EXPECT_DOUBLE_EQ(sim.sim_time(), 0.0);
}

TEST(SimulationTest, FullOrbitReturnsToStart) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.start();
    sim.step(0.0);

    const auto initial_position = sim.bodies()[1].position_km;

    // Step exactly one Earth orbital period in game seconds
    double game_seconds_per_orbit =
        sim.bodies()[1].rotation.orbital_period_s / solar::Simulation::TIME_SCALE;
    sim.step(game_seconds_per_orbit);

    const auto& earth = sim.bodies()[1];
    EXPECT_NEAR(earth.position_km.x, initial_position.x, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(earth.position_km.y, initial_position.y, KM_POSITION_TOLERANCE);
    EXPECT_NEAR(earth.position_km.z, initial_position.z, KM_POSITION_TOLERANCE);
}

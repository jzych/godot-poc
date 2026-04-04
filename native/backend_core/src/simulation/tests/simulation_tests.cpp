#include <gtest/gtest.h>

#include <cmath>
#include <numbers>

#include "massive_body/default_bodies.h"
#include "simulation/simulation.h"

namespace {

solar::MassiveBody make_sun() {
    return solar::make_default_bodies()[0];
}

solar::MassiveBody make_earth() {
    return solar::make_default_bodies()[1];
}

solar::MassiveBody make_moon() {
    return solar::make_default_bodies()[2];
}

double body_orbit_angle(const solar::MassiveBody& body, double sim_time_seconds = 0.0) {
    const double omega =
        2.0 * std::numbers::pi / body.rotation.orbital_period_s;

    switch (body.orbit.anomaly_kind) {
    case solar::OrbitalAnomalyKind::MeanAnomaly:
    case solar::OrbitalAnomalyKind::TrueAnomaly:
        return body.orbit.anomaly_at_epoch + (omega * sim_time_seconds);
    case solar::OrbitalAnomalyKind::TimeOfPeriapsisPassage:
        return omega * (sim_time_seconds - body.orbit.anomaly_at_epoch);
    case solar::OrbitalAnomalyKind::None:
    default:
        return omega * sim_time_seconds;
    }
}

} // namespace

TEST(SimulationTest, CanInstantiate) {
    solar::Simulation sim;
    EXPECT_FALSE(sim.is_running());
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
    const double expected_angle = body_orbit_angle(earth);
    EXPECT_NEAR(
        earth.position_km.x,
        earth.orbit.semi_major_axis_km * std::cos(expected_angle),
        0.1);
    EXPECT_NEAR(
        earth.position_km.z,
        earth.orbit.semi_major_axis_km * std::sin(expected_angle),
        0.1);
}

TEST(SimulationTest, EarthMaintainsOrbitalRadius) {
    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.start();
    sim.step(5.0);

    const auto& earth = sim.bodies()[1];
    double r = std::sqrt(earth.position_km.x * earth.position_km.x +
                         earth.position_km.z * earth.position_km.z);
    EXPECT_NEAR(r, earth.orbit.semi_major_axis_km, 0.1);
}

TEST(SimulationTest, MoonOrbitsEarth) {
    using enum solar::MassiveBodyType;

    solar::Simulation sim;
    sim.add_body(make_sun());
    sim.add_body(make_earth());
    sim.add_body(make_moon());
    sim.start();
    sim.step(1.0);

    const auto& earth = sim.bodies()[1];
    const auto& moon = sim.bodies()[2];
    double dx = moon.position_km.x - earth.position_km.x;
    double dz = moon.position_km.z - earth.position_km.z;
    double dist = std::sqrt(dx * dx + dz * dz);
    EXPECT_NEAR(dist, moon.orbit.semi_major_axis_km, 0.1);
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

    // Step exactly one Earth orbital period in game seconds
    double game_seconds_per_orbit =
        sim.bodies()[1].rotation.orbital_period_s / solar::Simulation::TIME_SCALE;
    sim.step(game_seconds_per_orbit);

    const auto& earth = sim.bodies()[1];
    const double expected_angle = body_orbit_angle(earth);
    EXPECT_NEAR(
        earth.position_km.x,
        earth.orbit.semi_major_axis_km * std::cos(expected_angle),
        1.0);
    EXPECT_NEAR(
        earth.position_km.z,
        earth.orbit.semi_major_axis_km * std::sin(expected_angle),
        1.0);
}

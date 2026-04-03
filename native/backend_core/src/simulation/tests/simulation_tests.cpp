#include <gtest/gtest.h>

#include <cmath>
#include <numbers>

#include "simulation/simulation.h"

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
    sim.add_body({solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                  {1, 0.65f, 0}, {}});
    sim.add_body({solar::MassiveBodyType::Earth, "Earth", 149597870.7,
                  31557600.0, 0, {0, 0, 1}, {}});
    EXPECT_EQ(sim.body_count(), 2u);
}

TEST(SimulationTest, SunRemainsAtOrigin) {
    solar::Simulation sim;
    sim.add_body({solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                  {1, 0.65f, 0}, {}});
    sim.start();
    sim.step(1.0);
    const auto& sun = sim.bodies()[0];
    EXPECT_DOUBLE_EQ(sun.position_km.x, 0.0);
    EXPECT_DOUBLE_EQ(sun.position_km.y, 0.0);
    EXPECT_DOUBLE_EQ(sun.position_km.z, 0.0);
}

TEST(SimulationTest, EarthMovesAfterStep) {
    solar::Simulation sim;
    sim.add_body({solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                  {1, 0.65f, 0}, {}});
    sim.add_body({solar::MassiveBodyType::Earth, "Earth", 149597870.7,
                  31557600.0, 0, {0, 0, 1}, {}});
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

TEST(SimulationTest, EarthMaintainsOrbitalRadius) {
    solar::Simulation sim;
    sim.add_body({solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                  {1, 0.65f, 0}, {}});
    sim.add_body({solar::MassiveBodyType::Earth, "Earth", 149597870.7,
                  31557600.0, 0, {0, 0, 1}, {}});
    sim.start();
    sim.step(5.0);

    const auto& earth = sim.bodies()[1];
    double r = std::sqrt(earth.position_km.x * earth.position_km.x +
                         earth.position_km.z * earth.position_km.z);
    EXPECT_NEAR(r, 149597870.7, 0.1);
}

TEST(SimulationTest, MoonOrbitsEarth) {
    using enum solar::MassiveBodyType;

    solar::Simulation sim;
    sim.add_body({Sun, "Sun", 0.0, 0.0, -1, {1, 0.65f, 0}, {}});
    sim.add_body({Earth, "Earth", 149597870.7, 31557600.0, 0, {0, 0, 1}, {}});
    sim.add_body({Moon, "Moon", 384400.0, 2360448.0, 1, {0.8f, 0.8f, 0.8f}, {}});
    sim.start();
    sim.step(1.0);

    const auto& earth = sim.bodies()[1];
    const auto& moon = sim.bodies()[2];
    double dx = moon.position_km.x - earth.position_km.x;
    double dz = moon.position_km.z - earth.position_km.z;
    double dist = std::sqrt(dx * dx + dz * dz);
    EXPECT_NEAR(dist, 384400.0, 0.1);
}

TEST(SimulationTest, StepDoesNothingWhenStopped) {
    solar::Simulation sim;
    sim.add_body({solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                  {1, 0.65f, 0}, {}});
    sim.add_body({solar::MassiveBodyType::Earth, "Earth", 149597870.7,
                  31557600.0, 0, {0, 0, 1}, {}});
    // Not started
    sim.step(1.0);
    EXPECT_DOUBLE_EQ(sim.sim_time(), 0.0);
}

TEST(SimulationTest, FullOrbitReturnsToStart) {
    solar::Simulation sim;
    sim.add_body({solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                  {1, 0.65f, 0}, {}});
    sim.add_body({solar::MassiveBodyType::Earth, "Earth", 149597870.7,
                  31557600.0, 0, {0, 0, 1}, {}});
    sim.start();

    // Step exactly one Earth orbital period in game seconds
    double game_seconds_per_orbit =
        31557600.0 / solar::Simulation::TIME_SCALE;
    sim.step(game_seconds_per_orbit);

    const auto& earth = sim.bodies()[1];
    // After full orbit, cos(2*pi) = 1, sin(2*pi) = 0
    EXPECT_NEAR(earth.position_km.x, 149597870.7, 1.0);
    EXPECT_NEAR(earth.position_km.z, 0.0, 1.0);
}

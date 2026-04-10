#include <gtest/gtest.h>

#include <numbers>

#include "massive_body/default_bodies.h"
#include "massive_body/massive_body.h"

TEST(MassiveBodyTest, DefaultConstruction) {
    solar::MassiveBody body;
    EXPECT_EQ(body.id, "");
    EXPECT_EQ(body.focus_type, solar::FocusTargetType::Planet);
    EXPECT_EQ(body.orbit.central_body_index, -1);
    EXPECT_EQ(body.orbit.semi_major_axis_km, 0.0);
    EXPECT_EQ(body.orbit.eccentricity, 0.0);
    EXPECT_EQ(body.rotation.orbital_period_s, 0.0);
    EXPECT_DOUBLE_EQ(body.radius_km, 1.0);
    EXPECT_DOUBLE_EQ(body.preferred_min_distance_km, 1.0);
    EXPECT_DOUBLE_EQ(body.preferred_max_distance_km, 1.0);
    EXPECT_DOUBLE_EQ(body.position_km.x, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.y, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.z, 0.0);
    EXPECT_DOUBLE_EQ(body.velocity_km_s.x, 0.0);
    EXPECT_DOUBLE_EQ(body.velocity_km_s.y, 0.0);
    EXPECT_DOUBLE_EQ(body.velocity_km_s.z, 0.0);
}

TEST(MassiveBodyTest, SunConfiguration) {
    const auto bodies = solar::make_default_bodies();
    const auto& sun = bodies[0];

    EXPECT_EQ(sun.type, solar::MassiveBodyType::Sun);
    EXPECT_EQ(sun.focus_type, solar::FocusTargetType::Star);
    EXPECT_EQ(sun.id, "sun");
    EXPECT_EQ(sun.name, "Sun");
    EXPECT_EQ(sun.orbit.central_body_index, -1);
    EXPECT_DOUBLE_EQ(sun.rotation.orbital_period_s, 0.0);
    EXPECT_DOUBLE_EQ(sun.radius_km, 696000.0);
    EXPECT_GT(sun.preferred_max_distance_km, sun.preferred_min_distance_km);
}

TEST(MassiveBodyTest, EarthConfiguration) {
    const auto bodies = solar::make_default_bodies();
    const auto& earth = bodies[1];

    EXPECT_EQ(earth.type, solar::MassiveBodyType::Earth);
    EXPECT_EQ(earth.focus_type, solar::FocusTargetType::Planet);
    EXPECT_EQ(earth.id, "earth");
    EXPECT_DOUBLE_EQ(earth.orbit.semi_major_axis_km, 149597870.7);
    EXPECT_DOUBLE_EQ(earth.orbit.eccentricity, 0.0167086);
    EXPECT_EQ(earth.orbit.central_body_index, 0);
    EXPECT_DOUBLE_EQ(earth.rotation.orbital_period_s, 31557600.0);
    EXPECT_DOUBLE_EQ(earth.radius_km, 6371.0);
    EXPECT_GT(earth.preferred_max_distance_km, earth.preferred_min_distance_km);
}

TEST(MassiveBodyTest, MoonConfiguration) {
    const auto bodies = solar::make_default_bodies();
    const auto& moon = bodies[2];

    EXPECT_EQ(moon.type, solar::MassiveBodyType::Moon);
    EXPECT_EQ(moon.focus_type, solar::FocusTargetType::Moon);
    EXPECT_EQ(moon.id, "moon");
    EXPECT_DOUBLE_EQ(moon.orbit.semi_major_axis_km, 384400.0);
    EXPECT_DOUBLE_EQ(moon.orbit.eccentricity, 0.0549);
    EXPECT_EQ(moon.orbit.central_body_index, 1);
    EXPECT_GT(moon.rotation.rotation_speed_rad_per_s, 0.0);
    EXPECT_DOUBLE_EQ(moon.radius_km, 1737.0);
}

TEST(MassiveBodyTest, DefaultSpacecraftConfiguration) {
    const auto spacecraft = solar::make_default_spacecraft();
    ASSERT_EQ(spacecraft.size(), 1u);

    const auto& probe = spacecraft[0];
    EXPECT_EQ(probe.id, "demo_probe");
    EXPECT_EQ(probe.name, "Demo Probe");
    EXPECT_EQ(probe.reference_body_index, 1);
    EXPECT_DOUBLE_EQ(probe.orbit.semi_major_axis_km, 8471.0);
    EXPECT_NEAR(probe.orbit.eccentricity, 100.0 / 8471.0, 1e-12);
    EXPECT_NEAR(
        probe.orbit.semi_major_axis_km * (1.0 - probe.orbit.eccentricity),
        8371.0,
        1e-9);
    EXPECT_DOUBLE_EQ(probe.orbit.apoapsis_km, 8571.0);
    EXPECT_NEAR(probe.orbit.inclination_rad, std::numbers::pi / 3.0, 1e-12);
    EXPECT_EQ(probe.orbit.central_body_index, 1);
    EXPECT_GT(probe.orbital_period_s, 0.0);
    EXPECT_NEAR(probe.visual_size_km, 0.1, 1e-12);
    EXPECT_NEAR(probe.bounding_radius_km, 0.0866025, 0.000001);
    EXPECT_GT(probe.preferred_max_distance_km, probe.preferred_min_distance_km);
}

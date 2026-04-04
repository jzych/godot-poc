#include <gtest/gtest.h>

#include "massive_body/default_bodies.h"
#include "massive_body/massive_body.h"

TEST(MassiveBodyTest, DefaultConstruction) {
    solar::MassiveBody body;
    EXPECT_EQ(body.orbit.central_body_index, -1);
    EXPECT_EQ(body.orbit.semi_major_axis_km, 0.0);
    EXPECT_EQ(body.orbit.eccentricity, 0.0);
    EXPECT_EQ(body.rotation.orbital_period_s, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.x, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.y, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.z, 0.0);
}

TEST(MassiveBodyTest, SunConfiguration) {
    const auto bodies = solar::make_default_bodies();
    const auto& sun = bodies[0];

    EXPECT_EQ(sun.type, solar::MassiveBodyType::Sun);
    EXPECT_EQ(sun.name, "Sun");
    EXPECT_EQ(sun.orbit.central_body_index, -1);
    EXPECT_DOUBLE_EQ(sun.rotation.orbital_period_s, 0.0);
}

TEST(MassiveBodyTest, EarthConfiguration) {
    const auto bodies = solar::make_default_bodies();
    const auto& earth = bodies[1];

    EXPECT_EQ(earth.type, solar::MassiveBodyType::Earth);
    EXPECT_DOUBLE_EQ(earth.orbit.semi_major_axis_km, 149597870.7);
    EXPECT_DOUBLE_EQ(earth.orbit.eccentricity, 0.0167086);
    EXPECT_EQ(earth.orbit.central_body_index, 0);
    EXPECT_DOUBLE_EQ(earth.rotation.orbital_period_s, 31557600.0);
}

TEST(MassiveBodyTest, MoonConfiguration) {
    const auto bodies = solar::make_default_bodies();
    const auto& moon = bodies[2];

    EXPECT_EQ(moon.type, solar::MassiveBodyType::Moon);
    EXPECT_DOUBLE_EQ(moon.orbit.semi_major_axis_km, 384400.0);
    EXPECT_DOUBLE_EQ(moon.orbit.eccentricity, 0.0549);
    EXPECT_EQ(moon.orbit.central_body_index, 1);
    EXPECT_GT(moon.rotation.rotation_speed_rad_per_s, 0.0);
}

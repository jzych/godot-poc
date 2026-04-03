#include <gtest/gtest.h>

#include "massive_body/massive_body.h"

TEST(MassiveBodyTest, DefaultConstruction) {
    solar::MassiveBody body;
    EXPECT_EQ(body.orbital_radius_km, 0.0);
    EXPECT_EQ(body.orbital_period_s, 0.0);
    EXPECT_EQ(body.parent_index, -1);
    EXPECT_DOUBLE_EQ(body.position_km.x, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.y, 0.0);
    EXPECT_DOUBLE_EQ(body.position_km.z, 0.0);
}

TEST(MassiveBodyTest, SunConfiguration) {
    solar::MassiveBody sun{
        solar::MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
        {1.0f, 0.65f, 0.0f}, {}};
    EXPECT_EQ(sun.type, solar::MassiveBodyType::Sun);
    EXPECT_EQ(sun.name, "Sun");
    EXPECT_EQ(sun.parent_index, -1);
}

TEST(MassiveBodyTest, EarthConfiguration) {
    solar::MassiveBody earth{
        solar::MassiveBodyType::Earth, "Earth", 149597870.7, 31557600.0, 0,
        {0.2f, 0.4f, 1.0f}, {}};
    EXPECT_EQ(earth.type, solar::MassiveBodyType::Earth);
    EXPECT_DOUBLE_EQ(earth.orbital_radius_km, 149597870.7);
    EXPECT_EQ(earth.parent_index, 0);
}

TEST(MassiveBodyTest, MoonConfiguration) {
    solar::MassiveBody moon{
        solar::MassiveBodyType::Moon, "Moon", 384400.0, 2360448.0, 1,
        {0.8f, 0.8f, 0.8f}, {}};
    EXPECT_EQ(moon.type, solar::MassiveBodyType::Moon);
    EXPECT_DOUBLE_EQ(moon.orbital_radius_km, 384400.0);
    EXPECT_EQ(moon.parent_index, 1);
}

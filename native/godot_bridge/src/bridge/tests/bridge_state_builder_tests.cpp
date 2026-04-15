#include <gtest/gtest.h>

#include "bridge/bridge_state_builder.h"
#include "massive_body/default_bodies.h"

namespace {

constexpr double TOLERANCE = 1e-9;

TEST(BridgeStateBuilderTest, BodyStateViewExportsExpectedMetadata) {
    solar::MassiveBody earth = solar::make_default_bodies()[1];
    earth.position_km = {.x = 100.0, .y = -50.0, .z = 25.0};
    earth.velocity_km_s = {.x = 1.0, .y = 2.0, .z = 3.0};

    const solar::FocusTargetStateView state =
        solar::build_body_state_view(earth, 1, "Sun");

    EXPECT_EQ(state.id, "earth");
    EXPECT_EQ(state.name, "Earth");
    EXPECT_EQ(state.focus_type, "planet");
    EXPECT_EQ(state.source_kind, "body");
    EXPECT_EQ(state.visual_shape, "sphere");
    EXPECT_EQ(state.render_domain_hint, "mid");
    EXPECT_EQ(state.central_body_name, "Sun");
    EXPECT_EQ(state.body_index, 1);
    EXPECT_GT(state.visual_size_km, earth.radius_km);
    EXPECT_EQ(state.orbit.anomaly_kind, "mean_anomaly");
    EXPECT_GT(state.rotation.rotation_speed_rad_per_s, 0.0);
    EXPECT_FALSE(state.orbital_period_ydhms.empty());
    EXPECT_DOUBLE_EQ(state.simulation_position_km.x, earth.position_km.x);
    EXPECT_DOUBLE_EQ(state.simulation_velocity_km_s.z, earth.velocity_km_s.z);
    EXPECT_NEAR(
        state.position.x,
        earth.position_km.x * solar::default_bridge_scale(),
        TOLERANCE);
    EXPECT_NEAR(
        state.position.y,
        earth.position_km.y * solar::default_bridge_scale(),
        TOLERANCE);
    EXPECT_NEAR(
        state.position.z,
        earth.position_km.z * solar::default_bridge_scale(),
        TOLERANCE);
}

TEST(BridgeStateBuilderTest, StarBodyUsesFarRenderDomainHint) {
    const solar::MassiveBody sun = solar::make_default_bodies()[0];

    const solar::FocusTargetStateView state =
        solar::build_body_state_view(sun, 0, "");

    EXPECT_EQ(state.focus_type, "star");
    EXPECT_EQ(state.render_domain_hint, "far");
    EXPECT_EQ(state.central_body_name, "");
}

TEST(BridgeStateBuilderTest, SpacecraftStateViewExportsExpectedMetadata) {
    solar::Spacecraft spacecraft = solar::make_default_spacecraft()[0];
    spacecraft.position_km = {.x = 10.0, .y = 20.0, .z = 30.0};
    spacecraft.velocity_km_s = {.x = -1.0, .y = -2.0, .z = -3.0};

    const solar::FocusTargetStateView state =
        solar::build_spacecraft_state_view(spacecraft, 0, "Earth");

    EXPECT_EQ(state.id, "demo_probe");
    EXPECT_EQ(state.name, "Demo Probe");
    EXPECT_EQ(state.focus_type, "spacecraft");
    EXPECT_EQ(state.source_kind, "spacecraft");
    EXPECT_EQ(state.visual_shape, "cube");
    EXPECT_EQ(state.render_domain_hint, "near");
    EXPECT_EQ(state.central_body_name, "Earth");
    EXPECT_EQ(state.spacecraft_index, 0);
    EXPECT_EQ(state.reference_body_index, 1);
    EXPECT_EQ(state.orbit.anomaly_kind, "mean_anomaly");
    EXPECT_DOUBLE_EQ(state.rotation.rotation_speed_rad_per_s, 0.0);
    EXPECT_DOUBLE_EQ(state.rotation.axial_tilt_to_orbit_rad, 0.0);
    EXPECT_GT(state.orbital_period_seconds, 0.0);
    EXPECT_FALSE(state.orbital_period_ydhms.empty());
    EXPECT_NEAR(
        state.position.x,
        spacecraft.position_km.x * solar::default_bridge_scale(),
        TOLERANCE);
    EXPECT_NEAR(
        state.position.z,
        spacecraft.position_km.z * solar::default_bridge_scale(),
        TOLERANCE);
}

TEST(BridgeStateBuilderTest, ZeroOrbitalPeriodProducesEmptyDurationText) {
    solar::MassiveBody body{};
    body.id = "test";
    body.name = "Test";
    body.focus_type = solar::FocusTargetType::Planet;
    body.rotation.orbital_period_s = 0.0;

    const solar::FocusTargetStateView state =
        solar::build_body_state_view(body, 3, "");

    EXPECT_TRUE(state.orbital_period_ydhms.empty());
    EXPECT_DOUBLE_EQ(state.rotation.orbital_period_seconds, 0.0);
}

} // namespace

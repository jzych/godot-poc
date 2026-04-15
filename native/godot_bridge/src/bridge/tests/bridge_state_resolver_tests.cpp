#include <gtest/gtest.h>

#include "bridge/bridge_state_resolver.h"
#include "massive_body/default_bodies.h"

namespace {

solar::Simulation make_populated_simulation() {
    solar::Simulation sim;
    for (auto body : solar::make_default_bodies()) {
        sim.add_body(std::move(body));
    }
    for (auto spacecraft : solar::make_default_spacecraft()) {
        sim.add_spacecraft(std::move(spacecraft));
    }
    return sim;
}

TEST(BridgeStateResolverTest, BodyStateResolvesCentralBodyNameAndIndex) {
    solar::Simulation sim = make_populated_simulation();

    const auto state = solar::resolve_body_state_view(sim, 1);

    ASSERT_TRUE(state.has_value());
    EXPECT_EQ(state->id, "earth");
    EXPECT_EQ(state->name, "Earth");
    EXPECT_EQ(state->central_body_name, "Sun");
    EXPECT_EQ(state->body_index, 1);
    EXPECT_EQ(state->orbit.central_body_index, 0);
    EXPECT_EQ(state->orbit.anomaly_kind, "mean_anomaly");
}

TEST(BridgeStateResolverTest, SpacecraftStateResolvesReferenceBodyNameAndIndex) {
    solar::Simulation sim = make_populated_simulation();

    const auto state = solar::resolve_spacecraft_state_view(sim, 0);

    ASSERT_TRUE(state.has_value());
    EXPECT_EQ(state->id, "demo_probe");
    EXPECT_EQ(state->name, "Demo Probe");
    EXPECT_EQ(state->central_body_name, "Earth");
    EXPECT_EQ(state->spacecraft_index, 0);
    EXPECT_EQ(state->reference_body_index, 1);
    EXPECT_EQ(state->render_domain_hint, "near");
}

TEST(BridgeStateResolverTest, FocusTargetStateRoutesBodyAndSpacecraftIndices) {
    solar::Simulation sim = make_populated_simulation();

    const auto body_state = solar::resolve_focus_target_state_view(sim, 0);
    const auto spacecraft_state =
        solar::resolve_focus_target_state_view(sim, static_cast<int>(sim.body_count()));

    ASSERT_TRUE(body_state.has_value());
    ASSERT_TRUE(spacecraft_state.has_value());
    EXPECT_EQ(body_state->id, "sun");
    EXPECT_EQ(spacecraft_state->id, "demo_probe");
}

TEST(BridgeStateResolverTest, InvalidIndicesReturnNullopt) {
    solar::Simulation sim = make_populated_simulation();

    EXPECT_FALSE(solar::resolve_body_state_view(sim, -1).has_value());
    EXPECT_FALSE(
        solar::resolve_body_state_view(sim, static_cast<int>(sim.body_count())).has_value());
    EXPECT_FALSE(solar::resolve_spacecraft_state_view(sim, -1).has_value());
    EXPECT_FALSE(
        solar::resolve_spacecraft_state_view(
            sim,
            static_cast<int>(sim.spacecraft_count()))
            .has_value());
    EXPECT_FALSE(
        solar::resolve_focus_target_state_view(
            sim,
            static_cast<int>(sim.body_count() + sim.spacecraft_count()))
            .has_value());
}

TEST(BridgeStateResolverTest, MissingReferenceNamesResolveToEmptyStrings) {
    solar::Simulation sim;

    solar::MassiveBody free_body = solar::make_default_bodies()[1];
    free_body.orbit.central_body_index = -1;
    sim.add_body(std::move(free_body));

    solar::Spacecraft free_spacecraft = solar::make_default_spacecraft()[0];
    free_spacecraft.reference_body_index = -1;
    sim.add_spacecraft(std::move(free_spacecraft));

    const auto body_state = solar::resolve_body_state_view(sim, 0);
    const auto spacecraft_state = solar::resolve_spacecraft_state_view(sim, 0);

    ASSERT_TRUE(body_state.has_value());
    ASSERT_TRUE(spacecraft_state.has_value());
    EXPECT_TRUE(body_state->central_body_name.empty());
    EXPECT_TRUE(spacecraft_state->central_body_name.empty());
}

} // namespace

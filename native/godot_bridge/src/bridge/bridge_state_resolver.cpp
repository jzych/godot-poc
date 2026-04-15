#include "bridge/bridge_state_resolver.h"

namespace solar {

namespace {

std::string body_name_if_valid(const Simulation& sim, int index) {
    if (index < 0 || index >= static_cast<int>(sim.body_count())) {
        return "";
    }

    return sim.bodies()[static_cast<size_t>(index)].name;
}

} // namespace

std::optional<FocusTargetStateView> resolve_body_state_view(
    const Simulation& sim,
    int index,
    double scale) {
    if (index < 0 || index >= static_cast<int>(sim.body_count())) {
        return std::nullopt;
    }

    const auto& body = sim.bodies()[static_cast<size_t>(index)];
    return build_body_state_view(
        body,
        index,
        body_name_if_valid(sim, body.orbit.central_body_index),
        scale);
}

std::optional<FocusTargetStateView> resolve_spacecraft_state_view(
    const Simulation& sim,
    int index,
    double scale) {
    if (index < 0 || index >= static_cast<int>(sim.spacecraft_count())) {
        return std::nullopt;
    }

    const auto& spacecraft = sim.spacecraft()[static_cast<size_t>(index)];
    return build_spacecraft_state_view(
        spacecraft,
        index,
        body_name_if_valid(sim, spacecraft.reference_body_index),
        scale);
}

std::optional<FocusTargetStateView> resolve_focus_target_state_view(
    const Simulation& sim,
    int index,
    double scale) {
    const int body_count = static_cast<int>(sim.body_count());
    if (index < body_count) {
        return resolve_body_state_view(sim, index, scale);
    }

    return resolve_spacecraft_state_view(sim, index - body_count, scale);
}

} // namespace solar

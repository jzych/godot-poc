#pragma once

#include <optional>

#include "bridge/bridge_state_builder.h"
#include "simulation/simulation.h"

namespace solar {

std::optional<FocusTargetStateView> resolve_body_state_view(
    const Simulation& sim,
    int index,
    double scale = default_bridge_scale());

std::optional<FocusTargetStateView> resolve_spacecraft_state_view(
    const Simulation& sim,
    int index,
    double scale = default_bridge_scale());

std::optional<FocusTargetStateView> resolve_focus_target_state_view(
    const Simulation& sim,
    int index,
    double scale = default_bridge_scale());

} // namespace solar

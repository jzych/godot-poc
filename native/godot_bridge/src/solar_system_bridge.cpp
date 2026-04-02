#include "godot_bridge/solar_system_bridge.h"

#include <godot_cpp/core/class_db.hpp>

namespace solar {

SolarSystemBridge::SolarSystemBridge() = default;
SolarSystemBridge::~SolarSystemBridge() = default;

void SolarSystemBridge::_bind_methods() {
    godot::ClassDB::bind_method(godot::D_METHOD("is_simulation_running"), &SolarSystemBridge::is_simulation_running);
}

void SolarSystemBridge::_ready() {}

void SolarSystemBridge::_process(double delta) {}

bool SolarSystemBridge::is_simulation_running() const {
    return simulation_running_;
}

} // namespace solar

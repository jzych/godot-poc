#include "bridge/solar_system_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/vector3.hpp>

namespace solar {

SolarSystemBridge::SolarSystemBridge() = default;
SolarSystemBridge::~SolarSystemBridge() = default;

void SolarSystemBridge::_bind_methods() {
    godot::ClassDB::bind_method(godot::D_METHOD("is_simulation_running"),
                                &SolarSystemBridge::is_simulation_running);
    godot::ClassDB::bind_method(godot::D_METHOD("get_body_count"),
                                &SolarSystemBridge::get_body_count);
    godot::ClassDB::bind_method(godot::D_METHOD("get_body_state", "index"),
                                &SolarSystemBridge::get_body_state);
    godot::ClassDB::bind_method(godot::D_METHOD("get_sim_time"),
                                &SolarSystemBridge::get_sim_time);
}

void SolarSystemBridge::_ready() {
    sim_.add_body({MassiveBodyType::Sun, "Sun", 0.0, 0.0, -1,
                   {1.0f, 0.65f, 0.0f}, {}});
    sim_.add_body({MassiveBodyType::Earth, "Earth", 149597870.7, 31557600.0, 0,
                   {0.2f, 0.4f, 1.0f}, {}});
    sim_.add_body({MassiveBodyType::Moon, "Moon", 384400.0, 2360448.0, 1,
                   {0.8f, 0.8f, 0.8f}, {}});
    sim_.start();
}

void SolarSystemBridge::_process(double delta) {
    sim_.step(delta);
}

bool SolarSystemBridge::is_simulation_running() const {
    return sim_.is_running();
}

int SolarSystemBridge::get_body_count() const {
    return static_cast<int>(sim_.body_count());
}

godot::Dictionary SolarSystemBridge::get_body_state(int index) const {
    godot::Dictionary state;

    if (index < 0 || index >= static_cast<int>(sim_.body_count())) {
        return state;
    }

    const auto& body = sim_.bodies()[static_cast<size_t>(index)];

    // Convert km to display units
    double display_x = body.position_km.x / KM_PER_AU * GODOT_UNITS_PER_AU;
    double display_z = body.position_km.z / KM_PER_AU * GODOT_UNITS_PER_AU;

    // Amplify Moon's offset from its parent for visibility
    if (body.parent_index >= 0) {
        const auto& parent = sim_.bodies()[static_cast<size_t>(body.parent_index)];

        // Check if this is a satellite (parent has its own parent, i.e. Moon around Earth)
        // or just apply amplification for any body with a non-root parent
        double parent_display_x = parent.position_km.x / KM_PER_AU * GODOT_UNITS_PER_AU;
        double parent_display_z = parent.position_km.z / KM_PER_AU * GODOT_UNITS_PER_AU;

        double offset_x = display_x - parent_display_x;
        double offset_z = display_z - parent_display_z;

        if (parent.parent_index >= 0) {
            // This is a moon-like body: amplify its offset from parent
            display_x = parent_display_x + offset_x * MOON_ORBIT_DISPLAY_SCALE;
            display_z = parent_display_z + offset_z * MOON_ORBIT_DISPLAY_SCALE;
        }
    }

    state["name"] = godot::String(body.name.c_str());
    state["position"] = godot::Vector3(
        static_cast<float>(display_x),
        0.0f,
        static_cast<float>(display_z));
    state["color"] = godot::Color(body.color.r, body.color.g, body.color.b);

    return state;
}

double SolarSystemBridge::get_sim_time() const {
    return sim_.sim_time();
}

} // namespace solar

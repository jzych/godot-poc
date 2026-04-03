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
    sim_.step(0.0);
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

    const double scale = GODOT_UNITS_PER_AU / KM_PER_AU;

    state["name"] = godot::String(body.name.c_str());
    state["position"] = godot::Vector3(
        static_cast<float>(body.position_km.x * scale),
        0.0f,
        static_cast<float>(body.position_km.z * scale));
    state["color"] = godot::Color(body.color.r, body.color.g, body.color.b);

    return state;
}

double SolarSystemBridge::get_sim_time() const {
    return sim_.sim_time();
}

} // namespace solar

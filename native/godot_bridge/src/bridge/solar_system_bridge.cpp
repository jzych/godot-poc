#include "bridge/solar_system_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "time/duration_format.h"

namespace solar {

namespace {

const char* anomaly_kind_name(OrbitalAnomalyKind kind) {
    switch (kind) {
    case OrbitalAnomalyKind::MeanAnomaly:
        return "mean_anomaly";
    case OrbitalAnomalyKind::TrueAnomaly:
        return "true_anomaly";
    case OrbitalAnomalyKind::TimeOfPeriapsisPassage:
        return "time_of_periapsis_passage";
    case OrbitalAnomalyKind::None:
    default:
        return "none";
    }
}

} // namespace

SolarSystemBridge::SolarSystemBridge() = default;
SolarSystemBridge::~SolarSystemBridge() = default;

void SolarSystemBridge::_bind_methods() {
    godot::ClassDB::bind_method(godot::D_METHOD("is_simulation_running"),
                                &SolarSystemBridge::is_simulation_running);
    godot::ClassDB::bind_method(godot::D_METHOD("get_body_count"),
                                &SolarSystemBridge::get_body_count);
    godot::ClassDB::bind_method(godot::D_METHOD("get_body_state", "index"),
                                &SolarSystemBridge::get_body_state);
    godot::ClassDB::bind_method(godot::D_METHOD("format_duration_ydhms", "total_seconds"),
                                &SolarSystemBridge::format_duration_ydhms);
    godot::ClassDB::bind_method(godot::D_METHOD("get_sim_time"),
                                &SolarSystemBridge::get_sim_time);
}

void SolarSystemBridge::_ready() {
    for (auto body : make_default_bodies()) {
        sim_.add_body(std::move(body));
    }
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
    std::string central_body_name;
    if (body.orbit.central_body_index >= 0 &&
        body.orbit.central_body_index < static_cast<int>(sim_.body_count())) {
        central_body_name =
            sim_.bodies()[static_cast<size_t>(body.orbit.central_body_index)].name;
    }
    const std::string orbital_period_text =
        body.rotation.orbital_period_s > 0.0
            ? solar::format_duration_ydhms(body.rotation.orbital_period_s)
            : "";

    const double scale = GODOT_UNITS_PER_AU / KM_PER_AU;
    godot::Dictionary orbit_state;
    orbit_state["central_body_index"] = body.orbit.central_body_index;
    orbit_state["semi_major_axis_km"] = body.orbit.semi_major_axis_km;
    orbit_state["eccentricity"] = body.orbit.eccentricity;
    orbit_state["inclination_rad"] = body.orbit.inclination_rad;
    orbit_state["longitude_of_ascending_node_rad"] =
        body.orbit.longitude_of_ascending_node_rad;
    orbit_state["argument_of_periapsis_rad"] =
        body.orbit.argument_of_periapsis_rad;
    orbit_state["apoapsis_km"] = body.orbit.apoapsis_km;
    orbit_state["anomaly_kind"] = godot::String(anomaly_kind_name(body.orbit.anomaly_kind));
    orbit_state["anomaly_at_epoch"] = body.orbit.anomaly_at_epoch;

    godot::Dictionary rotation_state;
    rotation_state["rotation_speed_rad_per_s"] = body.rotation.rotation_speed_rad_per_s;
    rotation_state["axial_tilt_to_orbit_rad"] =
        body.rotation.axial_tilt_to_orbit_rad;
    rotation_state["orbital_period_seconds"] = body.rotation.orbital_period_s;

    state["name"] = godot::String(body.name.c_str());
    state["position"] = godot::Vector3(
        static_cast<float>(body.position_km.x * scale),
        static_cast<float>(body.position_km.y * scale),
        static_cast<float>(body.position_km.z * scale));
    state["color"] = godot::Color(body.color.r, body.color.g, body.color.b);
    state["central_body_name"] = godot::String(central_body_name.c_str());
    state["orbital_period_seconds"] = body.rotation.orbital_period_s;
    state["orbital_period_ydhms"] = godot::String(orbital_period_text.c_str());
    state["orbit"] = orbit_state;
    state["rotation"] = rotation_state;

    return state;
}

godot::String SolarSystemBridge::format_duration_ydhms(double total_seconds) const {
    return godot::String(solar::format_duration_ydhms(total_seconds).c_str());
}

double SolarSystemBridge::get_sim_time() const {
    return sim_.sim_time();
}

} // namespace solar

#include "bridge/solar_system_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include "bridge/bridge_state_builder.h"
#include "time/duration_format.h"

namespace solar {

namespace {

godot::Dictionary vec3_to_dictionary(const Vec3& vector) {
    godot::Dictionary result;
    result["x"] = vector.x;
    result["y"] = vector.y;
    result["z"] = vector.z;
    return result;
}

godot::Vector3 vec3_to_vector3(const Vec3& vector) {
    return godot::Vector3(
        static_cast<godot::real_t>(vector.x),
        static_cast<godot::real_t>(vector.y),
        static_cast<godot::real_t>(vector.z));
}

godot::Dictionary orbit_to_dictionary(const OrbitStateView& orbit) {
    godot::Dictionary orbit_state;
    orbit_state["central_body_index"] = orbit.central_body_index;
    orbit_state["semi_major_axis_km"] = orbit.semi_major_axis_km;
    orbit_state["eccentricity"] = orbit.eccentricity;
    orbit_state["inclination_rad"] = orbit.inclination_rad;
    orbit_state["longitude_of_ascending_node_rad"] =
        orbit.longitude_of_ascending_node_rad;
    orbit_state["argument_of_periapsis_rad"] =
        orbit.argument_of_periapsis_rad;
    orbit_state["apoapsis_km"] = orbit.apoapsis_km;
    orbit_state["anomaly_kind"] = godot::String(orbit.anomaly_kind.c_str());
    orbit_state["anomaly_at_epoch"] = orbit.anomaly_at_epoch;
    return orbit_state;
}

godot::Dictionary rotation_to_dictionary(const RotationStateView& rotation) {
    godot::Dictionary rotation_state;
    rotation_state["rotation_speed_rad_per_s"] = rotation.rotation_speed_rad_per_s;
    rotation_state["axial_tilt_to_orbit_rad"] =
        rotation.axial_tilt_to_orbit_rad;
    rotation_state["orbital_period_seconds"] = rotation.orbital_period_seconds;
    return rotation_state;
}

godot::Dictionary focus_target_state_to_dictionary(const FocusTargetStateView& state_view) {
    godot::Dictionary state;
    state["id"] = godot::String(state_view.id.c_str());
    state["name"] = godot::String(state_view.name.c_str());
    state["focus_type"] = godot::String(state_view.focus_type.c_str());
    state["radius_km"] = state_view.radius_km;
    state["framing_radius_km"] = state_view.framing_radius_km;
    state["preferred_min_distance_km"] = state_view.preferred_min_distance_km;
    state["preferred_max_distance_km"] = state_view.preferred_max_distance_km;
    state["simulation_position_km"] =
        vec3_to_dictionary(state_view.simulation_position_km);
    state["simulation_velocity_km_s"] =
        vec3_to_dictionary(state_view.simulation_velocity_km_s);
    state["position"] = vec3_to_vector3(state_view.position);
    state["color"] = godot::Color(
        state_view.color.r,
        state_view.color.g,
        state_view.color.b);
    state["source_kind"] = godot::String(state_view.source_kind.c_str());
    state["visual_shape"] = godot::String(state_view.visual_shape.c_str());
    state["visual_size_km"] = state_view.visual_size_km;
    state["render_domain_hint"] =
        godot::String(state_view.render_domain_hint.c_str());
    state["central_body_name"] =
        godot::String(state_view.central_body_name.c_str());
    state["orbital_period_seconds"] = state_view.orbital_period_seconds;
    state["orbital_period_ydhms"] =
        godot::String(state_view.orbital_period_ydhms.c_str());
    state["orbit"] = orbit_to_dictionary(state_view.orbit);
    state["rotation"] = rotation_to_dictionary(state_view.rotation);

    if (state_view.body_index >= 0) {
        state["body_index"] = state_view.body_index;
    }
    if (state_view.spacecraft_index >= 0) {
        state["spacecraft_index"] = state_view.spacecraft_index;
    }
    if (state_view.reference_body_index >= 0) {
        state["reference_body_index"] = state_view.reference_body_index;
    }

    return state;
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
    godot::ClassDB::bind_method(godot::D_METHOD("get_spacecraft_count"),
                                &SolarSystemBridge::get_spacecraft_count);
    godot::ClassDB::bind_method(godot::D_METHOD("get_spacecraft_state", "index"),
                                &SolarSystemBridge::get_spacecraft_state);
    godot::ClassDB::bind_method(godot::D_METHOD("get_focus_target_count"),
                                &SolarSystemBridge::get_focus_target_count);
    godot::ClassDB::bind_method(godot::D_METHOD("get_focus_target_state", "index"),
                                &SolarSystemBridge::get_focus_target_state);
    godot::ClassDB::bind_method(godot::D_METHOD("format_duration_ydhms", "total_seconds"),
                                &SolarSystemBridge::format_duration_ydhms);
    godot::ClassDB::bind_method(godot::D_METHOD("get_sim_time"),
                                &SolarSystemBridge::get_sim_time);
}

void SolarSystemBridge::_ready() {
    for (auto body : make_default_bodies()) {
        sim_.add_body(std::move(body));
    }
    for (auto spacecraft : make_default_spacecraft()) {
        sim_.add_spacecraft(std::move(spacecraft));
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
    if (index < 0 || index >= static_cast<int>(sim_.body_count())) {
        return {};
    }

    const auto& body = sim_.bodies()[static_cast<size_t>(index)];
    std::string central_body_name;
    if (body.orbit.central_body_index >= 0 &&
        body.orbit.central_body_index < static_cast<int>(sim_.body_count())) {
        central_body_name =
            sim_.bodies()[static_cast<size_t>(body.orbit.central_body_index)].name;
    }
    const FocusTargetStateView state_view = build_body_state_view(
        body,
        index,
        central_body_name,
        GODOT_UNITS_PER_AU / KM_PER_AU);
    return focus_target_state_to_dictionary(state_view);
}

int SolarSystemBridge::get_spacecraft_count() const {
    return static_cast<int>(sim_.spacecraft_count());
}

godot::Dictionary SolarSystemBridge::get_spacecraft_state(int index) const {
    if (index < 0 || index >= static_cast<int>(sim_.spacecraft_count())) {
        return {};
    }

    const auto& spacecraft = sim_.spacecraft()[static_cast<size_t>(index)];
    std::string reference_body_name;
    if (spacecraft.reference_body_index >= 0 &&
        spacecraft.reference_body_index < static_cast<int>(sim_.body_count())) {
        reference_body_name =
            sim_.bodies()[static_cast<size_t>(spacecraft.reference_body_index)].name;
    }
    const FocusTargetStateView state_view = build_spacecraft_state_view(
        spacecraft,
        index,
        reference_body_name,
        GODOT_UNITS_PER_AU / KM_PER_AU);
    return focus_target_state_to_dictionary(state_view);
}

int SolarSystemBridge::get_focus_target_count() const {
    return get_body_count() + get_spacecraft_count();
}

godot::Dictionary SolarSystemBridge::get_focus_target_state(int index) const {
    const int body_count = get_body_count();
    if (index < body_count) {
        return get_body_state(index);
    }

    return get_spacecraft_state(index - body_count);
}

godot::String SolarSystemBridge::format_duration_ydhms(double total_seconds) const {
    return godot::String(solar::format_duration_ydhms(total_seconds).c_str());
}

double SolarSystemBridge::get_sim_time() const {
    return sim_.sim_time();
}

} // namespace solar

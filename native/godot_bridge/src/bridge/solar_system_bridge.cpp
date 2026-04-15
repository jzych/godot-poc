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

const char* focus_target_type_name(FocusTargetType type) {
    switch (type) {
    case FocusTargetType::Star:
        return "star";
    case FocusTargetType::Planet:
        return "planet";
    case FocusTargetType::Moon:
        return "moon";
    case FocusTargetType::Spacecraft:
        return "spacecraft";
    default:
        return "unknown";
    }
}

godot::Dictionary vec3_to_dictionary(const Vec3& vector) {
    godot::Dictionary result;
    result["x"] = vector.x;
    result["y"] = vector.y;
    result["z"] = vector.z;
    return result;
}

godot::Vector3 vec3_to_units(const Vec3& vector, double scale) {
    return godot::Vector3(
        vector.x * scale,
        vector.y * scale,
        vector.z * scale);
}

godot::Dictionary make_focus_metadata(
    const std::string& id,
    FocusTargetType focus_type,
    double radius_km,
    double preferred_min_distance_km,
    double preferred_max_distance_km,
    const Vec3& position_km,
    const Vec3& velocity_km_s,
    double scale) {
    godot::Dictionary state;
    state["id"] = godot::String(id.c_str());
    state["focus_type"] = godot::String(focus_target_type_name(focus_type));
    state["radius_km"] = radius_km;
    state["framing_radius_km"] = radius_km;
    state["preferred_min_distance_km"] = preferred_min_distance_km;
    state["preferred_max_distance_km"] = preferred_max_distance_km;
    state["simulation_position_km"] = vec3_to_dictionary(position_km);
    state["simulation_velocity_km_s"] = vec3_to_dictionary(velocity_km_s);
    state["position"] = vec3_to_units(position_km, scale);
    return state;
}

godot::Dictionary orbit_to_dictionary(const OrbitParameters& orbit) {
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
    orbit_state["anomaly_kind"] = godot::String(anomaly_kind_name(orbit.anomaly_kind));
    orbit_state["anomaly_at_epoch"] = orbit.anomaly_at_epoch;
    return orbit_state;
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
    const std::string orbital_period_text =
        body.rotation.orbital_period_s > 0.0
            ? solar::format_duration_ydhms(body.rotation.orbital_period_s)
            : "";

    const double scale = GODOT_UNITS_PER_AU / KM_PER_AU;
    godot::Dictionary state = make_focus_metadata(
        body.id,
        body.focus_type,
        body.radius_km,
        body.preferred_min_distance_km,
        body.preferred_max_distance_km,
        body.position_km,
        body.velocity_km_s,
        scale);
    godot::Dictionary orbit_state = orbit_to_dictionary(body.orbit);

    godot::Dictionary rotation_state;
    rotation_state["rotation_speed_rad_per_s"] = body.rotation.rotation_speed_rad_per_s;
    rotation_state["axial_tilt_to_orbit_rad"] =
        body.rotation.axial_tilt_to_orbit_rad;
    rotation_state["orbital_period_seconds"] = body.rotation.orbital_period_s;

    state["name"] = godot::String(body.name.c_str());
    state["color"] = godot::Color(body.color.r, body.color.g, body.color.b);
    state["source_kind"] = godot::String("body");
    state["body_index"] = index;
    state["visual_shape"] = godot::String("sphere");
    state["visual_size_km"] = body.radius_km * 2.0;
    state["render_domain_hint"] =
        godot::String(body.focus_type == FocusTargetType::Star ? "far" : "mid");
    state["central_body_name"] = godot::String(central_body_name.c_str());
    state["orbital_period_seconds"] = body.rotation.orbital_period_s;
    state["orbital_period_ydhms"] = godot::String(orbital_period_text.c_str());
    state["orbit"] = orbit_state;
    state["rotation"] = rotation_state;

    return state;
}

int SolarSystemBridge::get_spacecraft_count() const {
    return static_cast<int>(sim_.spacecraft_count());
}

godot::Dictionary SolarSystemBridge::get_spacecraft_state(int index) const {
    if (index < 0 || index >= static_cast<int>(sim_.spacecraft_count())) {
        return {};
    }

    const auto& spacecraft = sim_.spacecraft()[static_cast<size_t>(index)];
    const double scale = GODOT_UNITS_PER_AU / KM_PER_AU;
    godot::Dictionary state = make_focus_metadata(
        spacecraft.id,
        FocusTargetType::Spacecraft,
        spacecraft.bounding_radius_km,
        spacecraft.preferred_min_distance_km,
        spacecraft.preferred_max_distance_km,
        spacecraft.position_km,
        spacecraft.velocity_km_s,
        scale);

    std::string reference_body_name;
    if (spacecraft.reference_body_index >= 0 &&
        spacecraft.reference_body_index < static_cast<int>(sim_.body_count())) {
        reference_body_name =
            sim_.bodies()[static_cast<size_t>(spacecraft.reference_body_index)].name;
    }

    const std::string orbital_period_text =
        spacecraft.orbital_period_s > 0.0
            ? solar::format_duration_ydhms(spacecraft.orbital_period_s)
            : "";
    godot::Dictionary orbit_state = orbit_to_dictionary(spacecraft.orbit);
    godot::Dictionary empty_rotation_state;
    empty_rotation_state["rotation_speed_rad_per_s"] = 0.0;
    empty_rotation_state["axial_tilt_to_orbit_rad"] = 0.0;
    empty_rotation_state["orbital_period_seconds"] = spacecraft.orbital_period_s;

    state["name"] = godot::String(spacecraft.name.c_str());
    state["color"] = godot::Color(spacecraft.color.r, spacecraft.color.g, spacecraft.color.b);
    state["source_kind"] = godot::String("spacecraft");
    state["spacecraft_index"] = index;
    state["reference_body_index"] = spacecraft.reference_body_index;
    state["visual_shape"] = godot::String("cube");
    state["visual_size_km"] = spacecraft.visual_size_km;
    state["render_domain_hint"] = godot::String("near");
    state["central_body_name"] = godot::String(reference_body_name.c_str());
    state["orbital_period_seconds"] = spacecraft.orbital_period_s;
    state["orbital_period_ydhms"] = godot::String(orbital_period_text.c_str());
    state["orbit"] = orbit_state;
    state["rotation"] = empty_rotation_state;

    return state;
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

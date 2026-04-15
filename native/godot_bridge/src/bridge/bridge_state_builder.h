#pragma once

#include "massive_body/massive_body.h"

#include <string>
#include <string_view>

namespace solar {

inline constexpr double DEFAULT_KM_PER_AU = 149597870.7;
inline constexpr double DEFAULT_GODOT_UNITS_PER_AU = 10000.0;

constexpr double default_bridge_scale() {
    return DEFAULT_GODOT_UNITS_PER_AU / DEFAULT_KM_PER_AU;
}

struct OrbitStateView {
    int central_body_index = -1;
    double semi_major_axis_km = 0.0;
    double eccentricity = 0.0;
    double inclination_rad = 0.0;
    double longitude_of_ascending_node_rad = 0.0;
    double argument_of_periapsis_rad = 0.0;
    double apoapsis_km = 0.0;
    std::string anomaly_kind;
    double anomaly_at_epoch = 0.0;
};

struct RotationStateView {
    double rotation_speed_rad_per_s = 0.0;
    double axial_tilt_to_orbit_rad = 0.0;
    double orbital_period_seconds = 0.0;
};

struct FocusTargetStateView {
    std::string id;
    std::string name;
    std::string focus_type;
    std::string source_kind;
    std::string visual_shape;
    std::string render_domain_hint;
    std::string central_body_name;
    std::string orbital_period_ydhms;
    Color3 color;
    double radius_km = 0.0;
    double framing_radius_km = 0.0;
    double preferred_min_distance_km = 0.0;
    double preferred_max_distance_km = 0.0;
    double visual_size_km = 0.0;
    double orbital_period_seconds = 0.0;
    int body_index = -1;
    int spacecraft_index = -1;
    int reference_body_index = -1;
    Vec3 simulation_position_km;
    Vec3 simulation_velocity_km_s;
    Vec3 position;
    OrbitStateView orbit;
    RotationStateView rotation;
};

std::string anomaly_kind_name(OrbitalAnomalyKind kind);
std::string focus_target_type_name(FocusTargetType type);

FocusTargetStateView build_body_state_view(
    const MassiveBody& body,
    int body_index,
    std::string_view central_body_name,
    double scale = default_bridge_scale());

FocusTargetStateView build_spacecraft_state_view(
    const Spacecraft& spacecraft,
    int spacecraft_index,
    std::string_view reference_body_name,
    double scale = default_bridge_scale());

} // namespace solar

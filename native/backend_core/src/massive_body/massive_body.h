#pragma once

#include <string>

namespace solar {

struct Vec3 {
    double x = 0.0;
    double y = 0.0;
    double z = 0.0;
};

struct Color3 {
    float r = 1.0f;
    float g = 1.0f;
    float b = 1.0f;
};

enum class MassiveBodyType {
    Sun,
    Earth,
    Moon,
};

enum class FocusTargetType {
    Star,
    Planet,
    Moon,
    Spacecraft,
};

enum class OrbitalAnomalyKind {
    None,
    MeanAnomaly,
    TrueAnomaly,
    TimeOfPeriapsisPassage,
};

struct OrbitParameters {
    int central_body_index = -1;
    double semi_major_axis_km = 0.0;
    double eccentricity = 0.0;
    double inclination_rad = 0.0;
    double longitude_of_ascending_node_rad = 0.0;
    double argument_of_periapsis_rad = 0.0;
    double apoapsis_km = 0.0;
    OrbitalAnomalyKind anomaly_kind = OrbitalAnomalyKind::None;
    double anomaly_at_epoch = 0.0;
};

struct RotationParameters {
    double rotation_speed_rad_per_s = 0.0;
    double axial_tilt_to_orbit_rad = 0.0;
    double orbital_period_s = 0.0;
};

struct MassiveBody {
    MassiveBodyType type{};
    FocusTargetType focus_type = FocusTargetType::Planet;
    std::string id;
    std::string name;
    OrbitParameters orbit;
    RotationParameters rotation;
    Color3 color;
    double radius_km = 1.0;
    double preferred_min_distance_km = 1.0;
    double preferred_max_distance_km = 1.0;
    Vec3 position_km;
    Vec3 velocity_km_s;
};

struct Spacecraft {
    std::string id;
    std::string name;
    int reference_body_index = -1;
    OrbitParameters orbit;
    Color3 color;
    double orbital_period_s = 0.0;
    double bounding_radius_km = 0.01;
    double visual_size_km = 0.02;
    double preferred_min_distance_km = 0.05;
    double preferred_max_distance_km = 100000.0;
    Vec3 relative_position_km;
    Vec3 relative_velocity_km_s;
    Vec3 position_km;
    Vec3 velocity_km_s;
};

} // namespace solar

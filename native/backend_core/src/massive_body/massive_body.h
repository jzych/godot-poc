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
    std::string name;
    OrbitParameters orbit;
    RotationParameters rotation;
    Color3 color;
    Vec3 position_km;
};

} // namespace solar

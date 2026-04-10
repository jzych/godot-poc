#include "massive_body/default_bodies.h"

#include <numbers>

namespace solar {

namespace {

constexpr double deg_to_rad(double degrees) {
    return degrees * std::numbers::pi / 180.0;
}

MassiveBody make_sun() {
    return MassiveBody{
        .type = MassiveBodyType::Sun,
        .focus_type = FocusTargetType::Star,
        .id = "sun",
        .name = "Sun",
        .orbit = {},
        .rotation = {},
        .color = {1.0f, 0.65f, 0.0f},
        .radius_km = 696000.0,
        .preferred_min_distance_km = 1500000.0,
        .preferred_max_distance_km = 7000000000.0,
        .position_km = {},
        .velocity_km_s = {},
    };
}

MassiveBody make_earth() {
    constexpr double semi_major_axis_km = 149597870.7;
    constexpr double eccentricity = 0.0167086;
    constexpr double orbital_period_s = 31557600.0;
    constexpr double rotation_period_s = 86164.0905;

    return MassiveBody{
        .type = MassiveBodyType::Earth,
        .focus_type = FocusTargetType::Planet,
        .id = "earth",
        .name = "Earth",
        .orbit =
            {
                .central_body_index = 0,
                .semi_major_axis_km = semi_major_axis_km,
                .eccentricity = eccentricity,
                .inclination_rad = deg_to_rad(0.00005),
                .longitude_of_ascending_node_rad = deg_to_rad(-11.26064),
                .argument_of_periapsis_rad = deg_to_rad(114.20783),
                .apoapsis_km = semi_major_axis_km * (1.0 + eccentricity),
                .anomaly_kind = OrbitalAnomalyKind::MeanAnomaly,
                .anomaly_at_epoch = deg_to_rad(357.51716),
            },
        .rotation =
            {
                .rotation_speed_rad_per_s = 2.0 * std::numbers::pi / rotation_period_s,
                .axial_tilt_to_orbit_rad = deg_to_rad(23.439281),
                .orbital_period_s = orbital_period_s,
            },
        .color = {0.2f, 0.4f, 1.0f},
        .radius_km = 6371.0,
        .preferred_min_distance_km = 15000.0,
        .preferred_max_distance_km = 50000000.0,
        .position_km = {},
        .velocity_km_s = {},
    };
}

MassiveBody make_moon() {
    constexpr double semi_major_axis_km = 384400.0;
    constexpr double eccentricity = 0.0549;
    constexpr double orbital_period_s = 2360591.5;

    return MassiveBody{
        .type = MassiveBodyType::Moon,
        .focus_type = FocusTargetType::Moon,
        .id = "moon",
        .name = "Moon",
        .orbit =
            {
                .central_body_index = 1,
                .semi_major_axis_km = semi_major_axis_km,
                .eccentricity = eccentricity,
                .inclination_rad = deg_to_rad(5.145),
                .longitude_of_ascending_node_rad = deg_to_rad(125.08),
                .argument_of_periapsis_rad = deg_to_rad(318.15),
                .apoapsis_km = semi_major_axis_km * (1.0 + eccentricity),
                .anomaly_kind = OrbitalAnomalyKind::MeanAnomaly,
                .anomaly_at_epoch = deg_to_rad(115.3654),
            },
        .rotation =
            {
                .rotation_speed_rad_per_s = 2.0 * std::numbers::pi / orbital_period_s,
                .axial_tilt_to_orbit_rad = deg_to_rad(6.68),
                .orbital_period_s = orbital_period_s,
            },
        .color = {0.8f, 0.8f, 0.8f},
        .radius_km = 1737.0,
        .preferred_min_distance_km = 4500.0,
        .preferred_max_distance_km = 2500000.0,
        .position_km = {},
        .velocity_km_s = {},
    };
}

Spacecraft make_demo_spacecraft() {
    return Spacecraft{
        .id = "demo_probe",
        .name = "Demo Probe",
        .reference_body_index = 1,
        .color = {0.95f, 0.95f, 0.75f},
        .bounding_radius_km = 0.02,
        .preferred_min_distance_km = 0.05,
        .preferred_max_distance_km = 50000.0,
        .relative_position_km = {.x = 12000.0, .y = 0.0, .z = 0.0},
        .relative_velocity_km_s = {},
        .position_km = {},
        .velocity_km_s = {},
    };
}

} // namespace

std::vector<MassiveBody> make_default_bodies() {
    return {make_sun(), make_earth(), make_moon()};
}

std::vector<Spacecraft> make_default_spacecraft() {
    return {make_demo_spacecraft()};
}

} // namespace solar

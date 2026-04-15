#include "bridge/bridge_state_builder.h"

#include "time/duration_format.h"

namespace solar {

namespace {

Vec3 scale_vec3(const Vec3& vector, double scale) {
    return Vec3{
        .x = vector.x * scale,
        .y = vector.y * scale,
        .z = vector.z * scale,
    };
}

OrbitStateView build_orbit_state_view(const OrbitParameters& orbit) {
    return OrbitStateView{
        .central_body_index = orbit.central_body_index,
        .semi_major_axis_km = orbit.semi_major_axis_km,
        .eccentricity = orbit.eccentricity,
        .inclination_rad = orbit.inclination_rad,
        .longitude_of_ascending_node_rad = orbit.longitude_of_ascending_node_rad,
        .argument_of_periapsis_rad = orbit.argument_of_periapsis_rad,
        .apoapsis_km = orbit.apoapsis_km,
        .anomaly_kind = anomaly_kind_name(orbit.anomaly_kind),
        .anomaly_at_epoch = orbit.anomaly_at_epoch,
    };
}

FocusTargetStateView build_common_state_view(
    std::string_view id,
    std::string_view name,
    FocusTargetType focus_type,
    double radius_km,
    double preferred_min_distance_km,
    double preferred_max_distance_km,
    const Vec3& position_km,
    const Vec3& velocity_km_s,
    double scale) {
    return FocusTargetStateView{
        .id = std::string(id),
        .name = std::string(name),
        .focus_type = focus_target_type_name(focus_type),
        .radius_km = radius_km,
        .framing_radius_km = radius_km,
        .preferred_min_distance_km = preferred_min_distance_km,
        .preferred_max_distance_km = preferred_max_distance_km,
        .simulation_position_km = position_km,
        .simulation_velocity_km_s = velocity_km_s,
        .position = scale_vec3(position_km, scale),
    };
}

std::string orbital_period_text(double orbital_period_seconds) {
    if (orbital_period_seconds <= 0.0) {
        return "";
    }

    return format_duration_ydhms(orbital_period_seconds);
}

} // namespace

std::string anomaly_kind_name(OrbitalAnomalyKind kind) {
    using enum OrbitalAnomalyKind;

    switch (kind) {
    case MeanAnomaly:
        return "mean_anomaly";
    case TrueAnomaly:
        return "true_anomaly";
    case TimeOfPeriapsisPassage:
        return "time_of_periapsis_passage";
    case None:
    default:
        return "none";
    }
}

std::string focus_target_type_name(FocusTargetType type) {
    using enum FocusTargetType;

    switch (type) {
    case Star:
        return "star";
    case Planet:
        return "planet";
    case Moon:
        return "moon";
    case Spacecraft:
        return "spacecraft";
    default:
        return "unknown";
    }
}

FocusTargetStateView build_body_state_view(
    const MassiveBody& body,
    int body_index,
    std::string_view central_body_name,
    double scale) {
    FocusTargetStateView state = build_common_state_view(
        body.id,
        body.name,
        body.focus_type,
        body.radius_km,
        body.preferred_min_distance_km,
        body.preferred_max_distance_km,
        body.position_km,
        body.velocity_km_s,
        scale);

    state.source_kind = "body";
    state.visual_shape = "sphere";
    state.render_domain_hint = body.focus_type == FocusTargetType::Star ? "far" : "mid";
    state.central_body_name = std::string(central_body_name);
    state.color = body.color;
    state.visual_size_km = body.radius_km * 2.0;
    state.orbital_period_seconds = body.rotation.orbital_period_s;
    state.orbital_period_ydhms = orbital_period_text(body.rotation.orbital_period_s);
    state.body_index = body_index;
    state.orbit = build_orbit_state_view(body.orbit);
    state.rotation = RotationStateView{
        .rotation_speed_rad_per_s = body.rotation.rotation_speed_rad_per_s,
        .axial_tilt_to_orbit_rad = body.rotation.axial_tilt_to_orbit_rad,
        .orbital_period_seconds = body.rotation.orbital_period_s,
    };
    return state;
}

FocusTargetStateView build_spacecraft_state_view(
    const Spacecraft& spacecraft,
    int spacecraft_index,
    std::string_view reference_body_name,
    double scale) {
    FocusTargetStateView state = build_common_state_view(
        spacecraft.id,
        spacecraft.name,
        FocusTargetType::Spacecraft,
        spacecraft.bounding_radius_km,
        spacecraft.preferred_min_distance_km,
        spacecraft.preferred_max_distance_km,
        spacecraft.position_km,
        spacecraft.velocity_km_s,
        scale);

    state.source_kind = "spacecraft";
    state.visual_shape = "cube";
    state.render_domain_hint = "near";
    state.central_body_name = std::string(reference_body_name);
    state.color = spacecraft.color;
    state.visual_size_km = spacecraft.visual_size_km;
    state.orbital_period_seconds = spacecraft.orbital_period_s;
    state.orbital_period_ydhms = orbital_period_text(spacecraft.orbital_period_s);
    state.spacecraft_index = spacecraft_index;
    state.reference_body_index = spacecraft.reference_body_index;
    state.orbit = build_orbit_state_view(spacecraft.orbit);
    state.rotation = RotationStateView{
        .rotation_speed_rad_per_s = 0.0,
        .axial_tilt_to_orbit_rad = 0.0,
        .orbital_period_seconds = spacecraft.orbital_period_s,
    };
    return state;
}

} // namespace solar

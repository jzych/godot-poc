extends RefCounted
class_name OrbitMath

const KM_PER_AU := 149597870.7
const GODOT_UNITS_PER_AU := 10000.0
const KM_TO_UNITS := GODOT_UNITS_PER_AU / KM_PER_AU
const ORBIT_SOLVER_TOLERANCE := 0.000001
const MAX_KEPLER_ITERATIONS := 12
const MIN_SAMPLE_COUNT := 192
const MAX_SAMPLE_COUNT := 1024
const TARGET_UNITS_PER_SEGMENT := 80.0

static func normalize_angle(angle_rad: float) -> float:
	angle_rad = fmod(angle_rad, TAU)
	if angle_rad < -PI:
		angle_rad += TAU
	elif angle_rad > PI:
		angle_rad -= TAU
	return angle_rad

static func normalize_angle_positive(angle_rad: float) -> float:
	angle_rad = fmod(angle_rad, TAU)
	if angle_rad < 0.0:
		angle_rad += TAU
	return angle_rad

static func true_to_mean_anomaly(true_anomaly_rad: float, eccentricity: float) -> float:
	if is_zero_approx(eccentricity):
		return normalize_angle(true_anomaly_rad)

	var eccentric_anomaly: float = 2.0 * atan2(
		sqrt(1.0 - eccentricity) * sin(true_anomaly_rad * 0.5),
		sqrt(1.0 + eccentricity) * cos(true_anomaly_rad * 0.5)
	)
	return eccentric_anomaly - eccentricity * sin(eccentric_anomaly)

static func mean_anomaly_at_time(orbit: Dictionary, orbital_period_seconds: float, sim_time_seconds: float) -> float:
	var mean_motion: float = TAU / orbital_period_seconds
	var anomaly_kind: String = str(orbit.get("anomaly_kind", "none"))
	var anomaly_at_epoch: float = float(orbit.get("anomaly_at_epoch", 0.0))

	match anomaly_kind:
		"mean_anomaly":
			return anomaly_at_epoch + (mean_motion * sim_time_seconds)
		"true_anomaly":
			return true_to_mean_anomaly(
				anomaly_at_epoch,
				float(orbit.get("eccentricity", 0.0))
			) + (mean_motion * sim_time_seconds)
		"time_of_periapsis_passage":
			return mean_motion * (sim_time_seconds - anomaly_at_epoch)
		_:
			return mean_motion * sim_time_seconds

static func solve_eccentric_anomaly(mean_anomaly_rad: float, eccentricity: float) -> float:
	if is_zero_approx(eccentricity):
		return normalize_angle(mean_anomaly_rad)

	var normalized_mean_anomaly: float = normalize_angle(mean_anomaly_rad)
	var eccentric_anomaly: float = normalized_mean_anomaly if eccentricity < 0.8 else (PI if normalized_mean_anomaly >= 0.0 else -PI)

	for _iteration in range(MAX_KEPLER_ITERATIONS):
		var residual: float = eccentric_anomaly - (eccentricity * sin(eccentric_anomaly)) - normalized_mean_anomaly
		var derivative: float = 1.0 - (eccentricity * cos(eccentric_anomaly))
		var step: float = residual / derivative
		eccentric_anomaly -= step
		if abs(step) <= ORBIT_SOLVER_TOLERANCE:
			break

	return eccentric_anomaly

static func orbit_normal(orbit: Dictionary) -> Vector3:
	var ascending_node_longitude: float = float(orbit.get("longitude_of_ascending_node_rad", 0.0))
	var inclination: float = float(orbit.get("inclination_rad", 0.0))
	var ascending_node_axis: Vector3 = Vector3(cos(ascending_node_longitude), 0.0, sin(ascending_node_longitude)).normalized()
	if ascending_node_axis.is_zero_approx():
		ascending_node_axis = Vector3.RIGHT

	return Vector3.UP.rotated(ascending_node_axis, inclination).normalized()

static func periapsis_direction(orbit: Dictionary, orbit_normal_direction: Vector3) -> Vector3:
	var ascending_node_longitude: float = float(orbit.get("longitude_of_ascending_node_rad", 0.0))
	var argument_of_periapsis: float = float(orbit.get("argument_of_periapsis_rad", 0.0))
	var ascending_node_direction: Vector3 = Vector3(cos(ascending_node_longitude), 0.0, sin(ascending_node_longitude)).normalized()
	if ascending_node_direction.is_zero_approx():
		ascending_node_direction = Vector3.RIGHT

	return ascending_node_direction.rotated(orbit_normal_direction, argument_of_periapsis).normalized()

static func semi_major_axis_km(orbit: Dictionary) -> float:
	return float(orbit.get("semi_major_axis_km", 0.0))

static func periapsis_distance_km(orbit: Dictionary) -> float:
	var semi_major_axis: float = semi_major_axis_km(orbit)
	var eccentricity: float = float(orbit.get("eccentricity", 0.0))
	return semi_major_axis * (1.0 - eccentricity)

static func apoapsis_distance_km(orbit: Dictionary) -> float:
	var semi_major_axis: float = semi_major_axis_km(orbit)
	var eccentricity: float = float(orbit.get("eccentricity", 0.0))
	return semi_major_axis * (1.0 + eccentricity)

static func periapsis_relative_position_units(orbit: Dictionary) -> Vector3:
	var orbit_normal_direction: Vector3 = orbit_normal(orbit)
	var periapsis_world_direction: Vector3 = periapsis_direction(orbit, orbit_normal_direction)
	return periapsis_world_direction * (periapsis_distance_km(orbit) * KM_TO_UNITS)

static func apoapsis_relative_position_units(orbit: Dictionary) -> Vector3:
	return -periapsis_relative_position_units(orbit).normalized() * (apoapsis_distance_km(orbit) * KM_TO_UNITS)

static func time_until_mean_anomaly(
	orbit: Dictionary,
	orbital_period_seconds: float,
	sim_time_seconds: float,
	target_mean_anomaly: float
) -> float:
	if orbital_period_seconds <= 0.0:
		return 0.0

	var current_mean_anomaly: float = normalize_angle_positive(
		mean_anomaly_at_time(orbit, orbital_period_seconds, sim_time_seconds)
	)
	var normalized_target: float = normalize_angle_positive(target_mean_anomaly)
	var delta_mean_anomaly: float = normalize_angle_positive(normalized_target - current_mean_anomaly)
	return delta_mean_anomaly / (TAU / orbital_period_seconds)

static func relative_position_units(orbit: Dictionary, orbital_period_seconds: float, sim_time_seconds: float) -> Vector3:
	var eccentricity: float = float(orbit.get("eccentricity", 0.0))
	var semi_major_axis_units: float = float(orbit.get("semi_major_axis_km", 0.0)) * KM_TO_UNITS
	var mean_anomaly: float = mean_anomaly_at_time(orbit, orbital_period_seconds, sim_time_seconds)
	var eccentric_anomaly: float = solve_eccentric_anomaly(mean_anomaly, eccentricity)
	var denominator: float = 1.0 - (eccentricity * cos(eccentric_anomaly))
	var sin_true_anomaly: float = sqrt(max(0.0, 1.0 - (eccentricity * eccentricity))) * sin(eccentric_anomaly) / denominator
	var cos_true_anomaly: float = (cos(eccentric_anomaly) - eccentricity) / denominator
	var true_anomaly: float = atan2(sin_true_anomaly, cos_true_anomaly)
	var radius_units: float = semi_major_axis_units * denominator
	var orbit_normal_direction: Vector3 = orbit_normal(orbit)
	var periapsis_world_direction: Vector3 = periapsis_direction(orbit, orbit_normal_direction)
	var tangential_direction: Vector3 = orbit_normal_direction.cross(periapsis_world_direction).normalized()

	return (
		periapsis_world_direction * (radius_units * cos(true_anomaly)) +
		tangential_direction * (radius_units * sin(true_anomaly))
	)

static func recommended_sample_count(orbit: Dictionary) -> int:
	var semi_major_axis_units: float = float(orbit.get("semi_major_axis_km", 0.0)) * KM_TO_UNITS
	var eccentricity: float = clampf(float(orbit.get("eccentricity", 0.0)), 0.0, 0.999999)
	if semi_major_axis_units <= 0.0:
		return MIN_SAMPLE_COUNT

	var semi_minor_axis_units: float = semi_major_axis_units * sqrt(max(0.0, 1.0 - (eccentricity * eccentricity)))
	var h: float = pow(semi_major_axis_units - semi_minor_axis_units, 2.0) / pow(semi_major_axis_units + semi_minor_axis_units, 2.0)
	var circumference_estimate: float = PI * (semi_major_axis_units + semi_minor_axis_units) * (
		1.0 + ((3.0 * h) / (10.0 + sqrt(max(0.000001, 4.0 - (3.0 * h)))))
	)
	var recommended: int = int(ceil(circumference_estimate / TARGET_UNITS_PER_SEGMENT))
	return maxi(MIN_SAMPLE_COUNT, mini(recommended, MAX_SAMPLE_COUNT))

static func sample_relative_positions_units(
	orbit: Dictionary,
	orbital_period_seconds: float,
	sample_count: int,
	phase_time_seconds: float = 0.0
) -> PackedVector3Array:
	var positions: PackedVector3Array = PackedVector3Array()
	if sample_count < 2 or orbital_period_seconds <= 0.0:
		return positions

	positions.resize(sample_count + 1)
	for sample_index in range(sample_count + 1):
		var t: float = float(sample_index) / float(sample_count)
		positions[sample_index] = relative_position_units(
			orbit,
			orbital_period_seconds,
			phase_time_seconds + (orbital_period_seconds * t)
		)

	return positions

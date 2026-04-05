shader_type spatial;

render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 meridian_color : source_color = vec4(0.2, 0.2, 0.2, 1.0);
uniform float emission_strength : hint_range(0.0, 4.0) = 0.45;
uniform float meridian_width : hint_range(0.001, 0.25) = 0.035;
uniform float meridian_softness : hint_range(0.001, 0.25) = 0.015;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec3 surface_normal = normalize(local_position);
	float distance_to_meridian = abs(surface_normal.x);
	float meridian_mask =
		1.0 - smoothstep(
			meridian_width,
			meridian_width + meridian_softness,
			distance_to_meridian
		);
	vec3 shaded_color = mix(base_color.rgb, meridian_color.rgb, meridian_mask);
	ALBEDO = shaded_color;
	EMISSION = shaded_color * emission_strength;
	ROUGHNESS = 1.0;
}

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.08, 0.34, 0.20);
uniform vec3 tip_color : source_color = vec3(0.24, 0.62, 0.32);
uniform float sway_speed : hint_range(0.0, 5.0) = 1.65;
uniform float sway_strength : hint_range(0.0, 1.5) = 0.28;
uniform float plant_height : hint_range(0.5, 12.0) = 4.0;

varying float v_height_ratio;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h_factor = clamp(VERTEX.y / max(plant_height, 0.5), 0.0, 1.0);
	v_height_ratio = h_factor;

	float phase = world_pos.x * 0.45 + world_pos.z * 0.35;
	float wave_x = sin(TIME * sway_speed + phase + VERTEX.y * 0.7) * sway_strength;
	float wave_z = cos(TIME * sway_speed * 0.82 + phase * 1.3 + VERTEX.y * 0.55) * sway_strength * 0.85;

	float bend = pow(h_factor, 1.35);
	VERTEX.x += wave_x * bend;
	VERTEX.z += wave_z * bend;
}

void fragment() {
	vec3 col = mix(base_color, tip_color, clamp(v_height_ratio, 0.0, 1.0));
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
	ALBEDO = col;
	ROUGHNESS = 0.65;
	SPECULAR = 0.3;
	BACKLIGHT = tip_color * 0.35;
}

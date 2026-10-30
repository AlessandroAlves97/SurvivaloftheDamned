shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 sand_light_color : source_color = vec3(0.68, 0.62, 0.46);
uniform vec3 sand_dark_color : source_color = vec3(0.42, 0.39, 0.30);
uniform vec3 rock_color : source_color = vec3(0.20, 0.24, 0.27);
uniform vec3 deep_rock_color : source_color = vec3(0.11, 0.15, 0.19);
uniform vec3 reef_moss_color : source_color = vec3(0.18, 0.38, 0.28);
uniform vec3 caustic_color : source_color = vec3(0.35, 0.78, 0.92);
uniform float caustic_strength : hint_range(0.0, 1.0) = 0.42;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * value_noise(p);
		p = p * 2.03 + vec2(17.1, 31.7);
		amp *= 0.5;
	}
	return v;
}

float caustic_pattern(vec2 uv, float t) {
	vec2 p1 = uv * 0.38 + vec2(t * 0.18, -t * 0.14);
	vec2 p2 = uv * 0.42 + vec2(-t * 0.15, t * 0.21);
	float w1 = abs(sin(p1.x * 3.1 + cos(p1.y * 2.7 + t)) + cos(p1.y * 3.4 - sin(p1.x * 2.9 - t)));
	float w2 = abs(sin(p2.x * 2.8 - cos(p2.y * 3.2 - t)) + cos(p2.y * 2.6 + sin(p2.x * 3.5 + t)));
	float c = pow(clamp(1.0 - min(w1, w2) * 0.48, 0.0, 1.0), 3.5);
	return c;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec2 xz = v_world_pos.xz;
	float n_macro = fbm(xz * 0.045);
	float n_detail = fbm(xz * 0.35);

	// Ondulações sutis de areia no fundo do mar
	float sand_ripples = sin(xz.x * 2.4 + sin(xz.y * 1.6) * 1.5 + n_detail * 2.0) * 0.5 + 0.5;
	vec3 sand_col = mix(sand_dark_color, sand_light_color, clamp(n_macro * 0.75 + sand_ripples * 0.25, 0.0, 1.0));

	// Mistura com musgo/sedimento de recife em áreas mais elevadas
	float shallow_factor = smoothstep(-21.0, -10.0, v_world_pos.y);
	float moss_mask = smoothstep(0.52, 0.78, n_macro) * shallow_factor;
	sand_col = mix(sand_col, reef_moss_color, moss_mask * 0.55);

	// Inclinação define transição entre areia e rocha submarina
	float slope = 1.0 - clamp(v_world_normal.y, 0.0, 1.0);
	float rock_mask = smoothstep(0.16, 0.42, slope + (n_detail - 0.5) * 0.14);

	// Profundezas abissais ficam mais rochosas e escuras
	float abyss_factor = smoothstep(-23.0, -34.0, v_world_pos.y);
	vec3 rk_col = mix(rock_color, deep_rock_color, clamp(abyss_factor + (1.0 - n_detail) * 0.35, 0.0, 1.0));

	vec3 base_col = mix(sand_col, rk_col, clamp(rock_mask + abyss_factor * 0.45, 0.0, 1.0));

	// Cáusticas submarinas animadas projetadas nas superfícies voltadas para cima
	float depth_attenuation = smoothstep(-34.0, -6.0, v_world_pos.y);
	float up_facing = smoothstep(0.1, 0.75, v_world_normal.y);
	float caustics = caustic_pattern(xz, TIME * 0.85) * depth_attenuation * up_facing * caustic_strength;

	ALBEDO = base_col + caustic_color * caustics;
	ROUGHNESS = mix(0.92, 0.78, rock_mask);
	SPECULAR = 0.25;
}

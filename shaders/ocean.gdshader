shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.06, 0.38, 0.48);
uniform vec3 deep_color : source_color = vec3(0.02, 0.12, 0.22);
uniform vec3 foam_color : source_color = vec3(0.75, 0.88, 0.92);
uniform float wave_height : hint_range(0.0, 2.0) = 0.25;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.2;
uniform float roughness : hint_range(0.0, 1.0) = 0.15;

varying float v_height;
varying vec3 v_world_pos;

float get_wave(vec2 pos, float time) {
	float w1 = sin(pos.x * 0.4 + time * wave_speed) * cos(pos.y * 0.3 + time * wave_speed * 0.8);
	float w2 = sin((pos.x * 0.7 - pos.y * 0.5) + time * wave_speed * 1.3) * 0.5;
	float w3 = cos(pos.x * 1.5 + pos.y * 1.2 - time * wave_speed * 1.7) * 0.25;
	return (w1 + w2 + w3) * wave_height;
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = get_wave(v_world_pos.xz, TIME);
	VERTEX.y += h;
	v_height = h;

	// Aproximação da normal das ondas por diferenças finitas
	float eps = 0.25;
	float hx = get_wave(v_world_pos.xz + vec2(eps, 0.0), TIME);
	float hz = get_wave(v_world_pos.xz + vec2(0.0, eps), TIME);
	NORMAL = normalize(vec3(h - hx, eps, h - hz));
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float crest = smoothstep(wave_height * 0.6, wave_height * 1.3, v_height);

	vec3 water_col = mix(shallow_color, deep_color, fresnel);
	water_col = mix(water_col, foam_color, crest * 0.35);

	if (!FRONT_FACING) {
		// Visão de baixo d'água olhando para a superfície
		water_col = mix(vec3(0.04, 0.28, 0.38), vec3(0.2, 0.55, 0.68), 1.0 - fresnel);
	}

	ALBEDO = water_col;
	ROUGHNESS = roughness;
	METALLIC = 0.1;
	SPECULAR = 0.7;
	ALPHA = FRONT_FACING ? 0.88 : 0.75;
}

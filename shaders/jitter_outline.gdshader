shader_type spatial;
// Based on demos/sprites paper*.gdshader + jittering outline width.
// Mesh UVs from AnimatedSprite3D are atlas-space; sample texture_albedo with UV as-is.
render_mode depth_draw_opaque, cull_disabled, depth_prepass_alpha, unshaded;

uniform sampler2D texture_albedo : source_color, filter_nearest, hint_default_white;
// Required by SpriteBase3D custom-shader contract (godot#103274).
uniform ivec2 albedo_texture_size;
// Current frame region in atlas UV space (synced from script).
uniform vec2 atlas_uv_min = vec2(0.0);
uniform vec2 atlas_uv_size = vec2(1.0);

// Outline width in UV space (atlas UV when used with AnimatedSprite3D).
uniform float outline_thickness : hint_range(0.001, 0.08) = 0.02;
// Extra jitter amount added on top of thickness.
uniform float outline_jitter : hint_range(0.0, 0.05) = 0.01;
uniform float jitter_speed : hint_range(0.0, 20.0) = 6.0;
uniform float block_size : hint_range(1.0, 64.0) = 10.0;
uniform float alpha_threshold : hint_range(0.0, 1.0) = 0.1;

// Outline look: one scrolling texture (solid color / gradient / pattern all via this).
uniform sampler2D outline_texture : source_color, filter_linear, hint_default_white;
uniform float outline_scroll_speed : hint_range(-5.0, 5.0) = 0.15;
uniform float outline_scroll_angle : hint_range(0.0, 360.0) = 45.0;
uniform vec2 outline_texture_scale = vec2(1.0);

// Scrolling noise texture used to break the outer outline (R channel).
uniform sampler2D edge_noise_texture : filter_linear, hint_default_black;
uniform vec2 edge_noise_scale = vec2(1.0);
uniform float edge_noise_speed : hint_range(0.0, 10.0) = 0.8;
uniform float edge_noise_angle : hint_range(0.0, 360.0) = 90.0;
uniform float edge_noise_threshold : hint_range(0.0, 1.0) = 0.55;
// 0 = only outer rim breaks, higher = sharper falloff toward the body.
uniform float edge_noise_power : hint_range(0.25, 4.0) = 1.5;

float hash(vec2 p, float s) {
	return fract(35.1 * sin(dot(vec3(112.3, 459.2, 753.2), vec3(p, s))));
}

float noise(vec2 p, float s) {
	vec2 d = vec2(0.0, 1.0);
	vec2 b = floor(p);
	vec2 f = fract(p);
	return mix(
		mix(hash(b + d.xx, s), hash(b + d.yx, s), f.x),
		mix(hash(b + d.xy, s), hash(b + d.yy, s), f.x),
		f.y);
}

bool in_frame(vec2 uv) {
	vec2 uv_max = atlas_uv_min + atlas_uv_size;
	return uv.x >= atlas_uv_min.x && uv.y >= atlas_uv_min.y
		&& uv.x <= uv_max.x && uv.y <= uv_max.y;
}

// Outside the current frame: treat as empty so outline cannot wrap into other atlas cells.
float sample_alpha(vec2 uv) {
	if (!in_frame(uv)) {
		return 0.0;
	}
	return texture(texture_albedo, uv).a;
}

float jittered_thickness(vec2 uv) {
	float time_step = floor(TIME * jitter_speed);
	float n = noise(uv * block_size, time_step);
	n = mix(n, noise(uv * block_size * 0.5, time_step + 17.0), 0.5);
	return outline_thickness + outline_jitter * n;
}

float sample_outline(vec2 uv, float thickness) {
	float outline = 0.0;
	outline += step(alpha_threshold, sample_alpha(uv + vec2(thickness, 0.0)));
	outline += step(alpha_threshold, sample_alpha(uv - vec2(thickness, 0.0)));
	outline += step(alpha_threshold, sample_alpha(uv + vec2(0.0, thickness)));
	outline += step(alpha_threshold, sample_alpha(uv - vec2(0.0, thickness)));
	float d = thickness * 0.7071;
	outline += step(alpha_threshold, sample_alpha(uv + vec2(d, d)));
	outline += step(alpha_threshold, sample_alpha(uv + vec2(d, -d)));
	outline += step(alpha_threshold, sample_alpha(uv + vec2(-d, d)));
	outline += step(alpha_threshold, sample_alpha(uv + vec2(-d, -d)));
	return outline;
}

void fragment() {
	vec2 uv = UV;
	// Drop fragments that leave the frame quad (prevents wrap bands on the opposite edge).
	if (!in_frame(uv)) {
		discard;
	}

	vec4 center = texture(texture_albedo, uv);
	float thickness = jittered_thickness(uv);
	float outline = sample_outline(uv, thickness);

	if (center.a < alpha_threshold && outline > 0.0) {
		// Near body ≈ 0, outer rim ≈ 1 (noise only breaks outward).
		float near_hits = sample_outline(uv, thickness * 0.35);
		float outerness = 1.0 - clamp(near_hits / max(outline, 0.001), 0.0, 1.0);
		float influence = pow(outerness, edge_noise_power);

		float noise_radians = radians(edge_noise_angle);
		vec2 noise_dir = vec2(cos(noise_radians), sin(noise_radians));
		float dissolve = texture(
			edge_noise_texture,
			fract(uv / max(edge_noise_scale, vec2(0.001)) + noise_dir * edge_noise_speed * TIME)
		).r;
		if (mix(0.0, dissolve, influence) > edge_noise_threshold) {
			discard;
		}

		float radians_angle = radians(outline_scroll_angle);
		vec2 scroll_dir = vec2(cos(radians_angle), sin(radians_angle));
		vec4 final_color = texture(
			outline_texture,
			fract(uv / max(outline_texture_scale, vec2(0.001)) + scroll_dir * outline_scroll_speed * TIME)
		);

		ALBEDO = final_color.rgb;
		ALPHA = final_color.a;
	} else {
		ALBEDO = center.rgb;
		ALPHA = center.a;
	}

	ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
}

shader_type canvas_item;
// Gaftî Modu tam ekran post-process efekti (Ajan B).
// strength = 0 iken görüntü değişmez; 1 iken tam "yayla rüyası".

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float saturation_boost : hint_range(0.0, 2.0) = 0.65;
uniform float wave_amount : hint_range(0.0, 0.05) = 0.006;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.3;
uniform float vignette_amount : hint_range(0.0, 2.0) = 0.85;
uniform float blur_amount : hint_range(0.0, 4.0) = 2.4;
uniform float chroma_amount : hint_range(0.0, 0.02) = 0.0045;
uniform vec4 tint : source_color = vec4(0.72, 1.0, 0.78, 1.0);

vec3 saturate_color(vec3 c, float amount) {
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	return mix(vec3(luma), c, 1.0 + amount);
}

// Renk tonunu yavaşça kaydırır (rüya hissi).
vec3 hue_shift(vec3 c, float angle) {
	const vec3 k = vec3(0.57735);
	float ca = cos(angle);
	return c * ca + cross(k, c) * sin(angle) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float s = clamp(strength, 0.0, 1.0);
	float t = TIME * wave_speed;

	// Hafif dalga distorsiyonu
	vec2 wave = vec2(
		sin(uv.y * 9.0 + t) + 0.5 * sin(uv.y * 23.0 - t * 1.7),
		cos(uv.x * 7.0 + t * 0.8) + 0.5 * cos(uv.x * 19.0 + t * 1.3)
	) * wave_amount * s;
	uv += wave;

	// Kenarlara doğru artan bulanıklık (mipmap seviyesi)
	vec2 centered = uv - vec2(0.5);
	float edge = smoothstep(0.18, 0.75, length(centered * vec2(1.25, 1.0)));
	float lod = edge * blur_amount * s;

	// Renk kayması (kromatik sapma) kenarlarda daha güçlü
	vec2 shift = centered * chroma_amount * s * (0.4 + edge * 1.6);
	float r = textureLod(screen_tex, uv + shift, lod).r;
	float g = textureLod(screen_tex, uv, lod).g;
	float b = textureLod(screen_tex, uv - shift, lod).b;
	vec3 col = vec3(r, g, b);

	// Doygunluk artışı + yeşilimsi rüya tonu + yavaş renk dönmesi
	col = saturate_color(col, saturation_boost * s);
	col = mix(col, col * tint.rgb * 1.08, 0.35 * s);
	col = mix(col, hue_shift(col, sin(TIME * 0.35) * 0.35), 0.5 * s);

	// Vinyet
	float vig = 1.0 - smoothstep(0.35, 0.95, length(centered)) * vignette_amount * s;
	col *= clamp(vig, 0.0, 1.0);

	COLOR = vec4(col, 1.0);
}

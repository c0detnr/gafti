shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;
// Sarma kağıdı kıvrılma shader'ı (Ajan B). curl 0..1: kağıt yakın kenardan başlayıp
// "radius" yarıçaplı bir silindir etrafında sarılır. Eksen bilgisi yerel mesh uzayındadır.

uniform float curl : hint_range(0.0, 1.0) = 0.0;
uniform float radius = 0.0045;
uniform float half_width = 0.0225;
uniform float center = 0.0;
uniform float base_y = 0.0;
uniform bool across_x = false;
uniform vec4 paper_color : source_color = vec4(0.97, 0.94, 0.86, 1.0);
uniform float glue_glow : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float a = across_x ? VERTEX.x : VERTEX.z;
	float s = (center + half_width) - a;
	float rolled = curl * half_width * 2.0;
	float y0 = VERTEX.y - base_y;
	if (s < rolled) {
		float theta = (rolled - s) / radius;
		float r = radius + theta * 0.00011 + y0;
		float u = rolled - r * sin(theta);
		float h = radius - r * cos(theta);
		float na = -sin(theta);
		float ny = cos(theta);
		if (across_x) {
			VERTEX.x = center + half_width - u;
			NORMAL = vec3(na, ny, 0.0);
		} else {
			VERTEX.z = center + half_width - u;
			NORMAL = vec3(0.0, ny, na);
		}
		VERTEX.y = base_y + h;
	}
}

void fragment() {
	// İnce kağıt lifleri
	float fiber = 0.96 + 0.04 * sin(UV.x * 420.0 + sin(UV.y * 37.0) * 3.0);
	ALBEDO = paper_color.rgb * fiber;
	ROUGHNESS = 0.8;
	EMISSION = vec3(0.3, 0.6, 1.0) * glue_glow * 0.25;
}

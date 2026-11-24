shader_type spatial;
render_mode specular_disabled;

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_vertex_color = false;
uniform float rim_strength : hint_range(0.0, 1.0) = 0.15;

void fragment() {
    vec3 pigment = texture(albedo_texture, UV).rgb * albedo_color.rgb;
    ALBEDO = use_vertex_color ? pigment * COLOR.rgb : pigment;
    ROUGHNESS = 0.86;
    float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    EMISSION = ALBEDO * rim_strength * rim;
}

void light() {
    float n = dot(NORMAL, LIGHT);
    float shade = 0.19 + 0.45 * smoothstep(-0.10, 0.12, n) + 0.36 * smoothstep(0.46, 0.68, n);
    DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * shade / PI;
}

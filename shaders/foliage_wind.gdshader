shader_type spatial;
render_mode cull_disabled;

uniform float wind_strength : hint_range(0.0, 2.0) = 0.5;
uniform float wind_speed : hint_range(0.0, 6.0) = 1.3;
uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform float thirst : hint_range(0.0, 1.0) = 0.0;
uniform float quality : hint_range(0.0, 1.0) = 0.5;
uniform vec4 leaf_color : source_color = vec4(0.37, 0.69, 0.29, 1.0);
uniform vec4 bud_color : source_color = vec4(0.48, 0.68, 0.39, 1.0);
uniform int part : hint_enum("Stem", "Leaves", "Buds") = 1;
uniform float plant_height = 1.0;

void vertex() {
    float phase = dot(MODEL_MATRIX[3].xz, vec2(0.74, 1.23)) + UV.x * 0.18;
    float wave = sin(TIME * wind_speed + phase) + 0.28 * sin(2.1 * TIME * wind_speed + phase);
    float amplitude = plant_height * COLOR.r;
    VERTEX.xz += vec2(0.031, 0.014) * wave * amplitude * wind_strength;
    VERTEX.y -= 0.16 * amplitude * thirst;
}

void fragment() {
    float paint = COLOR.g;
    vec3 pigment = mix(leaf_color.rgb * vec3(0.18, 0.29, 0.54), leaf_color.rgb * 1.18, paint);
    pigment = mix(pigment, vec3(0.46, 0.65, 0.16), COLOR.b);
    float midrib = 1.0 - smoothstep(0.0, max(0.036, fwidth(UV.x)), abs(UV.x - 0.5));
    pigment = mix(pigment, vec3(0.51,0.67,0.18), 0.63 * midrib);
    if (part == 0) {
        pigment = mix(vec3(0.12,0.13,0.038), vec3(0.42,0.52,0.13), paint);
    } else if (part == 2) {
        pigment = mix(bud_color.rgb * 0.48, mix(bud_color.rgb, vec3(0.64,0.82,0.56), quality * 0.78), paint);
        pigment = mix(pigment, vec3(0.98,0.29,0.045), COLOR.b);
    }
    ALBEDO = mix(mix(vec3(0.15,0.068,0.025), vec3(0.58,0.40,0.086), paint), pigment, health);
    ROUGHNESS = part == 2 ? 0.85 - 0.36 * quality : 0.9;
    float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
    EMISSION = ALBEDO * rim * 0.13;
}

void light() {
    float n = dot(NORMAL, LIGHT);
    float bands = 0.18 + 0.45 * smoothstep(-0.12,0.12,n) + 0.37 * smoothstep(0.45,0.69,n);
    DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR * bands / PI;
    if (part == 2) {
        float glint = pow(max(dot(NORMAL, normalize(LIGHT + VIEW)),0.0), 20.0);
        SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * glint * quality * 0.12;
    }
}

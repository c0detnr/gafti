shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 smoke_color : source_color = vec4(0.84, 0.91, 0.86, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.42;
varying float age;
varying float phase;

void vertex() {
    age = INSTANCE_CUSTOM.y;
    phase = fract(float(INSTANCE_ID) * 0.618034) * 6.283185;
    float swell = mix(0.64, 1.24, smoothstep(0.0, 0.9, age));
    vec2 size = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
    MODELVIEW_MATRIX = mat4(vec4(size.x * swell, 0.0, 0.0, 0.0),
                            vec4(0.0, size.y * swell, 0.0, 0.0),
                            vec4(0.0, 0.0, 1.0, 0.0), VIEW_MATRIX * MODEL_MATRIX[3]);
}

float hash_cell(vec2 cell) {
    vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash_cell(i), hash_cell(i + vec2(1.0, 0.0)), f.x),
               mix(hash_cell(i + vec2(0.0, 1.0)), hash_cell(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    vec2 drift = vec2(phase, age * 1.6);
    float grain = noise2d(p * 3.0 + drift);
    float radius = length(p) + 0.25 * (grain - 0.5) + 0.10 * (noise2d(p * 6.0 - drift) - 0.5);
    float density = 1.0 - smoothstep(0.44, 0.89, radius);
    float envelope = smoothstep(0.0, 0.12, age) * (1.0 - smoothstep(0.52, 1.0, age));
    ALBEDO = smoke_color.rgb * mix(0.81, 1.10, grain);
    ALPHA = density * envelope * alpha * smoke_color.a;
}

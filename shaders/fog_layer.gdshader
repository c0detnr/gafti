shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform float density : hint_range(0.0, 1.0) = 0.28;
uniform vec4 color : source_color = vec4(0.79, 0.85, 0.80, 1.0);
uniform float speed : hint_range(0.0, 2.0) = 0.22;
varying vec2 ground_position;

float hash(vec2 p) {
    vec3 q = fract(p.xyx * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
    vec2 cell = floor(p);
    vec2 t = fract(p);
    t = t*t*(3.0-2.0*t);
    return mix(mix(hash(cell), hash(cell + vec2(1,0)), t.x),
               mix(hash(cell + vec2(0,1)), hash(cell + vec2(1,1)), t.x), t.y);
}

void vertex() {
    ground_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
    vec2 p = ground_position * vec2(0.13,0.23);
    vec2 drift = vec2(TIME * speed, TIME * speed * 0.37);
    float mist = 0.72 * noise2(p - drift) + 0.28 * noise2(p * 2.3 - drift * 1.35);
    vec2 edge = min(UV, 1.0 - UV);
    ALBEDO = color.rgb;
    ALPHA = density * color.a * smoothstep(0.19, 0.84, mist) * smoothstep(0.0, 0.13, min(edge.x,edge.y));
}

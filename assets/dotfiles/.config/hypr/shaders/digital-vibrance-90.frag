#version 300 es
precision mediump float;
in vec2 v_texcoord;
layout(location = 0) out vec4 fragColor;
uniform sampler2D tex;

void main() {
    vec4 color = texture(tex, v_texcoord);
    vec3 rgb = color.rgb;

    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    float maxc = max(max(rgb.r, rgb.g), rgb.b);
    float minc = min(min(rgb.r, rgb.g), rgb.b);
    float chroma = maxc - minc;

    float saturation = 1.585;
    float vibrance = 0.315 * (1.0 - smoothstep(0.0, 0.75, chroma));
    vec3 saturated = mix(vec3(luma), rgb, saturation + vibrance);

    fragColor = vec4(clamp(saturated, 0.0, 1.0), color.a);
}

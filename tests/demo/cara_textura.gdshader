shader_type spatial;
// Cabeza con la cara del dibujo original proyectada de frente (estilo PS2) y
// degradado de piel a pelo rapado hacia la nuca.
uniform sampler2D face : source_color, filter_linear_mipmap;
uniform vec4 skin : source_color = vec4(0.89, 0.63, 0.46, 1.0);
uniform vec4 shaved : source_color = vec4(0.45, 0.33, 0.25, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 uv = vec2(0.5 - lp.x * 0.5, 0.46 - lp.y * 0.55);
	vec3 f = texture(face, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	float front = smoothstep(0.0, 0.42, -lp.z);
	vec3 back = mix(skin.rgb, shaved.rgb, smoothstep(-0.15, 0.35, lp.z) * smoothstep(-0.6, -0.1, lp.y + 0.3));
	ALBEDO = mix(back, f, front);
	ROUGHNESS = 0.65;
	SPECULAR = 0.35;
}

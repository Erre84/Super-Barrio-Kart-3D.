shader_type spatial;
// Contorno de dibujo animado (casco invertido).
render_mode unshaded, cull_front;
uniform float width = 0.014;
uniform vec4 color : source_color = vec4(0.04, 0.03, 0.05, 1.0);
void vertex() { VERTEX += normalize(NORMAL) * width; }
void fragment() { ALBEDO = color.rgb; }

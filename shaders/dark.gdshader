shader_type canvas_item;
// Le noir (Nuit d'encre, Lampe torche, Encrier renversé) : tout l'écran sauf des ronds de lumière.
// lights[i] = (x, y, rayon) en pixels de l'écran ; le bord de chaque rond est doux sur 32 px.
uniform vec4 ink : source_color;
uniform int count = 0;
uniform vec3 lights[8];
uniform vec2 screen = vec2(640.0, 360.0);

void fragment() {
	vec2 p = UV * screen;
	float lit = 0.0;
	for (int i = 0; i < count; i++) {
		float r = lights[i].z;
		lit = max(lit, 1.0 - smoothstep(r, r + 32.0, distance(p, lights[i].xy)));
	}
	COLOR = vec4(ink.rgb, ink.a * (1.0 - lit));
}

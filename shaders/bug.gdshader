shader_type canvas_item;
// Bugs de L'Écran : couleurs inversées, et une bande de l'image décalée sur le côté.
// (Posé sur un rectangle plein écran, sous le HUD : le HUD reste lisible.)

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float invert = 0.0;       // 0 = normal, 1 = négatif
uniform float band_y = 0.0;       // haut de la bande décalée (0 à 1)
uniform float band_h = 0.0;       // hauteur de la bande (0 = pas de bande)
uniform float band_shift = 0.0;   // décalage horizontal de la bande (fraction de l'écran)

void fragment() {
	vec2 uv = SCREEN_UV;
	if (band_h > 0.0 && uv.y > band_y && uv.y < band_y + band_h) {
		uv.x = fract(uv.x + band_shift);
	}
	vec3 c = texture(screen_tex, uv).rgb;
	COLOR = vec4(mix(c, vec3(1.0) - c, invert), 1.0);
}

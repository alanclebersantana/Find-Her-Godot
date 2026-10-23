shader_type canvas_item;
// Sombra projetada no chão: tudo o que é desenhado vira uma mancha escura de borda macia
// (a borda fica mais macia quanto mais longe a sombra se estende; vem pelo alfa da cor).
uniform vec4 tint : source_color = vec4(0.05, 0.04, 0.09, 1.0);
uniform float soft = 3.0;   // raio do desfoque, em pixels de tela
void fragment() {
	vec2 ux = dFdx(UV);
	vec2 uy = dFdy(UV);
	float a = texture(TEXTURE, UV).a * 0.2;
	for (int i = 0; i < 8; i++) {
		float an = float(i) * 0.785398;
		vec2 o = (ux * cos(an) + uy * sin(an)) * soft;
		a += texture(TEXTURE, UV + o).a * 0.1;
	}
	COLOR = vec4(tint.rgb, a * COLOR.a);
}

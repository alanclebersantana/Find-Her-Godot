shader_type canvas_item;
// Volume no personagem (em vez do contorno de "adesivo"): a borda virada para a luz ganha um
// brilho fino POR DENTRO do desenho e o lado oposto escurece de leve, como um corpo redondo.
uniform vec2 light_uv = vec2(-0.7, -0.7);   // de onde vem a luz, no espaço da textura
uniform vec4 rim_col : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float rim_amt = 0.32;
uniform float shade_amt = 0.30;
uniform float reach = 2.6;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (c.a > 0.02) {
		vec2 d = light_uv * TEXTURE_PIXEL_SIZE * reach;
		float al = texture(TEXTURE, UV + d).a;
		float al2 = texture(TEXTURE, UV + d * 2.0).a;
		float as1 = texture(TEXTURE, UV - d).a;
		float as2 = texture(TEXTURE, UV - d * 2.2).a;
		float rim = clamp((1.0 - al) * 0.7 + (1.0 - al2) * 0.3, 0.0, 1.0);
		float sh = clamp((1.0 - as1) * 0.5 + (1.0 - as2) * 0.5, 0.0, 1.0);
		vec3 col = c.rgb;
		col = mix(col, col * vec3(0.58, 0.6, 0.7), sh * shade_amt);
		col += rim_col.rgb * rim * rim_amt * c.a;
		c.rgb = col;
	}
	COLOR = c * COLOR;
}

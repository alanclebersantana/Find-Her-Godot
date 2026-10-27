shader_type canvas_item;
render_mode blend_premul_alpha;
// Contorno de desenho animado em volta de tudo o que é do mundo (cenário fixo, objetos, bichos, o Tomé),
// sem o plano de fundo: o mundo é desenhado numa tela à parte com fundo transparente; aqui o recorte
// (alfa) é engordado alguns pixels e a borda nova vira um traço quase preto POR BAIXO do desenho.
// A borda sai lisa (sem serrilhado): o alfa lido com filtro linear e um smoothstep fazem a rampa.
// A cor que chega já é "pré-multiplicada" (é assim que o desenho fica numa tela transparente).
uniform float px = 2.2;          // espessura do traço, em pixels desta tela
uniform vec4 line_col : source_color = vec4(0.045, 0.03, 0.025, 1.0);
uniform float amt = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (amt > 0.0 && c.a < 0.985) {
		vec2 o = TEXTURE_PIXEL_SIZE * px;
		float m = c.a;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.5235988;
			vec2 d = vec2(cos(a), sin(a)) * o;
			m = max(m, texture(TEXTURE, UV + d).a);
			if (i % 2 == 1) {
				m = max(m, texture(TEXTURE, UV + d * 0.5).a);
			}
		}
		// só onde a vizinhança é bem mais cheia que o ponto: não escurece o miolo da água, da névoa etc.
		float e = smoothstep(0.2, 0.7, m) * smoothstep(0.05, 0.3, m - c.a + 0.05) * amt;
		c.rgb += line_col.rgb * line_col.a * e * (1.0 - c.a);
		c.a += line_col.a * e * (1.0 - c.a);
	}
	COLOR = c;
}

shader_type canvas_item;
render_mode blend_premul_alpha;
// Contorno de desenho animado em volta de tudo o que é do mundo (cenário fixo, objetos, bichos, o Tomé),
// sem o plano de fundo: o mundo é desenhado numa tela à parte com fundo transparente; aqui o recorte
// (alfa) é engordado alguns pixels e a borda nova vira um traço PRETO e cheio POR BAIXO do desenho.
// Borda lisa: em vez de pegar só o maior alfa da vizinhança (que copia os degraus do recorte), mede
// QUANTO de dois anéis em volta do ponto cai dentro do desenho — a média suaviza os degraus e a beira
// externa do traço sai numa rampa curta (~1 px), sem serrilhado e sem ficar fraca.
// A cor que chega já é "pré-multiplicada" (é assim que o desenho fica numa tela transparente).
uniform float px = 2.2;          // espessura do traço, em pixels desta tela
uniform vec4 line_col : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float amt = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (amt > 0.0 && c.a < 0.985) {
		vec2 o = TEXTURE_PIXEL_SIZE * px;
		float s1 = 0.0;   // anel de fora (raio = espessura)
		float s2 = 0.0;   // anel de dentro (meia espessura)
		float mx = c.a;
		for (int i = 0; i < 16; i++) {
			float a = float(i) * 0.3926991;
			vec2 d = vec2(cos(a), sin(a)) * o;
			float a1 = texture(TEXTURE, UV + d).a;
			s1 += a1;
			mx = max(mx, a1);
			if (i % 2 == 0) {
				float a2 = texture(TEXTURE, UV + d * 0.55).a;
				s2 += a2;
				mx = max(mx, a2);
			}
		}
		s1 /= 16.0;
		s2 /= 8.0;
		// cobertura: perto do desenho o anel de dentro já cai quase todo nele (traço cheio); na beira de
		// fora só um pedacinho do anel de fora encosta (rampa curta = borda lisa)
		float cov = clamp(max(s1 * 6.0, s2 * 3.0), 0.0, 1.0);
		cov = smoothstep(0.0, 1.0, cov);
		// só onde a vizinhança é bem mais cheia que o ponto: não escurece o miolo da água, da névoa etc.
		float e = cov * smoothstep(0.05, 0.3, mx - c.a + 0.05) * amt;
		c.rgb = c.rgb + line_col.rgb * line_col.a * e * (1.0 - c.a);
		c.a = c.a + line_col.a * e * (1.0 - c.a);
	}
	COLOR = c;
}

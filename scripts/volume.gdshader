shader_type canvas_item;
// Volume de verdade nos personagens pintados (aparência 3D):
// - forma: a silhueta vira um "travesseiro" (normais calculadas pela distância até a borda, em pixels
//   de TELA, então funciona em qualquer escala, espelhado ou girado);
// - relevo: as linhas e dobras da pintura viram pequenos relevos (normal pela variação de brilho);
// - luz: difusa com a cor da luz, sombra própria na cor do ambiente, brilho especular suave,
//   contraluz na borda oposta e oclusão (fica mais escuro embaixo e nas reentrâncias).
// Partes sem textura (polígonos) e brilhos suaves (alfa baixo) ficam como estão.
uniform vec3 light_dir = vec3(-0.55, -0.75, 0.62); // de onde vem a luz (tela: x direita, y para baixo, z para fora)
uniform vec4 light_col : source_color = vec4(1.0, 0.96, 0.86, 1.0);
uniform vec4 shade_col : source_color = vec4(0.42, 0.48, 0.66, 1.0); // cor da sombra própria (céu/ambiente)
uniform vec4 rim_col : source_color = vec4(1.0, 0.92, 0.72, 1.0);
uniform float strength = 1.0;   // 0 = desligado
uniform float radius = 7.0;     // largura do arredondado, em pixels de tela
uniform float bump = 0.5;       // relevo da pintura
uniform float diffuse = 0.75;
uniform float spec = 0.22;
uniform float rim = 0.55;
uniform float ao = 0.35;
// luz de ponto (lanterna do Tomé à noite / no escuro): a direção sai da lanterna até cada pixel
uniform vec2 lamp_px = vec2(640.0, 360.0);  // posição da lanterna na tela (pixels)
uniform float lamp_mix = 0.0;               // 0 = sol, 1 = lanterna

float A(sampler2D tx, vec2 uv) { return texture(tx, uv).a; }
float L(sampler2D tx, vec2 uv) { vec4 t = texture(tx, uv); return dot(t.rgb, vec3(0.3, 0.55, 0.15)) * t.a; }

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 ux = dFdx(UV);
	vec2 uy = dFdy(UV);
	// contorno e linhas escuras da pintura ficam intactos (a luz só age na cor)
	float lum0 = dot(c.rgb, vec3(0.3, 0.55, 0.15));
	float w = smoothstep(0.55, 0.98, c.a) * smoothstep(0.1, 0.32, lum0) * strength;
	if (w > 0.001 && length(ux) + length(uy) > 0.0) {
		// gradiente da silhueta (aponta para dentro do desenho), em dois anéis
		vec2 g = vec2(0.0);
		float cov = 0.0;
		for (int i = 0; i < 12; i++) {
			float a = float(i) * 0.523599;
			vec2 d = vec2(cos(a), sin(a));
			vec2 o = ux * d.x + uy * d.y;
			float s1 = A(TEXTURE, UV + o * radius);
			float s2 = A(TEXTURE, UV + o * radius * 0.55);
			float s3 = A(TEXTURE, UV + o * radius * 0.25);
			g += d * (s1 * 0.45 + s2 * 0.35 + s3 * 0.2);
			cov += s1 * 0.45 + s2 * 0.35 + s3 * 0.2;
		}
		g *= 8.0 / 12.0;
		cov /= 12.0;
		// relevo da pintura (variação de brilho a 1,5 px)
		float lx = L(TEXTURE, UV + ux * 1.5) - L(TEXTURE, UV - ux * 1.5);
		float ly = L(TEXTURE, UV + uy * 1.5) - L(TEXTURE, UV - uy * 1.5);
		vec3 n = normalize(vec3(-g.x * 0.6 - lx * bump, -g.y * 0.6 - ly * bump, 1.0));
		vec3 l = normalize(light_dir);
		if (lamp_mix > 0.0) {
			vec2 to = lamp_px - FRAGCOORD.xy;
			float dl = length(to);
			vec3 lp = normalize(vec3(to / max(dl, 1.0), clamp(60.0 / max(dl, 1.0), 0.35, 1.2)));
			l = normalize(mix(l, lp, lamp_mix));
		}
		float nd = max(dot(n, l), 0.0);
		float flat_nd = l.z;
		// difusa normalizada: superfície de frente para a câmera fica com a cor original
		float lit = mix(1.0, (0.55 + diffuse * nd) / (0.55 + diffuse * flat_nd), 1.0);
		vec3 col = c.rgb;
		vec3 shadow_tint = mix(vec3(1.0), shade_col.rgb, clamp(1.0 - lit, 0.0, 1.0) * 1.6);
		vec3 light_tint = mix(vec3(1.0), light_col.rgb, clamp(lit - 1.0, 0.0, 1.0) * 2.0);
		col = col * lit * shadow_tint * light_tint;
		// especular (mais forte nas partes claras/lisas)
		vec3 h = normalize(l + vec3(0.0, 0.0, 1.0));
		float sp = pow(max(dot(n, h), 0.0), 24.0) * spec * (0.4 + 0.6 * L(TEXTURE, UV));
		col += light_col.rgb * sp;
		// contraluz: borda do lado oposto à luz
		float edge = clamp(1.0 - n.z, 0.0, 1.0);
		float back = max(dot(normalize(vec2(n.x, n.y) + 1e-4), -normalize(l.xy)), 0.0);
		col += rim_col.rgb * edge * back * rim * 0.6;
		// oclusão: reentrâncias e a parte de baixo do corpo
		float occ = clamp(1.0 - cov, 0.0, 1.0);
		col *= 1.0 - ao * occ * max(n.y, 0.0) * 1.4;
		c.rgb = mix(c.rgb, col, w);
	}
	COLOR = c * COLOR;
}

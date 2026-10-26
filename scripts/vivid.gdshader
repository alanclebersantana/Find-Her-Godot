shader_type canvas_item;
// Acerto final de cor do mundo (por cima do cenário, da luz e dos efeitos; o HUD fica fora):
// cores mais saturadas e vivas, contraste um pouco maior, contornos escuros reforçados e luz de sol
// quente nos realces. Uma leitura da tela (mais 4 vizinhos para o contorno, só na qualidade alta).
uniform sampler2D scr : hint_screen_texture, filter_linear;
uniform float sat = 1.3;        // saturação geral
uniform float vib = 0.58;       // a mais nas cores apagadas (céu, água, folhagem cinzenta)
uniform float contrast = 1.1;
uniform float bright = 1.04;
uniform float lift = 0.015;     // sombras um tiquinho mais abertas (nada fica "lavado" de preto)
uniform float edge = 1.7;       // força do reforço dos contornos (0 = desligado)
uniform float px = 1.5;         // espessura da amostra do contorno, em pixels da tela
uniform float warm = 0.05;      // luz quente nos realces (sol); de noite cai para ~0
uniform float glow_sat = 0.25;  // luzes (lanterna, fogo, cristais) mais coloridas

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 c = texture(scr, SCREEN_UV).rgb;
	if (edge > 0.0) {
		vec2 o = SCREEN_PIXEL_SIZE * px;
		vec3 n = texture(scr, SCREEN_UV + vec2(o.x, 0.0)).rgb + texture(scr, SCREEN_UV - vec2(o.x, 0.0)).rgb
			+ texture(scr, SCREEN_UV + vec2(0.0, o.y)).rgb + texture(scr, SCREEN_UV - vec2(0.0, o.y)).rgb;
		// só escurece o que já é traço (pixel mais escuro que a vizinhança): o contorno aparece firme
		float d = luma(n * 0.25) - luma(c);
		c *= 1.0 - clamp(d * edge, 0.0, 0.55);
	}
	float L = luma(c);
	float mx = max(c.r, max(c.g, c.b));
	float s = mx - min(c.r, min(c.g, c.b));
	// saturação + "vibrance": as cores já fortes sobem pouco (pele não fica laranja), as apagadas sobem mais
	float k = sat + vib * (1.0 - s) * (1.0 - s);
	// luzes brilhantes e coloridas (chama, cristal, vaga-lume) ganham ainda mais cor
	k += glow_sat * smoothstep(0.7, 1.0, mx) * smoothstep(0.15, 0.5, s);
	c = mix(vec3(L), c, k);
	c = (c - 0.5) * contrast + 0.5;
	c = c * bright + lift;
	// sol: realces puxam para o dourado, sombras para um azul bem leve (luz viva, não cinza)
	float L2 = luma(c);
	c += warm * vec3(1.0, 0.62, 0.18) * smoothstep(0.55, 1.0, L2);
	c -= warm * 0.35 * vec3(0.3, 0.12, -0.2) * (1.0 - smoothstep(0.05, 0.4, L2));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}

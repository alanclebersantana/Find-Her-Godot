# Prompts das artes novas (opcionais)

O jogo já funciona sem elas: o Pipoca usa o desenho antigo do cachorro, e a toupeira, o morcego e a aranha
são desenhados por código. Quando você gerar uma destas artes e colocar o arquivo na pasta indicada, o jogo
passa a usá-la sozinho (não precisa mexer em código).

**Regras para todas as folhas de sprites** (`assets/sprites/novos/`):
- PNG com fundo transparente.
- Uma linha só, com quadros **quadrados e do mesmo tamanho** (ex.: 256×256 cada), na ordem pedida.
- Personagem virado para a **direita**, de corpo inteiro, **pés/barriga tocando a base do quadro**, centralizado,
  mesma escala em todos os quadros. Sem sombra no chão, sem texto, sem bordas.
- Mande junto uma imagem do jogo como referência de estilo (por exemplo `assets/sprites/javali.png` e o Tomé
  em `assets/sprites/pai.png`).

## Estilo base (cole no começo de cada pedido)
> 2D side-scrolling platformer sprite sheet, hand-drawn cartoon style with clean dark brown outlines, soft cel
> shading and warm storybook colors, matching the reference images exactly (same line weight, palette and
> proportions). Transparent background. One single horizontal row of N square frames of equal size, the
> character centered in each frame, facing RIGHT, feet touching the bottom edge, same scale in every frame,
> no ground shadow, no text, no borders.

---

## 1. Pipoca, o cachorro — `assets/sprites/novos/pipoca.png` (14 quadros)
> Character: "Pipoca", a small scruffy mixed-breed stray dog, light brown fur with darker patches, one floppy ear
> and one standing ear, a frayed rope collar, big friendly eyes, happy expression (NOT angry). N = 14 frames:
> 1–6 running loop (seamless), 7–8 sitting and panting (tongue out, tail wagging), 9–10 barking (mouth open,
> ears up), 11–12 digging with front paws (head low, dirt flying behind), 13 trotting while carrying a folded
> paper drawing in his mouth, 14 sad and tied (sitting, ears down, rope tight).

## 2. Toupeira — `assets/sprites/novos/toupeira.png` (6 quadros)
> Character: a chubby cartoon mole, gray-purple velvety fur, pink nose and pink claws, tiny squinting eyes,
> mischievous grin. N = 6 frames: 1 only a small dirt mound with a pink nose peeking out, 2 head and shoulders
> coming out of a dirt hole (dirt crumbs flying), 3 half out of the hole looking around, 4 fully out standing
> on the hole, 5 throwing a dirt clod overhand (clod in the raised paw), 6 lying on its back belly-up, dizzy,
> with swirly eyes.

## 3. Toupeira de capacete — `assets/sprites/novos/toupeira_capacete.png` (6 quadros)
> Same mole and same 6 poses as above, but wearing a too-big yellow miner's helmet with a small lamp. In frame 6
> (dizzy, belly-up) the helmet has fallen off and lies next to it.

## 4. Morcego — `assets/sprites/novos/morcego.png` (5 quadros)
> Character: a small cute cave bat, purple-brown body, big ears, tiny fangs, yellow eyes, membrane wings.
> N = 5 frames: 1 sleeping upside down hanging from the top edge of the frame, wings wrapped around the body
> (this frame is the only one anchored to the TOP), 2–5 flying flap loop (wings up, mid, down, mid), seen from
> the side.

## 5. Aranha — `assets/sprites/novos/aranha.png` (4 quadros)
> Character: a round cartoon spider, dark purple body with a lighter spot, big shiny eyes, eight thin bent legs,
> more funny than scary. N = 4 frames: 1–2 idle (legs slightly moving), 3–4 legs wiggling fast (going up/down a
> thread). Draw the spider without the thread (the game draws the thread).

---

## Ilustrações das cenas (opcionais) — `assets/ui/`
Formato paisagem 16:9 (por exemplo 1920×1080), JPG, mesmo estilo de livro ilustrado de `assets/ui/cena1.jpg`.
Elas aparecem por alguns segundos no meio das cenas dramáticas.

- **`cena_javali.jpg`**: "A gigantic angry wild boar king with huge curved tusks and a small crown of leaves
  leaping down from a rocky cliff at sunset into a forest clearing, dust and leaves flying, low dramatic camera
  angle, a tiny old gnome miner with a lantern in the foreground looking up in fear, warm orange and purple sky."
- **`cena_vargas.jpg`**: "Night, stormy sky with lightning, a sly mustached mine manager in a brown miner's helmet
  (Ademar Vargas, see reference) pushing a mine cart along rails toward a lit mine entrance, a little girl with
  pink dress and pigtails inside the cart reaching back and shouting, rain, dramatic blue and orange lighting."
- **`cena_cao.jpg`**: "A kind old gnome miner kneeling and cutting a rope tied to a small scruffy stray dog on a
  rocky hilltop at golden hour, the dog licking his face happily, warm emotional moment, soft light."

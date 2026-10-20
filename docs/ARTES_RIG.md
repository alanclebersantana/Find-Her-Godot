# Artes no estilo Oddmar — prompts completos

O jogo já está pronto para receber estas artes: é só colocar cada arquivo **com o nome exato** na pasta
indicada e mandar para o GitHub (ou me mandar as imagens aqui no chat que eu coloco e ajusto). Enquanto
uma arte não existir, o jogo continua usando a arte atual.

Dica para o Gemini (ou outro gerador): gere **primeiro a ficha do personagem** (passo 1) e mande essa
imagem junto em todos os pedidos seguintes, dizendo "same character as the attached reference".

---

## Estilo base (cole no começo de TODOS os pedidos)

> Premium 2D mobile platformer art in the style of games like Oddmar: rich hand-painted textures, soft
> painterly shading with strong rim light, thick but clean dark outlines, saturated warm storybook colors,
> chunky appealing proportions, high detail, crisp edges. No text, no watermark.

---

## 1. Ficha do Tomé (referência) — não vai para o jogo, serve de modelo

> Character design turnaround sheet of "Tomé", an old gnome miner, about 3 heads tall: big green pointed
> felt hat with a white pompom, rosy round nose, bushy white eyebrows and a long fluffy white beard,
> brown leather work coat with brass buttons and patched elbows, green-and-cream striped scarf, dark
> trousers, big brown boots, holding a brass oil lantern with a warm flame in his right hand. Kind but
> determined expression. Show: side view facing right, front view, back view, all standing, same scale,
> on a plain light gray background.

---

## 2. Tomé em peças (para a animação por ossos) — pasta `assets/rig/tome/`

**Regras para todas as peças** (escreva no fim de cada pedido):
> Single isolated body part of the same character as the attached reference, side view facing RIGHT,
> drawn at the same scale as if the whole character were 1000 pixels tall, centered on a transparent
> background (PNG with alpha), nothing else in the image, no shadow. Draw the hidden joint area fully
> (overlapping part), because it will be rotated in animation.

| arquivo | pedido (depois do estilo base) |
|---|---|
| `cabeca.png` | "Only the HEAD of Tomé: pointed green hat with pompom, face, eyebrows, nose, and the full white beard. No neck, no body. The bottom of the beard is the bottom of the image." |
| `tronco.png` | "Only the TORSO of Tomé: brown leather coat with buttons and the striped scarf around the neck, from the neck down to the hips, WITHOUT arms, WITHOUT head and WITHOUT legs. The shoulders end in round coat seams." |
| `braco_frente.png` | "Only the FRONT ARM of Tomé, hanging straight down: coat sleeve from the shoulder to the hand, the hand closed in a loose fist (as if holding a lantern handle). The shoulder is at the top of the image, the hand at the bottom." |
| `braco_tras.png` | "Only the BACK ARM of Tomé, hanging straight down, slightly darker (it is behind the body): coat sleeve from shoulder to hand, hand closed in a fist. Shoulder at the top, hand at the bottom." |
| `perna_frente.png` | "Only the FRONT LEG of Tomé, standing straight: dark trouser leg from the hip to a big brown boot, boot pointing right. Hip at the top, sole of the boot at the bottom." |
| `perna_tras.png` | "Only the BACK LEG of Tomé, standing straight, slightly darker than the front leg: trouser leg and big brown boot pointing right. Hip at the top, sole at the bottom." |
| `lanterna.png` | "Only the brass OIL LANTERN, hanging from its handle, warm glowing flame inside, glass panes with light reflections. Handle at the top of the image." |
| `picareta.png` | "Only a miner's PICKAXE, standing vertically with the wooden handle pointing DOWN and the iron head at the top, old and worn, iron head slightly chipped." |

Se alguma peça ficar com o ponto de encaixe (ombro, quadril, pescoço) um pouco fora do lugar, me mande as
imagens que eu ajusto no arquivo `assets/rig/tome/rig.json` — você não precisa mexer em nada.

---

## 3. Cenários em camadas (paralaxe) — pastas `assets/bg/<trecho>/`

Cada trecho tem 4 camadas. **Todas** em formato bem largo, **3840 × 1080 px**, e devem **emendar
perfeitamente na horizontal** (a borda esquerda continua a borda direita). As camadas 2, 3 e 4 têm
**fundo transparente** (PNG); a 1 é o céu inteiro (JPG).

Escreva no fim de cada pedido:
> Seamless horizontally tileable panorama, 3840x1080, side-scrolling game background layer, no characters,
> no text. (Para as camadas 2, 3 e 4:) Transparent background above the shapes (PNG with alpha), the
> shapes rest on the bottom of the image.

| trecho (pasta) | `1_ceu.jpg` | `2_longe.png` | `3_meio.png` | `4_perto.png` |
|---|---|---|---|---|
| **bosque** (manhã) | "Bright morning sky, soft clouds, warm sunlight rays from the upper left." | "Distant misty blue-green hills and far forest silhouettes, atmospheric perspective." | "Mid-distance forest: big round-canopy trees, mossy trunks, sunbeams, a wooden cabin roof far away." | "Near forest edge: tall tree trunks with roots, ferns, mushrooms and flowers, darker and more detailed." |
| **tarde** | "Golden-orange sunset sky with purple clouds, low warm sun." | "Distant hills and far trees as warm purple silhouettes." | "Autumn forest in golden light, trees with orange leaves, falling leaves." | "Near trunks, autumn bushes and rocks in warm backlight with strong rim light." |
| **pantano** (pântano com chuva) | "Overcast rainy gray-green sky, heavy clouds." | "Distant swamp: dead trees and mist, very desaturated." | "Swamp trees with hanging moss, twisted roots over dark water, fog." | "Near swamp: big twisted roots, cattails, hanging vines, very dark and wet." |
| **noite** | "Deep blue night sky, crescent moon, stars, faint aurora of fireflies." | "Distant dark rocky hills and a mine entrance far away with tiny warm lights." | "Night forest with blue moonlight, big rocks, wooden mine structures, fireflies." | "Near night forest: dark trunks and rocks with cold blue rim light." |

Quando as 4 camadas de um trecho estiverem na pasta, o jogo troca o cenário antigo pelas camadas.

---

## 4. Outras artes

As folhas de quadros do Pipoca, da toupeira, do morcego e da aranha, e as ilustrações das cenas, estão em
`docs/ARTES_NOVAS.md` — use o mesmo **estilo base** acima no lugar do estilo antigo daquele arquivo, para
ficar tudo no visual novo.

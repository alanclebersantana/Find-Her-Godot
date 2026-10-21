# Prompts para gerar as animações do Tomé (Gemini / outro gerador de imagem)

Mande junto a imagem de referência do Tomé (`assets/sprites/pai.png`, o primeiro quadro) para manter o
mesmo personagem. Gere uma folha por vez. Depois, se precisar, recorte/alinhe e salve em
`assets/sprites/tome/<nome>.png` (veja o LEIA-ME de lá).

## Prompt base (cole antes de cada pedido)
> Sprite sheet for a 2D side-scrolling platformer, hand-drawn cartoon style matching the reference image
> exactly: an elderly human miner named Tomé (not a gnome: round human ears, human proportions) with a green knitted beanie, long white beard, brown jacket, green
> scarf, holding a lit brass lantern in his front hand. Facing RIGHT, full body, side view.
> One single horizontal row of N square frames of equal size, transparent background (PNG with alpha),
> the character centered in each frame with his feet touching the bottom edge of the frame, same scale
> and same position in every frame, no shadows on the ground, no text, no frame borders, no motion lines.
> Consistent colors, line thickness and proportions across all frames.

## Pedidos
1. **idle.png — N = 8**: "Idle breathing loop: chest rises and falls gently, beard sways slightly, lantern
   swings a little, one blink on frame 5. Loops seamlessly from the last frame back to the first."
2. **walk.png — N = 12**: "Walk cycle loop: contact, down, passing, up for each leg (12 frames total), arms
   swing opposite to legs, the lantern hand swings forward and back, hat tip bounces slightly. Seamless loop."
3. **run.png — N = 8**: "Run cycle loop: leaning forward, long strides, both feet off the ground on frames 3
   and 7, lantern held forward, beard blown back. Seamless loop."
4. **jump.png — N = 4**: "Jump rising: 1 crouch push-off, 2 leaving ground with legs extended, 3 rising with
   knees tucked, 4 apex with arms slightly open."
5. **fall.png — N = 4**: "Falling: 1 just after apex, 2 starting to fall with beard and hat lifting, 3 falling
   with legs reaching down, 4 fast fall bracing for landing."
6. **land.png — N = 3**: "Landing: 1 feet touch with knees bent deeply (squash), 2 recovering, 3 standing."

Dica: se o gerador não acertar o alinhamento, peça cada quadro separado e monte a linha no
https://www.piskelapp.com/ ou num editor de imagem (todos com o mesmo tamanho).

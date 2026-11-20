# All the Above — O Planeta dos Colossos (protótipo)

Jogo de ação em 3D (Godot 4.6, Android): a nave do Tomé caiu num planeta de colossos alienígenas.
A picareta presa numa corda vira gancho: balança nas árvores gigantes, voa até o pelo dos colossos,
escala com a barra de agarre e arranca as peças da nave cravadas nos pontos fracos.

Protótipo 1: um pedaço do vale, o Chifrudo de Musgo (3 pontos fracos: joelho, nuca, testa) e três
alienígenas pequenos (caranguejo, morcego-água-viva, saltador). Tudo feito de formas simples por código;
a arte final (modelos 3D) vem depois.

- `scripts/main.gd` monta tudo · `world.gd` vale · `player.gd` Tomé (gancho, escalada) · `colossus.gd` colosso
- `tests/proto_test.gd` teste automático · `tests/shots.gd` capturas de tela
- APK: `.github/workflows/ata.yml` (versões `ata-N` na página de versões)

Controles: joystick à esquerda, arrastar à direita gira a câmera, botões GANCHO / PULAR / AGARRAR / PICARETA.
Teclado: WASD, Espaço pula, E/Shift gancho, Q/Ctrl agarrar, F picareta, I J K L câmera.
Controle: analógicos, A pula, X picareta, RB/RT gancho, LB/LT agarrar.

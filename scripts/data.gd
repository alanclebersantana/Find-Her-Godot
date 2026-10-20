class_name GameData
## Textos e regras fixas da Fase 1 (mochila, receitas, pistas, lápis).

const ITEM_INFO := {
	"corda": ["Corda", "🪢"], "gancho": ["Gancho de ferro", "🪝"], "gancho_corda": ["Gancho com corda", "🪝"],
	"engrenagem": ["Engrenagem", "⚙️"], "manivela_q": ["Manivela quebrada", "🔩"], "manivela": ["Manivela", "🔧"],
	"pavio": ["Pavio", "🧵"], "oleo": ["Lata de óleo", "🛢️"], "lanterna_acesa": ["Lanterna acesa", "🏮"],
}
const RECIPES := [
	["corda", "gancho", "gancho_corda", "Você amarrou a corda no gancho!"],
	["engrenagem", "manivela_q", "manivela", "A engrenagem encaixou: a manivela está consertada!"],
	["oleo", "pavio", "lanterna_acesa", "Óleo e pavio novo: a lanterna acendeu de novo!"],
]
const CLUE_INFO := {
	1: ["Um botão de uniforme", "Caído na varanda, ao lado dos lápis da Lia: um botão com o símbolo da picareta. É do uniforme da mina... mas não é meu."],
	2: ["Pegada de bota", "Uma pegada funda, com lama vermelha. Só existe lama dessa cor num lugar: lá embaixo, na mina."],
	3: ["Bilhete rasgado", "\"...ele nunca mais vai me denunciar ao patrão...\" Alguém escreveu isso com raiva. Eu denunciei os roubos da mina mês passado."],
	4: ["Páginas do livro-caixa", "As contas da mina, com números riscados e refeitos. Os roubos! Só o gerente mexia nesse livro."],
	5: ["Chaveiro com a letra V", "Um chaveiro de couro gravado com um V. As chaves do depósito da mina."],
	6: ["O crachá", "\"ADEMAR VARGAS — GERENTE\". Foi ele. Ele levou a Lia para se vingar de mim. E está indo para a mina."],
}
const PEN_LIST := ["vermelho", "laranja", "amarelo", "verde", "azul", "roxo"]
const PEN_COL := {
	"vermelho": Color("#e0463a"), "laranja": Color("#f08c2a"), "amarelo": Color("#f2cc2e"),
	"verde": Color("#4caf50"), "azul": Color("#3a7bd5"), "roxo": Color("#8e4ec6"),
}
const SONGS := ["manha", "tarde", "chuva", "noite", "tunel"]

#!/usr/bin/env python3
"""Episódio 2 (fuga da Isis): os lápis que ela deixa são MARCAS fincadas no chão (não são para pegar)."""
import json, os
P = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'data', 'level2.json')
L = json.load(open(P))
MSG = ["A Isis fincou um lápis vermelho no chão, de pé, como marca: o papai vai achar a trilha.",
       "Um lápis laranja fincado no chão: é uma marca da trilha (não é para pegar).",
       "Mais uma marca: o lápis azul, fincado de pé. Siga a trilha, papai!",
       "O lápis verde fincado no chão: ela marcou cada lugar por onde passou."]
for d, m in zip(L['drops'], MSG):
    d['msg'] = m
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
print('ok')
# os vigias da fuga da Isis (a visão deles ficou melhor): param mais tempo nas pontas da ronda
L = json.load(open(P))
for w in L['watchmen']:
    if w['x0'] > 30000:
        w['pause'] = 110
json.dump(L, open(P, 'w'), ensure_ascii=False, indent=1)
print('ok vigias')

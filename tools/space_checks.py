#!/usr/bin/env python3
"""Fogueiras (pontos de volta) nunca coladas umas nas outras: tira os pontos comuns a menos de MIN px
(no mesmo nível) de outro ponto mantido ou de uma fogueira grande. As fogueiras grandes (descanso) ficam."""
import json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIN = 900


def space(checks, keep_x=()):
    ch = sorted(checks, key=lambda c: c[0])
    rests = [c for c in ch if len(c) > 2]
    out = []
    for c in ch:
        if len(c) > 2 or c[0] in keep_x:
            out.append(c)
            continue
        near = [k for k in out + rests if k is not c and abs(k[0] - c[0]) < MIN and abs(k[1] - c[1]) < 150]
        if not near:
            out.append(c)
    return sorted(out, key=lambda c: c[0])


if __name__ == "__main__":
    for n in sys.argv[1:] or ["1", "2"]:
        p = os.path.join(ROOT, "assets", "data", "level%s.json" % n)
        L = json.load(open(p))
        a = len(L["checks"])
        L["checks"] = space(L["checks"])
        json.dump(L, open(p, "w"), ensure_ascii=False, indent=1)
        print("level%s: %d -> %d pontos de volta" % (n, a, len(L["checks"])))

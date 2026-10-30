from PIL import Image, ImageDraw, ImageFilter
import numpy as np, math
K=Image.open('/tmp/claude-0/hawk/key.png')
W,H=K.size
def polymask(pts):
    m=Image.new('L',(W,H),0); ImageDraw.Draw(m).polygon(pts,fill=255); return m
LW=[(0,40),(330,40),(475,380),(462,430),(445,470),(440,560),(400,630),(250,600),(0,580)]
RW=[(650,398),(690,280),(760,40),(1024,40),(1024,640),(760,610),(655,565),(628,522),(646,470)]
lm=polymask(LW); rm=polymask(RW)
def cut(m):
    o=Image.new('RGBA',(W,H),(0,0,0,0)); o.paste(K,(0,0),m); return o
lw=cut(lm); rw=cut(rm)
bm=Image.eval(Image.composite(Image.new('L',(W,H),0),Image.new('L',(W,H),255),Image.eval(Image.composite(lm,rm,lm),lambda v:v)),lambda v:v)
body=Image.new('RGBA',(W,H),(0,0,0,0)); body.paste(K,(0,0),bm)
lw.save('/tmp/claude-0/hawk/lw.png'); rw.save('/tmp/claude-0/hawk/rw.png'); body.save('/tmp/claude-0/hawk/body.png')
# coroa removida (para quando ele perde a coroa)
def crownless(b):
    a=np.array(b).copy()
    P0,P1,P2=np.array([498.,380.]),np.array([578.,322.]),np.array([654.,398.])
    ts=np.linspace(0,1,80)
    pts=[tuple((1-t)**2*P0+2*(1-t)*t*P1+t*t*P2) for t in ts]
    px=np.array([p[0] for p in pts]); py=np.array([p[1] for p in pts])
    ys,xs=np.mgrid[0:H,0:W]
    capy=np.interp(xs,px,py)
    region=(xs>=498)&(xs<=654)&(ys>250)
    above=region&(ys<capy)
    a[above,3]=0
    r,g,bb=[a[...,i].astype(int) for i in range(3)]
    crownc=region&(ys<400)&(((r>150)&(g>110)&(bb<120))|((r>120)&(g<70)&(bb<80)))&~above
    col=np.array(list(K.getpixel((575,410))[:3])+[255],np.uint8)
    a[crownc]=col
    im=Image.fromarray(a,'RGBA'); d=ImageDraw.Draw(im)
    d.polygon(pts+[(654,398),(560,398),(498,384)],fill=tuple(int(v) for v in col))
    d.line(pts,fill=(14,10,8,255),width=8,joint='curve')
    return im
crownless(body).save('/tmp/claude-0/hawk/body_nc.png')

# ---- quadros
PAD=260
CW,CH=W+2*PAD,H+2*PAD
def place(img):
    c=Image.new('RGBA',(CW,CH),(0,0,0,0)); c.paste(img,(PAD,PAD)); return c
LP=(450+PAD,455+PAD); RP=(645+PAD,450+PAD)
L=place(lw); R=place(rw); B=place(body); BN=place(crownless(body))
def xform(img,piv,ang,sx=1.0,sy=1.0):
    # escala em volta do pivô e gira (ângulo em graus, anti-horário na tela)
    a=math.radians(ang); ca,sa=math.cos(a),math.sin(a)
    # mapa inverso: saída -> entrada
    # p_out = piv + Rot(S(p_in - piv)) ; p_in = piv + S^-1 Rot^-1 (p_out - piv)
    # Rot (anti-horário na tela, y para baixo): [ca, sa; -sa, ca]
    px,py=piv
    # inverse rot: [ca,-sa; sa, ca]
    A=ca/sx; Bc=-sa/sx; D=sa/sy; E_=ca/sy
    C=px-A*px-Bc*py; F=py-D*px-E_*py
    return img.transform(img.size,Image.AFFINE,(A,Bc,C,D,E_,F),resample=Image.BICUBIC)
def frame(al,ar,s=1.0,sx=1.0,crown=True):
    f=Image.new('RGBA',(CW,CH),(0,0,0,0))
    f.alpha_composite(xform(L,LP,al,sx*s,s))
    f.alpha_composite(xform(R,RP,-ar,sx*s,s))
    f.alpha_composite(B if crown else BN)
    return f
import sys
frames=[]
for crown in (False,):
    for ang,s in [(0,1.0),(24,.97),(48,.93),(70,.9)]:
        frames.append(frame(ang,ang,s,crown=crown))
    frames.append(frame(-22,-22,1.0,.62,crown=crown))  # mergulho: asas recolhidas
bb=None
for f in frames:
    b=f.getbbox(); bb=b if bb is None else (min(bb[0],b[0]),min(bb[1],b[1]),max(bb[2],b[2]),max(bb[3],b[3]))
print('bbox',bb)
fw,fh=bb[2]-bb[0],bb[3]-bb[1]
FW=300; FHt=int(round(fh*FW/fw))
sheet=Image.new('RGBA',(FW*len(frames),FHt),(0,0,0,0))
for i,f in enumerate(frames):
    sheet.paste(f.crop(bb).resize((FW,FHt),Image.LANCZOS),(i*FW,0))
sheet.save('/tmp/claude-0/hawk/sheet.png')
# onde fica o corpo (centro do peito) e o topo da cabeça no quadro, em fração
print('FH',FHt,'chest',((540+PAD-bb[0])/fw,(600+PAD-bb[1])/fh),'feet',((560+PAD-bb[0])/fw,(860+PAD-bb[1])/fh),'head',((585+PAD-bb[0])/fw,(372+PAD-bb[1])/fh))

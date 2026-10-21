from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
R='/home/claude/find-her-godot/'
W,H=1280,720
F='/tmp/vid/fonts/'
def font(n,s): return ImageFont.truetype(F+n+'.ttf', s)
def text_c(d, xy, t, f, fill, stroke=0, sc=(0,0,0)):
    d.text(xy, t, font=f, fill=fill, anchor='mm', stroke_width=stroke, stroke_fill=sc)
def bg_img(path, dark=.5, blur=0):
    im=Image.open(path).convert('RGB')
    s=max(W/im.width,H/im.height); im=im.resize((int(im.width*s)+1,int(im.height*s)+1),Image.LANCZOS)
    x=(im.width-W)//2; y=(im.height-H)//2; im=im.crop((x,y,x+W,y+H))
    if blur: im=im.filter(ImageFilter.GaussianBlur(blur))
    return Image.blend(im, Image.new('RGB',(W,H),(10,7,5)), dark)
def panel(base, path, cx, cy, side, rot):
    p=Image.open(path).convert('RGB').resize((side,side),Image.LANCZOS)
    fr=Image.new('RGBA',(side+20,side+20),(250,245,230,255)); fr.paste(p,(10,10))
    d=ImageDraw.Draw(fr); d.rectangle([10,10,side+9,side+9],outline=(20,15,10),width=4)
    sh=Image.new('RGBA',fr.size,(0,0,0,120))
    fr=fr.rotate(rot,expand=True,resample=Image.BICUBIC); sh=sh.rotate(rot,expand=True)
    base.paste(sh,(int(cx-fr.width/2+10),int(cy-fr.height/2+12)),sh)
    base.paste(fr,(int(cx-fr.width/2),int(cy-fr.height/2)),fr)
def caption(base, t, y=650):
    d=ImageDraw.Draw(base)
    f=font('Lora-Italic',30)
    w=d.textlength(t,font=f)+60
    d.rounded_rectangle([W/2-w/2,y-30,W/2+w/2,y+30],12,fill=(255,243,207),outline=(30,20,10),width=3)
    text_c(d,(W/2,y),t,f,(40,26,12))
# título
im=bg_img(R+'assets/ui/cena1.jpg',.45).convert('RGBA'); d=ImageDraw.Draw(im)
text_c(d,(W/2,300),'ENCONTRE-A',font('Cinzel-Bold',120),(242,210,138),6,(30,15,5))
text_c(d,(W/2,400),'EPISÓDIO 1 · O BOSQUE',font('Cinzel-Bold',40),(232,201,138),3,(30,15,5))
im.convert('RGB').save('/tmp/vid/cards/titulo.png')
# história 1
im=bg_img(R+'assets/ui/cena1.jpg',.15).convert('RGBA'); caption(im,'Toda tarde, a Isis desenhava na varanda...',640); im.convert('RGB').save('/tmp/vid/cards/hist1.png')
# mistério (sem revelar quem levou)
im=bg_img(R+'assets/ui/cena1.jpg',.72,7).convert('RGBA'); d=ImageDraw.Draw(im)
text_c(d,(W/2,250),'Até que, numa tarde, ela sumiu.',font('Lora-Italic',44),(240,228,200),2,(10,5,2))
text_c(d,(W/2,320),'Só ficou uma trilha de lápis de cor...',font('Lora-Italic',36),(225,212,185),2,(10,5,2))
text_c(d,(W/2,450),'QUEM LEVOU A ISIS?',font('Cinzel-Bold',76),(255,214,77),6,(30,12,5))
im.convert('RGB').save('/tmp/vid/cards/hist2.png')
# quadrinhos dos chefes / reações
def boss(name, a, b, title, bg, sub):
    im=bg_img(R+bg,.6,8).convert('RGBA')
    panel(im,R+'assets/comic/%s.jpg'%a,W/2-215,370,410,3); panel(im,R+'assets/comic/%s.jpg'%b,W/2+215,380,410,-3)
    d=ImageDraw.Draw(im); text_c(d,(W/2,95),title,font('Cinzel-Bold',72),(255,214,77),6,(30,12,5))
    if sub: caption(im,sub,672)
    im.convert('RGB').save('/tmp/vid/cards/%s.png'%name)
boss('c_javali','javali_a','javali_b','JAVALI-REI','assets/bg/tarde.jpg','')
boss('c_gaviao','gaviao_a','gaviao_b','GAVIÃO-REI','assets/bg/tarde.jpg','')
boss('c_bagre','bagre_a','bagre_b','BAGRE-REI','assets/bg/pantano.jpg','')
boss('c_urso','urso_a','urso_b','URSO-PARDO-REI','assets/bg/neve.jpg','')
def single(name,a,bg,txt):
    im=bg_img(R+bg,.6,8).convert('RGBA'); panel(im,R+'assets/comic/%s.jpg'%a,W/2,330,480,-2); caption(im,txt,660); im.convert('RGB').save('/tmp/vid/cards/%s.png'%name)
single('c_frio','neve','assets/bg/neve.jpg','Brrr! Que frio... aguenta firme, Isis!')
single('c_mina','mina','assets/bg/noite.jpg','Escuro demais... ainda bem que eu trouxe a lanterna.')
# final
im=bg_img(R+'assets/bg/noite.jpg',.55,4).convert('RGBA'); d=ImageDraw.Draw(im)
text_c(d,(W/2,215),'ENCONTRE-A',font('Cinzel-Bold',110),(242,210,138),6,(30,15,5))
text_c(d,(W/2,315),'EPISÓDIO 1 · O BOSQUE',font('Cinzel-Bold',44),(232,201,138),3,(30,15,5))
text_c(d,(W/2,400),'Corredeira · biplano · cogumelos gigantes · fuga na mina',font('Lora-Italic',30),(240,228,200))
text_c(d,(W/2,520),'Em breve: EPISÓDIO 2 · As Profundezas da Mina',font('Lora-Bold',30),(255,214,120),2,(20,10,5))
text_c(d,(W/2,600),'Para Android',font('Lora-Italic',26),(220,210,190))
im.convert('RGB').save('/tmp/vid/cards/final.png')
# legendas dos trechos de jogo (faixa transparente)
caps={'manha':'Manhã: flores-catapulta e casas na árvore','copas':'Saltos pelas copas das árvores','regias':'Pântano: pule nas vitórias-régias','cipos2':'Balance nos cipós sobre a água tóxica','jangada':'Desça a corredeira de jangada','bolaneve':'Neve: empurre bolas de neve gigantes','cavalo':'Cavalgada pela trilha nevada','urso':'Desvie das patadas do Urso-Rei','vento':'Suba a montanha contra o vento','ponte':'Corra! A ponte está se soltando','voo':'Voe de biplano sobre o vale','cogumelos':'Noite: o bosque dos cogumelos gigantes','pedra':'Fuja da pedra gigante na mina','pedra2':'Abaixe no buraco... e deixe passar!'}
for k,t in caps.items():
    im=Image.new('RGBA',(W,H),(0,0,0,0)); d=ImageDraw.Draw(im)
    f=font('Lora-Italic',30); w=d.textlength(t,font=f)+56
    d.rounded_rectangle([W/2-w/2,H-92,W/2+w/2,H-38],12,fill=(14,10,6,200))
    text_c(d,(W/2,H-65),t,f,(245,235,210))
    im.save('/tmp/vid/cards/cap_%s.png'%k)
print('ok')

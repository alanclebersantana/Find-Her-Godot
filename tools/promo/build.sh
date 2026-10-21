#!/bin/bash
set -e
cd /tmp/vid
C=cards
V="-c:v libx264 -preset medium -crf 20 -pix_fmt yuv420p -r 30 -an"
still(){ # nome dur saída
  ffmpeg -v error -y -loop 1 -framerate 30 -t $2 -i $C/$1.png -vf "scale=1280*1.06:-1,zoompan=z='min(1+on*0.0012,1.06)':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1280x720:fps=30,fade=t=in:st=0:d=0.25,fade=t=out:st=$(echo "$2-0.25"|bc):d=0.25" $V $3
}
clip(){ # avi inicio dur saída [legenda]
  ffmpeg -v error -y -ss $2 -t $3 -i $1.avi -i $C/cap_${5:-$1}.png -filter_complex "[0:v]crop=1024:576:128:80,scale=1280:720,fps=30[v];[v][1:v]overlay=0:0,fade=t=in:st=0:d=0.2,fade=t=out:st=$(echo "$3-0.2"|bc):d=0.2" $V $4
}
rm -f seg/*.mp4
still titulo 2.4 seg/01.mp4
still hist1 2.2 seg/02.mp4
still hist2 2.8 seg/03.mp4
clip manha 1.0 2.6 seg/04.mp4
clip copas 3.5 3.0 seg/05.mp4
clip regias 0.5 2.6 seg/06.mp4
clip regias 6.2 2.8 seg/07.mp4 cipos2
clip corda 3.5 2.4 seg/08.mp4
clip mergulho 2.5 2.0 seg/09.mp4
still c_frio 1.4 seg/10.mp4
clip bolaneve 1.5 2.8 seg/11.mp4
clip gelofino 2.0 2.4 seg/12.mp4
clip gelo 1.0 2.4 seg/13.mp4
clip cavalo 1.2 3.0 seg/14.mp4
clip urso 2.0 2.0 seg/15.mp4
clip tunel 1.5 3.6 seg/16.mp4
still final 4.6 seg/17.mp4
ls seg/*.mp4 | sed "s/^/file '/;s/$/'/" > list.txt
ffmpeg -v error -y -f concat -safe 0 -i list.txt -c copy video_mudo.mp4
D=$(ffprobe -v error -show_entries format=duration -of csv=p=0 video_mudo.mp4)
A=/home/claude/find-her-godot/assets/audio
# trilha: tema na abertura, perseguição no resto (cruzando), som some no fim
ffmpeg -v error -y -i $A/mus_tema.ogg -stream_loop 2 -i $A/mus_perseguicao.ogg -filter_complex "[0:a]atrim=0:9.5,afade=t=out:st=7.6:d=1.9[a0];[1:a]atrim=0:40,adelay=7600|7600,afade=t=in:st=7.6:d=1.2[a1];[a0][a1]amix=inputs=2:normalize=0,atrim=0:$D,afade=t=out:st=$(echo "$D-2.5"|bc):d=2.5,volume=0.9[a]" -map "[a]" -c:a aac -b:a 160k trilha.m4a
ffmpeg -v error -y -i video_mudo.mp4 -i trilha.m4a -c:v copy -c:a aac -shortest -movflags +faststart encontre-a_promo.mp4
ffprobe -v error -show_entries format=duration -of csv=p=0 encontre-a_promo.mp4

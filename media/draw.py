from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math
N=256
def bg():
    img=Image.new('RGBA',(N,N),(0,0,0,0))
    px=img.load()
    for y in range(N):
        for x in range(N):
            d=math.hypot(x-N/2,y-N/2)/(N/2)
            if d<=1:
                t=min(1,d)
                r=int(70*(1-t)+25*t); g=int(35*(1-t)+10*t); b=int(120*(1-t)+50*t)
                px[x,y]=(r,g,b,255)
    return img
def gold_fill(mask):
    grad=Image.new('RGBA',(N,N))
    gp=grad.load()
    for y in range(N):
        t=y/N
        gp_row=(255,int(240-90*t),int(120-110*t),255)
        for x in range(N): gp[x,y]=gp_row
    out=Image.new('RGBA',(N,N),(0,0,0,0)); out.paste(grad,(0,0),mask); return out
def qmark(size,pos,font='/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf'):
    m=Image.new('L',(N,N),0); d=ImageDraw.Draw(m)
    f=ImageFont.truetype(font,size)
    d.text(pos,'?',font=f,fill=255,anchor='mm')
    return m
def outline(mask,w):
    return mask.filter(ImageFilter.MaxFilter(w*2+1))
def coin(d,cx,cy,rx,ry,layers):
    for i in range(layers):
        y=cy-i*int(ry*0.9)
        d.ellipse((cx-rx,y-ry,cx+rx,y+ry),fill=(120,70,0,255))
        d.ellipse((cx-rx,y-ry-4,cx+rx,y+ry-4),fill=(255,200,40,255),outline=(150,90,0,255),width=4)
def circ(img):
    m=Image.new('L',(N*4,N*4),0); ImageDraw.Draw(m).ellipse((0,0,N*4-1,N*4-1),fill=255); m=m.resize((N,N),Image.LANCZOS)
    a=img.split()[3]; from PIL import ImageChops; img.putalpha(ImageChops.multiply(a,m)); return img
# D: ? only
D=bg(); q=qmark(230,(N/2,N/2+8)); o=outline(q,10)
D.alpha_composite(Image.new('RGBA',(N,N),(20,8,0,255)),(0,0)) if False else None
dark=Image.new('RGBA',(N,N),(25,10,0,255)); tmp=Image.new('RGBA',(N,N),(0,0,0,0)); tmp.paste(dark,(0,0),o); D.alpha_composite(tmp); D.alpha_composite(gold_fill(q))
D=circ(D); D.save('icon2/D_q_256.png')
# E: ? + coins
E=bg(); dd=ImageDraw.Draw(E); coin(dd,170,205,62,24,3)
q=qmark(190,(100,108)); o=outline(q,9)
tmp=Image.new('RGBA',(N,N),(0,0,0,0)); tmp.paste(Image.new('RGBA',(N,N),(25,10,0,255)),(0,0),o); E.alpha_composite(tmp); E.alpha_composite(gold_fill(q))
E=circ(E); E.save('icon2/E_qcoin_256.png')
sheet=Image.new('RGBA',(2*200+40,260),(20,20,20,255)); d=ImageDraw.Draw(sheet)
for i,(k,c) in enumerate([('D_q',D),('E_qcoin',E)]):
    s=c.resize((20,20),Image.LANCZOS)
    sheet.alpha_composite(s.resize((160,160),Image.NEAREST),(20+i*200,20)); sheet.alpha_composite(s,(20+i*200+70,200)); d.text((20+i*200,230),k,fill=(255,255,255,255))
sheet.save('icon2/sheet2.png')

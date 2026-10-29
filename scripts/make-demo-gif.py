"""Compose actual native UI recordings into a lightweight, captioned GIF."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
ROOT=Path(__file__).resolve().parent.parent
font_path='/System/Library/Fonts/HelveticaNeue.ttc'
font=ImageFont.truetype(font_path,25)
small=ImageFont.truetype(font_path,15)
headings=['One tiny menu bar utility','A tiny Chinese / English switch','Keep your Mac awake','Never: no timer, safety still on','Set a countdown','Cancel whenever you like']
frames=[]
for index,title in enumerate(headings):
    shot=Image.open(ROOT/f'.build/native-frames/frame-{index}.png').convert('RGBA')
    shot.thumbnail((760,340),Image.Resampling.LANCZOS)
    canvas=Image.new('RGB',(960,470),'#faf8f3')
    draw=ImageDraw.Draw(canvas)
    draw.text((45,32),'LIDOFF',font=small,fill='#9d6824')
    draw.text((45,66),title,font=font,fill='#202731')
    x=(960-shot.width)//2
    y=137+(270-shot.height)//2
    shadow=Image.new('RGBA',canvas.size)
    ImageDraw.Draw(shadow).rounded_rectangle((x-3,y+5,x+shot.width+3,y+shot.height+10),radius=18,fill=(55,45,28,50))
    shadow=shadow.filter(ImageFilter.GaussianBlur(15))
    canvas=Image.alpha_composite(canvas.convert('RGBA'),shadow)
    canvas.alpha_composite(shot,(x,y))
    draw=ImageDraw.Draw(canvas)
    draw.text((45,431),'macOS 13+   /   Apple Silicon + Intel   /   MIT',font=small,fill='#69717a')
    draw.text((850,431),f'0{index+1} / 06',font=small,fill='#69717a')
    frames.append(canvas.convert('RGB'))
frames[0].save(ROOT/'docs/assets/demo.gif',save_all=True,append_images=frames[1:],duration=[2200,2000,1800,2400,2400,1800],loop=0,optimize=True)
frames[3].save(ROOT/'docs/assets/social.png')
frames[0].save(ROOT/'docs/assets/demo-zh.png')
print('Wrote GIF and sharing image')

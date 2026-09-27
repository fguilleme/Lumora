from pathlib import Path
import json,numpy as np
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parent;repo=root.parents[1];corpus=json.loads((repo/'Validation/OpticalDiffusionV2Validation/corpus.json').read_text())['cases'];levels=[0,25,40,55,70,85,100];metrics=[]
sheet=Image.new('RGB',(1960,8*320+35),'#222');draw=ImageDraw.Draw(sheet)
for j,v in enumerate(levels):draw.text((j*280+5,8),'Intensity '+str(v),fill='white')
(root/'Crops').mkdir(exist_ok=True)
for row,c in enumerate(corpus):
 d=root/'Corpus'/c['id'];original=np.asarray(Image.open(d/'0.png').convert('RGB'));images=[]
 for j,v in enumerate(levels):
  im=Image.open(d/f'{v}.png').convert('RGB');images.append(im);a=np.asarray(im);delta=a.astype(float)-original
  raw=np.fromfile(d/f'{v}.rgba32f',np.float32).reshape(-1,4)[:,:3]
  metrics.append(dict(case=c['id'],intensity=v,newSaturatedPixels=int(((original<255)&(a==255)).any(axis=2).sum()),meanLuminance=float((raw@np.array([.2126,.7152,.0722])).mean()),peakRGB=float(raw.max()),mae255=float(np.abs(delta).mean())))
  thumb=im.copy();thumb.thumbnail((274,282));sheet.paste(thumb,(j*280,row*320+58));draw.text((j*280+4,row*320+37),c['id'],fill='white')
 for name,(x,y,xx,yy) in c['crops'].items():
  w=min(280,xx-x);h=min(240,yy-y);cx=(x+xx)//2;cy=(y+yy)//2;box=(cx-w//2,cy-h//2,cx-w//2+w,cy-h//2+h)
  out=Image.new('RGB',(w*7,h+28),'#222');dr=ImageDraw.Draw(out)
  for j,im in enumerate(images):out.paste(im.crop(box),(j*w,28));dr.text((j*w+3,5),str(levels[j]),fill='white')
  out.save(root/'Crops'/f'{c["id"]}_{name}.png')
sheet.save(root/'contact.png');(root/'metrics.json').write_text(json.dumps(metrics,indent=2))
for v in levels:print(v,sum(m['newSaturatedPixels'] for m in metrics if m['intensity']==v))
# Compare actual iPhone previews to its native exports after resolution/color normalization.
# Preview output is Display P3 whereas exports use sRGB: CI-based comparisons are required.

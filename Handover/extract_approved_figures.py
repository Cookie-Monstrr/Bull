#!/usr/bin/env python3
"""Local extraction of approved artwork: OpenCV DNN + seeded edge refinement.

No ONNX Runtime, telemetry or image upload. Model is a local u2netp.onnx file.
Run with --model PATH; requires numpy, Pillow and opencv-python-headless.
"""
import argparse
import json
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw

SPECS = {
    'bull': ('bull-state.png', [0, 282, 558, 839, 1140, 1536], [137, 415, 699, 997, 1350], (520, 0, 1010, 80)),
    'provider': ('bull-routine.png', [0, 294, 572, 862, 1170, 1536], [145, 423, 713, 1018, 1349], (430, 0, 1110, 65)),
    'devil': ('urge-state.png', [0, 288, 578, 868, 1170, 1536], [146, 429, 716, 1010, 1355], (490, 0, 1100, 75)),
    'angel': ('urge-routine.png', [0, 290, 575, 836, 1140, 1536], [154, 435, 709, 1001, 1370], (430, 0, 1110, 120)),
}


def prediction(net, rgb):
    scaled = cv2.resize(rgb, (320, 320)).astype(np.float32) / 255
    scaled = (scaled - np.array([.485, .456, .406], np.float32)) / np.array([.229, .224, .225], np.float32)
    net.setInput(scaled.transpose(2, 0, 1)[None])
    result = net.forward()[0, 0]
    result = (result - result.min()) / max(float(result.max() - result.min()), 1e-6)
    return cv2.resize(result, (rgb.shape[1], rgb.shape[0]), interpolation=cv2.INTER_LINEAR)


def background_seam(rgb, centre, radius=38):
    """Follow paper between adjacent silhouettes instead of cutting fixed rectangles."""
    low, high = centre - radius, centre + radius + 1
    patch = rgb[:, low:high].astype(np.float32)
    # Warm ivory background: high brightness, low contrast between channels.
    contrast = patch.max(2) - patch.min(2)
    dark = np.maximum(0, 226 - patch.mean(2))
    cost = np.maximum(0, contrast - 39) * 2 + dark * 2
    cost += np.abs(np.arange(low, high) - centre)[None] * .055
    cumulative = cost[0].copy()
    choices = np.zeros(cost.shape, np.int8)
    for y in range(1, len(cost)):
        candidates = np.stack([np.r_[1e8, cumulative[:-1]], cumulative, np.r_[cumulative[1:], 1e8]])
        best = candidates.argmin(0)
        choices[y] = best - 1
        cumulative = candidates[best, np.arange(len(cumulative))] + cost[y]
    x = int(cumulative.argmin())
    seam = np.empty(len(cost), np.int32)
    for y in range(len(cost)-1, -1, -1):
        seam[y] = x + low
        x += int(choices[y, x])
    return seam


ANGEL_WINGS = [
    [[(29,516),(32,394),(62,356),(85,339),(107,342),(108,462),(84,490),(61,490),(45,519)],
     [(204,321),(220,316),(241,327),(262,351),(273,382),(281,448),(282,489),(268,467),(257,437),(241,423),(221,380)]],
    [[(298,450),(312,372),(327,338),(345,328),(360,340),(368,464),(354,496),(339,501),(332,464),(315,480)],
     [(457,351),(473,306),(487,299),(502,313),(513,344),(526,389),(531,451),(521,424),(509,406),(503,382),(486,388)]],
    [[(530,440),(539,354),(557,306),(589,278),(603,274),(613,294),(620,345),(629,460),(612,505),(598,510),(595,473),(578,520),(563,505),(546,479)],
     [(718,342),(739,291),(753,283),(768,300),(779,334),(786,374),(794,441),(786,411),(778,405),(772,376),(759,399)]],
    [[(799,566),(800,378),(819,290),(850,238),(880,209),(905,204),(914,214),(911,235),(898,270),(895,316),(887,351),(863,399),(843,474),(824,556)],
     [(985,211),(995,202),(1013,205),(1039,223),(1064,256),(1082,295),(1092,335),(1108,389),(1088,369),(1076,336),(1065,328),(1052,306),(1036,314),(1014,277)]],
    [],
]


def extract(net, rgb, region, role, stage):
    ys, xs = np.where(region)
    x0, x1 = max(0, xs.min()-2), min(rgb.shape[1], xs.max()+3)
    crop = rgb[:, x0:x1].copy()
    allowed = region[:, x0:x1]
    crop[~allowed] = (247, 240, 225)
    padded = np.pad(crop, ((12,12),(12,12),(0,0)), constant_values=247)
    pred = prediction(net, padded)[12:-12,12:-12]
    seed = np.where(pred > .5, cv2.GC_PR_FGD, cv2.GC_PR_BGD).astype(np.uint8)
    seed[pred < .025] = cv2.GC_BGD
    seed[cv2.erode((pred > .95).astype(np.uint8), np.ones((3,3),np.uint8)) > 0] = cv2.GC_FGD
    if role == 'angel':
        # Reviewed feather envelopes restore pale details that semantic matting misses.
        wing = np.zeros(crop.shape[:2], np.uint8)
        for polygon in ANGEL_WINGS[stage]:
            points = np.array(polygon, np.int32) - np.array([x0, 0])
            cv2.fillPoly(wing, [points], 1)
        interior = cv2.erode(wing, np.ones((5,5),np.uint8)) > 0
        seed[cv2.dilate(wing,np.ones((9,9),np.uint8)) > 0] = cv2.GC_PR_FGD
        seed[interior] = cv2.GC_FGD
        # Narrow hand-reviewed spear strokes retain shafts and metal tips.
        spears = [(47,112,64,868),(306,186,329,844),(551,142,561,852),(1082,141,1116,867),(1482,35,1483,903)]
        sx,sy,ex,ey = spears[stage]
        spear = np.zeros_like(wing)
        cv2.line(spear,(sx-x0,sy),(ex-x0,ey),1,4)
        seed[cv2.dilate(spear,np.ones((9,9),np.uint8)) > 0] = cv2.GC_PR_FGD
        seed[spear > 0] = cv2.GC_FGD
    seed[~allowed] = cv2.GC_BGD
    seed[0,:] = cv2.GC_BGD
    seed[-1,:] = cv2.GC_BGD
    seed[:,0] = cv2.GC_BGD
    seed[:,-1] = cv2.GC_BGD
    cv2.grabCut(crop, seed, None, np.zeros((1,65),np.float64), np.zeros((1,65),np.float64), 3, cv2.GC_INIT_WITH_MASK)
    mask = ((seed == cv2.GC_FGD) | (seed == cv2.GC_PR_FGD)).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    keep = np.zeros_like(mask)
    for label in range(1,count):
        if stats[label,cv2.CC_STAT_AREA] >= 24:
            keep[labels == label] = 1
    alpha = cv2.GaussianBlur(keep.astype(np.float32), (3,3), .45)
    alpha[~allowed] = 0
    alpha = np.clip(alpha * 255,0,255).astype(np.uint8)
    # Avoid matte RGB bleeding during later scaling: alpha premultiplication is used below.
    rgba = np.dstack([crop,alpha])
    return Image.fromarray(rgba), x0


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model',type=Path,required=True)
    parser.add_argument('--source',type=Path,default=Path(__file__).parent/'Approved-Figures')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    cv2.setNumThreads(2)
    net=cv2.dnn.readNetFromONNX(str(args.model))
    args.output.mkdir(parents=True,exist_ok=True)
    records=[]
    for role,(filename,boundaries,centres,header) in SPECS.items():
        rgb=np.array(Image.open(args.source/filename).convert('RGB'))[:925]
        x0,y0,x1,y1=header
        rgb[y0:y1,x0:x1]=(247,240,225)
        height,width=rgb.shape[:2]
        seams=[np.zeros(height,np.int32)] + [background_seam(rgb,x) for x in boundaries[1:-1]] + [np.full(height,width,np.int32)]
        extracted=[]
        for i in range(5):
            xx=np.arange(width)[None]
            region=(xx >= seams[i][:,None]) & (xx < seams[i+1][:,None])
            cut,left=extract(net,rgb,region,role,i)
            bbox=cut.getbbox()
            if bbox is None:raise ValueError(f'Empty extraction {role}-{i+1}')
            extracted.append((cut,left,bbox,centres[i]))
        # One scale for every stage in a character set preserves the approved growth.
        scale=min(700/max(b[3]-b[1] for _,_,b,_ in extracted),
                  min(242/max(c-left-b[0],b[2]+left-c,1) for _,left,b,c in extracted))
        for i,(cut,left,bbox,centre) in enumerate(extracted):
            art=cut.crop(bbox)
            art=art.convert('RGBa').resize((round(art.width*scale),round(art.height*scale)),Image.Resampling.LANCZOS).convert('RGBA')
            canvas=Image.new('RGBA',(512,768))
            position=(round(256+(bbox[0]+left-centre)*scale),744-art.height)
            canvas.alpha_composite(art,position)
            name=f'bull-figure-{role}-{i+1}'
            canvas.save(args.output/f'{name}.png',optimize=True)
            records.append({'name':name,'source':filename,'source_body_centre_x':centre,'scale':scale,'bbox':canvas.getbbox()})
            print('Prepared',name,canvas.getbbox(),flush=True)
    (args.output/'extraction-layout.json').write_text(json.dumps(records,indent=2)+'\n')
    for bg,label in [((58,17,19),'oxblood'),((245,240,225),'ivory')]:
        sheet=Image.new('RGB',(5*205,4*326),bg)
        draw=ImageDraw.Draw(sheet)
        for i,row in enumerate(records):
            art=Image.open(args.output/(row['name']+'.png'))
            art.thumbnail((200,300),Image.Resampling.LANCZOS)
            x=(i%5)*205+(205-art.width)//2;y=(i//5)*326
            sheet.paste(art,(x,y),art)
            draw.text(((i%5)*205+8,y+304),row['name'].replace('bull-figure-',''),fill='white' if label=='oxblood' else 'black')
        sheet.save(args.output/f'contact-{label}.png')


if __name__=='__main__':main()

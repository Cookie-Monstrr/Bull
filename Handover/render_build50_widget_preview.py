#!/usr/bin/env python3
"""Render a geometry mock-up of the two figure widgets from production PNG assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "SharedFigures" / "Figures.xcassets"
OUT = ROOT / "Handover" / "BUILD50-FIGURE-WIDGET-PREVIEW.png"
W, H = 1014, 474  # systemMedium proportions at 3x
FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 75)


def asset(role, score):
    stage = min(5, int(max(0, min(100, score)) / 20) + 1)
    name = f"bull-figure-{role}-{stage}"
    return Image.open(CATALOG / f"{name}.imageset" / f"{name}.png").convert("RGBA")


def widget(left_role, left_score, right_role, right_score):
    image = Image.new("RGB", (W, H))
    pixels = image.load()
    for x in range(W):
        t = x / (W - 1)
        colour = tuple(round(a * (1-t) + b * t) for a, b in zip((53,17,18),(102,29,27)))
        for y in range(H): pixels[x,y] = colour
    mask = Image.new("L", (W,H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0,0,W-1,H-1), radius=78, fill=255)
    background = Image.new("RGB", (W,H), (237,232,221))
    background.paste(image, (0,0), mask)
    image = background.convert("RGBA")
    overlay = Image.new("RGBA", (W,H))
    odraw = ImageDraw.Draw(overlay)
    pad_x, pad_top, pad_bottom = 21, 12, 21
    inner_w, inner_h = W - 2*pad_x, H - pad_top - pad_bottom
    footer = max(108, round(inner_h * .23))
    art_h = inner_h - footer - 21
    col_w = (inner_w - 3) // 2
    footer_y = pad_top + art_h + 21
    odraw.rectangle((pad_x + col_w, pad_top, pad_x + col_w + 2, H-pad_bottom), fill=(255,243,218,51))
    odraw.rectangle((pad_x, footer_y, W-pad_x, footer_y+2), fill=(255,243,218,46))
    odraw.rectangle((pad_x, footer_y+3, W-pad_x, H-pad_bottom), fill=(255,243,218,9))
    image = Image.alpha_composite(image, overlay)
    draw = ImageDraw.Draw(image)
    for index,(role,score) in enumerate(((left_role,left_score),(right_role,right_score))):
        x0 = pad_x + index*(col_w+3)
        art = asset(role,score)
        scale = min((col_w-18)/art.width, art_h/art.height)
        art = art.resize((round(art.width*scale),round(art.height*scale)),Image.Resampling.LANCZOS)
        image.alpha_composite(art,(round(x0+(col_w-art.width)/2),pad_top))
        label = str(score)
        box = draw.textbbox((0,0),label,font=FONT)
        draw.text((x0+(col_w-(box[2]-box[0]))/2,
                   footer_y+(footer-(box[3]-box[1]))/2-box[1]),label,font=FONT,fill=(255,243,218,255))
    return image.convert("RGB")


canvas = Image.new("RGB", (W, H*2+30), (238,234,225))
canvas.paste(widget("bull",68,"devil",10),(0,0))
canvas.paste(widget("provider",77,"angel",59),(0,H+30))
canvas.save(OUT,optimize=True)
print(OUT)

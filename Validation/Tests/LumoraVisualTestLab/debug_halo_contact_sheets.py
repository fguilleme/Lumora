"""Build fixed-scale Debug Lab inspection sheets from archived diagnostic outputs."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "Validation/DebugLab"
HIGH = BASE / "HaloHighRes"
OVERLAY = BASE / "HaloOverlays"
OUT = BASE / "HaloDiagnostics"
OUT.mkdir(parents=True, exist_ok=True)

CASES = [
    ("01_portrait_light_skin", "Phase_2_A", (603, 468), "well-exposed portrait / hair"),
    ("07_white_subject", "Phase_2_A", (112, 192), "white subject / LEFT BORDER"),
    ("07_white_subject", "Phase_2_A", (224, 106), "white subject / local edge"),
    ("01_dark_indoor_portrait", "Phase_2_C", (665, 189), "dark portrait / window"),
    ("04_backlight", "Phase_2_A", (502, 679), "backlight / hair"),
    ("03_landscape_clouds", "Phase_2_C", (460, 654), "landscape / sky and rocks"),
    ("05_backlit_sunset_silhouette", "Phase_2_A", (407, 271), "silhouette / sky"),
]

try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 18)
    SMALL = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 14)
except OSError:
    FONT = ImageFont.load_default()
    SMALL = FONT


def crop(image: Image.Image, center: tuple[int, int], size: int) -> Image.Image:
    x, y = center
    left = max(0, min(image.width - size, x - size // 2))
    top = max(0, min(image.height - size, y - size // 2))
    return image.crop((left, top, left + size, top + size))


def over(base: Image.Image, overlay: Image.Image) -> Image.Image:
    result = base.convert("RGBA")
    result.alpha_composite(overlay.convert("RGBA"))
    return result.convert("RGB")


for magnification in (1, 2):
    source_size = 224
    tile = source_size * magnification
    gap = 8
    header = 38
    column_header = 32
    width = gap + 4 * (tile + gap)
    height = column_header + len(CASES) * (header + tile + gap) + gap
    sheet = Image.new("RGB", (width, height), "#151719")
    draw = ImageDraw.Draw(sheet)
    for column, label in enumerate(("Off / Original", "Processed variant",
                                    "Signed ΔY: red + / blue −", "Halo: pink + / cyan −")):
        draw.text((gap + column * (tile + gap) + 4, 7), label, fill="#efefef",
                  font=SMALL if magnification == 1 else FONT)
    for row, (name, variant, center, title) in enumerate(CASES):
        src_dir = HIGH / name
        map_dir = OVERLAY / f"{name}_{variant}"
        original = Image.open(src_dir / "Off_Original_pipeline.png").convert("RGB")
        processed = Image.open(src_dir / f"{variant}.png").convert("RGB")
        positive = Image.open(map_dir / "Positive_luminance_difference.png")
        negative = Image.open(map_dir / "Negative_luminance_difference.png")
        halo = Image.open(map_dir / "Halo_Map.png")
        signed = over(over(processed, positive), negative)
        columns = (original, processed, signed, over(processed, halo))
        y = column_header + row * (header + tile + gap)
        draw.text((gap + 4, y + 7), f"{name} | {variant} | {title} | {magnification * 100}%",
                  fill="#e4e7e6", font=FONT)
        for column, frame in enumerate(columns):
            part = crop(frame, center, source_size)
            if magnification == 2:
                part = part.resize((tile, tile), Image.Resampling.NEAREST)
            sheet.paste(part, (gap + column * (tile + gap), y + header))
    destination = OUT / f"worst_cases_{magnification * 100}_percent.png"
    sheet.save(destination)
    print(destination)

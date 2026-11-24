"""Extract temporary icons from approved cels; update only My Stuff cells 68/69."""
from pathlib import Path
import argparse, hashlib, json, xml.etree.ElementTree as ET
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'reports/motion-items/2026-10-23/registration-v1'
BASE = ROOT / 'resources/gfx/Effects/MotionShowcase/v7'
ATLAS = ROOT / 'resources/gfx/UI/NeverbirthDeathItems.png'


def extract(move, animation, layer_name):
    source = BASE / (move + '.anm2')
    tree = ET.parse(source).getroot()
    layer = tree.find(f'./Content/Layers/Layer[@Name="{layer_name}"]')
    sheet = tree.find(f'./Content/Spritesheets/Spritesheet[@Id="{layer.get("SpritesheetId")}"]')
    frames = tree.findall(f'./Animations/Animation[@Name="{animation}"]/LayerAnimations/LayerAnimation[@LayerId="{layer.get("Id")}"]/Frame')
    frame = next(f for f in frames if f.get('Visible') == 'true')
    x, y, w, h = (int(frame.get(k)) for k in ('XCrop', 'YCrop', 'Width', 'Height'))
    texture = BASE / sheet.get('Path')
    cropped = Image.open(texture).convert('RGBA').crop((x, y, x + w, y + h))
    subject = cropped.crop(cropped.getbbox())
    return subject, dict(source=str(source.relative_to(ROOT)), animation=animation, layer=layer_name,
                         texture=str(texture.relative_to(ROOT)), crop=[x, y, w, h],
                         texture_sha256=hashlib.sha256(texture.read_bytes()).hexdigest())


def fit(subject, size, inner):
    subject = ImageOps.contain(subject, (inner, inner), Image.Resampling.LANCZOS)
    output = Image.new('RGBA', (size, size))
    output.alpha_composite(subject, ((size - subject.width) // 2, (size - subject.height) // 2))
    return output


def sketch(subject):
    # Dedicated 16px monochrome ink conversion; separate from colored gfx art.
    image = fit(subject, 16, 14)
    alpha = image.getchannel('A')
    luma = image.convert('L')
    output = Image.new('RGBA', (16, 16))
    inks = [(52, 35, 29, 255), (110, 78, 57, 255), (169, 133, 92, 255)]
    for y in range(16):
        for x in range(16):
            if alpha.getpixel((x, y)) >= 64:
                output.putpixel((x, y), inks[min(2, luma.getpixel((x, y)) // 86)])
    return output


def build(check=False):
    ledger = []
    atlas = Image.open(ATLAS).convert('RGBA')
    icons = []
    for local_id, filename, move, anim, layer in (
        (68, 'motion_wave.png', 'wave', 'Preview', 'wave_a'),
        (69, 'motion_dp.png', 'dp', 'ODPreview', 'fire_back_0'),
    ):
        subject, provenance = extract(move, anim, layer)
        icon = fit(subject, 32, 28)
        ink = sketch(subject)
        dest = ROOT / 'resources/gfx/Items/Collectibles' / filename
        x, y = local_id % 20 * 16, local_id // 20 * 16
        if check:
            assert Image.open(dest).convert('RGBA').tobytes() == icon.tobytes(), filename + ' stale'
            assert atlas.crop((x, y, x + 16, y + 16)).tobytes() == ink.tobytes(), filename + ' sketch stale'
        else:
            icon.save(dest)
            ink.save(REPORT / (filename.removesuffix('.png') + '-sketch.png'))
            atlas.paste(ink, (x, y))
        icons.append(icon)
        ledger.append(dict(local_id=local_id, gfx=str(dest.relative_to(ROOT)), **provenance))
    if not check:
        atlas.save(ATLAS)
        (REPORT / 'icon-sources.json').write_text(json.dumps(ledger, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        icons = [Image.open(ROOT / 'resources/gfx/Items/Collectibles' / f).convert('RGBA')
                 for f in ('motion_wave.png', 'motion_dp.png', 'zangief_360.png', 'zangief_720.png')]
        preview = Image.new('RGB', (4 * 128, 3 * 128))
        for row, color in enumerate(((224, 224, 224), (255, 255, 255), (91, 73, 57))):
            for col, icon in enumerate(icons):
                bg = Image.new('RGBA', (32, 32), color + (255,))
                if row == 0:
                    for yy in range(32):
                        for xx in range(32):
                            if (xx // 4 + yy // 4) % 2:
                                bg.putpixel((xx, yy), (190, 190, 190, 255))
                bg.alpha_composite(icon)
                preview.paste(bg.convert('RGB').resize((128, 128), Image.Resampling.NEAREST), (col * 128, row * 128))
        preview.save(REPORT / 'registered-icons.png')
    print('Approved cel icons and My Stuff cells 68/69 ' + ('verified.' if check else 'extracted.'))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true')
    build(parser.parse_args().check)

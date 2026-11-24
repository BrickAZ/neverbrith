"""Formal registration/economy preservation and one owned combat carrier."""
from pathlib import Path
import hashlib, importlib.util, json, re, xml.etree.ElementTree as ET
from PIL import Image, ImageChops

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / 'reports/motion-items/2026-10-23/registration-v1'
BEFORE = REPORT / 'before'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
names = {66: ('360', '360', 'zangief_360.png'), 67: ('720', '720', 'zangief_720.png'),
         68: ('Wave', '波动', 'motion_wave.png'), 69: ('Dragon Punch', '升龙', 'motion_dp.png')}
for filename in ('items.xml', 'items.en_us.xml', 'items.zh_cn.xml'):
    tree = ET.parse(ROOT / 'content' / filename).getroot()
    old = ET.parse(BEFORE / 'content' / filename).getroot()
    collectible = lambda x: x.tag in ('active', 'passive', 'familiar')
    rows = {int(x.get('id')): x for x in tree if collectible(x)}
    assert set(rows) == set(range(1, 70))
    assert len([x for x in tree if collectible(x)]) == 69
    assert tree.attrib == old.attrib
    for previous in old:
        if collectible(previous):
            current = rows[int(previous.get('id'))]
            assert current.tag == previous.tag and current.attrib == previous.attrib, (filename, previous.attrib)
        else:
            assert any(x.tag == previous.tag and x.attrib == previous.attrib for x in tree)
    for local_id, (en, zh, gfx) in names.items():
        row = rows[local_id]
        assert row.tag == 'active'
        assert row.get('name') == (zh if filename == 'items.zh_cn.xml' else en)
        assert row.get('gfx') == gfx
        assert row.get('maxcharges') == '0' and row.get('chargetype') == 'special'
        assert set(row.attrib) == {'name', 'id', 'description', 'gfx', 'maxcharges', 'chargetype'}
        icon = Image.open(ROOT / 'resources' / tree.get('gfxroot') / 'Collectibles' / gfx)
        assert icon.mode == 'RGBA' and icon.size == (32, 32)
        alpha = icon.getchannel('A')
        assert alpha.getextrema() == (0, 255)
        assert all(alpha.getpixel(p) == 0 for p in ((0, 0), (0, 31), (31, 0), (31, 31)))
        assert alpha.getbbox()

# No pool/source, charge balance or unrelated content changes. The 2026-10-25
# input changes are carried OD metadata and the user-approved 720 raw chord.
for relative in ('content/itempools.xml', 'content/itempools.en_us.xml', 'content/itempools.zh_cn.xml',
                 'content/sounds.xml',
                 'motion_input_shooting.lua', 'content/gfx/UI/NeverbirthDeathItems.anm2'):
    assert sha(ROOT / relative) == sha(BEFORE / relative), relative + ' changed'
core = (ROOT / 'motion_input_core.lua').read_text(encoding='utf-8')
core = re.sub(r'    -- BEGIN approved720shortcut[^\n]*\n.*?    -- END approved720shortcut\n', '', core, flags=re.S)
core = '\n'.join(line for line in core.splitlines() if not line.strip().startswith('s.odRequested='))
core = core.replace(',odRequested=not not s.odRequested', '').replace(',odRequested=data.odRequested', '')
assert core.strip() == (BEFORE / 'motion_input_core.lua').read_text(encoding='utf-8').strip(), 'recognizer changed outside approved OD metadata and 720 shortcut blocks'
entities = ET.parse(ROOT / 'content/entities2.xml').getroot()
old_entities = ET.parse(BEFORE / 'content/entities2.xml').getroot()
wave = [e for e in entities if e.get('name') == 'Neverbirth Motion Wave']
assert len(wave) == 1 and wave[0].get('id') == '1000' and wave[0].get('variant') == '3026'
assert wave[0].get('collisionDamage') == '0'
assert (ROOT / 'resources/gfx' / wave[0].get('anm2path')).is_file()
entities.remove(wave[0])
assert ET.canonicalize(ET.tostring(entities, encoding='unicode'), strip_text=True) == ET.canonicalize(ET.tostring(old_entities, encoding='unicode'), strip_text=True)
atlas_path = 'resources/gfx/UI/NeverbirthDeathItems.png'
atlas, old_atlas = (Image.open(p).convert('RGBA') for p in (ROOT / atlas_path, BEFORE / atlas_path))
assert atlas.size == old_atlas.size == (320, 640)
for local_id in range(800):
    x, y = local_id % 20 * 16, local_id // 20 * 16
    current = atlas.crop((x, y, x + 16, y + 16))
    old = old_atlas.crop((x, y, x + 16, y + 16))
    if local_id in (68, 69):
        assert not old.getbbox() and current.getbbox()
    else:
        assert current.tobytes() == old.tobytes(), f'My Stuff cell {local_id} changed'

spec = importlib.util.spec_from_file_location('icons', ROOT / 'tools/build-motion-item-icons.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
builder.build(check=True)
ledger = json.loads((REPORT / 'icon-sources.json').read_text(encoding='utf-8'))
for entry in ledger:
    assert sha(ROOT / entry['texture']) == entry['texture_sha256']
for filename in ('zangief_360.png', 'zangief_720.png'):
    assert (ROOT / 'resources/gfx/Items/Collectibles' / filename).is_file()
for filename in ('motion_items.lua', 'motion_item_text.lua'):
    source = (ROOT / filename).read_text(encoding='utf-8')
    for token in (':TakeDamage(', ':AddCollectible(', ':AddCharge(', ':SaveData(', ':SetCanShoot(',
                  ':GetCollectibleRNG(', ':SetMinDamageCooldown('):
        assert token not in source, (filename, token)
print('motion_items_resources: PASS (4 actives in 3 locales; old 65 entries, 798 other atlas cells, 3 pools; input preserved outside approved OD metadata/720 shortcut)')

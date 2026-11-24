"""Read-only weapon charge contract evidence for the installed Isaac executable."""
import hashlib
import pathlib
import struct
import subprocess

exe = pathlib.Path(r"E:/Isaac - Repentance/isaac-ng.exe")
b = exe.read_bytes()
pe = struct.unpack_from('<I', b, 60)[0]
n = struct.unpack_from('<H', b, pe + 6)[0]
sz = struct.unpack_from('<H', b, pe + 20)[0]
sections = []
for i in range(n):
    o = pe + 24 + sz + i * 40
    _, va, size, raw = struct.unpack_from('<IIII', b, o + 8)
    sections.append((va, size, raw))

def offset(va):
    rva = va - 0x400000
    for start, size, raw in sections:
        if start <= rva < start + size:
            return raw + rva - start
    raise ValueError('unmapped address')

def u(va):
    return struct.unpack_from('<I', b, offset(va))[0]

lines = ['Isaac SHA-256: ' + hashlib.sha256(b).hexdigest()]
for v in range(0xb5cd6c, 0xb5d600, 4):
    try:
        td = u(u(v - 4) + 12)
        o = offset(td) + 8
        name = b[o:b.find(b'\0', o)].decode()
        if not name.startswith('.?AVWeapon_'):
            continue
        charge = u(v + 24)
        o = offset(charge)
        stop = b.find(b'\xcc\xcc\xcc', o, o + 500)
        if stop < 0:
            stop = o + 300
        txt = subprocess.run([r'C:/msys64/ucrt64/bin/objdump.exe', '-d', '-M', 'intel',
            '--start-address=' + hex(charge), '--stop-address=' + hex(charge + stop - o), str(exe)],
            check=True, capture_output=True, text=True).stdout
        lines += [name + ' vtable=' + hex(v) + ' charge=' + hex(charge), txt]
    except (ValueError, UnicodeDecodeError, struct.error):
        pass
for va in [0xb6a614, 0xb6a820, 0xb6a1c8, 0xb6a98c, 0xb6a8cc, 0xb6a864, 0xb6a8d4]:
    lines.append(hex(va) + ' float=' + str(struct.unpack_from('<f', b, offset(va))[0]))
result = '\n'.join(lines)
path = pathlib.Path('reports/drive-rush/2026-10-14/implementation-v1/native-charge-contract.txt')
path.write_text(result, encoding='utf-8')
print(result)

"""Disassemble a proto from a Customization file using this game's shuffled opcodes."""
import os, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

# confirmed shuffled opcodes for this game
OPN = {1: 'LOADBOOL', 3: 'GETTABUP', 4: 'CALL', 7: 'SETTABLE', 8: 'SETTABUP',
       11: 'RETURN', 12: 'CLOSURE', 14: 'LOADK', 18: 'MOVE', 19: 'GETTABLE',
       20: 'JMP', 37: 'NOT', 44: 'SELF', 45: 'TEST'}

AOV = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'


def load(fileglob):
    zd = pyzstd.ZstdDict(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    zf = zipfile.ZipFile(os.path.join(AOV, 'Customization.pkg.bytes'))
    for it in zf.infolist():
        b = it.filename.split('/')[-1].replace('.bytes', '')
        if fileglob.lower() not in b.lower():
            continue
        raw = zf.read(it.filename)
        d = pyzstd.decompress(raw[8:], zd) if raw[:4] == b'\x22\x4a\x00\xef' else raw
        if b'\x1bLua' not in d:
            continue
        return b, L.parse_file(d)
    return None, None


def kstr(proto, idx):
    if idx < len(proto.constants):
        t, v = proto.constants[idx]
        if t in (4, 0x14):
            return repr(v.decode('utf-8', 'replace'))
        return repr(v)
    return f'k{idx}'


def disasm(proto, name=''):
    print(f"--- proto {name}: {len(proto.code)}i {proto.numparams}params maxstack={proto.maxstacksize} ---")
    for i, ins in enumerate(proto.code):
        op = ins & 0x3F
        A = (ins >> 6) & 0xFF
        Bx = (ins >> 14) & 0x3FFFF
        B = (ins >> 23) & 0x1FF
        C = (ins >> 14) & 0x1FF
        sBx = Bx - 131071
        nm = OPN.get(op, f'op{op}')
        extra = ''
        if op in (3, 8):  # GETTABUP/SETTABUP: C is key (const if >=256)
            if op == 3 and B >= 256:
                extra = f'  ; key={kstr(proto, B-256)}'
            if C >= 256:
                extra = f'  ; {kstr(proto, C-256)}'
        elif op in (7, 19, 44):  # SETTABLE/GETTABLE/SELF
            parts = []
            if B >= 256: parts.append(f'B={kstr(proto,B-256)}')
            if C >= 256: parts.append(f'C={kstr(proto,C-256)}')
            if parts: extra = '  ; ' + ' '.join(parts)
        elif op == 14:  # LOADK
            extra = f'  ; {kstr(proto, Bx)}'
        elif op == 12:  # CLOSURE
            extra = f'  ; proto[{Bx}]'
        if op in (14, 12, 20):
            print(f'  [{i:3d}] {nm:10s} A={A} Bx={Bx} sBx={sBx}{extra}')
        else:
            print(f'  [{i:3d}] {nm:10s} A={A} B={B} C={C}{extra}')


if __name__ == '__main__':
    fname = sys.argv[1]
    b, lf = load(fname)
    if not lf:
        print('not found'); sys.exit(1)
    m = map_methods(lf)
    want = sys.argv[2:] if len(sys.argv) > 2 else None
    for k, v in sorted(m.items(), key=lambda x: x[1]):
        if want and k not in want:
            continue
        disasm(lf.main.protos[v], f'{b}.{k}[{v}]')

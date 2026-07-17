"""Recursively find CLOSURE+SET binding of given method names in ALL protos."""
import os, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd

OP_CLOSURE = 12
AOV = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
NAMES = set(sys.argv[2:]) if len(sys.argv) > 2 else {'canUse', 'canWear', 'canEquip', 'canChange'}
SUB = sys.argv[1] if len(sys.argv) > 1 else ''


def walk(proto, path, results):
    cs = {i: v for i, (t, v) in enumerate(proto.constants) if t in (4, 0x14)}
    pend = None
    for ins in proto.code:
        op = ins & 0x3F
        A = (ins >> 6) & 0xFF
        Bx = (ins >> 14) & 0x3FFFF
        B = (ins >> 23) & 0x1FF
        C = (ins >> 14) & 0x1FF
        if op == OP_CLOSURE:
            pend = (A, Bx)
        elif op in (7, 8) and pend is not None:
            k = (B - 256) if B >= 256 else None
            if k in cs and C == pend[0]:
                nm = cs[k].decode('utf-8', 'replace')
                if nm in NAMES:
                    results.append((path + [pend[1]], nm))
            pend = None
    for i, sub in enumerate(proto.protos):
        walk(sub, path + [i], results)


def main():
    zd = pyzstd.ZstdDict(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    zf = zipfile.ZipFile(os.path.join(AOV, 'Customization.pkg.bytes'))
    for it in zf.infolist():
        b = it.filename.split('/')[-1].replace('.bytes', '')
        if SUB and SUB.lower() not in b.lower():
            continue
        raw = zf.read(it.filename)
        d = pyzstd.decompress(raw[8:], zd) if raw[:4] == b'\x22\x4a\x00\xef' else raw
        if b'\x1bLua' not in d:
            continue
        try:
            lf = L.parse_file(d)
        except Exception:
            continue
        res = []
        walk(lf.main, [], res)
        if res:
            print(f'{b}:')
            for path, nm in res:
                # resolve proto
                p = lf.main
                for idx in path:
                    p = p.protos[idx]
                print(f'    {nm:20s} path={path}  ({len(p.code)}i,{p.numparams}p)')


if __name__ == '__main__':
    main()

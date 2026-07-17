"""Diagnostic: map equip/response-check functions in Customization files."""
import os, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

AOV = sys.argv[1] if len(sys.argv) > 1 else \
    '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'

KEYS = ('isRspOK', 'isRspOk', 'RspOK', 'RspOk', 'canEquip', 'canWear', 'canUse',
        'isEquipped', 'isWearing', 'isWear', 'canRemove', 'canTakeOff',
        'canChange', 'isValid', 'checkCanEquip', 'isCanEquip')


def match(name):
    for k in KEYS:
        if k.lower() in name.lower():
            return True
    return False


def main():
    zd = pyzstd.ZstdDict(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    zf = zipfile.ZipFile(os.path.join(AOV, 'Customization.pkg.bytes'))
    for it in zf.infolist():
        b = it.filename.split('/')[-1].replace('.bytes', '')
        raw = zf.read(it.filename)
        d = pyzstd.decompress(raw[8:], zd) if raw[:4] == b'\x22\x4a\x00\xef' else raw
        if b'\x1bLua' not in d:
            continue
        try:
            lf = L.parse_file(d)
        except Exception:
            continue
        m = map_methods(lf)
        hits = {k: v for k, v in m.items() if match(k)}
        if hits:
            print(f'{b}:')
            for k, v in sorted(hits.items()):
                p = lf.main.protos[v]
                print(f'    {k:32s} -> proto[{v}] ({len(p.code)}i, {p.numparams}params)')


if __name__ == '__main__':
    main()

"""Dump ALL method names for files matching a substring."""
import os, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

AOV = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
SUB = sys.argv[1] if len(sys.argv) > 1 else 'System'


def main():
    zd = pyzstd.ZstdDict(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    zf = zipfile.ZipFile(os.path.join(AOV, 'Customization.pkg.bytes'))
    for it in zf.infolist():
        b = it.filename.split('/')[-1].replace('.bytes', '')
        if SUB.lower() not in b.lower():
            continue
        raw = zf.read(it.filename)
        d = pyzstd.decompress(raw[8:], zd) if raw[:4] == b'\x22\x4a\x00\xef' else raw
        if b'\x1bLua' not in d:
            continue
        try:
            lf = L.parse_file(d)
        except Exception:
            continue
        m = map_methods(lf)
        print(f'\n=== {b} ({len(m)} methods) ===')
        for k, v in sorted(m.items(), key=lambda x: x[1]):
            p = lf.main.protos[v]
            print(f'    [{v:3d}] {k:40s} ({len(p.code)}i,{p.numparams}p)')


if __name__ == '__main__':
    main()

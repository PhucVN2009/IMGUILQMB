"""Find and disasm-context every instruction referencing a given string const."""
import os, sys, zipfile
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from disasm import OPN, kstr

AOV = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
FILESUB = sys.argv[1]
TARGET = sys.argv[2]


def scan(proto, path, out):
    consts = proto.constants
    idxs = [i for i, (t, v) in enumerate(consts)
            if t in (4, 0x14) and v.decode('utf-8', 'replace') == TARGET]
    if idxs:
        for i, ins in enumerate(proto.code):
            op = ins & 0x3F
            B = (ins >> 23) & 0x1FF
            C = (ins >> 14) & 0x1FF
            Bx = (ins >> 14) & 0x3FFFF
            ref = None
            if (B - 256) in idxs: ref = 'B'
            if (C - 256) in idxs: ref = 'C'
            if op in (12, 14, 20) and Bx in idxs: ref = 'Bx'
            if ref:
                out.append((path, i, len(proto.code), proto.numparams))
    for j, sub in enumerate(proto.protos):
        scan(sub, path + [j], out)


def main():
    zd = pyzstd.ZstdDict(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    zf = zipfile.ZipFile(os.path.join(AOV, 'Customization.pkg.bytes'))
    for it in zf.infolist():
        b = it.filename.split('/')[-1].replace('.bytes', '')
        if FILESUB.lower() not in b.lower():
            continue
        raw = zf.read(it.filename)
        d = pyzstd.decompress(raw[8:], zd) if raw[:4] == b'\x22\x4a\x00\xef' else raw
        if b'\x1bLua' not in d:
            continue
        lf = L.parse_file(d)
        out = []
        scan(lf.main, [], out)
        for path, i, n, np in out:
            print(f'{b} proto{path} ({n}i,{np}p) @ line {i}')


if __name__ == '__main__':
    main()

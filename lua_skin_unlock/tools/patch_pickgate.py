"""
Remove the UnOwned gate in HeroSys.TryReqWearHeroSkin so you can select/wear an
unowned skin in the pick screen. Combined with the m_selectSkinIDList write in
PickHeroCustomizationButtonsView.onSkinChanged, this lets the whole chain fire
for unowned skins -> conclusive test of in-battle skin via Lua.

The gate is: [20] EQ ownState==UnOwned ; [21] JMP ->(skip wear). We neutralise
the JMP (sBx=0) so the wear branch always runs.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

JMP = 20


def patch(p):
    # UnOwned const index
    un = None
    for i, (t, v) in enumerate(p.constants):
        if t in (4, 0x14) and v == b'UnOwned':
            un = i
            break
    assert un is not None, 'UnOwned const not found'
    # find the GETTABLE that loads 'UnOwned' (key const == un), then the next EQ+JMP
    for i in range(len(p.code)):
        ins = p.code[i]
        if (ins & 0x3F) == 19 and ((ins >> 14) & 0x1FF) - 256 == un:  # GETTABLE ... UnOwned
            for j in range(i + 1, min(i + 4, len(p.code))):
                if (p.code[j] & 0x3F) == JMP and (p.code[j - 1] & 0x3F) == 15:
                    a = (p.code[j] >> 6) & 0xFF
                    p.code[j] = L.iAsBx(JMP, a, 0)  # neutralise -> fall through to wear
                    return j
    return -1


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools, 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    src = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base != 'HeroSys_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            at = patch(lf.main.protos[m['TryReqWearHeroSkin']])
            print(f"  TryReqWearHeroSkin[{m['TryReqWearHeroSkin']}] -> UnOwned gate neutralised at [{at+1}]")
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(src, 'wb') as f:
        f.write(buf.getvalue())
    print(f"-> {src} ({os.path.getsize(src)} bytes)")


if __name__ == '__main__':
    main()

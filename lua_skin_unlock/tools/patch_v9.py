"""
Patch v9 (experimental): make OnGmAddAllSkin run reliably & early.

v7 injected OnGmAddAllSkin into screen "awake" functions, but those may not
have executed at the right time (shop/battle stayed locked). v9 injects a
run-once guarded call into HeroModel.hasHero / hasSkin / hasHeroSkin - Lua
ownership helpers that fire whenever ANY hero/skin is displayed in the lobby
or pick screen. A shared _ENV flag makes the body run exactly once.

Goal of the experiment: get the client to genuinely believe it owns every
skin (CRoleInfo.m_ownSkinIdList populated) BEFORE the C# hero-select sends
selectSkinIDList to the server, to test whether the server then accepts the
skin into the match (especially VS-AI mode).

Applied on top of the current output HeroInfoLua (v5 + v7 + v8).
"""
import struct
import os
import sys
import zipfile
import io

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd

TARGET_PROTOS = [14, 15, 16]  # hasHero, hasSkin, hasHeroSkin


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 patch_v9.py <aov_files_dir> <output_dir>")
        sys.exit(1)
    orig_dir, out_dir = sys.argv[1], sys.argv[2]
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)

    src = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')
    if not os.path.exists(src):
        src = os.path.join(orig_dir, 'HeroInfoLua.pkg.bytes')
    out = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1].replace('.bytes', '') != 'HeroModel_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            for pi in TARGET_PROTOS:
                L.inject_add_all_skin_once(lf.main.protos[pi])
                print(f"  HeroModel proto[{pi}]: guarded OnGmAddAllSkin injected")
            newdata = L.ser_file(lf)
            L.parse_file(newdata)  # sanity
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp

    if not patched:
        print("HeroModel_lua not found"); return

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out} ({os.path.getsize(out)} bytes)")
    print("PATCH v9 COMPLETE")


if __name__ == '__main__':
    main()

"""
Patch v8: Force the wear-skin response to always succeed locally.

"Trang phuc khong ton tai" (skin does not exist) is the SERVER rejecting the
wear request in HeroSys.OnWearHeroSkinRsp: it calls
CUICommonSystem.instance:ProcessProtocolResult(rsp.ResultInfo) which pops the
error UI and returns the result code, then only applies the skin when the code
== M.Err_Common_Succ.

We rewrite the head of that function so the result is hardcoded to
Err_Common_Succ and ProcessProtocolResult is never called:

    result = M.Err_Common_Succ        -- instead of ProcessProtocolResult(...)

So no error popup shows and the success branch (OnWearHeroSkin -> apply skin +
broadcast HERO_SKIN_WEAR_SUCC) always runs. Combined with the ownership patches
(v5) and OnGmAddAllSkin (v7), selecting a skin and pressing "Dung" applies it
locally without the not-exist error.

Original HeroSys Proto[38] head:
  [11] SELF     R2, R2, ProcessProtocolResult
  [12] GETTABLE R4, R1, ResultInfo
  [13] CALL     R2, 3, 2                 ; R2 = ProcessProtocolResult(ResultInfo)
Patched:
  [11] GETTABUP R2, _ENV, "M"            ; R2 = M
  [12] GETTABLE R2, R2, "Err_Common_Succ"; R2 = M.Err_Common_Succ
  [13] MOVE     R0, R0                    ; NOP
"""
import struct
import os
import sys
import zipfile
import io

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd


def iABC(op, a, b, c):
    return L.iABC(op, a, b, c)

NOP = iABC(18, 0, 0, 0)
OP_GETTABUP = 3
OP_GETTABLE = 19


def const_index(proto, name):
    nb = name.encode()
    for i, (t, v) in enumerate(proto.constants):
        if t in (4, 0x14) and v == nb:
            return i
    raise ValueError("const %r not found" % name)


def patch_onwear_rsp(proto):
    # Verify this is OnWearHeroSkinRsp
    kM = const_index(proto, 'M')
    kSucc = const_index(proto, 'Err_Common_Succ')
    const_index(proto, 'WearHeroSkinRsp')
    const_index(proto, 'ProcessProtocolResult')

    # sanity: [11] should be SELF (op 44), [13] CALL (op 4)
    op11 = proto.code[11] & 0x3F
    op13 = proto.code[13] & 0x3F
    assert op11 == 44 and op13 == 4, "unexpected layout op11=%d op13=%d" % (op11, op13)

    proto.code[11] = iABC(OP_GETTABUP, 2, 0, 256 + kM)      # R2 = _ENV.M
    proto.code[12] = iABC(OP_GETTABLE, 2, 2, 256 + kSucc)   # R2 = M.Err_Common_Succ
    proto.code[13] = NOP


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 patch_v8.py <aov_files_dir> <output_dir>")
        sys.exit(1)
    orig_dir, out_dir = sys.argv[1], sys.argv[2]
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)

    # operate on the already-patched output HeroInfoLua if present, else original
    src = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')
    if not os.path.exists(src):
        src = os.path.join(orig_dir, 'HeroInfoLua.pkg.bytes')
    out = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base != 'HeroSys_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            patch_onwear_rsp(lf.main.protos[38])
            newdata = L.ser_file(lf)
            L.parse_file(newdata)  # sanity re-parse
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  HeroSys_lua: patched OnWearHeroSkinRsp (proto 38) force-success")

    if not patched:
        print("HeroSys_lua not found"); return

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out} ({os.path.getsize(out)} bytes)")
    print("PATCH v8 COMPLETE")


if __name__ == '__main__':
    main()

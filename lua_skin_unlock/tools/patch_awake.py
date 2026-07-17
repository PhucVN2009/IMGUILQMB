"""
Unlock Evo/Awake skins to MAX level (full bậc 5) — display, client-side.

Awake (Thức Tỉnh) skins have levels 1..N stored in awakeData.bWakeLevel (server
data) + a feature bitmask. The UI reads AwakeSkinSys checks to draw the state.
Force them so every level/feature shows unlocked and the current level = max:
  - IsFeatureUnlock(feature, awake): keep the nil guards, then return true.
  - IsLevelAwaken(awake, level): return true.
  - GetCurrentPromoteLevel(heroSkin): return GetMaxSkinWakeLevel(heroSkin).

IsAllFeatureUnlock iterates IsFeatureUnlock, so it follows automatically.
Runs on systemLua_default.pkg.bytes.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

LOADBOOL, RETURN, GETTABUP, MOVE, CALL = 1, 11, 3, 18, 4


def A(op, a, b, c):
    return L.iABC(op, a, b, c)


def const_idx(proto, name):
    nb = name.encode()
    for i, (t, v) in enumerate(proto.constants):
        if t in (4, 0x14) and v == nb:
            return i
    return None


def patch_is_feature_unlock(p):
    # numparams=2 (feature R0, awake R1); return reg R2. Keep [0..5] nil-guards,
    # replace [6],[7] with: R2=true; return R2.
    assert p.numparams == 2 and len(p.code) >= 8
    p.code[6] = A(LOADBOOL, 2, 1, 0)
    p.code[7] = A(RETURN, 2, 2, 0)


def patch_return_true(p):
    r = p.numparams
    p.code[0] = A(LOADBOOL, r, 1, 0)
    p.code[1] = A(RETURN, r, 2, 0)
    if p.maxstacksize <= r:
        p.maxstacksize = r + 1


def patch_current_level_to_max(p):
    # return AwakeSkinSys.GetMaxSkinWakeLevel(heroSkin).  upval0 = AwakeSkinSys.
    k = const_idx(p, 'GetMaxSkinWakeLevel')
    assert k is not None, 'GetMaxSkinWakeLevel const missing'
    code = [
        A(GETTABUP, 1, 0, k + 256),   # R1 = AwakeSkinSys.GetMaxSkinWakeLevel
        A(MOVE, 2, 0, 0),             # R2 = heroSkin (param R0)
        A(CALL, 1, 2, 2),             # R1 = GetMaxSkinWakeLevel(heroSkin)
        A(RETURN, 1, 2, 0),           # return R1
    ]
    p.code = code
    if p.maxstacksize < 3:
        p.maxstacksize = 3
    if p.lineinfo:
        p.lineinfo = [p.lineinfo[0]] * len(code)


def main():
    orig_dir = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools, 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    src = os.path.join(orig_dir, 'systemLua_default.pkg.bytes')
    out = os.path.join(out_dir, 'systemLua_default.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base != 'AwakeSkinSys_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            patch_is_feature_unlock(lf.main.protos[m['IsFeatureUnlock']])
            patch_return_true(lf.main.protos[m['IsLevelAwaken']])
            patch_current_level_to_max(lf.main.protos[m['GetCurrentPromoteLevel']])
            print(f"  IsFeatureUnlock[{m['IsFeatureUnlock']}] -> true (after nil guards)")
            print(f"  IsLevelAwaken[{m['IsLevelAwaken']}] -> true")
            print(f"  GetCurrentPromoteLevel[{m['GetCurrentPromoteLevel']}] -> max level")
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"-> {out} ({os.path.getsize(out)} bytes)")


if __name__ == '__main__':
    main()

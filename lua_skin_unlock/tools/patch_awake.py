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
SETTABLE, LOADK, GETTABLE = 7, 14, 19


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


def prepend_featureitems_maxlevel(p):
    # GetFeatureItems(heroSkin R0, level R1): overwrite R1 = GetMaxSkinWakeLevel(R0)
    # so the level cap becomes MAX -> returns features for every level. up0=AwakeSkinSys.
    k = const_idx(p, 'GetMaxSkinWakeLevel')
    if k is None:
        k = L.find_or_add_str_const(p, 'GetMaxSkinWakeLevel')
    block = [
        A(GETTABUP, 5, 0, k + 256),   # R5 = AwakeSkinSys.GetMaxSkinWakeLevel
        A(MOVE, 6, 0, 0),             # R6 = heroSkin
        A(CALL, 5, 2, 2),             # R5 = GetMaxSkinWakeLevel(heroSkin)
        A(MOVE, 1, 5, 0),             # R1 = R5  (overwrite the level param)
    ]
    p.code = block + p.code
    if p.maxstacksize < 7:
        p.maxstacksize = 7
    if p.lineinfo:
        p.lineinfo = [p.lineinfo[0]] * len(block) + p.lineinfo


def force_awake_data_max(p):
    # GetOrCreateAwakeSkinData returns the actual CRoleInfo.HeroSkinWakeDatas entry
    # (a C# object). Before returning it, force its fields to MAX so the C# renderer
    # (which reads that object) shows the skin fully evolved everywhere:
    #   entry.bWakeLevel     = GetMaxSkinWakeLevel(heroSkin)
    #   entry.bCurWearLevel  = same
    #   entry.ullWakeFeatureMask = all feature bits
    # up0 = AwakeSkinSys.  Entry is in R1, heroSkin in R0 at the return point.
    k_max = const_idx(p, 'GetMaxSkinWakeLevel') or L.find_or_add_str_const(p, 'GetMaxSkinWakeLevel')
    k_bwl = const_idx(p, 'bWakeLevel')
    k_bcw = const_idx(p, 'bCurWearLevel')
    k_mask = const_idx(p, 'ullWakeFeatureMask')
    k_val = len(p.constants)
    p.constants.append((0x13, struct.pack('<q', 0x7FFFFFFFFFFFFFFF)))  # all feature bits
    block = [
        A(GETTABUP, 2, 0, k_max + 256),   # R2 = AwakeSkinSys.GetMaxSkinWakeLevel
        A(MOVE, 3, 0, 0),                 # R3 = heroSkin
        A(CALL, 2, 2, 2),                 # R2 = max level
        A(SETTABLE, 1, k_bwl + 256, 2),   # entry.bWakeLevel = max
        A(SETTABLE, 1, k_bcw + 256, 2),   # entry.bCurWearLevel = max
        L.iABx(LOADK, 4, k_val),          # R4 = 0x7FFFFFFFFFFFFFFF
        A(SETTABLE, 1, k_mask + 256, 4),  # entry.ullWakeFeatureMask = all bits
    ]
    ins_at = len(p.code) - 2              # right before the final `return entry`
    p.code = p.code[:ins_at] + block + p.code[ins_at:]
    if p.maxstacksize < 5:
        p.maxstacksize = 5
    if p.lineinfo:
        p.lineinfo = p.lineinfo[:ins_at] + [p.lineinfo[ins_at]] * len(block) + p.lineinfo[ins_at:]


def force_on_sync(p):
    # UpdateAwakeSkinData copies the server's real wake level into the entry every
    # sync (undoing our forcing). Append a block that overwrites level/masks to MAX
    # AFTER the server copy, so the entry is always max -> lobby AND battle read max.
    # entry = R1, up0 = AwakeSkinSys. Uses entry.dwWakeSkinID as the skin key.
    k_max = const_idx(p, 'GetMaxSkinWakeLevel') or L.find_or_add_str_const(p, 'GetMaxSkinWakeLevel')
    k_id = const_idx(p, 'dwWakeSkinID')
    k_bwl = const_idx(p, 'bWakeLevel')
    k_bcw = const_idx(p, 'bCurWearLevel')
    k_wm = const_idx(p, 'ullWakeFeatureMask')
    k_wearm = const_idx(p, 'ullWearFeatureMask')
    k_val = len(p.constants)
    p.constants.append((0x13, struct.pack('<q', 0x7FFFFFFFFFFFFFFF)))
    block = [
        A(GETTABUP, 2, 0, k_max + 256),   # R2 = AwakeSkinSys.GetMaxSkinWakeLevel
        A(GETTABLE, 3, 1, k_id + 256),    # R3 = entry.dwWakeSkinID
        A(CALL, 2, 2, 2),                 # R2 = max level
        A(SETTABLE, 1, k_bwl + 256, 2),   # entry.bWakeLevel = max
        A(SETTABLE, 1, k_bcw + 256, 2),   # entry.bCurWearLevel = max
        L.iABx(LOADK, 3, k_val),          # R3 = all-bits
        A(SETTABLE, 1, k_wm + 256, 3),    # entry.ullWakeFeatureMask = all
        A(SETTABLE, 1, k_wearm + 256, 3), # entry.ullWearFeatureMask = all
    ]
    ins_at = len(p.code) - 1              # right before the final RETURN
    n = len(block)
    for i in range(ins_at):               # fix JMPs that cross the insertion point
        ins = p.code[i]
        if (ins & 0x3F) == 20:
            sbx = ((ins >> 14) & 0x3FFFF) - 131071
            if i + 1 + sbx >= ins_at:
                p.code[i] = L.iAsBx(20, (ins >> 6) & 0xFF, sbx + n)
    p.code = p.code[:ins_at] + block + p.code[ins_at:]
    if p.maxstacksize < 4:
        p.maxstacksize = 4
    if p.lineinfo:
        p.lineinfo = p.lineinfo[:ins_at] + [p.lineinfo[ins_at]] * n + p.lineinfo[ins_at:]


def patch_showmodel_use_getorcreate(p):
    # ShowModelFeatures returns early when GetAwakeSkinData is nil (unowned skin) ->
    # no model, "Chưa có tướng, trang phục". Point that call to
    # GetOrCreateAwakeSkinData, which builds default awake data (bWakeLevel=0) so the
    # render proceeds. Only repoint the key const (single-instruction change).
    old = const_idx(p, 'GetAwakeSkinData')
    assert old is not None
    new = const_idx(p, 'GetOrCreateAwakeSkinData')
    if new is None:
        new = L.find_or_add_str_const(p, 'GetOrCreateAwakeSkinData')
    for i, ins in enumerate(p.code):
        op = ins & 0x3F
        C = (ins >> 14) & 0x1FF
        if op == 3 and C >= 256 and (C - 256) == old:   # GETTABUP up[B][GetAwakeSkinData]
            a = (ins >> 6) & 0xFF
            b = (ins >> 23) & 0x1FF
            p.code[i] = L.iABC(3, a, b, new + 256)
            return True
    return False


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
            if base not in ('AwakeSkinSys_lua', 'AwakeSkinHeroView_lua'):
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            if base == 'AwakeSkinSys_lua':
                patch_is_feature_unlock(lf.main.protos[m['IsFeatureUnlock']])
                patch_return_true(lf.main.protos[m['IsLevelAwaken']])
                patch_current_level_to_max(lf.main.protos[m['GetCurrentPromoteLevel']])
                prepend_featureitems_maxlevel(lf.main.protos[m['GetFeatureItems']])
                force_awake_data_max(lf.main.protos[m['GetOrCreateAwakeSkinData']])
                force_on_sync(lf.main.protos[m['UpdateAwakeSkinData']])
                print(f"  IsFeatureUnlock[{m['IsFeatureUnlock']}] -> true (after nil guards)")
                print(f"  IsLevelAwaken[{m['IsLevelAwaken']}] -> true")
                print(f"  GetCurrentPromoteLevel[{m['GetCurrentPromoteLevel']}] -> max level")
                print(f"  GetFeatureItems[{m['GetFeatureItems']}] -> cap at max level (all features)")
                print(f"  GetOrCreateAwakeSkinData[{m['GetOrCreateAwakeSkinData']}] -> force entry fields to MAX")
            else:  # AwakeSkinHeroView_lua
                ok = patch_showmodel_use_getorcreate(lf.main.protos[m['ShowModelFeatures']])
                print(f"  ShowModelFeatures[{m['ShowModelFeatures']}] -> GetOrCreate (render unowned): {ok}")
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

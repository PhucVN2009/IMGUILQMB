"""
Battle effect (Hạ / Biến về / Tăng tốc) equip, client-side.

Like the skin unlock (many files), the "đang dùng" state is read in several
places; here it comes from a per-effect server entry that only exists for OWNED
effects, so an unowned effect can never show equipped and the equip request just
dies at the server.

Approach: keep a local choice map on the Model TABLE itself (require(Model)
returns the same `this` table the Model methods capture, so a field on it is
shared between the System and the Model):
  - rewrite reqChangeBattleEffect(id) to set  Model.__aov_be[id] = true  and
    broadcast CHANGE_BATTLE_EFFECT_RSP_EVENT (which the effect views listen to),
    never touching the network.
  - prepend a guard to isBattleEffectEquipped(id) (the function the element view
    uses for the checkmark): if this.__aov_be[id] then return true.

Only confirmed opcodes are used (GETTABUP reads this[...] directly). Runs on
output/Customization.pkg.bytes.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

GETTABUP, NEWTABLE, RETURN, LOADK, MOVE, GETTABLE, SELF, CALL, SETTABLE, TEST, JMP, LOADBOOL = \
    3, 10, 11, 14, 18, 19, 44, 4, 7, 45, 20, 1


def K(p, s):
    return L.find_or_add_str_const(p, s)


def A(op, a, b, c):
    return L.iABC(op, a, b, c)


def rewrite_req(proto):
    """reqChangeBattleEffect(id) -> Model.__aov_be[id]=true + broadcast, no net."""
    env = L.find_env_upval(proto)
    assert env is not None
    kreq = K(proto, 'require')
    kmodel = K(proto, 'AOV.Customization.BattleEffect.BattleEffectModel')
    ksys = K(proto, 'AOV.Customization.BattleEffect.BattleEffectSystem')
    kov = K(proto, '__aov_be')
    kbc = K(proto, 'BroadCastEvent')
    kev = K(proto, 'CHANGE_BATTLE_EFFECT_RSP_EVENT')
    code = [
        A(GETTABUP, 1, env, kreq + 256),      # R1 = require
        L.iABx(LOADK, 2, kmodel),             # R2 = model path
        A(CALL, 1, 2, 2),                     # R1 = Model (== this table)
        A(GETTABLE, 2, 1, kov + 256),         # R2 = Model.__aov_be
        A(TEST, 2, 0, 1),                     # truthy -> jump over create
        L.iAsBx(JMP, 0, 2),                   # -> skip create (to LOADBOOL)
        A(NEWTABLE, 2, 0, 0),                 # R2 = {}
        A(SETTABLE, 1, kov + 256, 2),         # Model.__aov_be = R2
        A(LOADBOOL, 3, 1, 0),                 # R3 = true
        A(SETTABLE, 2, 0, 3),                 # R2[id] = true   (id = R0)
        A(GETTABUP, 1, env, kreq + 256),      # R1 = require
        L.iABx(LOADK, 2, ksys),               # R2 = system path
        A(CALL, 1, 2, 2),                     # R1 = Sys
        A(SELF, 2, 1, kbc + 256),             # R2 = Sys.BroadCastEvent ; R3 = Sys
        A(GETTABLE, 4, 1, kev + 256),         # R4 = Sys.CHANGE_BATTLE_EFFECT_RSP_EVENT
        A(NEWTABLE, 5, 0, 0),                 # R5 = {}
        A(CALL, 2, 4, 1),                     # Sys:BroadCastEvent(event, {})
        A(RETURN, 0, 1, 0),
    ]
    proto.code = code
    if proto.maxstacksize < 6:
        proto.maxstacksize = 6
    if proto.lineinfo:
        proto.lineinfo = [proto.lineinfo[0]] * len(code)


def prepend_equipped_guard(proto):
    """isBattleEffectEquipped(id): if this.__aov_be[id] then return true. this=upval0."""
    kov = K(proto, '__aov_be')
    n = 8  # length of the prepended block; original code starts at index n
    block = [
        A(GETTABUP, 2, 0, kov + 256),   # [0] R2 = this.__aov_be   (upval0 = 'this')
        A(TEST, 2, 0, 0),               # [1] ov falsy -> take JMP to ORIG
        L.iAsBx(JMP, 0, n - 3),         # [2] -> ORIG (index n)
        A(GETTABLE, 3, 2, 0),           # [3] R3 = ov[id]   (id = R0)
        A(TEST, 3, 0, 0),               # [4] ov[id] falsy -> take JMP to ORIG
        L.iAsBx(JMP, 0, n - 6),         # [5] -> ORIG (index n)
        A(LOADBOOL, 2, 1, 0),           # [6] R2 = true
        A(RETURN, 2, 2, 0),             # [7] return true
    ]
    proto.code = block + proto.code
    if proto.maxstacksize < 4:
        proto.maxstacksize = 4
    if proto.lineinfo:
        proto.lineinfo = [proto.lineinfo[0]] * n + proto.lineinfo


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools, 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    src = os.path.join(out_dir, 'Customization.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base not in ('BattleEffectSystem_lua', 'BattleEffectModel_lua'):
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            if base == 'BattleEffectSystem_lua':
                rewrite_req(lf.main.protos[m['reqChangeBattleEffect']])
                print(f"  reqChangeBattleEffect[{m['reqChangeBattleEffect']}] -> local choice + broadcast")
            else:
                prepend_equipped_guard(lf.main.protos[m['isBattleEffectEquipped']])
                print(f"  isBattleEffectEquipped[{m['isBattleEffectEquipped']}] -> honors local choice")
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

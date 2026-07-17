"""
Patch v2 (local-apply): make equipping work WITHOUT the server.

The equip request round-trips to the server, which rejects unowned items and
never sends a usable response -> the loading spinner spins and nothing applies.

So instead of forcing the (never-run) response handler, we REWRITE the request
function to apply the change locally (via the Model's own setter) and broadcast
the refresh event, then return -- never touching the network. Fully client-side.

Starts with Soldier Skin (simplest: single-id local setter
`updateServerWearSoldierSkinId`). Built on output/Customization.pkg.bytes.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

# game opcodes
GETTABUP, NEWTABLE, RETURN, LOADK, MOVE, GETTABLE, SELF, CALL = 3, 10, 11, 14, 18, 19, 44, 4


def K(proto, s):
    return L.find_or_add_str_const(proto, s)


def rewrite_soldier(proto):
    env = L.find_env_upval(proto)
    assert env is not None
    k_req = K(proto, 'require')
    k_model = K(proto, 'AOV.Customization.SoldierSkin.SoldierSkinModel')
    k_sys = K(proto, 'AOV.Customization.SoldierSkin.SoldierSkinSystem')
    k_set = K(proto, 'updateServerWearSoldierSkinId')
    k_bcast = K(proto, 'BroadCastEvent')
    k_evt = K(proto, 'SOLDIER_SKIN_WEAR_RSP_EVENT')
    A = L.iABC
    code = [
        A(GETTABUP, 1, env, k_req + 256),          # R1 = require
        L.iABx(LOADK, 2, k_model),                 # R2 = model path
        A(CALL, 1, 2, 2),                          # R1 = require(path) = Model
        A(GETTABLE, 2, 1, k_set + 256),            # R2 = Model.updateServerWearSoldierSkinId
        A(MOVE, 3, 0, 0),                          # R3 = skinId (param R0)
        A(CALL, 2, 2, 1),                          # Model.updateServerWearSoldierSkinId(skinId)
        A(GETTABUP, 1, env, k_req + 256),          # R1 = require
        L.iABx(LOADK, 2, k_sys),                   # R2 = system path
        A(CALL, 1, 2, 2),                          # R1 = SS
        A(SELF, 2, 1, k_bcast + 256),              # R2 = SS.BroadCastEvent ; R3 = SS
        A(GETTABLE, 4, 1, k_evt + 256),            # R4 = SS.SOLDIER_SKIN_WEAR_RSP_EVENT
        A(NEWTABLE, 5, 0, 0),                      # R5 = {}
        A(CALL, 2, 4, 1),                          # SS:BroadCastEvent(event, {})
        A(RETURN, 0, 1, 0),                        # return
    ]
    proto.code = code
    if proto.maxstacksize < 6:
        proto.maxstacksize = 6
    if proto.lineinfo:
        proto.lineinfo = [proto.lineinfo[0]] * len(code)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools, 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    src = os.path.join(out_dir, 'Customization.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base != 'SoldierSkinSystem_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            rewrite_soldier(lf.main.protos[m['reqWearSoldierSkin']])
            print(f"  SoldierSkinSystem.reqWearSoldierSkin[{m['reqWearSoldierSkin']}] -> local apply + broadcast")
            newdata = L.ser_file(lf)
            L.parse_file(newdata)  # round-trip sanity
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

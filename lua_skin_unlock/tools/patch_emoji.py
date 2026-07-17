"""
Emoji local-apply: make equipping an emoji into a slot work client-side.

reqChangeBattleEmoji(slotType, index, emojiId) round-trips to the server, which
rejects an unowned emoji and never pushes the update Ntf -> slot stays empty.

The slot state lives in BattleEffectModel as data.slotTypeToEmojiIds[slotType]
(a fixed-length list, returned BY REFERENCE from getBattleEmojiIdListBySlotType).
So we rewrite reqChangeBattleEmoji to mutate that list in place
(list[index] = emojiId) and broadcast the refresh event, never touching the
network. Fully client-side. If the slot list doesn't exist the write is skipped
(harmless no-op).

Ownership of emojis in the grid/batch filter already reads isBattleEffectOwned,
which patch_cust forces true, so the grid shows them and batch-apply includes
them. Runs on output/Customization.pkg.bytes.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

GETTABUP, NEWTABLE, RETURN, LOADK, MOVE, GETTABLE, SELF, CALL, SETTABLE, TEST = \
    3, 10, 11, 14, 18, 19, 44, 4, 7, 45


def K(proto, s):
    return L.find_or_add_str_const(proto, s)


def rewrite_emoji(proto):
    env = L.find_env_upval(proto)
    assert env is not None
    k_req = K(proto, 'require')
    k_model = K(proto, 'AOV.Customization.BattleEffect.BattleEffectModel')
    k_sys = K(proto, 'AOV.Customization.BattleEffect.BattleEffectSystem')
    k_getlist = K(proto, 'getBattleEmojiIdListBySlotType')
    k_bcast = K(proto, 'BroadCastEvent')
    k_evt = K(proto, 'CHANGE_BATTLE_EMOJI_RSP_EVENT')
    A = L.iABC
    # params: R0=slotType, R1=index, R2=emojiId
    code = [
        A(GETTABUP, 3, env, k_req + 256),        # R3 = require
        L.iABx(LOADK, 4, k_model),               # R4 = model path
        A(CALL, 3, 2, 2),                        # R3 = Model
        A(GETTABLE, 4, 3, k_getlist + 256),      # R4 = Model.getBattleEmojiIdListBySlotType
        A(MOVE, 5, 0, 0),                        # R5 = slotType
        A(CALL, 4, 2, 2),                        # R4 = list (by ref)
        A(TEST, 4, 0, 1),                        # if list is falsy -> skip the SETTABLE
        A(SETTABLE, 4, 1, 2),                    # list[index] = emojiId
        A(GETTABUP, 3, env, k_req + 256),        # R3 = require
        L.iABx(LOADK, 4, k_sys),                 # R4 = system path
        A(CALL, 3, 2, 2),                        # R3 = Sys
        A(SELF, 4, 3, k_bcast + 256),            # R4 = Sys.BroadCastEvent ; R5 = Sys
        A(GETTABLE, 6, 3, k_evt + 256),          # R6 = Sys.CHANGE_BATTLE_EMOJI_RSP_EVENT
        A(NEWTABLE, 7, 0, 0),                    # R7 = {}
        A(CALL, 4, 4, 1),                        # Sys:BroadCastEvent(event, {})
        A(RETURN, 0, 1, 0),
    ]
    proto.code = code
    if proto.maxstacksize < 8:
        proto.maxstacksize = 8
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
            if base != 'BattleEffectSystem_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            rewrite_emoji(lf.main.protos[m['reqChangeBattleEmoji']])
            print(f"  BattleEffectSystem.reqChangeBattleEmoji[{m['reqChangeBattleEmoji']}] -> local slot apply + broadcast")
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

"""
Patch: make Customization items EQUIPPABLE / UN-equippable client-side.

Problem: items are unlocked (ownership funcs patched) but equipping fails because
the equip request round-trips to the server, which rejects unowned items; the
response handler then skips the client-side apply because its success gate
(LogicUtil.isRspOK / bIsSucc) reports failure.

Fix (v8 style, client-only): force the success gate in the EQUIP / CHANGE /
REMOVE response handlers so the client applies the change regardless of the
server result. Purchase (buy) handlers are deliberately NOT touched, so real
currency flows keep their error handling. If the server sends no usable data,
the existing null-checks make the forced path a harmless no-op (no corruption).

Transforms:
  T1 (isRspOK gate): find GETTABLE/GETTABUP that loads the 'isRspOK' constant
     into reg R, then force the following CALL(result=R) to LOADBOOL R,true.
  T2 (bIsSucc gate, onChangeBattleEffectRsp): neutralise the failure JMP that
     guards the apply region so the success path always runs.

Runs on output/Customization.pkg.bytes (keeps v6 + the 10 ownership patches).
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

OP_LOADBOOL, OP_GETTABUP, OP_CALL, OP_RETURN, OP_JMP, OP_GETTABLE, OP_TEST = 1, 3, 4, 11, 20, 19, 45


def iABC(op, a, b, c):
    return L.iABC(op, a, b, c)


def iAsBx(op, a, sbx):
    return L.iAsBx(op, a, sbx)


# functions whose success gate is LogicUtil.isRspOK -> force true
T1 = {
    'BattleEffectSystem_lua': ['onChangeBattleEmojiRsp', 'onChangeBatchBattleEmojiRsp',
                               'onRandomEquipBattleEffectRsp'],
    'HeroCostumeSystem_lua': ['onEquipSkinCostumeRsp', 'onRemoveSkinCostumeRsp'],
    'HeroMotionSystem_lua': ['onEquipSkinMotionRsp', 'onRemoveSkinMotionRsp', 'onSyncSkinMotionRsp'],
}
# functions whose success gate is bIsSucc -> neutralise guard JMP
T2 = {
    'BattleEffectSystem_lua': ['onChangeBattleEffectRsp'],
}


def const_indices(proto, name):
    return {i for i, (t, v) in enumerate(proto.constants)
            if t in (4, 0x14) and v.decode('utf-8', 'replace') == name}


def force_isrspok(proto):
    ki = const_indices(proto, 'isRspOK')
    if not ki:
        return False
    for j, ins in enumerate(proto.code):
        op = ins & 0x3F
        A = (ins >> 6) & 0xFF
        C = (ins >> 14) & 0x1FF
        if op in (OP_GETTABLE, OP_GETTABUP) and (C - 256) in ki:
            R = A
            for k in range(j + 1, min(j + 8, len(proto.code))):
                ck = proto.code[k]
                if (ck & 0x3F) == OP_CALL and ((ck >> 6) & 0xFF) == R:
                    proto.code[k] = iABC(OP_LOADBOOL, R, 1, 0)
                    return True
    return False


def force_bissucc(proto):
    # locate the success boolean's guarding TEST+JMP that protects the apply
    # region (the one whose JMP jumps far forward to the error/return tail).
    # We find the TEST whose register is the success flag derived from bIsSucc,
    # then blank the following JMP so both branches reach the apply code.
    ki = const_indices(proto, 'bIsSucc')
    if not ki:
        return False
    # find the first TEST followed by a forward JMP (sBx>3) after the bIsSucc read
    start = 0
    for j, ins in enumerate(proto.code):
        if (ins & 0x3F) == OP_GETTABLE and ((ins >> 14) & 0x1FF) - 256 in ki:
            start = j
            break
    for j in range(start, len(proto.code) - 1):
        if (proto.code[j] & 0x3F) == OP_TEST:
            nxt = proto.code[j + 1]
            if (nxt & 0x3F) == OP_JMP:
                sbx = ((nxt >> 14) & 0x3FFFF) - 131071
                if sbx > 3:  # a real forward skip to the tail
                    proto.code[j + 1] = iAsBx(OP_JMP, 0, 0)
                    return True
    return False


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools, 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    src = os.path.join(out_dir, 'Customization.pkg.bytes')
    out = src

    patched = {}
    total = 0
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base not in T1 and base not in T2:
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            changed = False
            for fn in T1.get(base, []):
                if fn in m and force_isrspok(lf.main.protos[m[fn]]):
                    print(f"  {base}.{fn} -> isRspOK forced true (proto[{m[fn]}])")
                    total += 1
                    changed = True
                else:
                    print(f"  !! {base}.{fn} NOT patched (isRspOK)")
            for fn in T2.get(base, []):
                if fn in m and force_bissucc(lf.main.protos[m[fn]]):
                    print(f"  {base}.{fn} -> success gate neutralised (proto[{m[fn]}])")
                    total += 1
                    changed = True
                else:
                    print(f"  !! {base}.{fn} NOT patched (bIsSucc)")
            if not changed:
                continue
            newdata = L.ser_file(lf)
            L.parse_file(newdata)  # sanity round-trip
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"\nForced {total} equip/change/remove handlers across {len(patched)} files.")
    print(f"-> {out} ({os.path.getsize(out)} bytes)")


if __name__ == '__main__':
    main()

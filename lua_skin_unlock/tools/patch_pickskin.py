"""
IN-BATTLE skin via Lua: write CHeroSelectBaseSystem.instance.m_selectSkinIDList.

The skin sent to battle comes from selectSkinIDList in SendSinglePrepareToBattleMsg,
whose source is the public field CHeroSelectBaseSystem.instance.m_selectSkinIDList
(a C# List<uint> on a Lua-reachable singleton). By writing that list to the skin
the player is viewing in the pick "Tr.phục" tab, the lock-in message carries that
skin -> battle renders it (skins are cosmetic; server trusts the client's choice).

We append to PickHeroCustomizationButtonsView.onSkinChanged(self, skinId, ...):
    local inst = N.CHeroSelectBaseSystem.instance
    if inst then local list = inst.m_selectSkinIDList
        if list then list[0] = skinId end
    end
Guarded with nil checks. (PoC: index 0 = local/single player.)
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

GETTABUP, GETTABLE, SETTABLE, TEST, JMP, RETURN = 3, 19, 7, 45, 20, 11


def A(op, a, b, c):
    return L.iABC(op, a, b, c)


def cidx(p, name):
    nb = name.encode()
    for i, (t, v) in enumerate(p.constants):
        if t in (4, 0x14) and v == nb:
            return i
    return L.find_or_add_str_const(p, name)


def patch_onskinchanged(p):
    env = L.find_env_upval(p)
    assert env is not None
    kN = cidx(p, 'N')
    kCH = cidx(p, 'CHeroSelectBaseSystem')
    kInst = cidx(p, 'instance')
    kList = cidx(p, 'm_selectSkinIDList')
    kInt0 = len(p.constants)
    p.constants.append((0x13, struct.pack('<q', 0)))  # integer key 0
    # skinId is param R1. Use scratch R5, R6.
    block = [
        A(GETTABUP, 5, env, kN + 256),      # R5 = N
        A(GETTABLE, 5, 5, kCH + 256),       # R5 = N.CHeroSelectBaseSystem
        A(GETTABLE, 5, 5, kInst + 256),     # R5 = .instance
        A(TEST, 5, 0, 0),                   # inst nil -> jump to RETURN
        L.iAsBx(JMP, 0, 4),                 # -> RETURN (over the 4 following)
        A(GETTABLE, 6, 5, kList + 256),     # R6 = inst.m_selectSkinIDList
        A(TEST, 6, 0, 0),                   # list nil -> jump to RETURN
        L.iAsBx(JMP, 0, 1),                 # -> RETURN
        A(SETTABLE, 6, kInt0 + 256, 1),     # list[0] = skinId (R1)
    ]
    ins_at = len(p.code) - 1                # before the final RETURN
    # (no existing jumps target ins_at; verified for onSkinChanged)
    p.code = p.code[:ins_at] + block + p.code[ins_at:]
    if p.maxstacksize < 7:
        p.maxstacksize = 7
    if p.lineinfo:
        p.lineinfo = p.lineinfo[:ins_at] + [p.lineinfo[ins_at]] * len(block) + p.lineinfo[ins_at:]


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools, 'zstd_dict.bin'), 'rb').read(), is_raw=True)
    src = os.path.join(out_dir, 'Customization.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base != 'PickHeroCustomizationButtonsView_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            patch_onskinchanged(lf.main.protos[m['onSkinChanged']])
            print(f"  onSkinChanged[{m['onSkinChanged']}] -> write m_selectSkinIDList[0] = skinId")
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

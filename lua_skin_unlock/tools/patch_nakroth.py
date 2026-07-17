"""
FOCUSED TEST: force hero 150 (Nakroth) -> skin 15009 in the pick selection.

Injects into PickHeroCustomizationButtonsView.onSkinChanged a robust write:
  local sys = N.CHeroSelectBaseSystem.instance
  if sys then
    local hl = sys.m_selectHeroIDList
    local sl = sys.m_selectSkinIDList
    if hl and sl then
      for i=0,9 do if hl[i]==150 then sl[i]=15009 end end   -- unrolled
    end
  end
Targets the slot actually holding Nakroth (not hardcoded [0]) and forces 15009
regardless of which skin was clicked. Only for testing whether the pick-screen
selection survives to battle.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

GETTABUP, GETTABLE, SETTABLE, TEST, JMP, LOADK, EQ, RETURN = 3, 19, 7, 45, 20, 14, 15, 11
HERO = 150
SKIN = 15009
NSLOT = 10

def A(op, a, b, c): return L.iABC(op, a, b, c)

def sidx(p, name):
    nb = name.encode()
    for i, (t, v) in enumerate(p.constants):
        if t in (4, 0x14) and v == nb: return i
    return L.find_or_add_str_const(p, name)

def iconst(p, n):
    b = struct.pack('<q', n)
    for i, (t, v) in enumerate(p.constants):
        if t == 0x13 and v == b: return i
    p.constants.append((0x13, b)); return len(p.constants) - 1

def patch(p):
    env = L.find_env_upval(p); assert env is not None
    kN, kCH, kInst = sidx(p,'N'), sidx(p,'CHeroSelectBaseSystem'), sidx(p,'instance')
    kHL, kSL = sidx(p,'m_selectHeroIDList'), sidx(p,'m_selectSkinIDList')
    kHero, kSkin = iconst(p, HERO), iconst(p, SKIN)
    kI = [iconst(p, i) for i in range(NSLOT)]

    blk = []
    guard_jmps = []
    blk.append(A(GETTABUP, 5, env, kN + 256))     # R5 = N
    blk.append(A(GETTABLE, 5, 5, kCH + 256))      # R5 = .CHeroSelectBaseSystem
    blk.append(A(GETTABLE, 5, 5, kInst + 256))    # R5 = .instance
    blk.append(A(TEST, 5, 0, 0)); guard_jmps.append(len(blk)); blk.append(0)  # if nil -> END
    blk.append(A(GETTABLE, 6, 5, kHL + 256))      # R6 = hl
    blk.append(A(TEST, 6, 0, 0)); guard_jmps.append(len(blk)); blk.append(0)
    blk.append(A(GETTABLE, 7, 5, kSL + 256))      # R7 = sl
    blk.append(A(TEST, 7, 0, 0)); guard_jmps.append(len(blk)); blk.append(0)
    blk.append(L.iABx(LOADK, 8, kSkin))           # R8 = 15009
    for i in range(NSLOT):
        blk.append(A(GETTABLE, 9, 6, kI[i] + 256))  # R9 = hl[i]
        blk.append(A(EQ, 0, 9, kHero + 256))        # if R9==150: fall to SETTABLE
        blk.append(L.iAsBx(JMP, 0, 1))              # else skip SETTABLE
        blk.append(A(SETTABLE, 7, kI[i] + 256, 8))  # sl[i] = 15009
    END = len(blk)  # RETURN sits right after the block
    for gj in guard_jmps:
        blk[gj] = L.iAsBx(JMP, 0, END - (gj + 1))

    ins_at = len(p.code) - 1  # before final RETURN
    # fix any existing JMP whose absolute target lands at/after the insertion
    for i in range(ins_at):
        if (p.code[i] & 0x3F) == JMP:
            sbx = ((p.code[i] >> 14) & 0x3FFFF) - 131071
            tgt = i + 1 + sbx
            if tgt >= ins_at:
                a = (p.code[i] >> 6) & 0xFF
                p.code[i] = L.iAsBx(JMP, a, sbx + len(blk))
    p.code = p.code[:ins_at] + blk + p.code[ins_at:]
    if p.maxstacksize < 10: p.maxstacksize = 10
    if p.lineinfo:
        p.lineinfo = p.lineinfo[:ins_at] + [p.lineinfo[ins_at]] * len(blk) + p.lineinfo[ins_at:]
    return len(blk)

def main():
    out_dir = sys.argv[1]
    src_dir = sys.argv[2]
    tools = os.path.dirname(os.path.abspath(__file__))
    zdict = pyzstd.ZstdDict(open(os.path.join(tools,'zstd_dict.bin'),'rb').read(), is_raw=True)
    os.makedirs(out_dir, exist_ok=True)
    src = os.path.join(src_dir, 'Customization.pkg.bytes')
    patched = {}
    with zipfile.ZipFile(src,'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1] != 'PickHeroCustomizationButtonsView_lua.bytes':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4]==b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            m = map_methods(lf)
            n = patch(lf.main.protos[m['onSkinChanged']])
            newdata = L.ser_file(lf)
            L.parse_file(newdata)  # round-trip check
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  onSkinChanged[{m['onSkinChanged']}] -> +{n} instr, force hero {HERO}=skin {SKIN}")
    dst = os.path.join(out_dir,'Customization.pkg.bytes')
    buf = io.BytesIO()
    with zipfile.ZipFile(src,'r') as zin, zipfile.ZipFile(buf,'w',zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    open(dst,'wb').write(buf.getvalue())
    print(f"-> {dst} ({os.path.getsize(dst)} bytes)")

if __name__ == '__main__':
    main()

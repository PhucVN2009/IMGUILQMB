"""
Patch: unlock ALL Customization items (battle effect, emoji, billboard, costume,
motion, personal button, soldier skin) by forcing the central ownership
functions in the Customization *Model* Lua files to report OWNED.

Views and Helpers all call these Model methods, so patching the models unlocks
everything. Method->proto mapping is recovered from the Class binding in main
(CLOSURE op12 R, proto[i]; SETTABLE class[name]=R).

Each target function is turned into an early `return true` (return false for
*NotOwned predicates), like the v5 HeroModel patches.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd

OP_CLOSURE_GAME = 12
OP_LOADBOOL = 1
OP_RETURN = 11


def iABC(op, a, b, c):
    return L.iABC(op, a, b, c)


def map_methods(lf):
    mp = lf.main
    cs = {i: v for i, (t, v) in enumerate(mp.constants) if t in (4, 0x14)}
    out = {}
    pend = None
    for ins in mp.code:
        op = ins & 0x3F
        A = (ins >> 6) & 0xFF
        Bx = (ins >> 14) & 0x3FFFF
        B = (ins >> 23) & 0x1FF
        C = (ins >> 14) & 0x1FF
        if op == OP_CLOSURE_GAME:
            pend = (A, Bx)
        elif op in (7, 8) and pend is not None:
            k = (B - 256) if B >= 256 else None
            if k in cs and C == pend[0]:
                out[cs[k].decode('utf-8', 'replace')] = pend[1]
            pend = None
    return out


def classify(name):
    if 'NotOwned' in name:
        return False
    if name.endswith('Owned') or name in ('isOwn', 'isOwned'):
        return True
    if name.startswith('hasOwned'):
        return True
    if name in ('IsFeatureUnlock', 'FucIsUnlock') or name.startswith('isAwakeFeatureUnlock'):
        return True
    return None


def patch_return_bool(proto, val):
    r = proto.numparams
    proto.code[0] = iABC(OP_LOADBOOL, r, 1 if val else 0, 0)
    proto.code[1] = iABC(OP_RETURN, r, 2, 0)
    if proto.maxstacksize <= r:
        proto.maxstacksize = r + 1


def main():
    orig_dir = sys.argv[1] if len(sys.argv) > 1 else \
        '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
    out_dir = sys.argv[2] if len(sys.argv) > 2 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)

    # build on the already-patched output Customization (keeps v6), else original
    src = os.path.join(out_dir, 'Customization.pkg.bytes')
    if not os.path.exists(src):
        src = os.path.join(orig_dir, 'Customization.pkg.bytes')
    out = os.path.join(out_dir, 'Customization.pkg.bytes')

    patched = {}
    total = 0
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            if b'\x1bLua' not in data:
                continue
            try:
                lf = L.parse_file(data)
            except Exception:
                continue
            m = map_methods(lf)
            targets = {name: (classify(name), idx) for name, idx in m.items() if classify(name) is not None}
            if not targets:
                continue
            for name, (val, idx) in sorted(targets.items()):
                patch_return_bool(lf.main.protos[idx], val)
                print(f"  {base}.{name} -> return {val}  (proto[{idx}])")
                total += 1
            newdata = L.ser_file(lf)
            L.parse_file(newdata)  # sanity
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"\nPatched {total} ownership functions across {len(patched)} files.")
    print(f"-> {out} ({os.path.getsize(out)} bytes)")


if __name__ == '__main__':
    main()

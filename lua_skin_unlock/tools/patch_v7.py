"""
Patch v7: Inject a call to OnGmAddAllSkin() at screen-init points.

This is the real mechanism behind pure-Lua full-skin mods. `CRoleInfo` (C#)
stores owned skins in `m_ownSkinIdList`; every screen (Lua UI and the C#
HeroSelectBanPickWindow / shop) reads ownership from it. The C# method
`CRoleInfo.OnGmAddAllSkin()` populates that list with ALL skins. It is public,
so Lua can call it.

We inject, at the top of each target screen's awake/init function:

    if CRoleInfoManager.instance:GetMasterRoleInfo() then
        CRoleInfoManager.instance:GetMasterRoleInfo():OnGmAddAllSkin()
    end

Once it runs, IsHaveHeroSkin/GetSkinOwnState return owned everywhere, so pick,
shop, profile and lobby all show/allow all skins (client-side).

Injection points (awake functions verified to register UI events / use role
info, and to have an _ENV upvalue):
  LowFrequency  :: LeftHeroListView :: proto 1   (in-match hero/skin pick)
  MallLua       :: MallSystem       :: proto 0   (shop)
  HeroInfoLua   :: HeroSys          :: proto 7   (lobby hero system)
  HeroInfoLua   :: HeroInfoView     :: proto 2   (lobby hero page)
  PlayerInfoLua :: HomePageChangeHeroView :: proto 1 (profile hero/skin change)

Layering: HeroInfoLua/MallLua/PlayerInfoLua inputs are the already v5/v6-patched
outputs (UI display patches kept as a fallback); LowFrequency starts from the
original package.
"""
import struct
import os
import sys
import zipfile
import io

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L

import pyzstd


# (source_pkg_path_key, entry_basename, proto_index)
# source_pkg_path_key: 'output' = use lua_skin_unlock/output (already patched),
#                      'orig'   = use the original aov_files dir.
INJECTIONS = [
    ('orig',   'LowFrequency',  'LeftHeroListView_lua',       1),
    ('output', 'MallLua',       'MallSystem_lua',             0),
    ('output', 'HeroInfoLua',   'HeroSys_lua',                7),
    ('output', 'HeroInfoLua',   'HeroInfoView_lua',           2),
    ('output', 'PlayerInfoLua', 'HomePageChangeHeroView_lua', 1),
]


def load_zdict():
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin')
    return pyzstd.ZstdDict(open(p, 'rb').read(), is_raw=True)


def inject_entry(data, proto_index):
    lf = L.parse_file(data)
    if proto_index >= len(lf.main.protos):
        raise ValueError("proto index %d out of range (%d)" % (proto_index, len(lf.main.protos)))
    L.inject_add_all_skin(lf.main.protos[proto_index])
    out = L.ser_file(lf)
    # sanity: must re-parse
    L.parse_file(out)
    return out


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 patch_v7.py <aov_files_dir> <output_dir>")
        sys.exit(1)
    orig_dir = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    zdict = load_zdict()

    # group injections by package
    by_pkg = {}
    for srckey, pkg, base, pi in INJECTIONS:
        by_pkg.setdefault(pkg, {'srckey': srckey, 'files': {}})
        by_pkg[pkg]['files'][base] = pi

    for pkg, info in by_pkg.items():
        srckey = info['srckey']
        src = os.path.join(out_dir if srckey == 'output' else orig_dir, f'{pkg}.pkg.bytes')
        if not os.path.exists(src):
            # fall back to original if output not present yet
            src = os.path.join(orig_dir, f'{pkg}.pkg.bytes')
        out = os.path.join(out_dir, f'{pkg}.pkg.bytes')
        print(f"\n{'='*60}\nPACKAGE: {pkg}.pkg.bytes (src={src})")

        patched = {}
        with zipfile.ZipFile(src, 'r') as zf:
            for item in zf.infolist():
                base = item.filename.split('/')[-1].replace('.bytes', '')
                if base not in info['files']:
                    continue
                raw = zf.read(item.filename)
                if raw[:4] == b'\x22\x4a\x00\xef':
                    data = pyzstd.decompress(raw[8:], zdict)
                else:
                    data = raw
                pi = info['files'][base]
                newdata = inject_entry(data, pi)
                comp = pyzstd.compress(newdata, 17, zdict)
                assert pyzstd.decompress(comp, zdict) == newdata
                patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
                print(f"  {base}: injected @proto[{pi}]  ({len(data)}->{len(newdata)} bytes lua)")

        if not patched:
            print("  (no targets)")
            continue

        buf = io.BytesIO()
        with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
            for item in zin.infolist():
                if item.filename in patched:
                    zout.writestr(item, patched[item.filename])
                else:
                    zout.writestr(item, zin.read(item.filename))
        with open(out, 'wb') as f:
            f.write(buf.getvalue())
        print(f"  -> {out} ({os.path.getsize(out)} bytes)")

    print(f"\n{'='*60}\nPATCH v7 COMPLETE")


if __name__ == '__main__':
    main()

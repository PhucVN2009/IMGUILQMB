"""
Patch v6: Extend skin-unlock UI display to Profile, Pick, and Shop screens.

v5 only patched HeroInfoLua (lobby). v6 adds three more packages so skins
also show as owned on the personal-profile / in-match pick screen and in
the shop. Same safe strategy: NOP the SELF+args+CALL of an ownership check
and drop LOADBOOL true at the CALL slot, leaving all EQ/JMP/TEST intact.

IMPORTANT LIMITATION (menu-cosmetic only):
IsHaveHeroSkin / IsCanUseSkin / WearSkinId are C# (il2cpp) methods, not Lua
functions. Patching Lua callers only changes each screen's *display*. It does
NOT make skins usable in a real match ("Tr.phuc khong ton tai" on Use), and
does not change server-validated ownership. Real in-match skins require the
il2cpp/protocol approach (modskin.h).

Packages patched:
- PlayerInfoLua.pkg.bytes  : HomePageChangeHeroView (profile / pick skin list)
- Customization.pkg.bytes  : HeroCostumeModel       (shared costume model)
- MallLua.pkg.bytes        : MallExchangeSubView, UIBuySkin3DView (shop display)

Skipped (unsafe EQ-against-Owned or buy-flow logic):
- MallBuyItemDetailView (EQ vs Owned), UIBuySkin3DView SourcePlanEXP buy checks.
"""
import struct
import os
import sys
import zipfile
import io

# Reuse the v5 core (parse_proto, encoders, helpers)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from patch_v5 import (
    parse_proto, parse_lua_header, set_instr, get_instr, nop_range,
    loadbool, verify_const, NOP, encode_iABC, encode_iABx,
)


# ---- (package, file) -> patch function ----

def patch_homepage_change_hero(data, main_proto, si, ss, sii, sn):
    """PlayerInfoLua/HomePageChangeHeroView Proto[10]: IsHaveHeroSkin -> true."""
    p = main_proto.children[10]
    verify_const(p, 15, 'string', 'IsHaveHeroSkin')
    # SELF[27] GETTABLE[28] GETTABLE[29] CALL[30], TEST[31]
    nop_range(data, p, 27, 30)
    set_instr(data, p, 30, loadbool(9, 1))
    print(f"    Proto[10] IsHaveHeroSkin: NOP [27-29], [30] LOADBOOL R9,1")
    return 1


def patch_hero_costume_model(data, main_proto, si, ss, sii, sn):
    """Customization/HeroCostumeModel Proto[6]: GetHero/GetSkinOwnState -> non-UnOwned."""
    p = main_proto.children[6]
    verify_const(p, 8, 'string', 'GetHeroOwnState')
    verify_const(p, 11, 'string', 'GetSkinOwnState')
    verify_const(p, 10, 'string', 'UnOwned')
    # GetHeroOwnState SELF[18] MOVE[19] CALL[20], EQ vs UnOwned
    nop_range(data, p, 18, 20)
    set_instr(data, p, 20, loadbool(6, 1))
    # GetSkinOwnState SELF[28] MOVE[29] CALL[30], EQ vs UnOwned
    nop_range(data, p, 28, 30)
    set_instr(data, p, 30, loadbool(7, 1))
    print(f"    Proto[6] GetHeroOwnState: NOP [18-19], [20] LOADBOOL R6,1")
    print(f"    Proto[6] GetSkinOwnState: NOP [28-29], [30] LOADBOOL R7,1")
    return 2


def patch_mall_exchange_sub(data, main_proto, si, ss, sii, sn):
    """MallLua/MallExchangeSubView Proto[4] IsHaveHero, Proto[5] IsHaveHeroSkin -> true."""
    count = 0
    p4 = main_proto.children[4]
    verify_const(p4, 61, 'string', 'IsHaveHero')
    # SELF[191] GETTABLE[192] LOADBOOL[193] CALL[194], TEST[195]
    nop_range(data, p4, 191, 194)
    set_instr(data, p4, 194, loadbool(12, 1))
    print(f"    Proto[4] IsHaveHero: NOP [191-193], [194] LOADBOOL R12,1")
    count += 1

    p5 = main_proto.children[5]
    verify_const(p5, 65, 'string', 'IsHaveHeroSkin')
    # SELF[199] GETTABLE[200] GETTABLE[201] CALL[202], TEST[203]
    nop_range(data, p5, 199, 202)
    set_instr(data, p5, 202, loadbool(13, 1))
    print(f"    Proto[5] IsHaveHeroSkin: NOP [199-201], [202] LOADBOOL R13,1")
    count += 1
    return count


def patch_ui_buy_skin_3d(data, main_proto, si, ss, sii, sn):
    """MallLua/UIBuySkin3DView Proto[3]: IsHaveHeroSkin -> true (owned display only)."""
    p = main_proto.children[3]
    verify_const(p, 52, 'string', 'IsHaveHeroSkin')
    # SELF[190] MOVE[191] MOVE[192] LOADBOOL[193] CALL[194], TEST[195]
    nop_range(data, p, 190, 194)
    set_instr(data, p, 194, loadbool(22, 1))
    print(f"    Proto[3] IsHaveHeroSkin: NOP [190-193], [194] LOADBOOL R22,1")
    return 1


# package -> { file_basename -> patch_fn }
PACKAGE_MAP = {
    'PlayerInfoLua': {
        'HomePageChangeHeroView_lua': patch_homepage_change_hero,
    },
    'Customization': {
        'HeroCostumeModel_lua': patch_hero_costume_model,
    },
    'MallLua': {
        'MallExchangeSubView_lua': patch_mall_exchange_sub,
        'UIBuySkin3DView_lua': patch_ui_buy_skin_3d,
    },
}


def patch_lua_file(data, basename, patch_fn):
    data = bytearray(data)
    offset, si, ss, sii, sn = parse_lua_header(data)
    main_proto = parse_proto(data, offset, si, ss, sii, sn)
    print(f"\n  {basename} ({len(data)} bytes, {len(main_proto.children)} children)")
    n = patch_fn(data, main_proto, si, ss, sii, sn)
    print(f"    -> {n} patches")
    return bytes(data)


def process_package(pkg_path, out_path, file_map, zdict):
    import pyzstd
    patched_entries = {}
    with zipfile.ZipFile(pkg_path, 'r') as zf:
        for item in zf.infolist():
            base = item.filename.split('/')[-1].replace('.bytes', '')
            if base not in file_map:
                continue
            raw = zf.read(item.filename)
            if raw[:4] == b'\x22\x4a\x00\xef':
                decompressed = pyzstd.decompress(raw[8:], zdict)
            else:
                decompressed = raw
            patched = patch_lua_file(decompressed, base, file_map[base])
            compressed = pyzstd.compress(patched, 17, zdict)
            assert pyzstd.decompress(compressed, zdict) == patched
            pkg_entry = b'\x22\x4a\x00\xef' + struct.pack('<I', len(patched)) + compressed
            patched_entries[item.filename] = pkg_entry
            print(f"    Compressed: {len(patched)} -> {len(pkg_entry)} bytes")

    if not patched_entries:
        print("    (no target files found)")
        return False

    buf = io.BytesIO()
    with zipfile.ZipFile(pkg_path, 'r') as zf_in:
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zf_out:
            for item in zf_in.infolist():
                if item.filename in patched_entries:
                    zf_out.writestr(item, patched_entries[item.filename])
                else:
                    zf_out.writestr(item, zf_in.read(item.filename))
    with open(out_path, 'wb') as f:
        f.write(buf.getvalue())
    return True


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 patch_v6.py <aov_files_dir> <output_dir>")
        print("  aov_files_dir: directory containing the original *.pkg.bytes")
        print("  output_dir:    where patched packages are written")
        sys.exit(1)

    src_dir = sys.argv[1]
    out_dir = sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    import pyzstd
    script_dir = os.path.dirname(os.path.abspath(__file__))
    with open(os.path.join(script_dir, 'zstd_dict.bin'), 'rb') as f:
        zdict = pyzstd.ZstdDict(f.read(), is_raw=True)

    for pkg_name, file_map in PACKAGE_MAP.items():
        pkg_path = os.path.join(src_dir, f'{pkg_name}.pkg.bytes')
        out_path = os.path.join(out_dir, f'{pkg_name}.pkg.bytes')
        if not os.path.exists(pkg_path):
            print(f"\n[MISSING] {pkg_name}.pkg.bytes")
            continue
        print(f"\n{'='*60}\nPACKAGE: {pkg_name}.pkg.bytes")
        ok = process_package(pkg_path, out_path, file_map, zdict)
        if ok:
            o, n = os.path.getsize(pkg_path), os.path.getsize(out_path)
            print(f"  Output: {out_path}  ({o} -> {n}, {n-o:+d} bytes)")

    print(f"\n{'='*60}\nPATCH v6 COMPLETE")


if __name__ == '__main__':
    main()

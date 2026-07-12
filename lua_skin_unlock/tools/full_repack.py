"""
Full repack pipeline: compress patched Lua files and rebuild .pkg.bytes ZIPs.
Produces ready-to-install game files.
"""
import struct
import os
import sys
import zipfile
import io

SCRATCHPAD = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad'
ZSTD_LEVEL = 17

# Load custom zstd dictionary
gmhall_path = '/root/.claude/uploads/225a4123-2613-56d7-9ef1-6593374f172c/d99a6eb0-gmhallv3.py'
zstd_globals = {}
with open(gmhall_path, 'r') as f:
    content = f.read()
start = content.find('ZSTD_DICT = ')
end = content.find('\n\n', start)
if end < 0: end = content.find('\ndef ', start)
exec(content[start:end], zstd_globals)
ZSTD_DICT = zstd_globals['ZSTD_DICT']

import pyzstd

def compress_lua(input_data):
    zdict = pyzstd.ZstdDict(ZSTD_DICT, is_raw=True)
    compressed = pyzstd.compress(input_data, ZSTD_LEVEL, zdict)
    header = b'\x22\x4a\x00\xef' + struct.pack('<I', len(input_data))
    return header + compressed

def repack_pkg(original_pkg_path, patched_entries, output_path):
    """Replace entries in a .pkg.bytes ZIP."""
    with zipfile.ZipFile(original_pkg_path, 'r') as zf_in:
        output_buffer = io.BytesIO()
        with zipfile.ZipFile(output_buffer, 'w', zipfile.ZIP_STORED) as zf_out:
            for item in zf_in.infolist():
                if item.filename in patched_entries:
                    zf_out.writestr(item, patched_entries[item.filename])
                    print(f"    Replaced: {item.filename}")
                else:
                    zf_out.writestr(item, zf_in.read(item.filename))

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(output_buffer.getvalue())
    return os.path.getsize(output_path)


def main():
    output_dir = os.path.join(SCRATCHPAD, 'aov_patched/output')
    os.makedirs(output_dir, exist_ok=True)

    # Define patches: (patched_lua_path, zip_entry_name, pkg_bytes_filename)
    patches = {
        'HeroInfoLua.pkg.bytes': [
            ('aov_patched/HeroSkinListItem_lua.lua', 'Lua_Signed/AOV/HeroInfo/HeroSkinListItem_lua.bytes'),
            ('aov_patched/HeroModel_lua.lua', 'Lua_Signed/AOV/HeroInfo/HeroModel_lua.bytes'),
        ]
    }

    print("=== AOV Skin Unlock - Full Repack ===\n")

    for pkg_name, file_patches in patches.items():
        print(f"Processing {pkg_name}:")
        original_pkg = os.path.join(SCRATCHPAD, f'aov_files/{pkg_name}')

        if not os.path.exists(original_pkg):
            print(f"  ERROR: {original_pkg} not found!")
            continue

        patched_entries = {}
        for lua_path, entry_name in file_patches:
            full_lua_path = os.path.join(SCRATCHPAD, lua_path)
            if not os.path.exists(full_lua_path):
                print(f"  ERROR: {full_lua_path} not found!")
                continue

            with open(full_lua_path, 'rb') as f:
                raw_data = f.read()

            compressed = compress_lua(raw_data)

            # Verify
            zdict = pyzstd.ZstdDict(ZSTD_DICT, is_raw=True)
            verify = pyzstd.decompress(compressed[8:], zdict)
            assert verify == raw_data, f"Verification failed for {lua_path}"

            patched_entries[entry_name] = compressed
            print(f"    {os.path.basename(lua_path)}: {len(raw_data)} → {len(compressed)} bytes")

        output_pkg = os.path.join(output_dir, pkg_name)
        size = repack_pkg(original_pkg, patched_entries, output_pkg)

        orig_size = os.path.getsize(original_pkg)
        print(f"    Output: {output_pkg}")
        print(f"    Size: {orig_size} → {size} ({size-orig_size:+d} bytes)\n")

    print("=" * 60)
    print("OUTPUT FILES:")
    print(f"  {output_dir}/HeroInfoLua.pkg.bytes")
    print()
    print("INSTALLATION:")
    print("  1. Copy patched .pkg.bytes to device game data folder:")
    print("     /sdcard/Android/data/com.garena.game.kgvn/files/Bundles/Lua/")
    print("     (or equivalent path for your game version)")
    print()
    print("  2. Apply RSA signature bypass using one of:")
    print("     a) Frida: frida -U -f com.garena.game.kgvn -l bypass_signature.js")
    print("     b) Binary patch: NOP the PKCS1.Verify_v15 call in libil2cpp.so")
    print("     c) Modded APK with signature check removed")
    print()
    print("WHAT WAS PATCHED:")
    print("  - HeroSkinListItem_lua: UI always shows skins as 'Owned'")
    print("    - Instruction [108]: heroOwnState check → always owned")
    print("    - Instruction [136]: skinOwnState check → always owned")
    print("    - Instruction [149]: heroOwnState==Owned check → always true")
    print("    - Instruction [169]: skinOwnState subsequent check → owned path")
    print("  - HeroModel_lua: Core ownership getter functions patched")
    print("    - GetHeroOwnState(): always returns 'not UnOwned' (owned)")
    print("    - GetSkinOwnState(): always returns 'not UnOwned' (owned)")
    print("    - GetSkinOwnState(heroId, skinId): always returns 'not UnOwned' (owned)")
    print()
    print("NOTE: This is a CLIENT-SIDE visual unlock only. The server still")
    print("tracks actual ownership. Attempting to USE an unowned skin in a")
    print("match will likely be rejected by the server.")


if __name__ == '__main__':
    main()

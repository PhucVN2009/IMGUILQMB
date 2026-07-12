"""
Complete pipeline to repack patched Lua bytecode into game format:
1. Compress patched bytecode with zstd + custom dictionary
2. Add custom header (magic + uncompressed size)
3. Replace entry in HeroInfoLua.pkg.bytes ZIP

Usage: python3 repack_skin_unlock.py
Output: aov_patched/HeroInfoLua.pkg.bytes (modified game file)
"""
import struct
import os
import sys
import zipfile
import io

SCRATCHPAD = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad'
ZSTD_LEVEL = 17

# Import the custom dictionary from gmhallv3.py
sys.path.insert(0, SCRATCHPAD)
gmhall_path = '/root/.claude/uploads/225a4123-2613-56d7-9ef1-6593374f172c/d99a6eb0-gmhallv3.py'

# Extract ZSTD_DICT by exec
zstd_globals = {}
with open(gmhall_path, 'r') as f:
    content = f.read()
# Only exec the ZSTD_DICT definition
start = content.find('ZSTD_DICT = ')
if start < 0:
    raise RuntimeError("Cannot find ZSTD_DICT in gmhallv3.py")
end = content.find('\n\n', start)
if end < 0:
    end = content.find('\ndef ', start)
exec(content[start:end], zstd_globals)
ZSTD_DICT = zstd_globals['ZSTD_DICT']
print(f"Loaded ZSTD_DICT: {len(ZSTD_DICT)} bytes")

import pyzstd

def compress_lua(input_data):
    """Compress Lua bytecode using game's custom format."""
    zdict = pyzstd.ZstdDict(ZSTD_DICT, is_raw=True)
    compressed = pyzstd.compress(input_data, ZSTD_LEVEL, zdict)

    # Build header: magic (4 bytes) + uncompressed size (4 bytes LE)
    header = b'\x22\x4a\x00\xef' + struct.pack('<I', len(input_data))
    return header + compressed

def repack_pkg(original_pkg_path, patched_files, output_path):
    """
    Create new .pkg.bytes ZIP with patched files replaced.
    patched_files: dict of {entry_name: patched_bytes_content}
    """
    # Read original ZIP
    with zipfile.ZipFile(original_pkg_path, 'r') as zf_in:
        # Create new ZIP in memory
        output_buffer = io.BytesIO()
        with zipfile.ZipFile(output_buffer, 'w', zipfile.ZIP_STORED) as zf_out:
            for item in zf_in.infolist():
                if item.filename in patched_files:
                    # Use patched content
                    zf_out.writestr(item, patched_files[item.filename])
                    print(f"  Replaced: {item.filename} ({len(patched_files[item.filename])} bytes)")
                else:
                    # Copy original
                    zf_out.writestr(item, zf_in.read(item.filename))

    # Write output
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(output_buffer.getvalue())

    print(f"  Output: {output_path} ({os.path.getsize(output_path)} bytes)")


def main():
    # Read patched bytecode
    patched_lua_path = os.path.join(SCRATCHPAD, 'aov_patched/HeroSkinListItem_lua.lua')
    with open(patched_lua_path, 'rb') as f:
        patched_data = f.read()
    print(f"Patched bytecode: {len(patched_data)} bytes")

    # Compress with custom format
    compressed = compress_lua(patched_data)
    print(f"Compressed: {len(compressed)} bytes (header + zstd)")

    # Verify by decompressing
    zdict = pyzstd.ZstdDict(ZSTD_DICT, is_raw=True)
    verify = pyzstd.decompress(compressed[8:], zdict)
    assert verify == patched_data, "Decompression verification failed!"
    print("Compression verified OK")

    # Repack into HeroInfoLua.pkg.bytes
    original_pkg = os.path.join(SCRATCHPAD, 'aov_files/HeroInfoLua.pkg.bytes')
    output_pkg = os.path.join(SCRATCHPAD, 'aov_patched/HeroInfoLua.pkg.bytes')

    patched_files = {
        'Lua_Signed/AOV/HeroInfo/HeroSkinListItem_lua.bytes': compressed
    }

    print(f"\nRepacking {os.path.basename(original_pkg)}...")
    repack_pkg(original_pkg, patched_files, output_pkg)

    # Compare sizes
    orig_size = os.path.getsize(original_pkg)
    new_size = os.path.getsize(output_pkg)
    print(f"\nOriginal pkg size: {orig_size} bytes")
    print(f"Patched pkg size:  {new_size} bytes")
    print(f"Difference: {new_size - orig_size:+d} bytes")

    print("\n=== REPACK COMPLETE ===")
    print(f"Output file: {output_pkg}")
    print("\nIMPORTANT: RSA signature handling")
    print("The 128-byte RSA signature at the start of the Lua bytecode will fail verification.")
    print("Options to bypass:")
    print("  1. Hook LuaLoaderImpl.Verify in libil2cpp.so (patch RSA check to always return true)")
    print("  2. Use a Frida script to bypass PKCS1.Verify_v15")
    print("  3. Patch libxlua.so to skip signature check before loading")


if __name__ == '__main__':
    main()

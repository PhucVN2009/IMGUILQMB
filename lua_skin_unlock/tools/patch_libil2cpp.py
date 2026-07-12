"""
Patch libil2cpp.so to bypass Lua RSA signature verification.

This patches PKCS1.Verify_v15() to always return true (1),
allowing modified Lua bytecode files to load without valid signatures.

Usage:
    python3 patch_libil2cpp.py libil2cpp.so

Output:
    libil2cpp_patched.so (in same directory)

After patching:
    1. Replace libil2cpp.so in APK/lib/arm64-v8a/ (or armeabi-v7a)
    2. Re-sign APK
    3. Install and copy modded .pkg.bytes files

Target functions (from dump.cs):
    PKCS1.Verify_v15 (TypeDefIndex: 21628)
    - RVA: 0x640A218 (4-param, called by LuaLoaderImpl)
    - RVA: 0x640A298 (5-param with tryNonStandardEncoding)
    - RVA: 0x640A4B0 (string hashName variant)

    Mono.Security.Cryptography.PKCS1.Verify_v15 (TypeDefIndex: 32179)
    - RVA: 0x63E8DAC (5-param)
"""
import struct
import sys
import os
import shutil

# ARM64 (AArch64) instructions
# MOV W0, #1  ->  0x52800020
# RET         ->  0xD65F03C0
ARM64_RETURN_TRUE = bytes([
    0x20, 0x00, 0x80, 0x52,  # MOV W0, #1
    0xC0, 0x03, 0x5F, 0xD6,  # RET
])

# ARM32 (ARMv7) instructions
# MOV R0, #1  ->  0xE3A00001
# BX LR       ->  0xE12FFF1E
ARM32_RETURN_TRUE = bytes([
    0x01, 0x00, 0xA0, 0xE3,  # MOV R0, #1
    0x1E, 0xFF, 0x2F, 0xE1,  # BX LR
])

# THUMB mode (ARMv7 Thumb-2)
# MOVS R0, #1 -> 0x2001
# BX LR       -> 0x4770
THUMB_RETURN_TRUE = bytes([
    0x01, 0x20,  # MOVS R0, #1
    0x70, 0x47,  # BX LR
])

# RVA addresses for PKCS1.Verify_v15 functions
VERIFY_RVAS = [
    (0x640A218, "PKCS1.Verify_v15(RSA,HashAlgorithm,byte[],byte[])"),
    (0x640A298, "PKCS1.Verify_v15(RSA,HashAlgorithm,byte[],byte[],bool)"),
    (0x640A4B0, "PKCS1.Verify_v15(RSA,string,byte[],byte[])"),
    (0x63E8DAC, "Mono.PKCS1.Verify_v15(RSA,HashAlgorithm,byte[],byte[],bool)"),
]

# Alternative: PUBLIC_KEY string to search for (base64)
PUBLIC_KEY_PATTERN = b"BgIAAACkAABSU0ExAAQAAAEAAQBtGoQSyC4C"


def detect_arch(data):
    """Detect if the .so is ARM64 or ARM32."""
    # ELF header: e_machine at offset 18
    if data[:4] != b'\x7fELF':
        return None

    ei_class = data[4]  # 1=32bit, 2=64bit
    e_machine = struct.unpack_from('<H', data, 18)[0]

    if ei_class == 2 and e_machine == 183:  # EM_AARCH64
        return "arm64"
    elif ei_class == 1 and e_machine == 40:  # EM_ARM
        return "arm32"
    return None


def find_function_at_rva(data, rva, arch):
    """Verify that an RVA points to a plausible function start."""
    if rva >= len(data) - 8:
        return False

    # Check if it looks like code (not all zeros or 0xFF)
    chunk = data[rva:rva+16]
    if chunk == b'\x00' * 16 or chunk == b'\xFF' * 16:
        return False

    if arch == "arm64":
        # ARM64 functions often start with STP (store pair) or SUB SP
        # STP X29, X30, [SP, #-N]! : 0xA9B..FD (varies)
        # SUB SP, SP, #N : 0xD10...FF
        word = struct.unpack_from('<I', data, rva)[0]
        # Just verify it's not obviously invalid
        if word == 0:
            return False
        return True
    elif arch == "arm32":
        word = struct.unpack_from('<I', data, rva)[0]
        if word == 0:
            return False
        return True

    return True


def patch_at_rva(data, rva, patch_bytes, name, arch):
    """Apply patch at given RVA."""
    if rva >= len(data) - len(patch_bytes):
        print(f"  [-] {name}: RVA 0x{rva:X} out of bounds (file size: 0x{len(data):X})")
        return False

    if not find_function_at_rva(data, rva, arch):
        print(f"  [-] {name}: RVA 0x{rva:X} doesn't look like valid code")
        return False

    # Show original bytes
    original = data[rva:rva+len(patch_bytes)]
    print(f"  [*] {name}")
    print(f"      RVA: 0x{rva:X}")
    print(f"      Original: {original.hex()}")
    print(f"      Patched:  {patch_bytes.hex()}")

    data[rva:rva+len(patch_bytes)] = patch_bytes
    return True


def search_and_patch_pubkey(data):
    """Alternative: find PUBLIC_KEY string and corrupt it so verify always fails
    and the fallback path returns the bytecode anyway."""
    idx = data.find(PUBLIC_KEY_PATTERN)
    if idx >= 0:
        print(f"\n  [*] Found PUBLIC_KEY string at offset 0x{idx:X}")
        print(f"      (Can zero it out as alternative bypass)")
        return idx
    return -1


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 patch_libil2cpp.py <libil2cpp.so>")
        print("\nExtract libil2cpp.so from APK:")
        print("  unzip -o game.apk lib/arm64-v8a/libil2cpp.so")
        print("  python3 patch_libil2cpp.py lib/arm64-v8a/libil2cpp.so")
        sys.exit(1)

    input_path = sys.argv[1]
    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)

    # Read file
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    print(f"File: {input_path}")
    print(f"Size: {len(data)} bytes ({len(data)/1024/1024:.1f} MB)")

    # Detect architecture
    arch = detect_arch(data)
    if not arch:
        print("Error: Not a valid ELF file or unsupported architecture")
        sys.exit(1)

    print(f"Architecture: {arch}")

    # Select patch bytes
    if arch == "arm64":
        patch_bytes = ARM64_RETURN_TRUE
    else:
        # For ARM32, check if Thumb mode (RVA bit 0 set, or typical for il2cpp)
        patch_bytes = ARM32_RETURN_TRUE

    print(f"\nPatching PKCS1.Verify_v15 functions:")
    print(f"  Patch: MOV R0/W0, #1; RET/BX LR (always return true)")
    print()

    success_count = 0
    for rva, name in VERIFY_RVAS:
        if patch_at_rva(data, rva, patch_bytes, name, arch):
            success_count += 1
        print()

    # Also look for public key
    pk_offset = search_and_patch_pubkey(data)

    if success_count == 0:
        print("\n[!] NO PATCHES APPLIED!")
        print("[!] The RVA addresses don't match this version of libil2cpp.so.")
        print("[!] You need to re-dump with Il2CppDumper and find the correct RVAs.")
        print("[!] Look for 'PKCS1' and 'Verify_v15' in the new dump.cs")

        # Try alternative: search for known byte patterns
        print("\n[*] Attempting pattern search...")
        # The PUBLIC_KEY base64 string is in the .rodata section
        if pk_offset >= 0:
            print("[*] Found PUBLIC_KEY - you can try zeroing it as alternative")
        sys.exit(1)

    # Write output
    dir_name = os.path.dirname(input_path) or "."
    base_name = os.path.basename(input_path)
    name_no_ext = os.path.splitext(base_name)[0]
    output_path = os.path.join(dir_name, name_no_ext + "_patched.so")

    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"\n{'='*60}")
    print(f"[+] SUCCESS: {success_count}/{len(VERIFY_RVAS)} functions patched")
    print(f"[+] Output: {output_path}")
    print(f"\nNext steps:")
    print(f"  1. Replace in APK: lib/arm64-v8a/libil2cpp.so")
    print(f"  2. Re-sign APK (uber-apk-signer, apktool, etc.)")
    print(f"  3. Install modded APK")
    print(f"  4. Copy patched HeroInfoLua.pkg.bytes to:")
    print(f"     /sdcard/Android/data/com.garena.game.kgvn/files/Bundles/Lua/")
    print(f"  5. Launch game - skins should show as owned")


if __name__ == '__main__':
    main()

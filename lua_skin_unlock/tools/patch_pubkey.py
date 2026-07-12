"""
Patch libil2cpp.so to replace the RSA public key used for Lua signature verification.

Instead of patching code (NOP'ing verify functions), this replaces the PUBLIC_KEY
string in .rodata with your custom key. The verify code still runs, but now it
verifies against YOUR key - so files signed with your private key pass verification.

This is cleaner than code patching because:
- No architecture-specific patches needed (works on ARM64 and ARM32)
- The game's verification logic stays intact
- Only the trusted key changes

Usage:
    python3 patch_pubkey.py <libil2cpp.so>

Output:
    libil2cpp_patched.so (same directory)

After patching:
    1. Replace libil2cpp.so in APK
    2. Re-sign APK
    3. Use resign_lua.py to sign modified Lua files with matching private key
"""
import sys
import os
import struct
import base64

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KEY_PATH = os.path.join(SCRIPT_DIR, 'signing_key.pem')

ORIG_PUBKEY_B64 = b"BgIAAACkAABSU0ExAAQAAAEAAQBtGoQSyC4C+179FHh1BoKbCn+tO73sKDZRwjXwlvucfexezI++0vvESdptQ8lHZ4/NGL+EnT5DCUn6m603kVsPs8Hwsrr1pn6hKKkqVBK3BylmjYSzrBXAbbM4Qx1ZPgPuDuWoPaquJZJjyFFd8UlhWByvk6tYlR3r5qlE+Kwywg=="


def get_new_pubkey():
    from Crypto.PublicKey import RSA

    if not os.path.exists(KEY_PATH):
        print("No signing key found. Generating new key pair...")
        key = RSA.generate(1024)
        with open(KEY_PATH, 'wb') as f:
            f.write(key.export_key())
        print(f"  Saved: {KEY_PATH}")
    else:
        with open(KEY_PATH, 'rb') as f:
            key = RSA.import_key(f.read())

    modulus_be = key.n.to_bytes(128, 'big')
    modulus_le = modulus_be[::-1]
    blob = struct.pack('<BBHI', 6, 2, 0, 0x0000a400)
    blob += b'RSA1'
    blob += struct.pack('<I', 1024)
    blob += struct.pack('<I', key.e)
    blob += modulus_le
    return base64.b64encode(blob)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 patch_pubkey.py <libil2cpp.so>")
        sys.exit(1)

    input_path = sys.argv[1]
    if not os.path.exists(input_path):
        print(f"Error: {input_path} not found")
        sys.exit(1)

    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    print(f"File: {input_path}")
    print(f"Size: {len(data)} bytes ({len(data)/1024/1024:.1f} MB)")

    # Find all occurrences of the original public key
    occurrences = []
    search_from = 0
    while True:
        idx = data.find(ORIG_PUBKEY_B64, search_from)
        if idx < 0:
            break
        occurrences.append(idx)
        search_from = idx + 1

    if not occurrences:
        print("\n[!] Original PUBLIC_KEY string not found in this file!")
        print("[!] The game version may use a different key.")
        print("[!] Try searching for 'RSA1' or 'BgIAAACkAABSU0Ex' in the binary.")

        partial = b"BgIAAACkAABSU0Ex"
        idx = data.find(partial)
        if idx >= 0:
            print(f"\n[*] Found partial match at 0x{idx:X}")
            found_key = data[idx:idx+200]
            print(f"[*] Key at that offset: {found_key[:200]}")
        sys.exit(1)

    print(f"\nFound {len(occurrences)} occurrence(s) of PUBLIC_KEY:")
    for idx in occurrences:
        print(f"  Offset: 0x{idx:X}")

    # Get new public key
    new_pubkey = get_new_pubkey()
    assert len(new_pubkey) == len(ORIG_PUBKEY_B64), \
        f"Key length mismatch: {len(new_pubkey)} vs {len(ORIG_PUBKEY_B64)}"

    # Replace all occurrences
    for idx in occurrences:
        data[idx:idx+len(ORIG_PUBKEY_B64)] = new_pubkey
        print(f"  Patched at 0x{idx:X}")

    # Write output
    dir_name = os.path.dirname(input_path) or "."
    base_name = os.path.basename(input_path)
    name_no_ext = os.path.splitext(base_name)[0]
    output_path = os.path.join(dir_name, name_no_ext + "_patched.so")

    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"\n{'='*60}")
    print(f"[+] SUCCESS: {len(occurrences)} key(s) replaced")
    print(f"[+] Output: {output_path}")
    print(f"\nNew PUBLIC_KEY: {new_pubkey.decode()}")
    print(f"\nNext steps:")
    print(f"  1. Replace libil2cpp.so in APK with {os.path.basename(output_path)}")
    print(f"  2. Re-sign APK")
    print(f"  3. Use resign_lua.py to sign modified Lua files")
    print(f"  4. Repack into .pkg.bytes and install")


if __name__ == '__main__':
    main()

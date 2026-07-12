"""
Re-sign modified Lua bytecode files with custom RSA key.

The game verifies Lua files using RSA-1024 PKCS#1 v1.5 SHA-1 signatures.
Each .lua file = [128-byte RSA signature][Lua 5.3 bytecode starting with \x1bLua]

This tool:
1. Strips the old signature (first 128 bytes)
2. Signs the Lua bytecode with our private key
3. Prepends the new signature

Requires: pycryptodome (pip install pycryptodome)

Usage:
    python3 resign_lua.py <input.lua> [output.lua]
    python3 resign_lua.py --genkey          # Generate new key pair
    python3 resign_lua.py --pubkey          # Show PUBLIC_KEY for game patching
"""
import sys
import os
import struct
import base64

from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA1

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
KEY_PATH = os.path.join(SCRIPT_DIR, 'signing_key.pem')

ORIG_PUBKEY = "BgIAAACkAABSU0ExAAQAAAEAAQBtGoQSyC4C+179FHh1BoKbCn+tO73sKDZRwjXwlvucfexezI++0vvESdptQ8lHZ4/NGL+EnT5DCUn6m603kVsPs8Hwsrr1pn6hKKkqVBK3BylmjYSzrBXAbbM4Qx1ZPgPuDuWoPaquJZJjyFFd8UlhWByvk6tYlR3r5qlE+Kwywg=="


def generate_key():
    key = RSA.generate(1024)
    with open(KEY_PATH, 'wb') as f:
        f.write(key.export_key())
    print(f"Generated new RSA-1024 key: {KEY_PATH}")
    print_pubkey(key)
    return key


def load_key():
    if not os.path.exists(KEY_PATH):
        print("No signing key found. Generating new key pair...")
        return generate_key()
    with open(KEY_PATH, 'rb') as f:
        return RSA.import_key(f.read())


def get_dotnet_pubkey_blob(key):
    modulus_be = key.n.to_bytes(128, 'big')
    modulus_le = modulus_be[::-1]
    blob = struct.pack('<BBHI', 6, 2, 0, 0x0000a400)
    blob += b'RSA1'
    blob += struct.pack('<I', 1024)
    blob += struct.pack('<I', key.e)
    blob += modulus_le
    return base64.b64encode(blob).decode()


def print_pubkey(key=None):
    if key is None:
        key = load_key()
    new_pubkey = get_dotnet_pubkey_blob(key)
    print(f"\n=== PUBLIC_KEY for game ===")
    print(f"Replace this string in libil2cpp.so:")
    print(f"  Original: {ORIG_PUBKEY}")
    print(f"  New:      {new_pubkey}")
    print(f"\nBoth are {len(ORIG_PUBKEY)} chars - direct byte replacement in .so file")


def sign_file(input_path, output_path=None):
    key = load_key()

    with open(input_path, 'rb') as f:
        data = f.read()

    lua_off = data.find(b'\x1bLua')
    if lua_off < 0:
        print(f"Error: No Lua header found in {input_path}")
        sys.exit(1)

    if lua_off == 128:
        lua_bytecode = data[128:]
    elif lua_off == 0:
        lua_bytecode = data
    else:
        print(f"Warning: Lua header at unusual offset {lua_off}, using content from there")
        lua_bytecode = data[lua_off:]

    h = SHA1.new(lua_bytecode)
    signature = pkcs1_15.new(key).sign(h)

    signed_data = signature + lua_bytecode

    if output_path is None:
        output_path = input_path

    with open(output_path, 'wb') as f:
        f.write(signed_data)

    print(f"Signed: {input_path} -> {output_path}")
    print(f"  Bytecode: {len(lua_bytecode)} bytes")
    print(f"  SHA1: {h.hexdigest()}")
    print(f"  Signature: {signature[:16].hex()}...")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    if sys.argv[1] == '--genkey':
        generate_key()
    elif sys.argv[1] == '--pubkey':
        print_pubkey()
    else:
        input_path = sys.argv[1]
        output_path = sys.argv[2] if len(sys.argv) > 2 else None
        sign_file(input_path, output_path)


if __name__ == '__main__':
    main()

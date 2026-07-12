"""
Patch v3: Full skin unlock - ownership + visual brightness.

Changes from v2:
- Also patches SetWearBtnGO and SetShareBtnGO to keep NoStateBG hidden,
  so skin icons always appear BRIGHT instead of dimmed for unowned skins.

Patches:
1. Proto[24] SetHeroSkinData: K[9]=1, LOADK R9/R10 = Owned
2. Proto[9] SetWearBtnGO: NOT → LOADBOOL false (NoStateBG hidden)
3. Proto[10] SetShareBtnGO: NOT → LOADBOOL false (NoStateBG hidden)
"""
import struct
import os
import sys
import zipfile
import io

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def encode_iABC(op, A, B, C):
    return (op & 0x3F) | ((A & 0xFF) << 6) | ((C & 0x1FF) << 14) | ((B & 0x1FF) << 23)

def encode_iABx(op, A, Bx):
    return (op & 0x3F) | ((A & 0xFF) << 6) | ((Bx & 0x3FFFF) << 14)

def decode_instr(instr):
    op = instr & 0x3F
    A = (instr >> 6) & 0xFF
    B = (instr >> 23) & 0x1FF
    C = (instr >> 14) & 0x1FF
    return op, A, B, C


def read_string_raw(data, offset, sizeof_sizet):
    size = data[offset]; offset += 1
    if size == 0: return b"", offset
    if size == 0xFF:
        size = int.from_bytes(data[offset:offset+sizeof_sizet], 'little')
        offset += sizeof_sizet
    s = data[offset:offset+size-1]; offset += size - 1
    return s, offset


class ProtoInfo:
    def __init__(self):
        self.instr_start = 0
        self.n_instr = 0
        self.const_entries_start = 0
        self.n_const = 0
        self.end_offset = 0
        self.children = []
        self.constants = []


def parse_proto(data, off, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    info = ProtoInfo()
    _, off = read_string_raw(data, off, sizeof_sizet)
    off += sizeof_int * 2 + 3

    info.n_instr = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
    info.instr_start = off
    off += info.n_instr * 4

    info.n_const = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
    info.const_entries_start = off
    for _ in range(info.n_const):
        t = data[off]; off += 1
        if t == 0:
            info.constants.append(('nil', None))
        elif t == 1:
            info.constants.append(('bool', data[off])); off += 1
        elif t == 3:
            info.constants.append(('number', struct.unpack_from('<d', data, off)[0])); off += sizeof_number
        elif t == 0x13:
            info.constants.append(('integer', int.from_bytes(data[off:off+sizeof_integer], 'little', signed=True))); off += sizeof_integer
        elif t in (4, 0x14):
            s, off = read_string_raw(data, off, sizeof_sizet)
            info.constants.append(('string', s.decode('utf-8', errors='replace')))

    nu = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nu * 2
    np = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
    for _ in range(np):
        child = parse_proto(data, off, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)
        info.children.append(child)
        off = child.end_offset

    nl = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nl * sizeof_int
    nv = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
    for _ in range(nv):
        _, off = read_string_raw(data, off, sizeof_sizet); off += sizeof_int * 2
    nn = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
    for _ in range(nn):
        _, off = read_string_raw(data, off, sizeof_sizet)

    info.end_offset = off
    return info


def patch_lua(data):
    """Apply all patches to Lua bytecode. Returns patched bytearray."""
    data = bytearray(data)

    lua_off = data.find(b'\x1bLua')
    if lua_off < 0:
        raise ValueError("No Lua header found")

    offset = lua_off + 4 + 1
    fmt = data[offset]; offset += 1
    offset += 6
    sizeof_int = data[offset]; offset += 1
    sizeof_sizet = data[offset]; offset += 1
    if fmt == 1:
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    else:
        offset += 1; sizeof_integer = data[offset]; offset += 1; sizeof_number = data[offset]; offset += 1
    offset += sizeof_integer + sizeof_number + 1

    main_proto = parse_proto(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)

    p9 = main_proto.children[9]
    p10 = main_proto.children[10]
    p24 = main_proto.children[24]

    assert p9.constants[0] == ('string', 'wearBtnGO'), "Proto[9] not SetWearBtnGO"
    assert p10.constants[0] == ('string', 'shareBtnGO'), "Proto[10] not SetShareBtnGO"

    # Proto[24]: K[9] = 1
    off = p24.const_entries_start
    for i in range(10):
        t = data[off]; off += 1
        if i == 9:
            assert t == 0x13
            struct.pack_into('<q', data, off, 1)
            break
        if t == 0: pass
        elif t == 1: off += 1
        elif t == 3: off += sizeof_number
        elif t == 0x13: off += sizeof_integer
        elif t in (4, 0x14): _, off = read_string_raw(data, off, sizeof_sizet)

    # Proto[24]: [97] LOADK R9, K[9]; [101] LOADK R10, K[9]
    struct.pack_into('<I', data, p24.instr_start + 97 * 4, encode_iABx(14, 9, 9))
    struct.pack_into('<I', data, p24.instr_start + 101 * 4, encode_iABx(14, 10, 9))

    # Proto[24]: NOP [95,96,98,99,100]
    nop = encode_iABC(18, 0, 0, 0)
    for idx in [95, 96, 98, 99, 100]:
        struct.pack_into('<I', data, p24.instr_start + idx * 4, nop)

    # Proto[9] SetWearBtnGO: [6] NOT→LOADBOOL false
    loadbool_false = encode_iABC(1, 4, 0, 0)
    i6 = struct.unpack_from('<I', data, p9.instr_start + 6 * 4)[0]
    assert (i6 & 0x3F) == 37, f"Proto[9][6] op={i6 & 0x3F}, expected 37 (NOT)"
    struct.pack_into('<I', data, p9.instr_start + 6 * 4, loadbool_false)

    # Proto[10] SetShareBtnGO: [6] NOT→LOADBOOL false
    i6_10 = struct.unpack_from('<I', data, p10.instr_start + 6 * 4)[0]
    assert (i6_10 & 0x3F) == 37, f"Proto[10][6] op={i6_10 & 0x3F}, expected 37 (NOT)"
    struct.pack_into('<I', data, p10.instr_start + 6 * 4, loadbool_false)

    return bytes(data)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 patch_v3.py <HeroSkinListItem_lua.lua> [output.lua]")
        print("  Patches Lua bytecode for full skin unlock (ownership + brightness)")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    with open(input_path, 'rb') as f:
        data = f.read()

    print(f"Input: {input_path} ({len(data)} bytes)")
    patched = patch_lua(data)

    if output_path is None:
        base = os.path.splitext(input_path)[0]
        output_path = base + '_patched.lua'

    with open(output_path, 'wb') as f:
        f.write(patched)

    print(f"Output: {output_path} ({len(patched)} bytes)")
    print("Patches applied:")
    print("  - heroOwnState = Owned (always)")
    print("  - skinOwnState = Owned (always)")
    print("  - NoStateBG hidden in SetWearBtnGO (icons bright)")
    print("  - NoStateBG hidden in SetShareBtnGO (icons bright)")


if __name__ == '__main__':
    main()

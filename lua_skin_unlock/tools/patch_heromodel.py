"""
Patch HeroModel_lua.lua to make GetHeroOwnState and GetSkinOwnState
always return "owned" state.

Proto[17] GetHeroOwnState - patch instr[17]
Proto[18] GetSkinOwnState - patch instr[17]
Proto[19] GetSkinOwnState (2-param variant) - patch instr[18]
"""
import struct
import os
import sys

SCRATCHPAD = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad'
sys.path.insert(0, SCRATCHPAD)
from opcode_analyzer import get_opcode, get_A, get_B, get_C

def encode_instr(op, A, B, C):
    return (op & 0x3F) | ((A & 0xFF) << 6) | ((C & 0x1FF) << 14) | ((B & 0x1FF) << 23)

def decode_instr(instr):
    return get_opcode(instr), get_A(instr), get_B(instr), get_C(instr)

def read_string(data, offset, sizeof_sizet):
    size = data[offset]; offset += 1
    if size == 0: return b"", offset
    if size == 0xFF:
        size = int.from_bytes(data[offset:offset+sizeof_sizet], 'little')
        offset += sizeof_sizet
    s = data[offset:offset+size-1]; offset += size - 1
    return s, offset

def skip_to_proto_instructions(data, lua_offset, target_proto, target_instr):
    """Navigate bytecode to find byte offset of specific instruction in a proto."""
    offset = lua_offset + 4  # skip \x1bLua
    offset += 1  # version
    fmt = data[offset]; offset += 1
    offset += 6  # LUAC_DATA
    sizeof_int = data[offset]; offset += 1
    sizeof_sizet = data[offset]; offset += 1

    if fmt == 1:
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    else:
        offset += 1
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1

    offset += sizeof_integer + sizeof_number + 1  # LUAC_INT + LUAC_NUM + sizeupvalues

    def skip_func(off):
        _, off = read_string(data, off, sizeof_sizet)
        off += sizeof_int * 2 + 3
        n = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        instr_start = off
        off += n * 4
        nc = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(nc):
            t = data[off]; off += 1
            if t == 0: pass
            elif t == 1: off += 1
            elif t == 3: off += sizeof_number
            elif t == 0x13: off += sizeof_integer
            elif t in (4, 0x14): _, off = read_string(data, off, sizeof_sizet)
        nu = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nu * 2
        np = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(np): _, off = skip_func(off)
        nl = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nl * sizeof_int
        nv = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(nv):
            _, off = read_string(data, off, sizeof_sizet); off += sizeof_int * 2
        nn = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(nn): _, off = read_string(data, off, sizeof_sizet)
        return instr_start, off

    # Skip main function header to reach protos
    _, offset = read_string(data, offset, sizeof_sizet)
    offset += sizeof_int * 2 + 3
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little'); offset += sizeof_int
    offset += n * 4
    nc = int.from_bytes(data[offset:offset+sizeof_int], 'little'); offset += sizeof_int
    for _ in range(nc):
        t = data[offset]; offset += 1
        if t == 0: pass
        elif t == 1: offset += 1
        elif t == 3: offset += sizeof_number
        elif t == 0x13: offset += sizeof_integer
        elif t in (4, 0x14): _, offset = read_string(data, offset, sizeof_sizet)
    nu = int.from_bytes(data[offset:offset+sizeof_int], 'little'); offset += sizeof_int; offset += nu * 2
    np = int.from_bytes(data[offset:offset+sizeof_int], 'little'); offset += sizeof_int

    # Skip to target proto
    for i in range(target_proto):
        _, offset = skip_func(offset)

    # Get instruction offset in target proto
    _, offset = read_string(data, offset, sizeof_sizet)
    offset += sizeof_int * 2 + 3
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little'); offset += sizeof_int

    return offset + target_instr * 4


def patch_file(input_path, output_path):
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    # Find Lua header
    lua_off = 0
    if data[:4] != b'\x1bLua':
        lua_off = data.find(b'\x1bLua')

    patches = [
        # Proto[17] GetHeroOwnState, instr[17]: EQ A=1, R2, R3
        # Patch to: EQ A=0, R3, R3 → always skip JMP → always "not unowned" path
        (17, 17, 15, 1, 2, 3, "GetHeroOwnState"),
        # Proto[18] GetSkinOwnState, instr[17]: EQ A=1, R2, R3
        (18, 17, 15, 1, 2, 3, "GetSkinOwnState"),
        # Proto[19] GetSkinOwnState (2-param), instr[18]: EQ A=1, R3, R4
        (19, 18, 15, 1, 3, 4, "GetSkinOwnState(2p)"),
    ]

    for proto_idx, instr_idx, expected_op, expected_A, expected_B, expected_C, name in patches:
        byte_offset = skip_to_proto_instructions(data, lua_off, proto_idx, instr_idx)

        original = struct.unpack_from('<I', data, byte_offset)[0]
        op, A, B, C = decode_instr(original)

        print(f"Proto[{proto_idx}] {name} [{instr_idx}]: op={op} A={A} B={B} C={C}")

        if op != expected_op:
            print(f"  ERROR: expected op={expected_op}, got op={op}")
            continue
        if A != expected_A:
            print(f"  WARNING: expected A={expected_A}, got A={A}")

        # Patch: EQ A=0, R(C), R(C) → self-compare always true, A=0 means skip if (1!=0) → always skip
        patched = encode_instr(expected_op, 0, C, C)
        struct.pack_into('<I', data, byte_offset, patched)
        new_op, new_A, new_B, new_C = decode_instr(patched)
        print(f"  Patched → op={new_op} A={new_A} B={new_B} C={new_C} (always skip JMP → owned path)")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"\nOutput: {output_path} ({len(data)} bytes)")
    return True


if __name__ == '__main__':
    input_file = os.path.join(SCRATCHPAD, 'aov_decoded/Lua_Signed/AOV/HeroInfo/HeroModel_lua.lua')
    output_file = os.path.join(SCRATCHPAD, 'aov_patched/HeroModel_lua.lua')
    patch_file(input_file, output_file)

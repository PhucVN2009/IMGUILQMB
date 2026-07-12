"""
Patch HeroSkinListItem Lua bytecode to unlock all skins.

Strategy: In Proto[24] (SetHeroSkinData), patch instruction [136] which checks
if skinOwnState == UnOwned. Change it so the "owned" path is ALWAYS taken.

Original: EQ A=0, B=R10(skinOwnState), C=R13(UnOwned) → skip JMP if equal (unowned path)
Patched:  EQ A=1, B=R13, C=R13 → skip if R13!=R13 → never skip → always JMP to owned path

Also patches other critical EQ checks that compare skin states later in the function.
"""
import struct
import os
import sys

SCRATCHPAD = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad'

def encode_instr(op, A, B, C):
    return (op & 0x3F) | ((A & 0xFF) << 6) | ((C & 0x1FF) << 14) | ((B & 0x1FF) << 23)

def decode_instr(instr):
    op = instr & 0x3F
    A = (instr >> 6) & 0xFF
    B = (instr >> 23) & 0x1FF
    C = (instr >> 14) & 0x1FF
    return op, A, B, C

def read_string(data, offset, sizeof_sizet):
    size = data[offset]
    offset += 1
    if size == 0:
        return "", offset
    if size == 0xFF:
        size = int.from_bytes(data[offset:offset+sizeof_sizet], 'little')
        offset += sizeof_sizet
    s = data[offset:offset+size-1]
    offset += size - 1
    return s, offset

def skip_function(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Skip a function and return offset after it, plus instruction section offset and count."""
    func_start = offset

    # Source name
    _, offset = read_string(data, offset, sizeof_sizet)

    # Line numbers
    offset += sizeof_int * 2

    # Params
    offset += 3

    # Instructions
    instr_offset = offset
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    instr_data_offset = offset
    offset += n * 4

    # Constants
    n_const = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n_const):
        t = data[offset]; offset += 1
        if t == 0:
            pass
        elif t == 1:
            offset += 1
        elif t == 3:
            offset += sizeof_number
        elif t == 0x13:
            offset += sizeof_integer
        elif t in (4, 0x14):
            _, offset = read_string(data, offset, sizeof_sizet)
        else:
            raise ValueError(f"Unknown const type {t} at {offset-1}")

    # Upvalues
    n_up = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    offset += n_up * 2

    # Protos (recursive)
    n_proto = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n_proto):
        _, offset = skip_function(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)

    # Line info
    n_line = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    offset += n_line * sizeof_int

    # Local vars
    n_loc = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n_loc):
        _, offset = read_string(data, offset, sizeof_sizet)
        offset += sizeof_int * 2

    # Upvalue names
    n_upn = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n_upn):
        _, offset = read_string(data, offset, sizeof_sizet)

    return (instr_data_offset, int.from_bytes(data[instr_offset:instr_offset+sizeof_int], 'little')), offset

def find_proto_instruction_offset(data, target_proto_idx):
    """Navigate through the bytecode file to find the instruction section of proto[target_proto_idx]."""

    # Parse header
    lua_off = 0
    if data[:4] != b'\x1bLua':
        lua_off = data.find(b'\x1bLua')
        if lua_off < 0:
            raise ValueError("Not a Lua bytecode file")

    offset = lua_off + 4
    version = data[offset]; offset += 1
    fmt = data[offset]; offset += 1
    offset += 6  # LUAC_DATA

    sizeof_int = data[offset]; offset += 1
    sizeof_sizet = data[offset]; offset += 1

    if fmt == 1:
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    else:
        offset += 1  # sizeof_instr
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1

    # Skip LUAC_INT and LUAC_NUM
    offset += sizeof_integer + sizeof_number

    # Sizeupvalues
    offset += 1

    # Now at main function. We need to navigate into its protos to find proto[target_proto_idx]
    # Skip main function header to get to its protos

    # Source name
    _, offset = read_string(data, offset, sizeof_sizet)
    # Line numbers
    offset += sizeof_int * 2
    # Params
    offset += 3

    # Instructions (main func)
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    offset += n * 4

    # Constants (main func)
    n_const = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n_const):
        t = data[offset]; offset += 1
        if t == 0: pass
        elif t == 1: offset += 1
        elif t == 3: offset += sizeof_number
        elif t == 0x13: offset += sizeof_integer
        elif t in (4, 0x14): _, offset = read_string(data, offset, sizeof_sizet)
        else: raise ValueError(f"Unknown const type {t}")

    # Upvalues (main func)
    n_up = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    offset += n_up * 2

    # Protos (main func) - here we navigate to proto[target_proto_idx]
    n_proto = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int

    if target_proto_idx >= n_proto:
        raise ValueError(f"Proto index {target_proto_idx} out of range (only {n_proto} protos)")

    # Skip protos before target
    for i in range(target_proto_idx):
        _, offset = skip_function(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)

    # Now at target proto - get its instruction offset
    # Source name
    _, offset = read_string(data, offset, sizeof_sizet)
    # Line numbers
    offset += sizeof_int * 2
    # Params
    offset += 3

    # Instructions count
    n_instr = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    instr_data_start = offset

    return instr_data_start, n_instr, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number


def patch_file(input_path, output_path):
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    print(f"File size: {len(data)} bytes")

    # Find instruction section of Proto[24]
    instr_start, n_instr, si, ss, sie, sn = find_proto_instruction_offset(data, 24)
    print(f"Proto[24] instructions start at offset {instr_start}, count={n_instr}")

    # Verify instruction [136] matches expected
    offset_136 = instr_start + 136 * 4
    original_instr = struct.unpack_from('<I', data, offset_136)[0]
    op, A, B, C = decode_instr(original_instr)
    print(f"Instruction [136] at offset {offset_136}: 0x{original_instr:08x} op={op} A={A} B={B} C={C}")

    if op != 15 or A != 0 or B != 10 or C != 13:
        print(f"WARNING: Instruction [136] doesn't match expected EQ 0,R10,R13!")
        print(f"  Expected: op=15 A=0 B=10 C=13")
        print(f"  Got:      op={op} A={A} B={B} C={C}")
        return False

    # Patch instruction [136]: EQ 1, R13, R13 (always takes owned path)
    patched_instr = encode_instr(15, 1, 13, 13)
    struct.pack_into('<I', data, offset_136, patched_instr)
    print(f"Patched [136]: 0x{patched_instr:08x} (EQ 1, R13, R13) - always owned")

    # Also patch instruction [108] - heroOwnState check
    # [108] EQ A=1, R9(heroOwnState), R12(UnOwned) - skip if hero NOT owned
    # We want to always consider hero as owned too
    offset_108 = instr_start + 108 * 4
    instr_108 = struct.unpack_from('<I', data, offset_108)[0]
    op108, A108, B108, C108 = decode_instr(instr_108)
    print(f"\nInstruction [108] at offset {offset_108}: 0x{instr_108:08x} op={op108} A={A108} B={B108} C={C108}")

    if op108 == 15:
        # Patch: EQ 1, R12, R12 → R12==R12 always true, A=1 means skip if != → never skip → take JMP
        # Actually for [108] we need to check the semantics more carefully
        # Let's check [109] to see what JMP follows
        instr_109 = struct.unpack_from('<I', data, instr_start + 109*4)[0]
        op109 = instr_109 & 0x3F
        sBx_109 = ((instr_109 >> 14) & 0x3FFFF) - 131071
        print(f"  [109]: op={op109} sBx={sBx_109}")

        # For heroOwnState, A108=1 means "skip if heroState != UnOwned" i.e. skip JMP if hero IS owned
        # Wait - EQ A=1 B C: skip if (B==C) != 1 → skip if B != C
        # So A=1, R9, R12: skip if R9 != R12(UnOwned) → skip if hero is NOT unowned (=owned) → skip JMP
        # That means the JMP goes to "hero unowned" path
        # We want hero always owned → always skip JMP → patch to EQ 0, R12, R12
        # EQ 0, R12, R12: skip if R12==R12 → always true → always skip JMP
        patched_108 = encode_instr(15, 0, 12, 12)
        struct.pack_into('<I', data, offset_108, patched_108)
        print(f"  Patched [108]: 0x{patched_108:08x} (EQ 0, R12, R12) - always hero owned")

    # Patch other skin state checks to force "owned" everywhere
    # [149] EQ: heroOwnState vs Owned - let's check it
    offset_149 = instr_start + 149 * 4
    instr_149 = struct.unpack_from('<I', data, offset_149)[0]
    op149, A149, B149, C149 = decode_instr(instr_149)
    print(f"\nInstruction [149] at offset {offset_149}: op={op149} A={A149} B={B149} C={C149}")
    if op149 == 15:
        # [149] EQ 0, R9, R13(Owned) - skip if heroState==Owned
        # After our [108] patch, code might not reach here, but let's patch for safety
        # We want hero to appear owned: EQ 0 R13 R13 → always skip (R13==R13, A=0 means skip if equal)
        patched_149 = encode_instr(15, 0, 13, 13)
        struct.pack_into('<I', data, offset_149, patched_149)
        print(f"  Patched [149]: 0x{patched_149:08x} (EQ 0, R13, R13) - always hero owned")

    # Patch [169] - another skinOwnState check
    offset_169 = instr_start + 169 * 4
    instr_169 = struct.unpack_from('<I', data, offset_169)[0]
    op169, A169, B169, C169 = decode_instr(instr_169)
    print(f"\nInstruction [169] at offset {offset_169}: op={op169} A={A169} B={B169} C={C169}")
    if op169 == 15 and B169 == 10:
        # Another skin state comparison - force owned path
        # EQ 0, R10, R13 → same pattern as [136], skin vs some state
        # Patch to never match (so we skip to next check, which should be "Owned")
        patched_169 = encode_instr(15, 1, 13, 13)
        struct.pack_into('<I', data, offset_169, patched_169)
        print(f"  Patched [169]: 0x{patched_169:08x} (EQ 1, R13, R13) - skip non-owned states")

    # Write output
    with open(output_path, 'wb') as f:
        f.write(data)

    print(f"\nPatched file written to: {output_path}")
    print(f"File size unchanged: {len(data)} bytes")
    return True


if __name__ == '__main__':
    input_file = os.path.join(SCRATCHPAD, 'aov_decoded/Lua_Signed/AOV/HeroInfo/HeroSkinListItem_lua.lua')
    output_file = os.path.join(SCRATCHPAD, 'aov_patched/HeroSkinListItem_lua.lua')

    os.makedirs(os.path.dirname(output_file), exist_ok=True)

    success = patch_file(input_file, output_file)
    if success:
        print("\n=== PATCH SUCCESSFUL ===")
        print("Next steps:")
        print("1. Strip/re-sign RSA signature (128 bytes at start)")
        print("2. Re-compress with zstd custom dictionary")
        print("3. Re-package into .pkg.bytes ZIP")
    else:
        print("\n=== PATCH FAILED ===")

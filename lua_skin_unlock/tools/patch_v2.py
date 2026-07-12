"""
Patch v2: Force skinOwnState and heroOwnState to always be Owned(1).

Strategy:
1. Change constant K[9] in Proto[24] from integer 0 to integer 1
2. Replace CALL GetSkinOwnState [101] with LOADK R10, K[9] (loads 1=Owned)
3. Replace CALL GetHeroOwnState [97] with LOADK R9, K[9] (loads 1=Owned)
4. NOP the setup instructions [98-100] and [95-96] (they setup args for removed calls)

This ensures R10=1(Owned) and R9=1(Owned) throughout the function,
making ALL subsequent EQ checks behave correctly.
"""
import struct
import os
import sys

SCRATCHPAD = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad'

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


def find_proto24_offsets(data):
    """Find byte offsets for Proto[24]'s instruction section and constant pool."""
    lua_off = data.find(b'\x1bLua')
    if lua_off < 0:
        raise ValueError("No Lua header")

    offset = lua_off + 4 + 1  # skip magic + version
    fmt = data[offset]; offset += 1
    offset += 6  # LUAC_DATA
    sizeof_int = data[offset]; offset += 1
    sizeof_sizet = data[offset]; offset += 1
    if fmt == 1:
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    else:
        offset += 1; sizeof_integer = data[offset]; offset += 1; sizeof_number = data[offset]; offset += 1
    offset += sizeof_integer + sizeof_number + 1  # LUAC_INT + LUAC_NUM + sizeupvalues

    def parse_func_get_offsets(off, is_target=False):
        """Parse function, return (instr_offset, const_offset, end_offset)"""
        _, off = read_string_raw(data, off, sizeof_sizet)
        off += sizeof_int * 2 + 3  # linedefined, lastline, params, vararg, maxstack

        # Instructions
        n_instr = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        instr_start = off
        off += n_instr * 4

        # Constants
        const_start = off
        n_const = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        const_entries_start = off
        for _ in range(n_const):
            t = data[off]; off += 1
            if t == 0: pass
            elif t == 1: off += 1
            elif t == 3: off += sizeof_number
            elif t == 0x13: off += sizeof_integer
            elif t in (4, 0x14): _, off = read_string_raw(data, off, sizeof_sizet)

        # Upvalues
        nu = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nu * 2

        # Protos
        np = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(np):
            _, _, off = parse_func_get_offsets(off)

        # Debug info
        nl = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nl * sizeof_int
        nv = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(nv):
            _, off = read_string_raw(data, off, sizeof_sizet); off += sizeof_int * 2
        nn = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
        for _ in range(nn): _, off = read_string_raw(data, off, sizeof_sizet)

        return instr_start, const_entries_start, off

    # Parse main function to get to its protos
    _, off = read_string_raw(data, offset, sizeof_sizet)
    off += sizeof_int * 2 + 3
    n = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += n * 4
    nc = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int
    for _ in range(nc):
        t = data[off]; off += 1
        if t == 0: pass
        elif t == 1: off += 1
        elif t == 3: off += sizeof_number
        elif t == 0x13: off += sizeof_integer
        elif t in (4, 0x14): _, off = read_string_raw(data, off, sizeof_sizet)
    nu = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int; off += nu * 2
    np = int.from_bytes(data[off:off+sizeof_int], 'little'); off += sizeof_int

    # Skip to proto[24]
    for i in range(24):
        _, _, off = parse_func_get_offsets(off)

    # Parse proto[24]
    instr_start, const_start, _ = parse_func_get_offsets(off)
    return instr_start, const_start, sizeof_int, sizeof_integer


def find_constant_k9_offset(data, const_entries_start, sizeof_int, sizeof_integer):
    """Find byte offset of K[9]'s integer value in the constant pool."""
    off = const_entries_start
    sizeof_number = 8  # from header

    for i in range(70):  # Proto[24] has 70 constants
        t = data[off]; off += 1
        if i == 9:
            # This should be type 0x13 (integer)
            if t != 0x13:
                print(f"  WARNING: K[9] is type {t}, expected 0x13 (integer)")
                return None
            # The integer value starts here
            val = int.from_bytes(data[off:off+sizeof_integer], 'little', signed=True)
            print(f"  K[9] at offset {off}: value={val} (type=0x13, {sizeof_integer} bytes)")
            return off

        # Skip based on type
        if t == 0: pass
        elif t == 1: off += 1
        elif t == 3: off += sizeof_number
        elif t == 0x13: off += sizeof_integer
        elif t in (4, 0x14): _, off = read_string_raw(data, off, 4)  # sizeof_sizet=4

    return None


def main():
    input_file = os.path.join(SCRATCHPAD, 'aov_decoded/Lua_Signed/AOV/HeroInfo/HeroSkinListItem_lua.lua')
    output_file = os.path.join(SCRATCHPAD, 'aov_patched_v2/HeroSkinListItem_lua.lua')

    with open(input_file, 'rb') as f:
        data = bytearray(f.read())

    print(f"Input: {len(data)} bytes")

    # Find offsets
    instr_start, const_start, sizeof_int, sizeof_integer = find_proto24_offsets(data)
    print(f"Proto[24] instructions at: {instr_start}")
    print(f"Proto[24] constants at: {const_start}")

    # PATCH 1: Change K[9] from 0 to 1
    k9_offset = find_constant_k9_offset(data, const_start, sizeof_int, sizeof_integer)
    if k9_offset is None:
        print("ERROR: Cannot find K[9]")
        return

    # Write integer 1 (little-endian, 8 bytes)
    struct.pack_into('<q', data, k9_offset, 1)
    verify = int.from_bytes(data[k9_offset:k9_offset+8], 'little', signed=True)
    print(f"  Patched K[9] = {verify}")

    # PATCH 2: Replace instruction [97] (CALL for GetHeroOwnState) with LOADK R9, K[9]
    # Original [95]: SELF A=9, R8, K['GetHeroOwnState']
    # Original [96]: MOVE A=11, R3
    # Original [97]: CALL A=9, B=3, C=2 → R9 = R8:GetHeroOwnState(R11)
    # Replace [97] with: LOADK R9, K[9] (= integer 1 = Owned)
    off_97 = instr_start + 97 * 4
    loadk_r9 = encode_iABx(14, 9, 9)  # LOADK R9, K[9]
    print(f"\n  [97] Original: 0x{struct.unpack_from('<I', data, off_97)[0]:08x}")
    struct.pack_into('<I', data, off_97, loadk_r9)
    print(f"  [97] Patched:  0x{loadk_r9:08x} (LOADK R9, K[9]=1)")

    # PATCH 3: Replace instruction [101] (CALL for GetSkinOwnState) with LOADK R10, K[9]
    # Original [98]: SELF A=10, R8, K['GetSkinOwnState']
    # Original [99]: MOVE A=12, R3
    # Original [100]: MOVE A=13, R4
    # Original [101]: CALL A=10, B=4, C=2 → R10 = R8:GetSkinOwnState(R12, R13)
    # Replace [101] with: LOADK R10, K[9] (= integer 1 = Owned)
    off_101 = instr_start + 101 * 4
    loadk_r10 = encode_iABx(14, 10, 9)  # LOADK R10, K[9]
    print(f"  [101] Original: 0x{struct.unpack_from('<I', data, off_101)[0]:08x}")
    struct.pack_into('<I', data, off_101, loadk_r10)
    print(f"  [101] Patched: 0x{loadk_r10:08x} (LOADK R10, K[9]=1)")

    # PATCH 4: NOP instructions [95-96] and [98-100] (setup for removed calls)
    # These MOVE/SELF instructions are now dead code
    nop = encode_iABC(18, 0, 0, 0)  # MOVE R0, R0 (harmless NOP)
    for idx in [95, 96, 98, 99, 100]:
        off = instr_start + idx * 4
        struct.pack_into('<I', data, off, nop)
    print(f"  [95,96,98,99,100] NOP'd (MOVE R0, R0)")

    # PATCH 5: Also NOP the GetHeroWearSkinId call which uses R11 (may crash with wrong setup)
    # Actually leave it - R11 is set from CALL [104] which uses R8 (roleInfo) - still valid
    # since we only changed the RETURN value, not the method call to GetHeroWearSkinId.
    # Wait - we NOP'd [95-96] which were SELF+MOVE for GetHeroOwnState using R8.
    # R8 (roleInfo) was set BEFORE [95], so [102-104] GetHeroWearSkinId still works.
    # But [95] was SELF which sets R9=R8 and R[9+1]=R8 for method call...
    # After NOP, R9 gets set by LOADK at [97], R10 by LOADK at [101].
    # [102] SELF A=11, R8, K['GetHeroWearSkinId'] → still valid, R8 is roleInfo
    # [103] MOVE A=13, R3 → copies heroId
    # [104] CALL A=11, B=3, C=2 → R11 = R8:GetHeroWearSkinId(R13) → fine

    # Write output
    os.makedirs(os.path.dirname(output_file), exist_ok=True)
    with open(output_file, 'wb') as f:
        f.write(data)

    print(f"\nOutput: {output_file} ({len(data)} bytes)")
    print("\n=== PATCH SUMMARY ===")
    print("  K[9]: 0 → 1 (Owned enum value)")
    print("  [95-96]: NOP (was SELF+MOVE for GetHeroOwnState)")
    print("  [97]: LOADK R9 = 1 (heroOwnState = Owned)")
    print("  [98-100]: NOP (was SELF+MOVE+MOVE for GetSkinOwnState)")
    print("  [101]: LOADK R10 = 1 (skinOwnState = Owned)")
    print("\n  Effect: ALL ownership checks see Owned(1) state")
    print("  R9=1, R10=1 → skinState!=UnOwned(0) → owned display path")
    print("  skinState==Owned(1) → 'Hero_SkinState_Own' text shown")
    print("  Wear button displayed, share button enabled")


if __name__ == '__main__':
    main()

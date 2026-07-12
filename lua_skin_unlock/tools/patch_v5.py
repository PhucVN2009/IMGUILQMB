"""
Patch v5: Safe full skin unlock - NOP ownership CALLs, set result directly.

Key insight: Instead of NOP-ing JMPs/EQs (which broke control flow in v4),
we NOP the entire SELF+args+CALL sequence for ownership checks and replace
the CALL with LOADBOOL to set the result register. All downstream control
flow (EQ/JMP/TEST) remains intact and evaluates correctly against the
faked result.

Patches 8 Lua files in HeroInfoLua.pkg.bytes:
1. HeroModel_lua       - hasHero/hasSkin/isNotOwned → early return
2. HeroSkinListItem_lua - SetHeroSkinData K[9]=Owned, NoStateBG hidden
3. HeroSys_lua          - IsCanUseSkin→true, TryReqWearHeroSkin, IsHaveHeroSkin
4. HeroView_lua         - IsHaveHero, GetOwnState, IsHaveHeroSkin panels
5. HeroOverviewSys_lua  - 5x IsHaveHero calls
6. HeroSkinBuySys_lua   - IsHaveHeroSkin, IsHaveHero
7. HeroSkinView_lua     - IsHaveHeroSkin
8. HeroSkinSmallListItem_lua - GetOwnState (UnOwned-only comparisons)
"""
import struct
import os
import sys
import zipfile
import io


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


NOP = encode_iABC(18, 0, 0, 0)

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
        if t == 0: info.constants.append(('nil', None))
        elif t == 1: info.constants.append(('bool', data[off])); off += 1
        elif t == 3: info.constants.append(('number', struct.unpack_from('<d', data, off)[0])); off += sizeof_number
        elif t == 0x13: info.constants.append(('integer', int.from_bytes(data[off:off+sizeof_integer], 'little', signed=True))); off += sizeof_integer
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


def parse_lua_header(data):
    lua_off = data.find(b'\x1bLua')
    if lua_off < 0:
        raise ValueError("No Lua header found")
    offset = lua_off + 5
    fmt = data[offset]; offset += 1
    offset += 6
    sizeof_int = data[offset]; offset += 1
    sizeof_sizet = data[offset]; offset += 1
    if fmt == 1:
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    else:
        offset += 1
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    offset += sizeof_integer + sizeof_number + 1
    return offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number


def set_instr(data, proto, idx, value):
    struct.pack_into('<I', data, proto.instr_start + idx * 4, value)

def get_instr(data, proto, idx):
    return struct.unpack_from('<I', data, proto.instr_start + idx * 4)[0]

def nop_range(data, proto, start, end):
    for i in range(start, end):
        set_instr(data, proto, i, NOP)

def loadbool(reg, val):
    return encode_iABC(1, reg, val, 0)

def ret(reg):
    return encode_iABC(11, reg, 2, 0)

def verify_const(proto, idx, expected_type, expected_val):
    ct, cv = proto.constants[idx]
    assert ct == expected_type and cv == expected_val, \
        f"K[{idx}] expected ({expected_type}, {expected_val}), got ({ct}, {cv})"


# ============================================================
# Per-file patch functions
# ============================================================

def patch_hero_model(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[14-19]: Early return true/false for ownership query functions."""
    patches = [
        (14, 'IsHaveHero',          'K[5]=IsHaveHero',   2, True),
        (15, 'IsHaveHeroSkin',      'K[5]=IsHaveHeroSkin', 2, True),
        (16, 'IsHaveHeroSkin(2)',    'K[5]=IsHaveHeroSkin', 3, True),
        (17, 'isHeroNotOwned',      'K[5]=GetHeroOwnState', 2, False),
        (18, 'isSkinNotOwned',      'K[5]=GetSkinOwnState', 2, False),
        (19, 'isHeroSkinNotOwned',  'K[5]=GetSkinOwnState', 3, False),
    ]
    count = 0
    for pi, name, check, ret_reg, ret_val in patches:
        p = main_proto.children[pi]
        set_instr(data, p, 0, loadbool(ret_reg, 1 if ret_val else 0))
        set_instr(data, p, 1, ret(ret_reg))
        count += 1
        print(f"    Proto[{pi}] {name}: [0-1] return {ret_val}")
    return count


def patch_hero_skin_list_item(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[24]: K[9]=1 + LOADK. Proto[9,10]: NOT→LOADBOOL."""
    count = 0

    p24 = main_proto.children[24]
    verify_const(p24, 38, 'string', 'GetHeroOwnState')
    verify_const(p24, 39, 'string', 'GetSkinOwnState')

    off = p24.const_entries_start
    for i in range(10):
        t = data[off]; off += 1
        if i == 9:
            assert t == 0x13, f"K[9] type={t:#x}, expected 0x13 (integer)"
            struct.pack_into('<q', data, off, 1)
            print(f"    Proto[24] K[9]: 0 → 1 (Owned)")
            break
        if t == 0: pass
        elif t == 1: off += 1
        elif t == 3: off += sizeof_number
        elif t == 0x13: off += sizeof_integer
        elif t in (4, 0x14): _, off = read_string_raw(data, off, sizeof_sizet)

    set_instr(data, p24, 97, encode_iABx(14, 9, 9))
    set_instr(data, p24, 101, encode_iABx(14, 10, 9))
    nop_range(data, p24, 95, 97)
    nop_range(data, p24, 98, 101)
    print(f"    Proto[24] [97] LOADK R9,K[9]=1; [101] LOADK R10,K[9]=1; NOP [95-96,98-100]")
    count += 1

    for pi in [9, 10]:
        p = main_proto.children[pi]
        names = {9: 'SetWearBtnGO', 10: 'SetShareBtnGO'}
        i6 = get_instr(data, p, 6)
        assert (i6 & 0x3F) == 37, f"Proto[{pi}][6] op={i6 & 0x3F}, expected 37 (NOT)"
        set_instr(data, p, 6, loadbool(4, 0))
        print(f"    Proto[{pi}] {names[pi]}: [6] NOT→LOADBOOL R4,0 (NoStateBG hidden)")
        count += 1

    return count


def patch_hero_sys(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[13,14]: IsCanUseSkin→true. Proto[32]: GetSkinOwnState→non-UnOwned.
    Proto[54]: IsHaveHeroSkin→true."""
    count = 0

    p13 = main_proto.children[13]
    verify_const(p13, 4, 'string', 'IsCanUseSkin')
    set_instr(data, p13, 0, loadbool(1, 1))
    set_instr(data, p13, 1, ret(1))
    print(f"    Proto[13] IsCanUseSkin: [0-1] return true")
    count += 1

    p14 = main_proto.children[14]
    verify_const(p14, 6, 'string', 'IsCanUseSkin')
    set_instr(data, p14, 0, loadbool(2, 1))
    set_instr(data, p14, 1, ret(2))
    print(f"    Proto[14] IsCanUseSkin(2): [0-1] return true")
    count += 1

    p32 = main_proto.children[32]
    verify_const(p32, 6, 'string', 'GetSkinOwnState')
    verify_const(p32, 8, 'string', 'UnOwned')
    nop_range(data, p32, 13, 16)
    set_instr(data, p32, 16, loadbool(4, 1))
    print(f"    Proto[32] TryReqWearHeroSkin: NOP [13-15], [16] LOADBOOL R4,1")
    count += 1

    p54 = main_proto.children[54]
    verify_const(p54, 7, 'string', 'IsHaveHeroSkin')
    nop_range(data, p54, 14, 18)
    set_instr(data, p54, 18, loadbool(6, 1))
    print(f"    Proto[54] IsHaveHeroSkin: NOP [14-17], [18] LOADBOOL R6,1")
    count += 1

    return count


def patch_hero_view(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[15]: IsHaveHero→true. Proto[22]: GetOwnState→true.
    Proto[50]: IsHaveHeroSkin→true. Proto[55]: GetSkinOwnState→true."""
    count = 0

    # Proto[15]: IsHaveHero SELF[12]+args[13,14]+CALL[15] → NOP+LOADBOOL R6
    p15 = main_proto.children[15]
    verify_const(p15, 5, 'string', 'IsHaveHero')
    nop_range(data, p15, 12, 15)
    set_instr(data, p15, 15, loadbool(6, 1))
    print(f"    Proto[15] IsHaveHero: NOP [12-14], [15] LOADBOOL R6,1")
    count += 1

    # Proto[22]: GetHeroOwnState SELF[13]+GETTABLE[14]+CALL[15]+CALL[16]
    #            GetSkinOwnState SELF[17]+GETTABLE[18]+CALL[19]+GETTABLE[20]+CALL[21]+CALL[22]
    p22 = main_proto.children[22]
    verify_const(p22, 6, 'string', 'GetHeroOwnState')
    verify_const(p22, 8, 'string', 'GetSkinOwnState')
    verify_const(p22, 11, 'string', 'UnOwned')
    nop_range(data, p22, 13, 16)
    set_instr(data, p22, 16, loadbool(3, 1))
    nop_range(data, p22, 17, 22)
    set_instr(data, p22, 22, loadbool(4, 1))
    print(f"    Proto[22] WearBtn: NOP [13-15],[17-21]; [16] LOADBOOL R3,1; [22] LOADBOOL R4,1")
    count += 1

    # Proto[50]: IsHaveHeroSkin SELF[36]+GETTABLE[37]+GETTABLE[38]+CALL[39]
    p50 = main_proto.children[50]
    verify_const(p50, 16, 'string', 'IsHaveHeroSkin')
    nop_range(data, p50, 36, 39)
    set_instr(data, p50, 39, loadbool(5, 1))
    print(f"    Proto[50] IsHaveHeroSkin: NOP [36-38], [39] LOADBOOL R5,1")
    count += 1

    # Proto[55]: GetSkinOwnState SELF[91]+GETTABLE[92]+CALL[93]+GETTABLE[94]+CALL[95]+CALL[96]
    p55 = main_proto.children[55]
    verify_const(p55, 28, 'string', 'GetSkinOwnState')
    verify_const(p55, 32, 'string', 'UnOwned')
    nop_range(data, p55, 91, 96)
    set_instr(data, p55, 96, loadbool(4, 1))
    print(f"    Proto[55] Panel: NOP [91-95], [96] LOADBOOL R4,1")
    count += 1

    return count


def patch_hero_overview_sys(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[26]: 5x IsHaveHero calls → NOP SELF+args, LOADBOOL at CALL."""
    count = 0
    p26 = main_proto.children[26]
    verify_const(p26, 27, 'string', 'IsHaveHero')

    calls = [
        # (self_idx, nop_range, call_idx, result_reg)
        (95,  (95, 97),  97,  17),   # SELF[95]+GETTABLE[96]+CALL[97]
        (242, (242, 244), 244, 17),  # SELF[242]+GETTABLE[243]+CALL[244]
        (375, (375, 378), 378, 19),  # SELF[375]+GETTABLE[376]+LOADBOOL[377]+CALL[378]
        (419, (419, 421), 421, 17),  # SELF[419]+GETTABLE[420]+CALL[421]
        (453, (453, 455), 455, 22),  # SELF[453]+GETTABLE[454]+CALL[455]
    ]

    for self_idx, (nop_start, call_idx), _, result_reg in calls:
        nop_range(data, p26, nop_start, call_idx)
        set_instr(data, p26, call_idx, loadbool(result_reg, 1))
        count += 1

    print(f"    Proto[26]: 5x IsHaveHero → LOADBOOL true at [{','.join(str(c[2]) for c in calls)}]")
    return count


def patch_hero_skin_buy_sys(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[3]: IsHaveHeroSkin+IsHaveHero→true. Proto[53]: IsHaveHeroSkin→true."""
    count = 0

    p3 = main_proto.children[3]
    verify_const(p3, 69, 'string', 'IsHaveHeroSkin')
    verify_const(p3, 75, 'string', 'IsHaveHero')

    # IsHaveHeroSkin: SELF[266]+GETTABLE[267]+GETTABLE[268]+LOADBOOL[269]+CALL[270]
    nop_range(data, p3, 266, 270)
    set_instr(data, p3, 270, loadbool(25, 1))
    print(f"    Proto[3] IsHaveHeroSkin: NOP [266-269], [270] LOADBOOL R25,1")
    count += 1

    # IsHaveHero: SELF[287]+GETTABLE[288]+LOADBOOL[289]+CALL[290]
    nop_range(data, p3, 287, 290)
    set_instr(data, p3, 290, loadbool(25, 1))
    print(f"    Proto[3] IsHaveHero: NOP [287-289], [290] LOADBOOL R25,1")
    count += 1

    p53 = main_proto.children[53]
    verify_const(p53, 37, 'string', 'IsHaveHeroSkin')
    # SELF[80]+GETTABLE[81]+GETTABLE[82]+LOADBOOL[83]+CALL[84]
    nop_range(data, p53, 80, 84)
    set_instr(data, p53, 84, loadbool(5, 1))
    print(f"    Proto[53] IsHaveHeroSkin: NOP [80-83], [84] LOADBOOL R5,1")
    count += 1

    return count


def patch_hero_skin_view(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[6]: IsHaveHeroSkin→true."""
    count = 0
    p6 = main_proto.children[6]
    verify_const(p6, 5, 'string', 'IsHaveHeroSkin')
    # SELF[8]+MOVE[9]+MOVE[10]+LOADBOOL[11]+CALL[12]
    nop_range(data, p6, 8, 12)
    set_instr(data, p6, 12, loadbool(5, 1))
    print(f"    Proto[6] IsHaveHeroSkin: NOP [8-11], [12] LOADBOOL R5,1")
    count += 1
    return count


def patch_hero_skin_small_list_item(data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    """Proto[2]: GetHeroOwnState+GetSkinOwnState→true (safe: only UnOwned comparisons)."""
    count = 0
    p2 = main_proto.children[2]
    verify_const(p2, 16, 'string', 'GetHeroOwnState')
    verify_const(p2, 17, 'string', 'GetSkinOwnState')

    # GetHeroOwnState: SELF[38]+MOVE[39]+CALL[40]
    nop_range(data, p2, 38, 40)
    set_instr(data, p2, 40, loadbool(7, 1))
    print(f"    Proto[2] GetHeroOwnState: NOP [38-39], [40] LOADBOOL R7,1")
    count += 1

    # GetSkinOwnState: SELF[41]+MOVE[42]+MOVE[43]+CALL[44]
    nop_range(data, p2, 41, 44)
    set_instr(data, p2, 44, loadbool(8, 1))
    print(f"    Proto[2] GetSkinOwnState: NOP [41-43], [44] LOADBOOL R8,1")
    count += 1

    return count


# ============================================================
# File → patch function mapping
# ============================================================
PATCH_MAP = {
    'HeroModel_lua':            patch_hero_model,
    'HeroSkinListItem_lua':     patch_hero_skin_list_item,
    'HeroSys_lua':              patch_hero_sys,
    'HeroView_lua':             patch_hero_view,
    'HeroOverviewSys_lua':      patch_hero_overview_sys,
    'HeroSkinBuySys_lua':       patch_hero_skin_buy_sys,
    'HeroSkinView_lua':         patch_hero_skin_view,
    'HeroSkinSmallListItem_lua': patch_hero_skin_small_list_item,
}


def patch_lua_file(data, filename):
    """Parse and patch a single Lua file. Returns patched bytes or None."""
    basename = filename.replace('.lua', '').replace('.bytes', '')
    if basename not in PATCH_MAP:
        return None

    data = bytearray(data)
    offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number = parse_lua_header(data)
    main_proto = parse_proto(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)

    print(f"\n  {basename} ({len(data)} bytes, {len(main_proto.children)} children)")
    count = PATCH_MAP[basename](data, main_proto, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)
    print(f"    → {count} patches applied")

    return bytes(data)


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 patch_v5.py <HeroInfoLua.pkg.bytes> [output.pkg.bytes]")
        print("  Patches Lua bytecode for safe full skin unlock")
        print("  Input: original HeroInfoLua.pkg.bytes (ZIP archive)")
        print("  Output: patched HeroInfoLua.pkg.bytes")
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    if output_path is None:
        base = os.path.splitext(input_path)[0]
        output_path = base + '_patched.pkg.bytes'

    # Load zstd dictionary
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dict_path = os.path.join(script_dir, 'zstd_dict.bin')
    if not os.path.exists(dict_path):
        print(f"ERROR: zstd_dict.bin not found at {dict_path}")
        print("Place the 112640-byte zstd dictionary as tools/zstd_dict.bin")
        sys.exit(1)

    import pyzstd
    with open(dict_path, 'rb') as f:
        zstd_dict_data = f.read()
    zdict = pyzstd.ZstdDict(zstd_dict_data, is_raw=True)

    print(f"Input: {input_path}")
    print(f"Zstd dict: {len(zstd_dict_data)} bytes")

    patched_entries = {}
    with zipfile.ZipFile(input_path, 'r') as zf:
        for item in zf.infolist():
            raw = zf.read(item.filename)
            basename = item.filename.split('/')[-1].replace('.bytes', '')

            if basename not in PATCH_MAP:
                continue

            if raw[:4] == b'\x22\x4a\x00\xef':
                uncomp_size = struct.unpack_from('<I', raw, 4)[0]
                decompressed = pyzstd.decompress(raw[8:], zdict)
            else:
                decompressed = raw

            patched = patch_lua_file(decompressed, basename)
            if patched is not None:
                compressed = pyzstd.compress(patched, 17, zdict)
                verify = pyzstd.decompress(compressed, zdict)
                assert verify == patched, f"Compression roundtrip failed for {basename}"
                pkg_entry = b'\x22\x4a\x00\xef' + struct.pack('<I', len(patched)) + compressed
                patched_entries[item.filename] = pkg_entry
                print(f"    Compressed: {len(patched)} → {len(pkg_entry)} bytes")

    print(f"\nRepacking {len(patched_entries)} patched files...")
    buf = io.BytesIO()
    with zipfile.ZipFile(input_path, 'r') as zf_in:
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zf_out:
            for item in zf_in.infolist():
                if item.filename in patched_entries:
                    zf_out.writestr(item, patched_entries[item.filename])
                else:
                    zf_out.writestr(item, zf_in.read(item.filename))

    with open(output_path, 'wb') as f:
        f.write(buf.getvalue())

    orig_size = os.path.getsize(input_path)
    new_size = os.path.getsize(output_path)
    print(f"\nOutput: {output_path}")
    print(f"Size: {orig_size} → {new_size} ({new_size - orig_size:+d} bytes)")
    print(f"\nPATCH v5 COMPLETE - {len(patched_entries)} files patched")
    print("Strategy: NOP SELF+args, LOADBOOL at CALL (preserves all control flow)")


if __name__ == '__main__':
    main()

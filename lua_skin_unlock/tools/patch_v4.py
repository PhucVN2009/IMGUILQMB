"""
Patch v4: Comprehensive full skin unlock across ALL Lua files.

Patches 7 Lua files in HeroInfoLua.pkg.bytes to force all skins/heroes
to appear as Owned. No Frida or il2cpp patching required.

Files patched:
1. HeroModel_lua - Core ownership query functions (hasHero, hasSkin, etc.)
2. HeroSkinListItem_lua - Skin list item view (ownership + brightness)
3. HeroSkinSmallListItem_lua - Grid view icons (ownership + dimming)
4. HeroView_lua - Detail view (WearBtn, price view, panels)
5. HeroSkinPriceView_lua - Buy/price panel
6. HeroSys_lua - IsCanUseSkin, TryReqWearHeroSkin
7. HeroOverviewSys_lua - Hero overview dimming
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


NOP = encode_iABC(18, 0, 0, 0)  # MOVE R0, R0

OP_LOADBOOL = 1
OP_GETTABUP = 3
OP_CALL = 4
OP_SETTABLE = 7
OP_RETURN = 11
OP_LOADNIL = 12
OP_LOADK = 14
OP_EQ = 15
OP_MOVE = 18
OP_GETTABLE = 19
OP_JMP = 20
OP_NOT = 37
OP_SELF = 44
OP_TEST = 45


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


def get_instr(data, proto, idx):
    return struct.unpack_from('<I', data, proto.instr_start + idx * 4)[0]

def set_instr(data, proto, idx, value):
    struct.pack_into('<I', data, proto.instr_start + idx * 4, value)

def has_const_str(proto, name):
    return any(c[0] == 'string' and c[1] == name for c in proto.constants)

def find_const_idx(proto, name):
    for i, (ct, cv) in enumerate(proto.constants):
        if ct == 'string' and cv == name:
            return i
    return -1


def patch_set_instr(data, proto, idx, new_instr, desc=""):
    old = get_instr(data, proto, idx)
    set_instr(data, proto, idx, new_instr)
    if desc:
        print(f"    [{idx:3d}] {desc}  (0x{old:08x} -> 0x{new_instr:08x})")


def verify_proto(proto, idx, expected_first_const):
    if expected_first_const:
        if proto.constants[0] != expected_first_const:
            raise ValueError(
                f"Proto[{idx}] K[0]={proto.constants[0]}, expected {expected_first_const}")


# ============================================================
# PATCH FUNCTIONS PER FILE
# ============================================================

def patch_hero_model(data, main_proto):
    """Patch HeroModel_lua: Proto[14-19] ownership query functions."""
    print("\n  === HeroModel_lua ===")

    # Proto[14] hasHero: always return true
    p = main_proto.children[14]
    assert has_const_str(p, 'IsHaveHero'), f"Proto[14] missing IsHaveHero"
    patch_set_instr(data, p, 0, encode_iABC(OP_LOADBOOL, 1, 1, 0), "LOADBOOL R1, true")
    patch_set_instr(data, p, 1, encode_iABC(OP_RETURN, 1, 2, 0), "RETURN R1, 2")
    print("    Proto[14] hasHero -> always true")

    # Proto[15] hasSkin: always return true
    p = main_proto.children[15]
    assert has_const_str(p, 'IsHaveHeroSkin'), f"Proto[15] missing IsHaveHeroSkin"
    patch_set_instr(data, p, 0, encode_iABC(OP_LOADBOOL, 1, 1, 0), "LOADBOOL R1, true")
    patch_set_instr(data, p, 1, encode_iABC(OP_RETURN, 1, 2, 0), "RETURN R1, 2")
    print("    Proto[15] hasSkin -> always true")

    # Proto[16] hasHeroSkin: always return true
    p = main_proto.children[16]
    assert has_const_str(p, 'IsHaveHeroSkin'), f"Proto[16] missing IsHaveHeroSkin"
    patch_set_instr(data, p, 0, encode_iABC(OP_LOADBOOL, 2, 1, 0), "LOADBOOL R2, true")
    patch_set_instr(data, p, 1, encode_iABC(OP_RETURN, 2, 2, 0), "RETURN R2, 2")
    print("    Proto[16] hasHeroSkin -> always true")

    # Proto[17] isHeroNotOwned: always return false (hero IS owned)
    p = main_proto.children[17]
    assert has_const_str(p, 'GetHeroOwnState'), f"Proto[17] missing GetHeroOwnState"
    assert has_const_str(p, 'UnOwned'), f"Proto[17] missing UnOwned"
    patch_set_instr(data, p, 0, encode_iABC(OP_LOADBOOL, 1, 0, 0), "LOADBOOL R1, false")
    patch_set_instr(data, p, 1, encode_iABC(OP_RETURN, 1, 2, 0), "RETURN R1, 2")
    print("    Proto[17] isHeroNotOwned -> always false (=owned)")

    # Proto[18] isSkinNotOwned: always return false (skin IS owned)
    p = main_proto.children[18]
    assert has_const_str(p, 'GetSkinOwnState'), f"Proto[18] missing GetSkinOwnState"
    assert has_const_str(p, 'UnOwned'), f"Proto[18] missing UnOwned"
    patch_set_instr(data, p, 0, encode_iABC(OP_LOADBOOL, 1, 0, 0), "LOADBOOL R1, false")
    patch_set_instr(data, p, 1, encode_iABC(OP_RETURN, 1, 2, 0), "RETURN R1, 2")
    print("    Proto[18] isSkinNotOwned -> always false (=owned)")

    # Proto[19] isHeroSkinNotOwned: always return false
    p = main_proto.children[19]
    assert has_const_str(p, 'GetSkinOwnState'), f"Proto[19] missing GetSkinOwnState"
    assert has_const_str(p, 'UnOwned'), f"Proto[19] missing UnOwned"
    patch_set_instr(data, p, 0, encode_iABC(OP_LOADBOOL, 2, 0, 0), "LOADBOOL R2, false")
    patch_set_instr(data, p, 1, encode_iABC(OP_RETURN, 2, 2, 0), "RETURN R2, 2")
    print("    Proto[19] isHeroSkinNotOwned -> always false (=owned)")


def patch_hero_skin_list_item(data, main_proto):
    """Patch HeroSkinListItem_lua: ownership + brightness (v3 patches)."""
    print("\n  === HeroSkinListItem_lua ===")

    p9 = main_proto.children[9]
    p10 = main_proto.children[10]
    p24 = main_proto.children[24]

    assert p9.constants[0] == ('string', 'wearBtnGO'), f"Proto[9] K[0]={p9.constants[0]}"
    assert p10.constants[0] == ('string', 'shareBtnGO'), f"Proto[10] K[0]={p10.constants[0]}"

    # Proto[24]: K[9] = 1 (Owned)
    off = p24.const_entries_start
    sizeof_int = 4
    sizeof_number = 8
    sizeof_integer = 8
    sizeof_sizet = 8
    for i in range(10):
        t = data[off]; off += 1
        if i == 9:
            assert t == 0x13, f"K[9] type={t:#x}, expected 0x13"
            struct.pack_into('<q', data, off, 1)
            print("    Proto[24] K[9] -> 1 (Owned)")
            break
        if t == 0: pass
        elif t == 1: off += 1
        elif t == 3: off += sizeof_number
        elif t == 0x13: off += sizeof_integer
        elif t in (4, 0x14): _, off = read_string_raw(data, off, sizeof_sizet)

    # Proto[24]: LOADK + NOP patches
    patch_set_instr(data, p24, 97, encode_iABx(OP_LOADK, 9, 9), "LOADK R9, K[9]=1")
    patch_set_instr(data, p24, 101, encode_iABx(OP_LOADK, 10, 9), "LOADK R10, K[9]=1")
    for idx in [95, 96, 98, 99, 100]:
        set_instr(data, p24, idx, NOP)
    print("    Proto[24] [95-101] -> heroOwnState=Owned, skinOwnState=Owned")

    # Proto[9] SetWearBtnGO: [6] NOT -> LOADBOOL false
    i6 = get_instr(data, p9, 6)
    assert (i6 & 0x3F) == OP_NOT, f"Proto[9][6] op={i6 & 0x3F}, expected NOT"
    patch_set_instr(data, p9, 6, encode_iABC(OP_LOADBOOL, 4, 0, 0), "LOADBOOL R4, false (NoStateBG hidden)")

    # Proto[10] SetShareBtnGO: [6] NOT -> LOADBOOL false
    i6 = get_instr(data, p10, 6)
    assert (i6 & 0x3F) == OP_NOT, f"Proto[10][6] op={i6 & 0x3F}, expected NOT"
    patch_set_instr(data, p10, 6, encode_iABC(OP_LOADBOOL, 4, 0, 0), "LOADBOOL R4, false (NoStateBG hidden)")


def patch_hero_skin_small_list_item(data, main_proto):
    """Patch HeroSkinSmallListItem_lua Proto[2]: grid view ownership."""
    print("\n  === HeroSkinSmallListItem_lua ===")

    p = main_proto.children[2]
    assert has_const_str(p, 'GetHeroOwnState'), f"Proto[2] missing GetHeroOwnState"
    assert has_const_str(p, 'noSkinGo'), f"Proto[2] missing noSkinGo"

    # [48] EQ 1, heroOwnState, UnOwned -> [49] JMP (jump when UnOwned)
    # NOP [49] to force "hero owned" path (fall through to [50])
    i48 = get_instr(data, p, 48)
    assert (i48 & 0x3F) == OP_EQ, f"Proto[2][48] op={i48 & 0x3F}, expected EQ"
    patch_set_instr(data, p, 49, NOP, "NOP JMP (force hero owned)")

    # [65] EQ 1, skinOwnState, UnOwned -> [66] JMP (shows noSkinGo when UnOwned)
    # NOP [66] to force "skin owned" path -> noSkinGo hidden
    i65 = get_instr(data, p, 65)
    assert (i65 & 0x3F) == OP_EQ, f"Proto[2][65] op={i65 & 0x3F}, expected EQ"
    patch_set_instr(data, p, 66, NOP, "NOP JMP (force skin owned, noSkinGo hidden)")

    # [78] EQ 0, skinOwnState, UnOwned -> NOP to force btnShare visible
    i78 = get_instr(data, p, 78)
    assert (i78 & 0x3F) == OP_EQ, f"Proto[2][78] op={i78 & 0x3F}, expected EQ"
    patch_set_instr(data, p, 78, NOP, "NOP EQ (force btnShare visible)")


def patch_hero_view(data, main_proto):
    """Patch HeroView_lua: WearBtn, price view, panel visibility."""
    print("\n  === HeroView_lua ===")

    # Proto[22]: WearBtn visibility
    p22 = main_proto.children[22]
    assert has_const_str(p22, 'WearBtn'), f"Proto[22] missing WearBtn"
    assert has_const_str(p22, 'GetHeroOwnState'), f"Proto[22] missing GetHeroOwnState"

    # [26] EQ 0, skinOwnState, UnOwned -> NOP to force "skin not UnOwned"
    # (NOP makes [27] JMP always execute -> goes to hero check at [30])
    i26 = get_instr(data, p22, 26)
    assert (i26 & 0x3F) == OP_EQ, f"Proto[22][26] op={i26 & 0x3F}, expected EQ"
    patch_set_instr(data, p22, 26, NOP, "NOP EQ (skin always not UnOwned)")

    # [35] JMP (when hero UnOwned) -> NOP to force "hero owned"
    i34 = get_instr(data, p22, 34)
    assert (i34 & 0x3F) == OP_EQ, f"Proto[22][34] op={i34 & 0x3F}, expected EQ"
    patch_set_instr(data, p22, 35, NOP, "NOP JMP (force hero owned)")

    # [53] JMP (hero UnOwned second check) -> NOP
    i52 = get_instr(data, p22, 52)
    assert (i52 & 0x3F) == OP_EQ, f"Proto[22][52] op={i52 & 0x3F}, expected EQ"
    patch_set_instr(data, p22, 53, NOP, "NOP JMP (force hero owned final)")

    # Proto[35]: ShowPriceView
    p35 = main_proto.children[35]
    assert has_const_str(p35, 'GetHeroOwnState'), f"Proto[35] missing GetHeroOwnState"
    assert has_const_str(p35, 'Owned'), f"Proto[35] missing Owned"

    # [32] EQ 0, heroOwnState, Owned -> [33] JMP to price view when NOT Owned
    # NOP [33] to force "hero Owned" (fall through to skin check)
    i32 = get_instr(data, p35, 32)
    assert (i32 & 0x3F) == OP_EQ, f"Proto[35][32] op={i32 & 0x3F}, expected EQ"
    patch_set_instr(data, p35, 33, NOP, "NOP JMP (force hero Owned)")

    # [37] EQ 0, skinOwnState, Owned -> [38] JMP to price view when NOT Owned
    # NOP [38] to force "skin Owned" (fall through to owned path)
    i37 = get_instr(data, p35, 37)
    assert (i37 & 0x3F) == OP_EQ, f"Proto[35][37] op={i37 & 0x3F}, expected EQ"
    patch_set_instr(data, p35, 38, NOP, "NOP JMP (force skin Owned)")

    # Proto[55]: Panel fullscreen / price view toggle
    p55 = main_proto.children[55]
    assert has_const_str(p55, 'GetSkinOwnState'), f"Proto[55] missing GetSkinOwnState"
    assert has_const_str(p55, 'UnOwned'), f"Proto[55] missing UnOwned"

    # [102] EQ 1, skinOwnState, UnOwned -> [103] JMP (forces R1=true when UnOwned)
    # NOP [103] to force "skin owned" (R1=false -> hide price panel)
    i102 = get_instr(data, p55, 102)
    assert (i102 & 0x3F) == OP_EQ, f"Proto[55][102] op={i102 & 0x3F}, expected EQ"
    patch_set_instr(data, p55, 103, NOP, "NOP JMP (force skin owned, hide price)")


def patch_hero_skin_price_view(data, main_proto):
    """Patch HeroSkinPriceView_lua Proto[3]: buy/price panel."""
    print("\n  === HeroSkinPriceView_lua ===")

    p = main_proto.children[3]
    assert has_const_str(p, 'GetHeroOwnState'), f"Proto[3] missing GetHeroOwnState"
    assert has_const_str(p, 'Owned'), f"Proto[3] missing Owned"
    assert has_const_str(p, 'buyBtnGO'), f"Proto[3] missing buyBtnGO"

    # [43] EQ 1, heroOwnState, Owned -> [44] JMP 187 (to skin check when IS Owned)
    # NOP [43] to force JMP always executes -> always goes to skin Owned check
    i43 = get_instr(data, p, 43)
    assert (i43 & 0x3F) == OP_EQ, f"Proto[3][43] op={i43 & 0x3F}, expected EQ"
    patch_set_instr(data, p, 43, NOP, "NOP EQ (force hero Owned -> skip buy panel)")

    # [235] EQ 1, skinOwnState, Owned -> [236] JMP 199 (to end when IS Owned)
    # NOP [235] to force JMP always executes -> skip price panel entirely
    i235 = get_instr(data, p, 235)
    assert (i235 & 0x3F) == OP_EQ, f"Proto[3][235] op={i235 & 0x3F}, expected EQ"
    patch_set_instr(data, p, 235, NOP, "NOP EQ (force skin Owned -> skip buy panel)")


def patch_hero_sys(data, main_proto):
    """Patch HeroSys_lua: IsCanUseSkin + TryReqWearHeroSkin."""
    print("\n  === HeroSys_lua ===")

    # Proto[13] IsCanUseSkin: always return true
    p13 = main_proto.children[13]
    assert has_const_str(p13, 'IsCanUseSkin'), f"Proto[13] missing IsCanUseSkin"
    patch_set_instr(data, p13, 0, encode_iABC(OP_LOADBOOL, 2, 1, 0), "LOADBOOL R2, true")
    patch_set_instr(data, p13, 1, encode_iABC(OP_RETURN, 2, 2, 0), "RETURN R2, 2")
    print("    Proto[13] IsCanUseSkin -> always true")

    # Proto[14] IsCanUseSkin (alt): always return true
    p14 = main_proto.children[14]
    assert has_const_str(p14, 'IsCanUseSkin'), f"Proto[14] missing IsCanUseSkin"
    patch_set_instr(data, p14, 0, encode_iABC(OP_LOADBOOL, 5, 1, 0), "LOADBOOL R5, true")
    patch_set_instr(data, p14, 1, encode_iABC(OP_RETURN, 5, 2, 0), "RETURN R5, 2")
    print("    Proto[14] IsCanUseSkin -> always true")

    # Proto[32] TryReqWearHeroSkin: NOP the UnOwned check JMP
    p32 = main_proto.children[32]
    assert has_const_str(p32, 'GetSkinOwnState'), f"Proto[32] missing GetSkinOwnState"
    assert has_const_str(p32, 'UnOwned'), f"Proto[32] missing UnOwned"
    assert has_const_str(p32, 'ReqWearHeroSkin'), f"Proto[32] missing ReqWearHeroSkin"

    # [20] EQ 1, skinOwnState, UnOwned -> [21] JMP (bail if unowned)
    # NOP [21] to allow wearing "unowned" skins
    i20 = get_instr(data, p32, 20)
    assert (i20 & 0x3F) == OP_EQ, f"Proto[32][20] op={i20 & 0x3F}, expected EQ"
    patch_set_instr(data, p32, 21, NOP, "NOP JMP (allow wearing unowned skins)")


def patch_hero_overview_sys(data, main_proto):
    """Patch HeroOverviewSys_lua Proto[26]: hero overview dimming."""
    print("\n  === HeroOverviewSys_lua ===")

    p = main_proto.children[26]
    assert has_const_str(p, 'IsHaveHero'), f"Proto[26] missing IsHaveHero"

    # Find all SELF+IsHaveHero -> CALL -> TEST -> JMP patterns
    ihh_idx = find_const_idx(p, 'IsHaveHero')
    ihh_rk = 256 + ihh_idx

    patched = 0
    for j in range(p.n_instr - 4):
        raw = get_instr(data, p, j)
        op, A, B, C = decode_instr(raw)

        if op == OP_SELF and C == ihh_rk:
            # Found SELF Rx, Ry, IsHaveHero
            # Look for CALL, then TEST Rx, 0 + JMP
            for k in range(j + 1, min(j + 6, p.n_instr)):
                raw_k = get_instr(data, p, k)
                op_k = raw_k & 0x3F
                if op_k == OP_CALL:
                    call_A = (raw_k >> 6) & 0xFF
                    if call_A == A:
                        # Found CALL on same register
                        for m in range(k + 1, min(k + 3, p.n_instr)):
                            raw_m = get_instr(data, p, m)
                            op_m = raw_m & 0x3F
                            if op_m == OP_TEST:
                                test_A = (raw_m >> 6) & 0xFF
                                test_C = (raw_m >> 14) & 0x1FF
                                if test_A == A and test_C == 0:
                                    # TEST Rx, 0 -> skip if false
                                    # Next should be JMP
                                    if m + 1 < p.n_instr:
                                        raw_jmp = get_instr(data, p, m + 1)
                                        if (raw_jmp & 0x3F) == OP_JMP:
                                            patch_set_instr(data, p, m + 1, NOP,
                                                f"NOP JMP after IsHaveHero (force hero owned)")
                                            patched += 1
                            elif op_m == OP_NOT:
                                # NOT Rx, Rx -> used as parameter (proficiency icon)
                                not_A = (raw_m >> 6) & 0xFF
                                not_B = (raw_m >> 23) & 0x1FF
                                if not_B == A:
                                    patch_set_instr(data, p, m,
                                        encode_iABC(OP_LOADBOOL, not_A, 0, 0),
                                        f"LOADBOOL R{not_A}, false (not grayed)")
                                    patched += 1
                    break

    print(f"    Proto[26] patched {patched} IsHaveHero checks")


# ============================================================
# MAIN
# ============================================================

def process_file(filepath, patch_func):
    """Load a Lua file, parse it, apply patches, return patched data."""
    with open(filepath, 'rb') as f:
        data = bytearray(f.read())

    offset, si, ss, sie, sn = parse_lua_header(data)
    main_proto = parse_proto(data, offset, si, ss, sie, sn)

    patch_func(data, main_proto)

    return bytes(data)


def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)

    if len(sys.argv) >= 2:
        input_pkg = sys.argv[1]
    else:
        input_pkg = os.path.join(repo_root, 'input', 'HeroInfoLua.pkg.bytes')
        if not os.path.exists(input_pkg):
            scratchpad = os.environ.get('SCRATCHPAD', '/tmp')
            input_pkg = os.path.join(scratchpad, 'aov_files/HeroInfoLua.pkg.bytes')

    if not os.path.exists(input_pkg):
        print(f"ERROR: Input file not found: {input_pkg}")
        print("Usage: python3 patch_v4.py [HeroInfoLua.pkg.bytes]")
        sys.exit(1)

    output_pkg = sys.argv[2] if len(sys.argv) >= 3 else os.path.join(repo_root, 'output', 'HeroInfoLua.pkg.bytes')
    os.makedirs(os.path.dirname(output_pkg), exist_ok=True)

    # Load zstd dictionary
    gmhall_path = os.environ.get('GMHALL_PATH')
    if not gmhall_path:
        candidates = [
            '/root/.claude/uploads/225a4123-2613-56d7-9ef1-6593374f172c/d99a6eb0-gmhallv3.py',
            os.path.join(repo_root, 'tools', 'gmhallv3.py'),
        ]
        for c in candidates:
            if os.path.exists(c):
                gmhall_path = c
                break

    if not gmhall_path or not os.path.exists(gmhall_path):
        print("ERROR: ZSTD dictionary file not found.")
        print("Set GMHALL_PATH environment variable to gmhallv3.py location.")
        sys.exit(1)

    zstd_globals = {}
    with open(gmhall_path, 'r') as f:
        content = f.read()
    start = content.find('ZSTD_DICT = ')
    end = content.find('\n\n', start)
    if end < 0:
        end = content.find('\ndef ', start)
    exec(content[start:end], zstd_globals)
    ZSTD_DICT = zstd_globals['ZSTD_DICT']

    import pyzstd
    zdict = pyzstd.ZstdDict(ZSTD_DICT, is_raw=True)

    # Files to patch and their patch functions
    file_patches = {
        'HeroModel_lua': patch_hero_model,
        'HeroSkinListItem_lua': patch_hero_skin_list_item,
        'HeroSkinSmallListItem_lua': patch_hero_skin_small_list_item,
        'HeroView_lua': patch_hero_view,
        'HeroSkinPriceView_lua': patch_hero_skin_price_view,
        'HeroSys_lua': patch_hero_sys,
        'HeroOverviewSys_lua': patch_hero_overview_sys,
    }

    print(f"{'='*60}")
    print(f"AOV SKIN UNLOCK - PATCH v4 (Comprehensive)")
    print(f"{'='*60}")
    print(f"Input: {input_pkg} ({os.path.getsize(input_pkg)} bytes)")

    patched_entries = {}

    with zipfile.ZipFile(input_pkg, 'r') as zf:
        for item in zf.infolist():
            basename = item.filename.split('/')[-1].replace('.bytes', '')
            if basename not in file_patches:
                continue

            raw = zf.read(item.filename)
            if raw[:4] == b'\x22\x4a\x00\xef':
                uncomp_size = struct.unpack_from('<I', raw, 4)[0]
                decompressed = pyzstd.decompress(raw[8:], zdict)
            else:
                decompressed = raw

            print(f"\n  Processing {basename} ({len(decompressed)} bytes)...")

            # Write temp file for processing
            import tempfile
            with tempfile.NamedTemporaryFile(suffix='.lua', delete=False) as tmp:
                tmp.write(decompressed)
                tmp_path = tmp.name

            try:
                patched = process_file(tmp_path, file_patches[basename])
            finally:
                os.unlink(tmp_path)

            # Compress
            compressed = pyzstd.compress(patched, 17, zdict)
            verify = pyzstd.decompress(compressed, zdict)
            assert verify == patched, f"Compression verify failed for {basename}!"

            pkg_entry = b'\x22\x4a\x00\xef' + struct.pack('<I', len(patched)) + compressed
            patched_entries[item.filename] = pkg_entry
            print(f"  {basename}: {len(decompressed)} -> {len(pkg_entry)} bytes (compressed)")

    # Repack
    print(f"\n{'='*60}")
    print("Repacking ZIP...")

    buf = io.BytesIO()
    with zipfile.ZipFile(input_pkg, 'r') as zf_in:
        with zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zf_out:
            for item in zf_in.infolist():
                if item.filename in patched_entries:
                    zf_out.writestr(item, patched_entries[item.filename])
                    print(f"  Replaced: {item.filename}")
                else:
                    zf_out.writestr(item, zf_in.read(item.filename))

    with open(output_pkg, 'wb') as f:
        f.write(buf.getvalue())

    orig_size = os.path.getsize(input_pkg)
    new_size = os.path.getsize(output_pkg)
    print(f"\nOutput: {output_pkg}")
    print(f"Size: {orig_size} -> {new_size} ({new_size - orig_size:+d} bytes)")

    print(f"\n{'='*60}")
    print("PATCH v4 COMPLETE - Files patched:")
    print("  1. HeroModel_lua:")
    print("     - hasHero() -> always true")
    print("     - hasSkin() -> always true")
    print("     - hasHeroSkin() -> always true")
    print("     - isHeroNotOwned() -> always false (=owned)")
    print("     - isSkinNotOwned() -> always false (=owned)")
    print("     - isHeroSkinNotOwned() -> always false (=owned)")
    print("  2. HeroSkinListItem_lua:")
    print("     - heroOwnState/skinOwnState = Owned")
    print("     - NoStateBG always hidden (bright icons)")
    print("  3. HeroSkinSmallListItem_lua:")
    print("     - Grid view: hero+skin always owned")
    print("     - noSkinGo overlay hidden")
    print("     - btnShare visible")
    print("  4. HeroView_lua:")
    print("     - WearBtn: hero+skin always owned")
    print("     - ShowPriceView: hero+skin Owned (no buy panel)")
    print("     - Panel: skin owned (price panel hidden)")
    print("  5. HeroSkinPriceView_lua:")
    print("     - hero Owned -> skip hero buy panel")
    print("     - skin Owned -> skip skin buy panel")
    print("  6. HeroSys_lua:")
    print("     - IsCanUseSkin() -> always true")
    print("     - TryReqWearHeroSkin: allow wearing 'unowned' skins")
    print("  7. HeroOverviewSys_lua:")
    print("     - IsHaveHero checks -> force owned (no dimming)")
    print(f"{'='*60}")


if __name__ == '__main__':
    main()

"""
Analyze custom Lua 5.3 bytecode to deduce opcode mapping.
Game uses format=1 (header omits sizeof(Instruction), implies 4 bytes).
"""
import struct
import sys
import os

# Standard Lua 5.3 opcodes
STD_OPCODES = [
    "MOVE", "LOADK", "LOADKX", "LOADBOOL", "LOADNIL",
    "GETUPVAL", "GETTABUP", "GETTABLE", "SETTABUP", "SETUPVAL",
    "SETTABLE", "NEWTABLE", "SELF", "ADD", "SUB",
    "MUL", "MOD", "POW", "DIV", "IDIV",
    "BAND", "BOR", "BXOR", "SHL", "SHR",
    "UNM", "BNOT", "NOT", "LEN", "CONCAT",
    "JMP", "EQ", "LT", "LE", "TEST",
    "TESTSET", "CALL", "TAILCALL", "RETURN", "FORLOOP",
    "FORPREP", "TFORCALL", "TFORLOOP", "SETLIST", "CLOSURE",
    "VARARG", "EXTRAARG"
]

# Instruction format masks
def get_opcode(instr):
    return instr & 0x3F

def get_A(instr):
    return (instr >> 6) & 0xFF

def get_B(instr):
    return (instr >> 23) & 0x1FF

def get_C(instr):
    return (instr >> 14) & 0x1FF

def get_Bx(instr):
    return (instr >> 14) & 0x3FFFF

def get_sBx(instr):
    return get_Bx(instr) - 131071  # MAXARG_sBx = (1<<17)-1

def get_Ax(instr):
    return (instr >> 6) & 0x3FFFFFF

def is_K(val):
    """Check if B or C field is a constant reference (bit 8 set for 9-bit fields)"""
    return val >= 256

def K_index(val):
    return val - 256 if val >= 256 else val


class LuaChunk:
    def __init__(self):
        self.source = ""
        self.linedefined = 0
        self.lastlinedefined = 0
        self.numparams = 0
        self.is_vararg = 0
        self.maxstacksize = 0
        self.instructions = []
        self.constants = []
        self.upvalues = []
        self.protos = []
        self.lineinfo = []
        self.locvars = []
        self.upvalue_names = []


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
    try:
        return s.decode('utf-8'), offset
    except:
        return s.decode('latin-1'), offset


def parse_function(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number):
    chunk = LuaChunk()
    
    # Source name
    chunk.source, offset = read_string(data, offset, sizeof_sizet)
    
    # Line numbers
    chunk.linedefined = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    chunk.lastlinedefined = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    
    # Params
    chunk.numparams = data[offset]
    chunk.is_vararg = data[offset+1]
    chunk.maxstacksize = data[offset+2]
    offset += 3
    
    # Instructions (4 bytes each)
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        instr = struct.unpack_from('<I', data, offset)[0]
        chunk.instructions.append(instr)
        offset += 4
    
    # Constants
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        t = data[offset]
        offset += 1
        if t == 0:  # nil
            chunk.constants.append(None)
        elif t == 1:  # boolean
            chunk.constants.append(bool(data[offset]))
            offset += 1
        elif t == 3:  # float
            val = struct.unpack_from('<d', data, offset)[0]
            chunk.constants.append(val)
            offset += sizeof_number
        elif t == 0x13:  # integer
            val = int.from_bytes(data[offset:offset+sizeof_integer], 'little', signed=True)
            chunk.constants.append(val)
            offset += sizeof_integer
        elif t in (4, 0x14):  # short/long string
            s, offset = read_string(data, offset, sizeof_sizet)
            chunk.constants.append(s)
        else:
            raise ValueError(f"Unknown constant type {t} at offset {offset-1}")
    
    # Upvalues
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        instack = data[offset]
        idx = data[offset+1]
        chunk.upvalues.append((instack, idx))
        offset += 2
    
    # Protos
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        proto, offset = parse_function(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)
        chunk.protos.append(proto)
    
    # Line info
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        chunk.lineinfo.append(int.from_bytes(data[offset:offset+sizeof_int], 'little'))
        offset += sizeof_int
    
    # Local vars
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        name, offset = read_string(data, offset, sizeof_sizet)
        startpc = int.from_bytes(data[offset:offset+sizeof_int], 'little')
        offset += sizeof_int
        endpc = int.from_bytes(data[offset:offset+sizeof_int], 'little')
        offset += sizeof_int
        chunk.locvars.append((name, startpc, endpc))
    
    # Upvalue names
    n = int.from_bytes(data[offset:offset+sizeof_int], 'little')
    offset += sizeof_int
    for i in range(n):
        name, offset = read_string(data, offset, sizeof_sizet)
        chunk.upvalue_names.append(name)
    
    return chunk, offset


def parse_file(filepath):
    with open(filepath, 'rb') as f:
        data = f.read()
    
    # Skip 128-byte signature
    if data[:4] != b'\x1bLua':
        lua_off = data.find(b'\x1bLua')
        if lua_off >= 0:
            data = data[lua_off:]
    
    # Parse header (format=1)
    offset = 4  # skip \x1bLua
    version = data[offset]; offset += 1
    fmt = data[offset]; offset += 1
    offset += 6  # LUAC_DATA
    
    sizeof_int = data[offset]; offset += 1
    sizeof_sizet = data[offset]; offset += 1
    
    if fmt == 1:
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    else:
        sizeof_instr = data[offset]; offset += 1
        sizeof_integer = data[offset]; offset += 1
        sizeof_number = data[offset]; offset += 1
    
    # Skip LUAC_INT and LUAC_NUM
    offset += sizeof_integer + sizeof_number
    
    # Sizeupvalues
    sizeupvalues = data[offset]; offset += 1
    
    # Parse main function
    main_chunk, end = parse_function(data, offset, sizeof_int, sizeof_sizet, sizeof_integer, sizeof_number)
    
    return main_chunk


def analyze_opcodes(chunk, depth=0):
    """Analyze a chunk to deduce opcode mapping based on expected patterns."""
    results = {}
    prefix = "  " * depth
    
    print(f"{prefix}Function: {chunk.source or '(main)'} [{chunk.linedefined}-{chunk.lastlinedefined}]")
    print(f"{prefix}  params={chunk.numparams} vararg={chunk.is_vararg} maxstack={chunk.maxstacksize}")
    print(f"{prefix}  {len(chunk.instructions)} instructions, {len(chunk.constants)} constants, {len(chunk.protos)} protos")
    print(f"{prefix}  upvalues: {chunk.upvalue_names}")
    
    # Print constants
    if len(chunk.constants) <= 40:
        for i, c in enumerate(chunk.constants):
            print(f"{prefix}  K[{i}] = {repr(c)}")
    
    # Print first N instructions with decoded fields
    print(f"{prefix}  Instructions:")
    for i, instr in enumerate(chunk.instructions[:30]):
        op = get_opcode(instr)
        A = get_A(instr)
        B = get_B(instr)
        C = get_C(instr)
        Bx = get_Bx(instr)
        sBx = get_sBx(instr)
        
        # Try to annotate with constant names
        b_str = ""
        c_str = ""
        if is_K(B) and K_index(B) < len(chunk.constants):
            b_str = f" ; K[{K_index(B)}]={repr(chunk.constants[K_index(B)])}"
        if is_K(C) and K_index(C) < len(chunk.constants):
            c_str = f" ; K[{K_index(C)}]={repr(chunk.constants[K_index(C)])}"
        
        bx_str = ""
        if Bx < len(chunk.constants):
            bx_str = f" ; K[{Bx}]={repr(chunk.constants[Bx])}"
        
        print(f"{prefix}  [{i:3d}] op={op:2d} A={A:3d} B={B:3d} C={C:3d} Bx={Bx:5d}{b_str}{c_str}{bx_str}")
    
    if len(chunk.instructions) > 30:
        print(f"{prefix}  ... ({len(chunk.instructions)-30} more)")
    
    print()
    
    # Recurse into first few protos
    for i, proto in enumerate(chunk.protos[:3]):
        analyze_opcodes(proto, depth+1)
    
    return results


if __name__ == '__main__':
    scratchpad = os.environ.get('SCRATCHPAD', '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad')
    
    # Parse a simple known file
    filepath = os.path.join(scratchpad, 'aov_decoded/Lua_Signed/AOV/Mall/SubModule/MallBoutiqueNewCharacterItemView_lua.lua')
    print(f"=== Analyzing: {os.path.basename(filepath)} ===\n")
    chunk = parse_file(filepath)
    analyze_opcodes(chunk)
    
    print("\n" + "="*60)
    # Also analyze a slightly more complex one
    filepath2 = os.path.join(scratchpad, 'aov_decoded/Lua_Signed/Kernel/Entry/global_lua.lua')
    if os.path.exists(filepath2):
        print(f"\n=== Analyzing: {os.path.basename(filepath2)} ===\n")
        chunk2 = parse_file(filepath2)
        analyze_opcodes(chunk2)

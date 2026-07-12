"""
Lua 5.3 (Tencent custom format) full parse -> tree -> serialize, plus a
bytecode injector.

Used to inject a call to `CRoleInfoManager.instance:GetMasterRoleInfo():OnGmAddAllSkin()`
at the top of a chosen function, so all skins are added to the local owned
list (m_ownSkinIdList). Every screen (Lua + C#) then reads a full owned list.

The serializer round-trips byte-identically for unmodified input (verified in
main() self-test), which guarantees we only change what we intend.
"""
import struct


# ---------- primitive readers/writers ----------

def r_u8(d, o): return d[o], o + 1
def r_int(d, o, n): return int.from_bytes(d[o:o+n], 'little'), o + n

def r_string(d, o, ss):
    size = d[o]; o += 1
    if size == 0:
        return None, o          # nil string (distinct from empty)
    if size == 0xFF:
        size = int.from_bytes(d[o:o+ss], 'little'); o += ss
    s = d[o:o+size-1]; o += size - 1
    return s, o

def w_string(s, ss):
    # s is bytes or None
    if s is None:
        return b'\x00'
    n = len(s) + 1
    if n < 0xFF:
        return bytes([n]) + s
    return b'\xFF' + n.to_bytes(ss, 'little') + s


class Proto:
    __slots__ = ('source', 'linedefined', 'lastlinedefined', 'numparams',
                 'is_vararg', 'maxstacksize', 'code', 'constants', 'upvalues',
                 'protos', 'lineinfo', 'locvars', 'upvalnames')


class LuaFile:
    def __init__(self):
        self.prefix = b''      # bytes before main proto (RSA prefix + \x1bLua header)
        self.suffix = b''      # trailing bytes after main proto (usually empty)
        self.si = 4            # sizeof_int
        self.ss = 8            # sizeof_sizet
        self.sii = 8           # sizeof_integer
        self.sn = 8            # sizeof_number
        self.main = None


def parse_proto(d, o, si, ss, sii, sn):
    p = Proto()
    p.source, o = r_string(d, o, ss)
    p.linedefined, o = r_int(d, o, si)
    p.lastlinedefined, o = r_int(d, o, si)
    p.numparams, o = r_u8(d, o)
    p.is_vararg, o = r_u8(d, o)
    p.maxstacksize, o = r_u8(d, o)

    n, o = r_int(d, o, si)
    p.code = list(struct.unpack_from('<%dI' % n, d, o)); o += n * 4

    n, o = r_int(d, o, si)
    p.constants = []
    for _ in range(n):
        t = d[o]; o += 1
        if t == 0:
            p.constants.append((0, None))
        elif t == 1:
            p.constants.append((1, d[o])); o += 1
        elif t == 3:
            p.constants.append((3, d[o:o+sn])); o += sn        # number: keep raw bytes
        elif t == 0x13:
            p.constants.append((0x13, d[o:o+sii])); o += sii    # integer: keep raw bytes
        elif t in (4, 0x14):
            s, o = r_string(d, o, ss)
            p.constants.append((t, s))
        else:
            raise ValueError("bad const type %d at %d" % (t, o))

    n, o = r_int(d, o, si)
    p.upvalues = []
    for _ in range(n):
        instack = d[o]; idx = d[o+1]; o += 2
        p.upvalues.append((instack, idx))

    n, o = r_int(d, o, si)
    p.protos = []
    for _ in range(n):
        c, o = parse_proto(d, o, si, ss, sii, sn)
        p.protos.append(c)

    n, o = r_int(d, o, si)
    p.lineinfo = list(struct.unpack_from('<%d%s' % (n, {4:'i',8:'q'}[si]), d, o)); o += n * si

    n, o = r_int(d, o, si)
    p.locvars = []
    for _ in range(n):
        s, o = r_string(d, o, ss)
        a, o = r_int(d, o, si)
        b, o = r_int(d, o, si)
        p.locvars.append((s, a, b))

    n, o = r_int(d, o, si)
    p.upvalnames = []
    for _ in range(n):
        s, o = r_string(d, o, ss)
        p.upvalnames.append(s)

    return p, o


def ser_proto(p, si, ss, sii, sn):
    out = bytearray()
    out += w_string(p.source, ss)
    out += p.linedefined.to_bytes(si, 'little')
    out += p.lastlinedefined.to_bytes(si, 'little')
    out += bytes([p.numparams, p.is_vararg, p.maxstacksize])

    out += len(p.code).to_bytes(si, 'little')
    out += struct.pack('<%dI' % len(p.code), *p.code)

    out += len(p.constants).to_bytes(si, 'little')
    for t, v in p.constants:
        if t == 0:
            out += bytes([0])
        elif t == 1:
            out += bytes([1, v])
        elif t == 3:
            out += bytes([3]) + v
        elif t == 0x13:
            out += bytes([0x13]) + v
        elif t in (4, 0x14):
            out += bytes([t]) + w_string(v, ss)

    out += len(p.upvalues).to_bytes(si, 'little')
    for instack, idx in p.upvalues:
        out += bytes([instack, idx])

    out += len(p.protos).to_bytes(si, 'little')
    for c in p.protos:
        out += ser_proto(c, si, ss, sii, sn)

    out += len(p.lineinfo).to_bytes(si, 'little')
    if p.lineinfo:
        out += struct.pack('<%d%s' % (len(p.lineinfo), {4:'i',8:'q'}[si]), *p.lineinfo)

    out += len(p.locvars).to_bytes(si, 'little')
    for s, a, b in p.locvars:
        out += w_string(s, ss)
        out += a.to_bytes(si, 'little')
        out += b.to_bytes(si, 'little')

    out += len(p.upvalnames).to_bytes(si, 'little')
    for s in p.upvalnames:
        out += w_string(s, ss)

    return bytes(out)


def parse_file(data):
    lf = LuaFile()
    lua_off = data.find(b'\x1bLua')
    if lua_off < 0:
        raise ValueError("no \\x1bLua")
    o = lua_off + 5
    fmt = data[o]; o += 1
    o += 6
    lf.si = data[o]; o += 1
    lf.ss = data[o]; o += 1
    if fmt == 1:
        lf.sii = data[o]; o += 1
        lf.sn = data[o]; o += 1
    else:
        o += 1
        lf.sii = data[o]; o += 1
        lf.sn = data[o]; o += 1
    o += lf.sii + lf.sn + 1
    lf.prefix = data[:o]
    lf.main, end = parse_proto(data, o, lf.si, lf.ss, lf.sii, lf.sn)
    lf.suffix = data[end:]
    return lf


def ser_file(lf):
    return lf.prefix + ser_proto(lf.main, lf.si, lf.ss, lf.sii, lf.sn) + lf.suffix


# ---------- instruction encoders ----------

def iABC(op, a, b, c):
    return (op & 0x3F) | ((a & 0xFF) << 6) | ((c & 0x1FF) << 14) | ((b & 0x1FF) << 23)

def iABx(op, a, bx):
    return (op & 0x3F) | ((a & 0xFF) << 6) | ((bx & 0x3FFFF) << 14)

OP_GETUPVAL = 0
OP_GETTABUP = 3
OP_CALL = 4
OP_GETTABLE = 19
OP_JMP = 20
OP_TEST = 45
OP_SELF = 44

def iAsBx(op, a, sbx):
    return iABx(op, a, sbx + 131071)


# ---------- constant helpers ----------

def find_or_add_str_const(proto, name):
    """Return index of string constant `name`, adding it (appended) if absent."""
    nb = name.encode()
    for i, (t, v) in enumerate(proto.constants):
        if t in (4, 0x14) and v == nb:
            return i
    proto.constants.append((4, nb))
    return len(proto.constants) - 1


def find_env_upval(proto):
    """Find the upvalue index whose name is '_ENV' (namespace access base)."""
    for i, nm in enumerate(proto.upvalnames):
        if nm == b'_ENV':
            return i
    return None


def inject_add_all_skin(proto):
    """Prepend a call: N.CRoleInfoManager.instance:GetMasterRoleInfo():OnGmAddAllSkin().

    Uses two fresh registers at the top of the stack. Safe w.r.t. jumps because
    the whole block is inserted before instruction 0 (all existing relative
    jumps shift uniformly).
    """
    env = find_env_upval(proto)
    if env is None:
        raise ValueError("no _ENV upvalue; cannot access globals")

    kN   = find_or_add_str_const(proto, 'N')
    kMgr = find_or_add_str_const(proto, 'CRoleInfoManager')
    kIns = find_or_add_str_const(proto, 'instance')
    kGet = find_or_add_str_const(proto, 'GetMasterRoleInfo')
    kAdd = find_or_add_str_const(proto, 'OnGmAddAllSkin')

    base = proto.maxstacksize          # first free register
    RK = lambda k: k + 256             # constant as RK operand

    # if masterRoleInfo then masterRoleInfo:OnGmAddAllSkin() end
    block = [
        iABC(OP_GETTABUP, base, env, RK(kN)),          # R[base] = N
        iABC(OP_GETTABLE, base, base, RK(kMgr)),       # R[base] = N.CRoleInfoManager
        iABC(OP_GETTABLE, base, base, RK(kIns)),       # R[base] = .instance
        iABC(OP_SELF,     base, base, RK(kGet)),       # R[base]=method, R[base+1]=self
        iABC(OP_CALL,     base, 2, 2),                 # R[base] = GetMasterRoleInfo()
        iABC(OP_TEST,     base, 0, 0),                 # if R[base] truthy: run; else skip jump
        iAsBx(OP_JMP,     0, 2),                        # skip the next 2 instrs when nil
        iABC(OP_SELF,     base, base, RK(kAdd)),       # R[base]=OnGmAddAllSkin, R[base+1]=self
        iABC(OP_CALL,     base, 2, 1),                 # call, no returns
    ]

    proto.code = block + proto.code
    # ensure lineinfo length matches code length (debug info); prepend zeros
    if proto.lineinfo:
        proto.lineinfo = [proto.lineinfo[0]] * len(block) + proto.lineinfo
    # need base+2 stack slots
    proto.maxstacksize = max(proto.maxstacksize, base + 2)


if __name__ == '__main__':
    import sys, os, zipfile
    import pyzstd

    # Self-test: round-trip every lua in a package byte-identically.
    dict_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin')
    zdict = pyzstd.ZstdDict(open(dict_path, 'rb').read(), is_raw=True)

    pkg = sys.argv[1]
    ok = bad = 0
    with zipfile.ZipFile(pkg) as zf:
        for it in zf.infolist():
            raw = zf.read(it.filename)
            if raw[:4] == b'\x22\x4a\x00\xef':
                try:
                    data = pyzstd.decompress(raw[8:], zdict)
                except Exception:
                    continue
            else:
                data = raw
            if b'\x1bLua' not in data:
                continue
            try:
                lf = parse_file(data)
                out = ser_file(lf)
            except Exception as e:
                print("PARSE FAIL", it.filename, e); bad += 1; continue
            if out == data:
                ok += 1
            else:
                bad += 1
                print("ROUNDTRIP MISMATCH", it.filename, len(out), len(data))
    print("roundtrip ok=%d bad=%d" % (ok, bad))

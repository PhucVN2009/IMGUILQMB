import pyzstd
import os
import sys

tool_path = '/root/.claude/uploads/225a4123-2613-56d7-9ef1-6593374f172c/d99a6eb0-gmhallv3.py'

# Read the raw bytes of the tool to extract ZSTD_DICT
with open(tool_path, 'r', encoding='utf-8', errors='surrogateescape') as f:
    source = f.read()

# Execute with mocked functions to just get ZSTD_DICT and ZSTD_LEVEL
fake_builtins = {
    '__import__': __import__,
    'print': lambda *a, **kw: None,
    'input': lambda *a: '3',  # invalid choice, exits early
    'len': len,
    'bytearray': bytearray,
    'open': open,
    'bytes': bytes,
    'b': bytes,
    'int': int,
    'str': str,
    'True': True,
    'False': False,
}
ns = {'__name__': '__not_main__', '__builtins__': __builtins__}
try:
    exec(compile(source, 'gmhallv3.py', 'exec'), ns)
except SystemExit:
    pass
except Exception as e:
    print(f"Warning during exec: {e}", file=sys.stderr)

ZSTD_DICT = ns.get('ZSTD_DICT')
ZSTD_LEVEL = ns.get('ZSTD_LEVEL', 10)

if ZSTD_DICT is None:
    print("ERROR: Could not extract ZSTD_DICT")
    sys.exit(1)

print(f"ZSTD_DICT size: {len(ZSTD_DICT)} bytes")
print(f"ZSTD_LEVEL: {ZSTD_LEVEL}")

# Decompress all .bytes files
input_dir = sys.argv[1]
output_dir = sys.argv[2] if len(sys.argv) > 2 else input_dir + '_decoded'
os.makedirs(output_dir, exist_ok=True)

zdict = pyzstd.ZstdDict(ZSTD_DICT, is_raw=True)
count = 0
errors = 0

for fname in sorted(os.listdir(input_dir)):
    if not fname.endswith('.pkg.bytes'):
        continue
    input_path = os.path.join(input_dir, fname)
    with open(input_path, 'rb') as f:
        data = f.read()
    
    # Find zstd magic bytes
    zstd_offset = data.find(b'\x28\xb5\x2f\xfd')
    if zstd_offset < 0:
        print(f"  SKIP {fname} (no zstd magic)")
        errors += 1
        continue
    
    try:
        decoded = pyzstd.decompress(data[zstd_offset:], zdict)
        out_path = os.path.join(output_dir, fname.replace('.pkg.bytes', '.lua'))
        with open(out_path, 'wb') as f:
            f.write(decoded)
        print(f"  OK {fname} -> {len(decoded)} bytes")
        count += 1
    except Exception as e:
        print(f"  ERR {fname}: {e}")
        errors += 1

print(f"\nDone: {count} decoded, {errors} errors/skipped")

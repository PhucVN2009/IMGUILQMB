"""
Patch v10: replicate modskin.h in Lua via xLua HOTFIX.

The game runs on Tencent Pandora / xLua. dump.cs shows LuaEnv, DoString,
com-tencent-pandora-LuaState, and KernelLua/util_lua exposes xlua.hotfix
(CS.XLua.HotfixDelegateBridge, private_accessible). That means Lua can REPLACE
C# methods at runtime - the real "do it in Lua, but different from C++" path.

We inject a run-once `loadstring(SRC)()` at the top of HeroModel.hasHero
(fires when the lobby hero list loads). SRC installs xlua hotfixes mirroring
modskin.h:

  CRoleInfo.IsHaveHeroSkin  -> true               (all skins shown owned)
  CRoleInfo.IsCanUseSkin    -> save{hero,skin}+true (allow wearing, remember pick)
  CRoleInfo.GetHeroWearSkinId(heroId) -> saved skin for that hero (local wear)
  CSkinInfo.GetWearSkinID(heroId)     -> saved skin (modskin.h WearSkinId)

Everything is pcall-guarded: wrong class/method names or a non-hotfixable
target simply have no effect (no crash).

STAGE-1 TEST SIGNAL: if the hotfix engine works, the SHOP (pure C#, reads
CRoleInfo.IsHaveHeroSkin) will show every skin as owned - something no
bytecode UI patch could do. That confirms we can then extend to the battle
protocol swap.
"""
import struct
import os
import sys
import zipfile
import io

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd


HOTFIX_SRC = r"""
return pcall(function()
  local xl = rawget(_G, "xlua")
  if not xl then local o,m = pcall(require, "xlua"); if o then xl = m end end
  if not (xl and xl.hotfix and CS) then return end
  local saved = _G.__aov_saved or { hero = 0, skin = 0 }
  _G.__aov_saved = saved
  local function H(cls, name, fn)
    if cls then pcall(xl.hotfix, cls, name, fn) end
  end
  local RI = CS.CRoleInfo
  H(RI, "IsHaveHeroSkin", function(self, a, b, c) return true end)
  H(RI, "IsCanUseSkin", function(self, heroId, skinId)
      if heroId and heroId ~= 0 then saved.hero = heroId; saved.skin = skinId or 0 end
      return true
  end)
  H(RI, "GetHeroWearSkinId", function(self, heroId)
      if saved.skin ~= 0 and heroId == saved.hero then return saved.skin end
      return 0
  end)
  H(CS.CSkinInfo, "GetWearSkinID", function(heroId)
      if saved.skin ~= 0 and heroId == saved.hero then return saved.skin end
      return 0
  end)
end)
"""


def main():
    if len(sys.argv) < 3:
        print("Usage: python3 patch_v10.py <aov_files_dir> <output_dir>")
        sys.exit(1)
    orig_dir, out_dir = sys.argv[1], sys.argv[2]
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)

    src = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')
    if not os.path.exists(src):
        src = os.path.join(orig_dir, 'HeroInfoLua.pkg.bytes')
    out = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1].replace('.bytes', '') != 'HeroModel_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            # inject the hotfix loader into hasHero (proto 14)
            L.inject_load_string_once(lf.main.protos[14], HOTFIX_SRC,
                                      flag='__aov_hotfix_done', loader='loadstring')
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  HeroModel proto[14]: injected loadstring(hotfix) [{len(HOTFIX_SRC)} chars]")

    if not patched:
        print("HeroModel_lua not found"); return

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out} ({os.path.getsize(out)} bytes)")
    print("PATCH v10 COMPLETE (xLua hotfix)")


if __name__ == '__main__':
    main()

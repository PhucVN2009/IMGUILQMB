"""
Patch v11: run the xLua hotfix from a CONFIRMED-executed function.

Diagnosis of v7/v9/v10: those injected into HeroModel.hasHero (proto 14),
which apparently is not called in the flows tested - so the injected code
never ran. In-place instruction patches (v3/v5/v8) worked because they sit
in HeroSkinListItem.SetHeroSkinData / HeroSys, which DO run.

v11 injects the hotfix loader into HeroSkinListItem.SetHeroSkinData
(proto 24) - the per-skin-item render, guaranteed to run whenever a hero's
skin list is shown. Uses `load` (standard Lua 5.3 global, verified present).

The script is a diagnostic + the real hotfix:
  1) DIRECT (no hotfix): N.CRoleInfoManager.instance:GetMasterRoleInfo()
     :OnGmAddAllSkin()   -- if the injection runs at all, the shop changes.
  2) xlua.hotfix mirroring modskin.h (IsHaveHeroSkin/IsCanUseSkin/WearSkin).

All pcall-guarded. Built clean on the ORIGINAL package so any effect is
attributable to this injection alone.
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
  -- (1) DIRECT populate owned skins (no hotfix needed) - shop diagnostic
  pcall(function()
    local ri = N.CRoleInfoManager.instance:GetMasterRoleInfo()
    if ri then ri:OnGmAddAllSkin() end
  end)
  -- (2) xlua hotfix (modskin.h in Lua)
  local xl = rawget(_G, "xlua")
  if not (xl and xl.hotfix) then return end
  local function T(n)
    local t
    pcall(function() if N then t = N[n] end end)
    if t == nil then pcall(function() if CS then t = CS[n] end end) end
    return t
  end
  local saved = _G.__aov_saved or { hero = 0, skin = 0 }
  _G.__aov_saved = saved
  local function H(c, n, f) if c then pcall(xl.hotfix, c, n, f) end end
  local RI = T("CRoleInfo")
  H(RI, "IsHaveHeroSkin", function(s, a, b, c) return true end)
  H(RI, "IsCanUseSkin", function(s, h, k)
      if h and h ~= 0 then saved.hero = h; saved.skin = k or 0 end
      return true
  end)
  H(RI, "GetHeroWearSkinId", function(s, h)
      if saved.skin ~= 0 and h == saved.hero then return saved.skin end
      return 0
  end)
  H(T("CSkinInfo"), "GetWearSkinID", function(h)
      if saved.skin ~= 0 and h == saved.hero then return saved.skin end
      return 0
  end)
end)
"""


def main():
    orig = '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
    if len(sys.argv) >= 2:
        orig = sys.argv[1]
    out_dir = '/home/user/IMGUILQMB/lua_skin_unlock/output'
    if len(sys.argv) >= 3:
        out_dir = sys.argv[2]
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)

    src = os.path.join(orig, 'HeroInfoLua.pkg.bytes')
    out = os.path.join(out_dir, 'HeroInfoLua_v11.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1].replace('.bytes', '') != 'HeroSkinListItem_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            L.inject_load_string_once(lf.main.protos[24], HOTFIX_SRC,
                                      flag='__aov_hf11', loader='load')
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  HeroSkinListItem proto[24]: injected load(hotfix) [{len(HOTFIX_SRC)} chars]")

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out} ({os.path.getsize(out)} bytes)")
    print("PATCH v11 COMPLETE (hotfix @ confirmed-run SetHeroSkinData)")


if __name__ == '__main__':
    main()

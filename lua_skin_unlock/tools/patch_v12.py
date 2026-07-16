"""
Patch v12: safe xLua hotfix (v11 proved the mechanism runs).

v11 caused "errors everywhere" -> that CONFIRMS the injected load(hotfix)
executes and xlua.hotfix applies. The crashes came from hotfixing
GetWearSkinID / GetHeroWearSkinId to return 0 for every hero whose skin we
had not saved: the game then tried to load skin id 0 and errored.

v12 keeps ONLY the safe hotfixes that modskin.h relies on and that have no
bad fallback:
  CRoleInfo.IsHaveHeroSkin -> true
  CRoleInfo.IsCanUseSkin   -> true   (also remembers the pick)
plus a direct OnGmAddAllSkin to populate the owned list.

The local worn skin is handled by the existing v8 wear-success patch (real
OnWearHeroSkin), so we do NOT hotfix the wear-skin getters here.

Injected into HeroSkinListItem.SetHeroSkinData (confirmed-run). Clean build.
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
  pcall(function()
    local ri = N.CRoleInfoManager.instance:GetMasterRoleInfo()
    if ri then ri:OnGmAddAllSkin() end
  end)
  local xl = rawget(_G, "xlua")
  if not (xl and xl.hotfix) then return end
  local function T(n)
    local t
    pcall(function() if N then t = N[n] end end)
    if t == nil then pcall(function() if CS then t = CS[n] end end) end
    return t
  end
  local RI = T("CRoleInfo")
  local saved = _G.__aov_saved or { hero = 0, skin = 0 }
  _G.__aov_saved = saved
  local function H(c, n, f) if c then pcall(xl.hotfix, c, n, f) end end
  H(RI, "IsHaveHeroSkin", function(s, a, b, c) return true end)
  H(RI, "IsCanUseSkin", function(s, h, k)
      if h and h ~= 0 then saved.hero = h; saved.skin = k or 0 end
      return true
  end)
end)
"""


def build(src_pkg, out_pkg, proto_index=24, entry='HeroSkinListItem_lua', flag='__aov_hf12'):
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)
    patched = {}
    with zipfile.ZipFile(src_pkg, 'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1].replace('.bytes', '') != entry:
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            L.inject_load_string_once(lf.main.protos[proto_index], HOTFIX_SRC, flag=flag, loader='load')
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  {entry} proto[{proto_index}]: injected load(hotfix) [{len(HOTFIX_SRC)} chars]")
    buf = io.BytesIO()
    with zipfile.ZipFile(src_pkg, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out_pkg, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out_pkg} ({os.path.getsize(out_pkg)} bytes)")


if __name__ == '__main__':
    orig = sys.argv[1] if len(sys.argv) > 1 else \
        '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
    out_dir = sys.argv[2] if len(sys.argv) > 2 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    build(os.path.join(orig, 'HeroInfoLua.pkg.bytes'),
          os.path.join(out_dir, 'HeroInfoLua_v12.pkg.bytes'))
    print("PATCH v12 COMPLETE (safe hotfix)")

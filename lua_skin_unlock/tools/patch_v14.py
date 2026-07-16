"""
Patch v14: minimal, safe in-battle hotfix on top of the stable v5-v8 base.

Reasoning:
- In-battle skin lives in C# (COMDT_HERO_COMMON_INFO). No Lua-bytecode point
  in the battle render pipeline exists, so a pure v5-v8 style patch cannot
  reach it. The only Lua path is xLua hotfix (v11 proved the engine runs).
- v11/v12 crashed because the payload called OnGmAddAllSkin (heavy, triggers
  cascading UI errors) and returned 0 from a wear-skin getter (game tried to
  load skin id 0). v14 removes BOTH mistakes.

v14 payload (injected once into confirmed-run HeroSkinListItem.SetHeroSkinData):
  * hotfix CRoleInfo.IsCanUseSkin -> remember ov[heroId]=skinId, return true
  * hotfix CSkinInfo.GetWearSkinID(heroId):
        return ov[heroId] if set          (your chosen hero -> chosen skin)
        else the REAL worn skin via GetHeroWearSkinId  (other heroes unchanged)
No OnGmAddAllSkin, never returns a bogus 0 -> should not crash. If the battle
reads GetWearSkinID for the local hero, it now returns the chosen skin.

Built on the stable v5-v8 output HeroInfoLua.
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
  if not (xl and xl.hotfix) then return end
  local ov = _G.__aov_ov or {}
  _G.__aov_ov = ov
  local function T(n)
    local t
    pcall(function() if N then t = N[n] end end)
    if t == nil then pcall(function() if CS then t = CS[n] end end) end
    return t
  end
  local function realWear(h)
    local r
    pcall(function() r = N.CRoleInfoManager.instance:GetMasterRoleInfo():GetHeroWearSkinId(h) end)
    return r
  end
  local RI = T("CRoleInfo")
  local SI = T("CSkinInfo")
  local function H(c, n, f) if c then pcall(xl.hotfix, c, n, f) end end
  H(RI, "IsCanUseSkin", function(s, h, k)
      if h and h ~= 0 and k and k ~= 0 then ov[h] = k end
      return true
  end)
  H(SI, "GetWearSkinID", function(h)
      if ov[h] and ov[h] ~= 0 then return ov[h] end
      return realWear(h)
  end)
end)
"""


def main():
    orig = sys.argv[1] if len(sys.argv) > 1 else \
        '/tmp/claude-0/-home-user-IMGUILQMB/225a4123-2613-56d7-9ef1-6593374f172c/scratchpad/aov_files'
    out_dir = sys.argv[2] if len(sys.argv) > 2 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)

    # base = the stable v5-v8 output HeroInfoLua
    src = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')
    out = os.path.join(out_dir, 'HeroInfoLua_v14.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1].replace('.bytes', '') != 'HeroSkinListItem_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            L.inject_load_string_once(lf.main.protos[24], HOTFIX_SRC, flag='__aov_hf14', loader='load')
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  HeroSkinListItem proto[24]: injected minimal in-battle hotfix [{len(HOTFIX_SRC)} chars]")

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out} ({os.path.getsize(out)} bytes)")
    print("PATCH v14 COMPLETE (minimal in-battle hotfix on v5-v8 base)")


if __name__ == '__main__':
    main()

"""
Patch v15: NARROW battle-only hotfix (diagnostic + VS-AI skin attempt).

Findings so far:
- Broad hotfixes (IsHaveHeroSkin / IsCanUseSkin / GetWearSkinID) corrupt the
  lobby skin list ("wwww/9999") because the lobby UI shares those functions and
  xLua hotfix fully replaces them (no clean call-to-original; hotfix_ex doesn't
  provide it either).
- So v15 hooks ONLY a battle-specific getter the lobby never uses:
      CHeroSelectBaseSystem.get_PvEAISelectSkinID  (VS-AI selected skin)
  returning the hero's currently-worn skin (v8 makes that the skin you picked).

Diagnostic value:
- If v15 shows NO "wwww" corruption, the crash was the broad hooks, not the
  load()+hotfix mechanism -> we can keep hunting the right narrow function.
- If VS-Máy then shows the skin, this getter is the right lever.

Injected into confirmed-run SetHeroSkinData; built on stable v5-v8 base.
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
  local function T(n)
    local t
    pcall(function() if N then t = N[n] end end)
    if t == nil then pcall(function() if CS then t = CS[n] end end) end
    return t
  end
  local function wornOf(hero)
    local s = 0
    pcall(function()
      if hero and hero ~= 0 then
        s = N.CRoleInfoManager.instance:GetMasterRoleInfo():GetHeroWearSkinId(hero) or 0
      end
    end)
    return s
  end
  local HS = T("CHeroSelectBaseSystem")
  local function H(c, n, f) if c then pcall(xl.hotfix, c, n, f) end end
  H(HS, "get_PvEAISelectSkinID", function(self)
    local h = 0
    pcall(function() h = self.PvEAISelectHeroID end)
    return wornOf(h)
  end)
end)
"""


def main():
    out_dir = sys.argv[2] if len(sys.argv) > 2 else '/home/user/IMGUILQMB/lua_skin_unlock/output'
    zdict = pyzstd.ZstdDict(
        open(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'zstd_dict.bin'), 'rb').read(),
        is_raw=True)
    src = os.path.join(out_dir, 'HeroInfoLua.pkg.bytes')  # stable v5-v8
    out = os.path.join(out_dir, 'HeroInfoLua_v15.pkg.bytes')

    patched = {}
    with zipfile.ZipFile(src, 'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1].replace('.bytes', '') != 'HeroSkinListItem_lua':
                continue
            raw = zf.read(item.filename)
            data = pyzstd.decompress(raw[8:], zdict) if raw[:4] == b'\x22\x4a\x00\xef' else raw
            lf = L.parse_file(data)
            L.inject_load_string_once(lf.main.protos[24], HOTFIX_SRC, flag='__aov_hf15', loader='load')
            newdata = L.ser_file(lf)
            L.parse_file(newdata)
            comp = pyzstd.compress(newdata, 17, zdict)
            assert pyzstd.decompress(comp, zdict) == newdata
            patched[item.filename] = b'\x22\x4a\x00\xef' + struct.pack('<I', len(newdata)) + comp
            print(f"  HeroSkinListItem proto[24]: narrow VS-AI hotfix [{len(HOTFIX_SRC)} chars]")

    buf = io.BytesIO()
    with zipfile.ZipFile(src, 'r') as zin, zipfile.ZipFile(buf, 'w', zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item, patched.get(item.filename, zin.read(item.filename)))
    with open(out, 'wb') as f:
        f.write(buf.getvalue())
    print(f"  -> {out} ({os.path.getsize(out)} bytes)")
    print("PATCH v15 COMPLETE (narrow battle-only hotfix)")


if __name__ == '__main__':
    main()

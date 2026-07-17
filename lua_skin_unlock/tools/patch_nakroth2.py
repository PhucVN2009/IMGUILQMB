"""
v2: force Nakroth(150)->skin 15009 for TRAINING, covering effect + model.
 - effect: m_selectSkinIDList[slot]=15009  (as v1)
 - model : role:SetFreeHeroWearSkinId(150,15009) + role.dwShowSkinID=15009
   so the actor spawn (which reads the worn/show skin) picks 15009 too.
Injected at PickHeroCustomizationButtonsView.onSkinChanged.
"""
import os, sys, zipfile, io, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import luainject as L
import pyzstd
from patch_cust import map_methods

GETTABUP, GETTABLE, SETTABLE, TEST, JMP, LOADK, EQ, SELF, CALL, RETURN = 3, 19, 7, 45, 20, 14, 15, 44, 4, 11
HERO, SKIN, NSLOT = 150, 15009, 10
def A(op,a,b,c): return L.iABC(op,a,b,c)
def s(p,n):
    nb=n.encode()
    for i,(t,v) in enumerate(p.constants):
        if t in (4,0x14) and v==nb: return i
    return L.find_or_add_str_const(p,n)
def ic(p,n):
    b=struct.pack('<q',n)
    for i,(t,v) in enumerate(p.constants):
        if t==0x13 and v==b: return i
    p.constants.append((0x13,b)); return len(p.constants)-1

def patch(p):
    env=L.find_env_upval(p); assert env is not None
    kN=s(p,'N'); kMgr=s(p,'CRoleInfoManager'); kGI=s(p,'GetInstance'); kGM=s(p,'GetMasterRoleInfo')
    kSet=s(p,'SetFreeHeroWearSkinId'); kShow=s(p,'dwShowSkinID')
    kCH=s(p,'CHeroSelectBaseSystem'); kInst=s(p,'instance')
    kHL=s(p,'m_selectHeroIDList'); kSL=s(p,'m_selectSkinIDList')
    kHero=ic(p,HERO); kSkin=ic(p,SKIN); kI=[ic(p,i) for i in range(NSLOT)]

    blk=[]; fix=[]  # fix: (index, 'AFTERWORN'|'END')
    # --- worn/model block ---
    blk.append(A(GETTABUP,5,env,kN+256))      # R5=N
    blk.append(A(GETTABLE,5,5,kMgr+256))      # R5=N.CRoleInfoManager
    blk.append(A(GETTABLE,6,5,kGI+256))       # R6=.GetInstance
    blk.append(A(CALL,6,1,2))                 # R6=GetInstance()
    blk.append(A(SELF,6,6,kGM+256))           # R6=:GetMasterRoleInfo(method),R7=self
    blk.append(A(CALL,6,2,2))                 # R6=role
    blk.append(A(TEST,6,0,0)); fix.append((len(blk),'AFTERWORN')); blk.append(0)
    blk.append(A(SELF,7,6,kSet+256))          # R7=method,R8=role
    blk.append(L.iABx(LOADK,9,kHero))         # R9=150
    blk.append(L.iABx(LOADK,10,kSkin))        # R10=15009
    blk.append(A(CALL,7,4,1))                 # role:SetFreeHeroWearSkinId(150,15009)
    blk.append(A(SETTABLE,6,kShow+256,kSkin+256))  # role.dwShowSkinID=15009
    AFTERWORN=len(blk)
    # --- effect block: selection list ---
    blk.append(A(GETTABUP,5,env,kN+256))
    blk.append(A(GETTABLE,5,5,kCH+256))
    blk.append(A(GETTABLE,5,5,kInst+256))
    blk.append(A(TEST,5,0,0)); fix.append((len(blk),'END')); blk.append(0)
    blk.append(A(GETTABLE,6,5,kHL+256))
    blk.append(A(TEST,6,0,0)); fix.append((len(blk),'END')); blk.append(0)
    blk.append(A(GETTABLE,7,5,kSL+256))
    blk.append(A(TEST,7,0,0)); fix.append((len(blk),'END')); blk.append(0)
    blk.append(L.iABx(LOADK,8,kSkin))
    for i in range(NSLOT):
        blk.append(A(GETTABLE,9,6,kI[i]+256))
        blk.append(A(EQ,0,9,kHero+256))
        blk.append(L.iAsBx(JMP,0,1))
        blk.append(A(SETTABLE,7,kI[i]+256,8))
    END=len(blk)
    for idx,tgt in fix:
        dst=AFTERWORN if tgt=='AFTERWORN' else END
        blk[idx]=L.iAsBx(JMP,0,dst-(idx+1))

    ins_at=len(p.code)-1
    for i in range(ins_at):
        if (p.code[i]&0x3F)==JMP:
            sbx=((p.code[i]>>14)&0x3FFFF)-131071
            if i+1+sbx>=ins_at:
                a=(p.code[i]>>6)&0xFF; p.code[i]=L.iAsBx(JMP,a,sbx+len(blk))
    p.code=p.code[:ins_at]+blk+p.code[ins_at:]
    if p.maxstacksize<12: p.maxstacksize=12
    if p.lineinfo:
        p.lineinfo=p.lineinfo[:ins_at]+[p.lineinfo[ins_at]]*len(blk)+p.lineinfo[ins_at:]
    return len(blk)

def main():
    out_dir,src_dir=sys.argv[1],sys.argv[2]
    tools=os.path.dirname(os.path.abspath(__file__))
    zdict=pyzstd.ZstdDict(open(os.path.join(tools,'zstd_dict.bin'),'rb').read(),is_raw=True)
    os.makedirs(out_dir,exist_ok=True)
    src=os.path.join(src_dir,'Customization.pkg.bytes'); patched={}
    with zipfile.ZipFile(src,'r') as zf:
        for item in zf.infolist():
            if item.filename.split('/')[-1]!='PickHeroCustomizationButtonsView_lua.bytes': continue
            raw=zf.read(item.filename)
            data=pyzstd.decompress(raw[8:],zdict) if raw[:4]==b'\x22\x4a\x00\xef' else raw
            lf=L.parse_file(data); m=map_methods(lf)
            n=patch(lf.main.protos[m['onSkinChanged']])
            nd=L.ser_file(lf); L.parse_file(nd)
            comp=pyzstd.compress(nd,17,zdict); assert pyzstd.decompress(comp,zdict)==nd
            patched[item.filename]=b'\x22\x4a\x00\xef'+struct.pack('<I',len(nd))+comp
            print(f"  onSkinChanged +{n} instr (effect+model force {HERO}->{SKIN})")
    dst=os.path.join(out_dir,'Customization.pkg.bytes'); buf=io.BytesIO()
    with zipfile.ZipFile(src,'r') as zin, zipfile.ZipFile(buf,'w',zipfile.ZIP_STORED) as zout:
        for item in zin.infolist():
            zout.writestr(item,patched.get(item.filename,zin.read(item.filename)))
    open(dst,'wb').write(buf.getvalue())
    print(f"-> {dst} ({os.path.getsize(dst)} bytes)")

if __name__=='__main__': main()

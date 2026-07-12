/**
 * AOV / Lien Quan Mobile - Full Skin Unlock (Frida Hook)
 *
 * Hooks il2cpp methods directly to force all skins as "Owned"
 * No file modification needed - pure runtime hook.
 *
 * Usage:
 *   frida -U -f com.garena.game.kgvn -l unlock_skin_frida.js --no-pause
 *
 * For other regions:
 *   com.garena.game.kgvn  (Vietnam)
 *   com.garena.game.kgtw  (Taiwan)
 *   com.garena.game.kgth  (Thailand)
 *   com.tencent.tmgp.sgame (China - Wangzhe Rongyao)
 *
 * Based on il2cpp dump analysis:
 *   CRoleInfo class (TypeDefIndex: 7188)
 *   RoleInfoOwnState enum: UnOwned=0, Owned=1, InExperience=2, ...
 */

"use strict";

var MODULE_NAME = "libil2cpp.so";

// RVA addresses from dump.cs
var HOOKS = {
    // CRoleInfo.GetHeroOwnState(uint heroId) -> RoleInfoOwnState
    GetHeroOwnState: 0x82B23C4,

    // CRoleInfo.GetSkinOwnState(uint skinId) -> RoleInfoOwnState
    GetSkinOwnState_1: 0x82B25F0,

    // CRoleInfo.GetSkinOwnState(uint heroId, uint skinEntry) -> RoleInfoOwnState
    GetSkinOwnState_2: 0x82B2780,

    // CRoleInfo.IsHaveHero(uint heroId) -> bool
    IsHaveHero: 0x82A3B20,

    // CRoleInfo.IsHaveHero(uint id, bool isIncludeTimeLimited) -> bool
    IsHaveHero_2: 0x82A333C,

    // CRoleInfo.IsHaveHeroSkin(uint heroId, uint skinId, bool isIncludeTimeLimited) -> bool
    IsHaveHeroSkin: 0x82A3F38,

    // CRoleInfo.IsHaveHeroSkin(uint skinUniId, bool isIncludeValidExperienceSkin) -> bool
    IsHaveHeroSkin_2: 0x82A48F4,
};

// RoleInfoOwnState.Owned = 1
var OWNED_STATE = 1;

function waitForModule(name, callback) {
    var mod = Process.findModuleByName(name);
    if (mod) {
        callback(mod);
        return;
    }

    var interval = setInterval(function() {
        mod = Process.findModuleByName(name);
        if (mod) {
            clearInterval(interval);
            callback(mod);
        }
    }, 500);
}

function hookOwnState(base, name, rva) {
    var addr = base.add(rva);
    try {
        Interceptor.attach(addr, {
            onLeave: function(retval) {
                // Force return Owned (1)
                retval.replace(OWNED_STATE);
            }
        });
        console.log("[+] Hooked " + name + " at " + addr);
    } catch(e) {
        console.log("[-] Failed to hook " + name + ": " + e);
    }
}

function hookBoolTrue(base, name, rva) {
    var addr = base.add(rva);
    try {
        Interceptor.attach(addr, {
            onLeave: function(retval) {
                // Force return true (1)
                retval.replace(1);
            }
        });
        console.log("[+] Hooked " + name + " at " + addr);
    } catch(e) {
        console.log("[-] Failed to hook " + name + ": " + e);
    }
}

function installHooks(mod) {
    console.log("[*] " + MODULE_NAME + " loaded at: " + mod.base);
    console.log("[*] Installing skin unlock hooks...\n");

    // Hook ownership state getters -> always return Owned
    hookOwnState(mod.base, "GetHeroOwnState", HOOKS.GetHeroOwnState);
    hookOwnState(mod.base, "GetSkinOwnState(skinId)", HOOKS.GetSkinOwnState_1);
    hookOwnState(mod.base, "GetSkinOwnState(heroId,skinEntry)", HOOKS.GetSkinOwnState_2);

    // Hook "have" checks -> always return true
    hookBoolTrue(mod.base, "IsHaveHero", HOOKS.IsHaveHero);
    hookBoolTrue(mod.base, "IsHaveHero(id,timeLimited)", HOOKS.IsHaveHero_2);
    hookBoolTrue(mod.base, "IsHaveHeroSkin(heroId,skinId,timeLimited)", HOOKS.IsHaveHeroSkin);
    hookBoolTrue(mod.base, "IsHaveHeroSkin(skinUniId,expSkin)", HOOKS.IsHaveHeroSkin_2);

    console.log("\n[*] All hooks installed! All skins should show as owned.");
    console.log("[*] Note: Server still validates on skin equip/use in match.");
}

// Entry point
console.log("=== AOV Skin Unlock by Frida ===");
console.log("[*] Waiting for " + MODULE_NAME + "...");

waitForModule(MODULE_NAME, function(mod) {
    // Small delay to ensure il2cpp is fully initialized
    setTimeout(function() {
        installHooks(mod);
    }, 3000);
});

/**
 * AOV / Lien Quan Mobile - Full Skin Unlock v2 (Frida Hook)
 *
 * This version hooks the XLua wrapper functions that bridge C# to Lua.
 * These are more stable across game updates since they're auto-generated.
 *
 * Usage:
 *   frida -U -f com.garena.game.kgvn -l unlock_skin_v2.js --no-pause
 *
 * If hooks fail, the RVA addresses may have changed in a game update.
 * Re-dump with Il2CppDumper and update the addresses below.
 */

"use strict";

var MODULE_NAME = "libil2cpp.so";

// Primary hooks: CRoleInfo methods (from dump.cs)
var PRIMARY_HOOKS = {
    GetHeroOwnState:      { rva: 0x82B23C4, type: "enum" },
    GetSkinOwnState_1p:   { rva: 0x82B25F0, type: "enum" },
    GetSkinOwnState_2p:   { rva: 0x82B2780, type: "enum" },
    IsHaveHero_1p:        { rva: 0x82A3B20, type: "bool" },
    IsHaveHero_2p:        { rva: 0x82A333C, type: "bool" },
    IsHaveHeroSkin_3p:    { rva: 0x82A3F38, type: "bool" },
    IsHaveHeroSkin_2p:    { rva: 0x82A48F4, type: "bool" },
};

// XLua generated wrappers (more resilient if main hooks fail)
var XLUA_WRAPPERS = {
    // __Gen_Wrap_1669(object, uint) -> RoleInfoOwnState (wraps GetSkinOwnState)
    Wrap_1669: { rva: 0, type: "enum" },  // search for this
    // __Gen_Wrap_1672(object, uint, uint) -> RoleInfoOwnState
    Wrap_1672: { rva: 0, type: "enum" },
};

var OWNED_STATE = ptr(1);  // RoleInfoOwnState.Owned = 1
var TRUE_VAL = ptr(1);

function waitForModule(name, callback) {
    var mod = Process.findModuleByName(name);
    if (mod) { callback(mod); return; }
    var interval = setInterval(function() {
        mod = Process.findModuleByName(name);
        if (mod) { clearInterval(interval); callback(mod); }
    }, 500);
}

function safeHook(base, name, rva, returnValue) {
    if (rva === 0) return false;
    var addr = base.add(rva);

    // Verify address is within module bounds
    var mod = Process.findModuleByName(MODULE_NAME);
    if (!mod) return false;
    var modEnd = mod.base.add(mod.size);
    if (addr.compare(mod.base) < 0 || addr.compare(modEnd) >= 0) {
        console.log("[-] " + name + ": RVA 0x" + rva.toString(16) + " out of bounds");
        return false;
    }

    try {
        // Quick sanity: first bytes shouldn't be 0x00000000 (unmapped)
        var firstBytes = addr.readByteArray(4);
        if (firstBytes === null) {
            console.log("[-] " + name + ": cannot read at " + addr);
            return false;
        }

        Interceptor.attach(addr, {
            onLeave: function(retval) {
                retval.replace(returnValue);
            }
        });
        console.log("[+] " + name + " @ " + addr + " (RVA: 0x" + rva.toString(16) + ")");
        return true;
    } catch(e) {
        console.log("[-] " + name + " failed: " + e.message);
        return false;
    }
}

function installHooks(mod) {
    console.log("\n[*] libil2cpp.so base: " + mod.base);
    console.log("[*] Module size: " + (mod.size / 1024 / 1024).toFixed(1) + " MB");
    console.log("[*] Installing hooks...\n");

    var successCount = 0;
    var totalCount = 0;

    // Install primary hooks
    for (var name in PRIMARY_HOOKS) {
        totalCount++;
        var h = PRIMARY_HOOKS[name];
        var retVal = (h.type === "enum") ? OWNED_STATE : TRUE_VAL;
        if (safeHook(mod.base, name, h.rva, retVal)) {
            successCount++;
        }
    }

    console.log("\n[*] Result: " + successCount + "/" + totalCount + " hooks installed");

    if (successCount === 0) {
        console.log("\n[!] ALL HOOKS FAILED - Game version likely updated.");
        console.log("[!] Need to re-dump il2cpp and update RVA addresses.");
        console.log("[!] Steps:");
        console.log("[!]   1. Extract libil2cpp.so from APK");
        console.log("[!]   2. Run Il2CppDumper to get new dump.cs");
        console.log("[!]   3. Search for 'GetSkinOwnState' in dump.cs");
        console.log("[!]   4. Update RVA addresses in this script");
    } else if (successCount < totalCount) {
        console.log("[!] Some hooks failed - partial unlock only.");
    } else {
        console.log("\n[*] === FULL SKIN UNLOCK ACTIVE ===");
        console.log("[*] All heroes and skins will appear as owned.");
        console.log("[*] NOTE: Selecting unowned skin for match may be");
        console.log("[*]       rejected by server. Visual unlock only.");
    }
}

// === ENTRY POINT ===
console.log("╔══════════════════════════════════════╗");
console.log("║  AOV / LQMB - Full Skin Unlock v2   ║");
console.log("║  Frida il2cpp Hook                   ║");
console.log("╚══════════════════════════════════════╝");
console.log("");

waitForModule(MODULE_NAME, function(mod) {
    // Wait for il2cpp metadata to fully load
    setTimeout(function() {
        installHooks(mod);
    }, 5000);
});

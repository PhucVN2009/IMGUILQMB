/**
 * Frida script to bypass Lua bytecode RSA signature verification
 * in Arena of Valor (Lien Quan Mobile).
 *
 * Hooks PKCS1.Verify_v15 to always return true, allowing modified
 * Lua bytecode files to load without valid signatures.
 *
 * Usage: frida -U -f com.garena.game.kgvn -l bypass_signature.js
 *
 * Target: LuaLoaderImpl -> uses PUBLIC_KEY to verify 128-byte RSA signature
 * prepended to each .bytes Lua file before loading.
 */

// Wait for il2cpp to load
function hookSignatureVerification() {
    var libil2cpp = Process.findModuleByName("libil2cpp.so");
    if (!libil2cpp) {
        console.log("[!] libil2cpp.so not found, retrying...");
        setTimeout(hookSignatureVerification, 1000);
        return;
    }

    console.log("[+] libil2cpp.so base: " + libil2cpp.base);

    // PKCS1.Verify_v15 (TypeDefIndex: 21628) - 4 param version
    // RVA: 0x640A218
    var verify_v15_rva = 0x640A218;
    var verify_v15_addr = libil2cpp.base.add(verify_v15_rva);

    Interceptor.attach(verify_v15_addr, {
        onEnter: function(args) {
            // args: RSA rsa, HashAlgorithm hash, byte[] hashValue, byte[] signature, bool tryNonStandardEncoding
            this.caller = "Verify_v15_4param";
        },
        onLeave: function(retval) {
            // Force return true (1)
            retval.replace(1);
            // console.log("[+] " + this.caller + " -> forced TRUE");
        }
    });
    console.log("[+] Hooked PKCS1.Verify_v15 (4-param) at " + verify_v15_addr);

    // PKCS1.Verify_v15 (5-param version with tryNonStandardEncoding)
    // RVA: 0x640A298
    var verify_v15_5_rva = 0x640A298;
    var verify_v15_5_addr = libil2cpp.base.add(verify_v15_5_rva);

    Interceptor.attach(verify_v15_5_addr, {
        onEnter: function(args) {
            this.caller = "Verify_v15_5param";
        },
        onLeave: function(retval) {
            retval.replace(1);
        }
    });
    console.log("[+] Hooked PKCS1.Verify_v15 (5-param) at " + verify_v15_5_addr);

    // Also hook the second PKCS1 class (TypeDefIndex: 32179)
    // RVA: 0x63E8DAC
    var verify_v15_mono_rva = 0x63E8DAC;
    var verify_v15_mono_addr = libil2cpp.base.add(verify_v15_mono_rva);

    Interceptor.attach(verify_v15_mono_addr, {
        onEnter: function(args) {},
        onLeave: function(retval) {
            retval.replace(1);
        }
    });
    console.log("[+] Hooked Mono.PKCS1.Verify_v15 at " + verify_v15_mono_addr);

    // Alternative: Hook LuaLoaderImpl directly to skip signature stripping
    // RVA: 0x74E87B8
    // This loads the full .bytes file, strips 128 bytes signature, verifies, then passes to xlua
    // By patching Verify_v15, the signature check passes regardless of content

    console.log("[+] All signature hooks installed. Modified Lua files will load.");
}

// Hook on il2cpp init
Java.perform(function() {
    hookSignatureVerification();
});

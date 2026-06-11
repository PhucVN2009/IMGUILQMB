#pragma once
#include <vector>
#include <string>
#include <cstdio>
#include <cstring>
#include <pthread.h>
#include <dlfcn.h>
#include <android/log.h>

// ============================================================
//  HOOK SCANNER – phát hiện Dobby trampolines trong libil2cpp.so
//
//  Cơ chế:
//   - Dobby ghi trampoline ARM64 tại địa chỉ bị hook:
//       LDR X17, #8   (0x58000051)
//       BR  X17       (0xD61F0220)
//       <8 bytes: địa chỉ đích>
//   - Scan toàn bộ vùng executable → tìm pattern → đọc target
//   - Tính RVA từ base libil2cpp.so → đây là offset cần dùng để hook
//   - Xác định target thuộc lib nào → biết mod nào cài hook
// ============================================================

struct HookScanEntry {
    uintptr_t   rva;          // il2cpp+offset (dùng để hook lại)
    uintptr_t   abs_addr;     // địa chỉ tuyệt đối của trampoline
    uintptr_t   target;       // địa chỉ đích nhảy đến
    uintptr_t   target_rva;   // offset của đích trong lib đích
    char        target_lib[128]; // lib chứa target (mod nào cài hook)
    bool        is_own;       // true = do mod này cài
};

static std::vector<HookScanEntry> g_hookEntries;
static volatile bool  g_spyScanBusy  = false;
static volatile bool  g_spyScanReady = false;
static int            g_spyScanCount = 0;
static char           g_spyOwnLib[128] = {0}; // tên lib của mod này

// ============================================================
//  Xây bảng tra cứu /proc/self/maps
// ============================================================

struct MapRegion {
    uintptr_t start, end;
    bool      exec;
    char      name[256];
};

static std::vector<MapRegion> BuildMapTable() {
    std::vector<MapRegion> table;
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) return table;
    char line[512];
    while (fgets(line, sizeof(line), f)) {
        MapRegion r;
        char perms[8], path[256] = {0};
        if (sscanf(line, "%lx-%lx %s %*s %*s %*s %255s",
                   &r.start, &r.end, perms, path) < 3) continue;
        r.exec = (perms[2] == 'x');
        const char *sl = strrchr(path, '/');
        strncpy(r.name, sl ? (sl + 1) : path, sizeof(r.name) - 1);
        r.name[sizeof(r.name) - 1] = '\0';
        table.push_back(r);
    }
    fclose(f);
    return table;
}

static void AddrToLib(uintptr_t addr, const std::vector<MapRegion> &table,
                      char *out_name, uintptr_t &out_base) {
    out_base = 0;
    out_name[0] = '?'; out_name[1] = '\0';
    for (const auto &r : table) {
        if (addr >= r.start && addr < r.end && r.name[0]) {
            strncpy(out_name, r.name, 127);
            out_name[127] = '\0';
            // Cần tìm base của lib này (segment đầu tiên có cùng tên)
            for (const auto &r2 : table) {
                if (strcmp(r2.name, r.name) == 0) {
                    if (out_base == 0 || r2.start < out_base) out_base = r2.start;
                }
            }
            return;
        }
    }
}

// ============================================================
//  Lấy tên lib của chính mod này (để đánh dấu "is_own")
// ============================================================

static void DetectOwnLib() {
    if (g_spyOwnLib[0]) return;
    // Địa chỉ của hàm này nằm trong lib của mod ta
    Dl_info info;
    if (dladdr((void *)DetectOwnLib, &info) && info.dli_fname) {
        const char *sl = strrchr(info.dli_fname, '/');
        strncpy(g_spyOwnLib, sl ? (sl + 1) : info.dli_fname, sizeof(g_spyOwnLib) - 1);
    }
}

// ============================================================
//  Background scan thread
// ============================================================

static void *HookScanThread(void *) {
    DetectOwnLib();

    // Tìm base libil2cpp.so
    auto table = BuildMapTable();
    uintptr_t il2cpp_base = 0;
    for (const auto &r : table) {
        if (strcmp(r.name, "libil2cpp.so") == 0) {
            if (il2cpp_base == 0 || r.start < il2cpp_base) il2cpp_base = r.start;
        }
    }
    if (!il2cpp_base) {
        g_spyScanBusy = false;
        return nullptr;
    }

    // ARM64 Dobby trampoline patterns
    // Pattern A: LDR X17, #8 (0x58000051)  ;  BR X17 (0xD61F0220)
    // Pattern B: LDR X16, #8 (0x58000050)  ;  BR X16 (0xD61F0200)
    struct Pat { uint32_t ldr, br; };
    const Pat pats[] = {
        { 0x58000051, 0xD61F0220 },
        { 0x58000050, 0xD61F0200 },
    };

    std::vector<HookScanEntry> found;

    for (const auto &region : table) {
        if (!region.exec) continue;
        if (strcmp(region.name, "libil2cpp.so") != 0) continue;

        uintptr_t sz = region.end - region.start;
        for (uintptr_t off = 0; off + 16 <= sz; off += 4) {
            const uint32_t *p = (const uint32_t *)(region.start + off);
            for (const auto &pat : pats) {
                if (p[0] != pat.ldr || p[1] != pat.br) continue;

                uintptr_t hook_abs = region.start + off;
                uintptr_t target   = *(const uintptr_t *)(hook_abs + 8);
                if (!target || target == (uintptr_t)-1) break;

                HookScanEntry e;
                e.rva      = hook_abs - il2cpp_base;
                e.abs_addr = hook_abs;
                e.target   = target;

                uintptr_t tbase = 0;
                AddrToLib(target, table, e.target_lib, tbase);
                e.target_rva = (tbase && target >= tbase) ? (target - tbase) : 0;
                e.is_own     = (g_spyOwnLib[0] && strcmp(e.target_lib, g_spyOwnLib) == 0);

                found.push_back(e);

                __android_log_print(ANDROID_LOG_INFO, "HOOKSPY",
                    "il2cpp+0x%08lX → [%s+0x%08lX]%s",
                    (unsigned long)e.rva,
                    e.target_lib,
                    (unsigned long)e.target_rva,
                    e.is_own ? " [THIS MOD]" : "");
                break;
            }
        }
    }

    g_hookEntries  = std::move(found);
    g_spyScanCount = (int)g_hookEntries.size();

    __android_log_print(ANDROID_LOG_INFO, "HOOKSPY",
        "=== SCAN DONE: %d hooks found (own lib: %s) ===",
        g_spyScanCount, g_spyOwnLib);

    g_spyScanReady = true;
    g_spyScanBusy  = false;
    return nullptr;
}

static void StartHookScan() {
    if (g_spyScanBusy) return;
    g_spyScanBusy  = true;
    g_spyScanReady = false;
    g_hookEntries.clear();
    pthread_t t;
    pthread_create(&t, nullptr, HookScanThread, nullptr);
    pthread_detach(t);
}

// ============================================================
//  Dump tất cả kết quả ra logcat (adb logcat -s HOOKSPY_DUMP)
// ============================================================

static void DumpHooksToLog() {
    __android_log_print(ANDROID_LOG_INFO, "HOOKSPY_DUMP",
        "=== FULL DUMP: %d hooks ===", (int)g_hookEntries.size());
    for (const auto &e : g_hookEntries) {
        __android_log_print(ANDROID_LOG_INFO, "HOOKSPY_DUMP",
            "HOOK il2cpp+0x%08lX -> %s+0x%08lX  (abs=0x%lX target=0x%lX)%s",
            (unsigned long)e.rva,
            e.target_lib,
            (unsigned long)e.target_rva,
            (unsigned long)e.abs_addr,
            (unsigned long)e.target,
            e.is_own ? " [OWN]" : "");
    }
    __android_log_print(ANDROID_LOG_INFO, "HOOKSPY_DUMP", "=== END DUMP ===");
}

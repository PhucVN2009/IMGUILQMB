#pragma once

#include "UnityInline.h"

static uintptr_t g_il2cpp_base = 0;

inline void InitUnityResolve() {
    while (g_il2cpp_base == 0) {
        g_il2cpp_base = KittyMemory::getLibraryBaseMap("libil2cpp.so").startAddress;
        if (g_il2cpp_base == 0) sleep(1);
    }
    Unity::get_cached_unity();
}

inline void *GetMethodOffset(const char *image, const char *namespaze, const char *clazz, const char *method, int args) {
    return Unity::GetMethodAddress(g_il2cpp_base, image, namespaze, clazz, method, args);
}

inline uintptr_t GetFieldOffset(const char *image, const char *namespaze, const char *clazz, const char *field) {
    return Unity::GetFieldOffset(image, namespaze, clazz, field);
}

// Tìm method theo tên trong toàn bộ class của image (không cần namespace/class)
// argsCount = -1 để skip kiểm tra số tham số
inline void *GetMethodOffsetAny(const char *image, const char *method, int args = -1) {
    uintptr_t rva = (uintptr_t)Unity::FindMethodOffsetAny(image, method, args);
    if (!rva) return nullptr;
    return (void *)(g_il2cpp_base + rva);
}

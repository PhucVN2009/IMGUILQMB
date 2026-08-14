#pragma once
#include <dlfcn.h>
#include <string>
#include <cstdlib>
#include <ctime>
#include <cstring>
#include <cstdarg>

static float GetTimeSeconds() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (float)ts.tv_sec + (float)ts.tv_nsec / 1000000000.0f;
}

static bool HideIcon;
int TabMenu = 1;

// il2cpp C API function types
typedef void* (*il2cpp_domain_get_t)();
typedef void** (*il2cpp_domain_get_assemblies_t)(void* domain, size_t* size);
typedef void* (*il2cpp_assembly_get_image_t)(void* assembly);
typedef void* (*il2cpp_class_from_name_t)(void* image, const char* ns, const char* name);
typedef void* (*il2cpp_object_new_t)(void* klass);
typedef void* (*il2cpp_class_get_field_from_name_t)(void* klass, const char* name);
typedef void (*il2cpp_field_static_get_value_t)(void* field, void* value);
typedef void* (*il2cpp_class_get_parent_t)(void* klass);
typedef void* (*il2cpp_class_get_method_from_name_t)(void* klass, const char* name, int argsCount);
typedef void* (*il2cpp_runtime_invoke_t)(void* method, void* obj, void** params, void** exc);

static il2cpp_domain_get_t fn_il2cpp_domain_get = nullptr;
static il2cpp_domain_get_assemblies_t fn_il2cpp_domain_get_assemblies = nullptr;
static il2cpp_assembly_get_image_t fn_il2cpp_assembly_get_image = nullptr;
static il2cpp_class_from_name_t fn_il2cpp_class_from_name = nullptr;
static il2cpp_object_new_t fn_il2cpp_object_new = nullptr;
static il2cpp_class_get_field_from_name_t fn_il2cpp_class_get_field_from_name = nullptr;
static il2cpp_field_static_get_value_t fn_il2cpp_field_static_get_value = nullptr;
static il2cpp_class_get_parent_t fn_il2cpp_class_get_parent = nullptr;
static il2cpp_class_get_method_from_name_t fn_il2cpp_class_get_method_from_name = nullptr;
static il2cpp_runtime_invoke_t fn_il2cpp_runtime_invoke = nullptr;

static bool g_il2cppApiResolved = false;

static void ResolveIl2CppApi() {
    if (g_il2cppApiResolved) return;
    void* handle = dlopen("libil2cpp.so", RTLD_NOLOAD);
    if (!handle) {
        __android_log_print(ANDROID_LOG_ERROR, "AUTOLIKE", "Failed to open libil2cpp.so");
        return;
    }
    fn_il2cpp_domain_get = (il2cpp_domain_get_t)dlsym(handle, "il2cpp_domain_get");
    fn_il2cpp_domain_get_assemblies = (il2cpp_domain_get_assemblies_t)dlsym(handle, "il2cpp_domain_get_assemblies");
    fn_il2cpp_assembly_get_image = (il2cpp_assembly_get_image_t)dlsym(handle, "il2cpp_assembly_get_image");
    fn_il2cpp_class_from_name = (il2cpp_class_from_name_t)dlsym(handle, "il2cpp_class_from_name");
    fn_il2cpp_object_new = (il2cpp_object_new_t)dlsym(handle, "il2cpp_object_new");
    fn_il2cpp_class_get_field_from_name = (il2cpp_class_get_field_from_name_t)dlsym(handle, "il2cpp_class_get_field_from_name");
    fn_il2cpp_field_static_get_value = (il2cpp_field_static_get_value_t)dlsym(handle, "il2cpp_field_static_get_value");
    fn_il2cpp_class_get_parent = (il2cpp_class_get_parent_t)dlsym(handle, "il2cpp_class_get_parent");
    fn_il2cpp_class_get_method_from_name = (il2cpp_class_get_method_from_name_t)dlsym(handle, "il2cpp_class_get_method_from_name");
    fn_il2cpp_runtime_invoke = (il2cpp_runtime_invoke_t)dlsym(handle, "il2cpp_runtime_invoke");
    g_il2cppApiResolved = true;
    __android_log_print(ANDROID_LOG_INFO, "AUTOLIKE",
        "il2cpp API: domain=%p assemblies=%p image=%p class=%p new=%p field=%p static=%p parent=%p method=%p invoke=%p",
        fn_il2cpp_domain_get, fn_il2cpp_domain_get_assemblies,
        fn_il2cpp_assembly_get_image, fn_il2cpp_class_from_name,
        fn_il2cpp_object_new, fn_il2cpp_class_get_field_from_name,
        fn_il2cpp_field_static_get_value, fn_il2cpp_class_get_parent,
        fn_il2cpp_class_get_method_from_name, fn_il2cpp_runtime_invoke);
}

static void* FindIl2CppImage(const char* assemblyName) {
    if (!fn_il2cpp_domain_get || !fn_il2cpp_domain_get_assemblies || !fn_il2cpp_assembly_get_image)
        return nullptr;
    void* domain = fn_il2cpp_domain_get();
    if (!domain) return nullptr;
    size_t count = 0;
    void** assemblies = fn_il2cpp_domain_get_assemblies(domain, &count);
    if (!assemblies) return nullptr;
    typedef const char* (*il2cpp_image_get_name_t)(void*);
    static il2cpp_image_get_name_t fn_image_get_name = nullptr;
    if (!fn_image_get_name) {
        void* handle = dlopen("libil2cpp.so", RTLD_NOLOAD);
        fn_image_get_name = (il2cpp_image_get_name_t)dlsym(handle, "il2cpp_image_get_name");
    }
    for (size_t i = 0; i < count; i++) {
        void* image = fn_il2cpp_assembly_get_image(assemblies[i]);
        if (image && fn_image_get_name) {
            const char* name = fn_image_get_name(image);
            if (name && strstr(name, assemblyName))
                return image;
        }
    }
    return nullptr;
}

// Debug log ring buffer
#define MAX_DEBUG_LOGS 30
struct DebugLogEntry {
    char msg[256];
    float timestamp;
};
static DebugLogEntry g_debugLogs[MAX_DEBUG_LOGS];
static int g_debugLogCount = 0;
static int g_debugLogHead = 0;

static void AddDebugLog(const char* fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int idx = g_debugLogHead;
    vsnprintf(g_debugLogs[idx].msg, sizeof(g_debugLogs[idx].msg), fmt, args);
    va_end(args);
    g_debugLogs[idx].timestamp = GetTimeSeconds();
    g_debugLogHead = (g_debugLogHead + 1) % MAX_DEBUG_LOGS;
    if (g_debugLogCount < MAX_DEBUG_LOGS) g_debugLogCount++;
    __android_log_print(ANDROID_LOG_INFO, "AUTOLIKE_LOG", "%s", g_debugLogs[idx].msg);
}

// Auto Like settings
struct _AutoLike {
    bool Enable = false;
    float Interval = 3.0f;
    char UidStr[32] = "15793107929203825";
    uint64_t TargetUid = 15793107929203825ULL;
    uint32_t LogicWorldId = 36;
    int LikeCount = 0;
    int LastError = 0;
    bool IsSending = false;
    char StatusMsg[128] = "San sang";
};
static _AutoLike AutoLike;

// Resolved method pointers (RVA-based)
typedef void* (*new_CSPkg_t)();
typedef void* (*new_COMDT_ACNT_UNIQ_t)();
typedef bool (*SendLobbyMsg_t)(void* networkModule, void** pMsg, bool isShowAlert, void* methodInfo);
typedef void* (*GetInstance_t)();

static new_CSPkg_t fn_new_CSPkg = nullptr;              // ProtocolObjectPool.new_CSPkg
static new_COMDT_ACNT_UNIQ_t fn_new_COMDT_ACNT_UNIQ = nullptr; // ProtocolObjectPool.new_COMDT_ACNT_UNIQ
static SendLobbyMsg_t fn_SendLobbyMsg = nullptr;         // NetworkModule.SendLobbyMsg
static GetInstance_t fn_GetNetworkModuleInstance = nullptr; // Singleton<NetworkModule>.get_instance

// Field offsets (from il2cpp dump)
static const uintptr_t OFF_CSPkg_stPkgHead = 0x8;
static const uintptr_t OFF_CSPkg_stPkgData = 0x10;
static const uintptr_t OFF_CSPkgHead_dwMsgID = 0x8;
static const uintptr_t OFF_CSPkgBody_dataObject = 0x8;
static const uintptr_t OFF_COMDT_ACNT_UNIQ_ullUid = 0x8;
static const uintptr_t OFF_COMDT_ACNT_UNIQ_dwLogicWorldId = 0x10;

static const uint32_t CSID_HOME_PAGE_LIKE_REQ = 12301;

static float g_lastLikeTime = 0.0f;

static void* g_cachedNetworkModule = nullptr;
static void* g_networkModuleMethod = nullptr;

static void* GetNetworkModuleInstance() {
    if (g_cachedNetworkModule) return g_cachedNetworkModule;

    // Method 1: Direct function pointer from GetMethodOffset
    if (fn_GetNetworkModuleInstance) {
        void* inst = fn_GetNetworkModuleInstance();
        if (inst) {
            g_cachedNetworkModule = inst;
            AddDebugLog("NetworkModule via GetMethodOffset: %p", inst);
            return inst;
        }
    }

    if (!fn_il2cpp_class_from_name) return nullptr;

    void* image = FindIl2CppImage("Project_d");
    if (!image) {
        AddDebugLog("ERROR: Project_d image not found");
        return nullptr;
    }

    void* klass = fn_il2cpp_class_from_name(image, "Assets.Scripts.Framework", "NetworkModule");
    if (!klass) {
        AddDebugLog("ERROR: NetworkModule class not found");
        return nullptr;
    }

    void* parentClass = fn_il2cpp_class_get_parent ? fn_il2cpp_class_get_parent(klass) : nullptr;
    void* grandParent = (parentClass && fn_il2cpp_class_get_parent) ? fn_il2cpp_class_get_parent(parentClass) : nullptr;

    // Method 2: il2cpp_runtime_invoke on get_instance/GetInstance
    if (fn_il2cpp_class_get_method_from_name && fn_il2cpp_runtime_invoke) {
        const char* methodNames[] = {"get_instance", "GetInstance", "get_Instance", nullptr};
        void* classes[] = {klass, parentClass, grandParent};
        for (int c = 0; c < 3 && classes[c]; c++) {
            for (int m = 0; methodNames[m]; m++) {
                void* method = fn_il2cpp_class_get_method_from_name(classes[c], methodNames[m], 0);
                if (method) {
                    g_networkModuleMethod = method;
                    void* exc = nullptr;
                    void* result = fn_il2cpp_runtime_invoke(method, nullptr, nullptr, &exc);
                    if (result && !exc) {
                        // runtime_invoke returns a boxed object for value types, or the object itself for ref types
                        // For a class instance (ref type), unbox: the object IS the pointer
                        g_cachedNetworkModule = result;
                        AddDebugLog("NetworkModule via invoke %s on class[%d]: %p", methodNames[m], c, result);
                        return result;
                    }
                    if (exc) {
                        AddDebugLog("invoke %s exc: %p", methodNames[m], exc);
                    }
                }
            }
        }
    }

    // Method 3: Static field read
    if (fn_il2cpp_class_get_field_from_name && fn_il2cpp_field_static_get_value) {
        const char* fieldNames[] = {"s_instance", "instance", "_instance", "m_instance", "s_Instance", nullptr};
        void* classes[] = {klass, parentClass, grandParent};
        for (int c = 0; c < 3 && classes[c]; c++) {
            for (int f = 0; fieldNames[f]; f++) {
                void* field = fn_il2cpp_class_get_field_from_name(classes[c], fieldNames[f]);
                if (field) {
                    void* instance = nullptr;
                    fn_il2cpp_field_static_get_value(field, &instance);
                    AddDebugLog("Field %s on class[%d]: field=%p val=%p", fieldNames[f], c, field, instance);
                    if (instance) {
                        g_cachedNetworkModule = instance;
                        return instance;
                    }
                }
            }
        }
    }

    AddDebugLog("ERROR: All NetworkModule resolution methods failed");
    return nullptr;
}

static bool SendLikeRequest() {
    if (!fn_new_CSPkg || !fn_new_COMDT_ACNT_UNIQ || !fn_SendLobbyMsg) {
        AddDebugLog("ERROR: Methods not resolved (CSPkg=%p ACNT=%p Send=%p)",
            fn_new_CSPkg, fn_new_COMDT_ACNT_UNIQ, fn_SendLobbyMsg);
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Loi: Chua resolve method");
        return false;
    }

    void* networkModule = GetNetworkModuleInstance();
    if (!networkModule) {
        AddDebugLog("ERROR: NetworkModule instance is null");
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Loi: NetworkModule null");
        return false;
    }

    void* csPkg = fn_new_CSPkg();
    if (!csPkg) {
        AddDebugLog("ERROR: new_CSPkg returned null");
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Loi: new_CSPkg null");
        return false;
    }

    void* acntUniq = fn_new_COMDT_ACNT_UNIQ();
    if (!acntUniq) {
        AddDebugLog("ERROR: new_COMDT_ACNT_UNIQ returned null");
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Loi: new_ACNT null");
        return false;
    }

    *(uint64_t*)((uintptr_t)acntUniq + OFF_COMDT_ACNT_UNIQ_ullUid) = AutoLike.TargetUid;
    *(uint32_t*)((uintptr_t)acntUniq + OFF_COMDT_ACNT_UNIQ_dwLogicWorldId) = AutoLike.LogicWorldId;

    void* pkgHead = *(void**)((uintptr_t)csPkg + OFF_CSPkg_stPkgHead);
    if (pkgHead) {
        *(uint32_t*)((uintptr_t)pkgHead + OFF_CSPkgHead_dwMsgID) = CSID_HOME_PAGE_LIKE_REQ;
    } else {
        AddDebugLog("ERROR: CSPkg.stPkgHead is null");
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Loi: PkgHead null");
        return false;
    }

    void* pkgBody = *(void**)((uintptr_t)csPkg + OFF_CSPkg_stPkgData);
    if (pkgBody) {
        *(void**)((uintptr_t)pkgBody + OFF_CSPkgBody_dataObject) = acntUniq;
    } else {
        AddDebugLog("ERROR: CSPkg.stPkgData is null");
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Loi: PkgBody null");
        return false;
    }

    AddDebugLog("Sending LIKE: UID=%llu WorldID=%u MsgID=%u",
        (unsigned long long)AutoLike.TargetUid, AutoLike.LogicWorldId, CSID_HOME_PAGE_LIKE_REQ);

    bool result = fn_SendLobbyMsg(networkModule, &csPkg, false, nullptr);

    AutoLike.LikeCount++;
    if (result) {
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg),
            "Da gui #%d (UID: %llu)", AutoLike.LikeCount, (unsigned long long)AutoLike.TargetUid);
        AddDebugLog("LIKE sent OK #%d", AutoLike.LikeCount);
    } else {
        snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg),
            "Gui that bai #%d", AutoLike.LikeCount);
        AddDebugLog("LIKE send FAILED #%d", AutoLike.LikeCount);
    }

    return result;
}

// Hook for SendLobbyMsg response (optional, to catch error codes)
static SendLobbyMsg_t fn_SendLobbyCSPkgMsg_orig = nullptr;

// FPS unlock hooks (keep for QoL)
bool (*_TRUE)(void* ins);
bool TRUE(void* ins) { return true; }

void DrawESP(ImDrawList* draw) {
    // no-op: all ESP removed
}

void GetIconHero() {
    // no-op: all hero icons removed
}

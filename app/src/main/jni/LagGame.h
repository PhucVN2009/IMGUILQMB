#pragma once
#include "UnityInline.h"
#include "Includes/Logger.h"
#include <time.h>

// ─────────────────────────────────────────────────────────────────────────────
// LAG GAME – làm lag cả 2 team bằng cách thao tác timeScale + targetFrameRate
//
// Nguyên lý: AOV dùng mô hình lockstep – tất cả client phải sync từng frame.
// Khi 1 client chạy chậm (timeScale thấp), server chờ → toàn bộ 2 team lag.
//
// Auto-Update: dùng GetMethodOffset/FindMethodOffset từ UnityInline.h,
// không hardcode RVA – tự resolve qua metadata mỗi khi patch game.
// ─────────────────────────────────────────────────────────────────────────────

struct LagGameSettings {
    bool  enable       = false;
    float timeScale    = 0.3f;  // 0.05 – 1.0  (thấp = lag mạnh hơn)
    bool  limitFPS     = true;
    int   targetFPS    = 10;    // 1 – 60
    bool  slowPhysics  = false;
    float fixedDelta   = 0.2f;  // fixedDeltaTime cao → physics chậm
};
LagGameSettings LagGame{};

// ─── Function pointers – resolve qua UnityInline auto-update ────────────────
static void  (*lag_set_timeScale)(float v)       = nullptr;
static float (*lag_get_timeScale)()              = nullptr;
static void  (*lag_set_targetFrameRate)(int v)   = nullptr;
static int   (*lag_get_targetFrameRate)()        = nullptr;
static void  (*lag_set_fixedDeltaTime)(float v)  = nullptr;
static float (*lag_get_fixedDeltaTime)()         = nullptr;

// Giá trị gốc để restore khi tắt
static float lag_orig_timeScale   = 1.0f;
static int   lag_orig_fps         = 60;
static float lag_orig_fixedDelta  = 0.02f;
static bool  lag_saved            = false;

// ─── Resolve tất cả function pointer (gọi 1 lần trong Init_Thread) ───────────
static void LagGame_Init() {
    // Time.set_timeScale / get_timeScale
    // Thử CoreModule trước, fallback sang UnityEngine.dll (auto-update pattern)
    lag_set_timeScale = (void(*)(float))
        GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Time", "set_timeScale", 1);
    if (!lag_set_timeScale)
        lag_set_timeScale = (void(*)(float))
            GetMethodOffset("UnityEngine.dll", "UnityEngine", "Time", "set_timeScale", 1);

    lag_get_timeScale = (float(*)())
        GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Time", "get_timeScale", 0);
    if (!lag_get_timeScale)
        lag_get_timeScale = (float(*)())
            GetMethodOffset("UnityEngine.dll", "UnityEngine", "Time", "get_timeScale", 0);

    // Application.set_targetFrameRate / get_targetFrameRate
    lag_set_targetFrameRate = (void(*)(int))
        GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Application", "set_targetFrameRate", 1);
    if (!lag_set_targetFrameRate)
        lag_set_targetFrameRate = (void(*)(int))
            GetMethodOffset("UnityEngine.dll", "UnityEngine", "Application", "set_targetFrameRate", 1);

    lag_get_targetFrameRate = (int(*)())
        GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Application", "get_targetFrameRate", 0);
    if (!lag_get_targetFrameRate)
        lag_get_targetFrameRate = (int(*)())
            GetMethodOffset("UnityEngine.dll", "UnityEngine", "Application", "get_targetFrameRate", 0);

    // Time.set_fixedDeltaTime / get_fixedDeltaTime
    lag_set_fixedDeltaTime = (void(*)(float))
        GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Time", "set_fixedDeltaTime", 1);
    if (!lag_set_fixedDeltaTime)
        lag_set_fixedDeltaTime = (void(*)(float))
            GetMethodOffset("UnityEngine.dll", "UnityEngine", "Time", "set_fixedDeltaTime", 1);

    lag_get_fixedDeltaTime = (float(*)())
        GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Time", "get_fixedDeltaTime", 0);
    if (!lag_get_fixedDeltaTime)
        lag_get_fixedDeltaTime = (float(*)())
            GetMethodOffset("UnityEngine.dll", "UnityEngine", "Time", "get_fixedDeltaTime", 0);

    LOGI("[LagGame] set_timeScale=%p get_timeScale=%p set_fps=%p set_fixed=%p",
         (void*)lag_set_timeScale, (void*)lag_get_timeScale,
         (void*)lag_set_targetFrameRate, (void*)lag_set_fixedDeltaTime);
}

// ─── Áp dụng lag – gọi mỗi frame trong eglSwapBuffers ───────────────────────
// Rate-limit để tránh gọi quá nhiều: chỉ apply mỗi 0.1s
static void LagGame_Update() {
    static float lastApply = 0.f;
    float now = GetTimeSeconds();
    if (now - lastApply < 0.1f) return;
    lastApply = now;

    if (!LagGame.enable) {
        // Restore về giá trị gốc nếu vừa tắt
        if (lag_saved) {
            if (lag_set_timeScale)      lag_set_timeScale(lag_orig_timeScale);
            if (lag_set_targetFrameRate) lag_set_targetFrameRate(lag_orig_fps);
            if (lag_set_fixedDeltaTime)  lag_set_fixedDeltaTime(lag_orig_fixedDelta);
            lag_saved = false;
            LOGI("[LagGame] Restored: timeScale=%.2f fps=%d fixedDelta=%.4f",
                 lag_orig_timeScale, lag_orig_fps, lag_orig_fixedDelta);
        }
        return;
    }

    // Lưu giá trị gốc lần đầu bật
    if (!lag_saved) {
        lag_orig_timeScale  = lag_get_timeScale  ? lag_get_timeScale()  : 1.0f;
        lag_orig_fps        = lag_get_targetFrameRate ? lag_get_targetFrameRate() : 60;
        lag_orig_fixedDelta = lag_get_fixedDeltaTime  ? lag_get_fixedDeltaTime()  : 0.02f;
        lag_saved = true;
        LOGI("[LagGame] Saved orig: timeScale=%.2f fps=%d fixedDelta=%.4f",
             lag_orig_timeScale, lag_orig_fps, lag_orig_fixedDelta);
    }

    // Áp dụng lag
    float ts = LagGame.timeScale;
    if (ts < 0.01f) ts = 0.01f;
    if (ts > 1.0f)  ts = 1.0f;

    if (lag_set_timeScale)
        lag_set_timeScale(ts);

    if (LagGame.limitFPS && lag_set_targetFrameRate) {
        int fps = LagGame.targetFPS;
        if (fps < 1)  fps = 1;
        if (fps > 60) fps = 60;
        lag_set_targetFrameRate(fps);
    }

    if (LagGame.slowPhysics && lag_set_fixedDeltaTime) {
        float fd = LagGame.fixedDelta;
        if (fd < 0.02f) fd = 0.02f;
        if (fd > 1.0f)  fd = 1.0f;
        lag_set_fixedDeltaTime(fd);
    }
}

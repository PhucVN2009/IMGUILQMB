#pragma once
#include "UnityInline.h"
#include "Includes/Logger.h"
#include <time.h>
#include <cmath>

// ═══════════════════════════════════════════════════════════════════════════
// LAG SPAM — Gửi lockstep frame commands liên tục → lag cả 2 team
//
// Nguyên lý: AOV dùng deterministic lockstep. Mỗi frame command được
// broadcast tới tất cả client và server chờ ALL client xử lý xong.
// Spam command nhanh → queue tắc → cả phòng lag.
//
// Instance capture: hook Awake/SendEmoji để lấy EffectPlayComponent*
// Auto-Move: GameInput.SendMoveDirection → MoveDirectionCommand [ID 2]
//   CHÚ Ý: server gán player ID từ session → chỉ điều khiển tướng BẠN
// ═══════════════════════════════════════════════════════════════════════════

struct LagSpamSettings {
    // ── Emoji / Dance / Gesture spam ─────────────────────────────────────
    bool  emojiEnable    = false;
    float emojiInterval  = 0.05f;   // giây giữa 2 lần spam
    int   emojiIndex     = 0;       // index emoji/dance (0–99)
    bool  typeEmoji      = true;    // SendEmojiCommandByIndex
    bool  typeDance      = false;   // SendDanceCommandByIndex
    bool  typeCombo      = false;   // SendEmojiDanceCommandByIndex
    bool  typeGesture2   = false;   // StartSkillGestureEffect2 (0 params)
    bool  typeGesture3   = false;   // StartSkillGestureEffect3 (0 params)
    bool  typeG2Cancel   = false;   // StartSkillGestureEffect2Cancel (0 params)

    // ── Chat Emoji spam (static – không cần instance) ────────────────────
    bool  chatEnable     = false;
    float chatInterval   = 0.10f;
    int   chatEmojiID    = 1;       // ID emoji team chat (1–50)
};
LagSpamSettings LagSpam{};

// ─── Auto-Movement settings ───────────────────────────────────────────────
struct AutoMoveSettings {
    bool  enable      = false;
    float interval    = 0.05f;   // giây giữa 2 move command
    // 4 hướng la bàn (chỉ 1 hướng active tại 1 thời điểm)
    bool  dirN        = false;   // Bắc  (Trước) — Y+  — 0°
    bool  dirS        = false;   // Nam  (Sau)   — Y-  — 180°
    bool  dirE        = false;   // Đông (Phải)  — X+  — 90°
    bool  dirW        = false;   // Tây  (Trái)  — X-  — 270°
    // Custom angle
    bool  useCustom   = false;
    int   customDeg   = 0;       // 0–359 (0=N, 90=E, 180=S, 270=W)
};
AutoMoveSettings AutoMove{};

// ─── Function pointers – EffectPlayComponent (instance methods) ──────────
static void (*spam_SendEmojiByIdx)(void*, int)      = nullptr;
static void (*spam_SendDanceByIdx)(void*, int)      = nullptr;
static void (*spam_SendEmojiDanceByIdx)(void*, int) = nullptr;
static void (*spam_Gesture2)(void*)                 = nullptr;
static void (*spam_Gesture3)(void*)                 = nullptr;
static void (*spam_Gesture2Cancel)(void*)           = nullptr;
static void* g_spamEffectComp                       = nullptr;

// ─── Function pointers – CChatNetUT (static) ─────────────────────────────
static void (*spam_ChatEmoji)(int) = nullptr;

// ─── Function pointers – GameInput (Auto-Move) ───────────────────────────
// Vec2 matching Unity Vector2 { float x, y; }
struct MoveVec2 { float x, y; };
static void (*move_SendDir)(void* thiz, MoveVec2 start, MoveVec2 end) = nullptr;
static void (*move_StopInput)(void* thiz)                              = nullptr;
static void* g_gameInputInst                                           = nullptr;

// ─── Hooks ────────────────────────────────────────────────────────────────

// Hook EffectPlayComponent.Awake – capture instance sớm nhất
void (*orig_spam_Awake)(void*) = nullptr;
static void hook_spam_Awake(void* thiz) {
    g_spamEffectComp = thiz;
    if (orig_spam_Awake) orig_spam_Awake(thiz);
}

// Fallback: capture khi người dùng gửi emoji lần đầu
void (*orig_spam_SendEmoji)(void*, int) = nullptr;
static void hook_spam_SendEmoji(void* thiz, int idx) {
    g_spamEffectComp = thiz;
    if (orig_spam_SendEmoji) orig_spam_SendEmoji(thiz, idx);
}

// Hook GameInput.UpdateFrame – capture GameInput instance mỗi frame
void (*orig_move_UpdateFrame)(void*) = nullptr;
static void hook_move_UpdateFrame(void* thiz) {
    g_gameInputInst = thiz;
    if (orig_move_UpdateFrame) orig_move_UpdateFrame(thiz);
}

// ─── Helpers ─────────────────────────────────────────────────────────────
static float LagSpam_Now() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (float)(ts.tv_sec + ts.tv_nsec * 1e-9);
}

// ─── Init – resolve tất cả method pointer ────────────────────────────────
static void LagSpam_Init() {
    const char* pdll = "Project_d.dll";
    const char* ns   = "Assets.Scripts.GameLogic";

    // EffectPlayComponent spam
    spam_SendEmojiByIdx      = (void(*)(void*,int)) GetMethodOffset(pdll, ns, "EffectPlayComponent", "SendEmojiCommandByIndex", 1);
    spam_SendDanceByIdx      = (void(*)(void*,int)) GetMethodOffset(pdll, ns, "EffectPlayComponent", "SendDanceCommandByIndex", 1);
    spam_SendEmojiDanceByIdx = (void(*)(void*,int)) GetMethodOffset(pdll, ns, "EffectPlayComponent", "SendEmojiDanceCommandByIndex", 1);
    spam_Gesture2            = (void(*)(void*))     GetMethodOffset(pdll, ns, "EffectPlayComponent", "StartSkillGestureEffect2", 0);
    spam_Gesture3            = (void(*)(void*))     GetMethodOffset(pdll, ns, "EffectPlayComponent", "StartSkillGestureEffect3", 0);
    spam_Gesture2Cancel      = (void(*)(void*))     GetMethodOffset(pdll, ns, "EffectPlayComponent", "StartSkillGestureEffect2Cancel", 0);

    // CChatNetUT static
    spam_ChatEmoji = (void(*)(int)) GetMethodOffset(pdll, "Assets.Scripts.GameSystem", "CChatNetUT", "SendEmojiMsgInTeam", 1);

    // GameInput – auto-movement
    // SendMoveDirection(Vector2 start, Vector2 end) – IDTag(1), paramCount=2
    // GetMethodOffset trả về IDTag(1) vì nó xuất hiện trước IDTag(0) trong metadata
    move_SendDir   = (void(*)(void*,MoveVec2,MoveVec2)) GetMethodOffset(pdll, ns, "GameInput", "SendMoveDirection", 2);
    move_StopInput = (void(*)(void*))                    GetMethodOffset(pdll, ns, "GameInput", "StopInput", 0);

    LOGI("[LagSpam] emoji=%p dance=%p combo=%p g2=%p g3=%p chat=%p",
         (void*)spam_SendEmojiByIdx, (void*)spam_SendDanceByIdx,
         (void*)spam_SendEmojiDanceByIdx, (void*)spam_Gesture2,
         (void*)spam_Gesture3, (void*)spam_ChatEmoji);
    LOGI("[AutoMove] SendDir=%p StopInput=%p",
         (void*)move_SendDir, (void*)move_StopInput);
}

// ─── Update – gọi mỗi frame ──────────────────────────────────────────────
static void LagSpam_Update() {
    float now = LagSpam_Now();

    // ── Emoji / Dance / Gesture spam ─────────────────────────────────────
    if (LagSpam.emojiEnable && g_spamEffectComp) {
        static float last = 0.f;
        if (now - last >= LagSpam.emojiInterval) {
            last = now;
            int i = LagSpam.emojiIndex;
            if (LagSpam.typeEmoji    && spam_SendEmojiByIdx)      spam_SendEmojiByIdx(g_spamEffectComp, i);
            if (LagSpam.typeDance    && spam_SendDanceByIdx)      spam_SendDanceByIdx(g_spamEffectComp, i);
            if (LagSpam.typeCombo    && spam_SendEmojiDanceByIdx) spam_SendEmojiDanceByIdx(g_spamEffectComp, i);
            if (LagSpam.typeGesture2 && spam_Gesture2)            spam_Gesture2(g_spamEffectComp);
            if (LagSpam.typeGesture3 && spam_Gesture3)            spam_Gesture3(g_spamEffectComp);
            if (LagSpam.typeG2Cancel && spam_Gesture2Cancel)      spam_Gesture2Cancel(g_spamEffectComp);
        }
    }

    // ── Chat emoji spam (static) ─────────────────────────────────────────
    if (LagSpam.chatEnable && spam_ChatEmoji) {
        static float lastChat = 0.f;
        if (now - lastChat >= LagSpam.chatInterval) {
            lastChat = now;
            spam_ChatEmoji(LagSpam.chatEmojiID);
        }
    }

    // ── Auto-Movement ────────────────────────────────────────────────────
    static bool prevAutoMove = false;
    if (AutoMove.enable && g_gameInputInst && move_SendDir) {
        static float lastMov = 0.f;
        if (now - lastMov >= AutoMove.interval) {
            lastMov = now;
            MoveVec2 org = {0.f, 0.f};
            MoveVec2 dir = {0.f, 0.f};
            bool moved = false;
            if (AutoMove.useCustom && AutoMove.customDeg >= 0) {
                float rad = AutoMove.customDeg * 3.14159265f / 180.f;
                dir = {sinf(rad) * 100.f, cosf(rad) * 100.f};
                moved = true;
            } else if (AutoMove.dirN) { dir = { 0.f,  100.f}; moved = true; }
            else if (AutoMove.dirS)   { dir = { 0.f, -100.f}; moved = true; }
            else if (AutoMove.dirE)   { dir = { 100.f,  0.f}; moved = true; }
            else if (AutoMove.dirW)   { dir = {-100.f,  0.f}; moved = true; }
            if (moved) move_SendDir(g_gameInputInst, org, dir);
        }
    }
    // Dừng di chuyển khi tắt auto-move
    if (prevAutoMove && !AutoMove.enable && g_gameInputInst && move_StopInput) {
        move_StopInput(g_gameInputInst);
    }
    prevAutoMove = AutoMove.enable;
}

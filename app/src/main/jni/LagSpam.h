#pragma once
#include "UnityInline.h"
#include "Includes/Logger.h"
#include <time.h>

// ═══════════════════════════════════════════════════════════════════════════
// LAG SPAM — Gửi lockstep frame commands liên tục → lag cả 2 team
//
// Nguyên lý: AOV dùng deterministic lockstep. Mỗi frame command được
// broadcast tới tất cả client và server chờ ALL client xử lý xong.
// Spam command nhanh → queue tắc → cả phòng lag.
//
// Instance capture: hook Awake/SendEmoji để lấy EffectPlayComponent*
// ═══════════════════════════════════════════════════════════════════════════

struct LagSpamSettings {
    // ── Emoji / Dance / Gesture spam ─────────────────────────────────────
    bool  emojiEnable    = false;
    float emojiInterval  = 0.05f;   // giây giữa 2 lần spam
    int   emojiIndex     = 0;       // index emoji/dance (0–99)
    bool  typeEmoji      = true;    // SendEmojiCommandByIndex
    bool  typeDance      = false;   // SendDanceCommandByIndex
    bool  typeCombo      = false;   // SendEmojiDanceCommandByIndex (bị fix nhưng vẫn thử)
    bool  typeGesture2   = false;   // StartSkillGestureEffect2 (0 params)
    bool  typeGesture3   = false;   // StartSkillGestureEffect3 (0 params)
    bool  typeG2Cancel   = false;   // StartSkillGestureEffect2Cancel (0 params)

    // ── Chat Emoji spam (static – không cần instance) ────────────────────
    bool  chatEnable     = false;
    float chatInterval   = 0.10f;
    int   chatEmojiID    = 1;       // ID emoji team chat (1–20)

    // ── Signal / Ping spam (cần LFrameSynchr, sẽ hỗ trợ sau) ────────────
    bool  signalEnable   = false;
    float signalInterval = 0.10f;
    int   signalID       = 1;
};
LagSpamSettings LagSpam{};

// ─── Function pointers – EffectPlayComponent (instance methods) ──────────
static void (*spam_SendEmojiByIdx)(void*, int)      = nullptr;
static void (*spam_SendDanceByIdx)(void*, int)      = nullptr;
static void (*spam_SendEmojiDanceByIdx)(void*, int) = nullptr;
static void (*spam_Gesture2)(void*)                 = nullptr;
static void (*spam_Gesture3)(void*)                 = nullptr;
static void (*spam_Gesture2Cancel)(void*)           = nullptr;

// Captured instance – điền bởi hook bên dưới
static void* g_spamEffectComp = nullptr;

// ─── Function pointers – CChatNetUT (static) ─────────────────────────────
static void (*spam_ChatEmoji)(int) = nullptr;

// ─── Hook Awake để capture EffectPlayComponent sớm nhất ──────────────────
void (*orig_spam_Awake)(void*) = nullptr;
static void hook_spam_Awake(void* thiz) {
    g_spamEffectComp = thiz;
    if (orig_spam_Awake) orig_spam_Awake(thiz);
}

// Fallback: hook SendEmojiCommandByIndex để capture nếu Awake miss
void (*orig_spam_SendEmoji)(void*, int) = nullptr;
static void hook_spam_SendEmoji(void* thiz, int idx) {
    g_spamEffectComp = thiz;
    if (orig_spam_SendEmoji) orig_spam_SendEmoji(thiz, idx);
}

// ─── Helpers ─────────────────────────────────────────────────────────────
static float LagSpam_Now() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (float)(ts.tv_sec + ts.tv_nsec * 1e-9);
}

// ─── Init – resolve tất cả method pointer ────────────────────────────────
static void LagSpam_Init() {
    const char* dll  = "Project_d.dll";
    const char* ns   = "Assets.Scripts.GameLogic";
    const char* cls  = "EffectPlayComponent";

    spam_SendEmojiByIdx      = (void(*)(void*,int)) GetMethodOffset(dll, ns, cls, "SendEmojiCommandByIndex", 1);
    spam_SendDanceByIdx      = (void(*)(void*,int)) GetMethodOffset(dll, ns, cls, "SendDanceCommandByIndex", 1);
    spam_SendEmojiDanceByIdx = (void(*)(void*,int)) GetMethodOffset(dll, ns, cls, "SendEmojiDanceCommandByIndex", 1);
    spam_Gesture2            = (void(*)(void*))     GetMethodOffset(dll, ns, cls, "StartSkillGestureEffect2", 0);
    spam_Gesture3            = (void(*)(void*))     GetMethodOffset(dll, ns, cls, "StartSkillGestureEffect3", 0);
    spam_Gesture2Cancel      = (void(*)(void*))     GetMethodOffset(dll, ns, cls, "StartSkillGestureEffect2Cancel", 0);

    spam_ChatEmoji = (void(*)(int)) GetMethodOffset("Project_d.dll", "Assets.Scripts.GameSystem", "CChatNetUT", "SendEmojiMsgInTeam", 1);

    LOGI("[LagSpam] emoji=%p dance=%p combo=%p g2=%p g3=%p g2c=%p chat=%p",
         (void*)spam_SendEmojiByIdx, (void*)spam_SendDanceByIdx,
         (void*)spam_SendEmojiDanceByIdx, (void*)spam_Gesture2,
         (void*)spam_Gesture3, (void*)spam_Gesture2Cancel,
         (void*)spam_ChatEmoji);
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
}

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

// ─── Function pointers – GameInput (Auto-Move self) ──────────────────────
// Vec2 matching Unity Vector2 { float x, y; }
struct MoveVec2 { float x, y; };
static void (*move_SendDir)(void* thiz, MoveVec2 start, MoveVec2 end) = nullptr;
static void (*move_StopInput)(void* thiz)                              = nullptr;
static void* g_gameInputInst                                           = nullptr;

// ─── AutoMoveAll – điều khiển di chuyển tất cả người chơi ────────────────
// GameInput.SendMoveDirection(int degree, uint playerId) – private overload
// Resolved via LagSpam_FindPrivateMethod (not hardcoded RVA)
// ActorLinker.get_playerId() – unique method, resolved via GetMethodOffset
static void         (*move_SendDir_Priv)(void* thiz, int degree, unsigned int playerId) = nullptr;
static unsigned int (*ama_get_playerId)(void* thiz)                                     = nullptr;

struct AutoMoveAllSettings {
    bool  enable        = false;
    float interval      = 0.05f;
    bool  dirN          = false;
    bool  dirS          = false;
    bool  dirE          = false;
    bool  dirW          = false;
    bool  useCustom     = false;
    int   customDeg     = 0;
    bool  targetSelf    = true;
    bool  targetAllies  = true;
    bool  targetEnemies = true;
};
AutoMoveAllSettings AutoMoveAll{};

// ─── Debug snapshot for Tab 7 / ESP overlay ──────────────────────────────
struct AMADebugEntry {
    unsigned int playerID;
    int          camp;
    bool         isHost;
    bool         targeted;
};
static AMADebugEntry g_amaDebugEntries[20];
static int           g_amaDebugCount  = 0;
static int           g_amaDebugDeg    = 0;
static bool          g_amaDebugActive = false;

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

// ─── Private-method resolver ─────────────────────────────────────────────
// Finds the PRIVATE overload of a method by scanning metadata for the
// private-flag match (METHOD_ATTRIBUTE_MEMBER_ACCESS_MASK & 0x07 == 0x01).
// Falls back to the 2nd occurrence if no private flag match is found.
// Returns the absolute runtime address (method_va from the in-memory
// method-pointer table, which is already the runtime VA).
static void* LagSpam_FindPrivateMethod(const char* image, const char* ns,
                                       const char* klass, const char* method,
                                       int argsCount) {
    Unity::unity_cache_t* cache = Unity::get_cached_unity();
    if (!cache) return nullptr;

    const Unity::file_buffer_t* meta = &cache->meta;
    const uint32_t*             hdr  = cache->hdr;
    if (!meta || !hdr) return nullptr;

    uint32_t imagesOffset          = hdr[42];
    uint32_t imagesSize            = hdr[43];
    uint32_t typeDefinitionsOffset = hdr[40];
    uint32_t typeDefinitionsSize   = hdr[41];
    uint32_t methodsOffset         = hdr[12];
    uint32_t methodsSize           = hdr[13];

    const Unity::Il2CppImageDefinition*  images  =
        (const Unity::Il2CppImageDefinition*)(meta->data + imagesOffset);
    int image_count = (int)(imagesSize / sizeof(Unity::Il2CppImageDefinition));

    const Unity::Il2CppTypeDefinition*   types   =
        (const Unity::Il2CppTypeDefinition*)(meta->data + typeDefinitionsOffset);
    int type_total  = (int)(typeDefinitionsSize / sizeof(Unity::Il2CppTypeDefinition));

    const Unity::Il2CppMethodDefinition* methods =
        (const Unity::Il2CppMethodDefinition*)(meta->data + methodsOffset);
    int method_total = (int)(methodsSize / sizeof(Unity::Il2CppMethodDefinition));

    for (int i = 0; i < image_count; i++) {
        const char* img_name = Unity::metadata_string(meta, hdr, images[i].nameIndex);
        if (!img_name || strcmp(img_name, image) != 0) continue;

        int type_start = images[i].typeStart;
        int type_end   = type_start + (int)images[i].typeCount;
        if (type_start < 0 || type_start >= type_total) continue;
        if (type_end > type_total) type_end = type_total;

        for (int t = type_start; t < type_end; t++) {
            const char* tns = Unity::metadata_string(meta, hdr, types[t].namespaceIndex);
            const char* tn  = Unity::metadata_string(meta, hdr, types[t].nameIndex);
            if (!tn) continue;
            if (ns) {
                if (!tns || strcmp(tns, ns) != 0) continue;
            }
            if (strcmp(tn, klass) != 0) continue;

            int m_start = types[t].methodStart;
            int m_end   = m_start + (int)types[t].method_count;
            if (m_start < 0 || m_start >= method_total) continue;
            if (m_end > method_total) m_end = method_total;

            // Two-pass: prefer private flag; fall back to 2nd overload by count
            int idx_private = -1;   // first match with private flag
            int idx_second  = -1;   // second match overall (any access)
            int match_count = 0;

            for (int m = m_start; m < m_end; m++) {
                const char* mn = Unity::metadata_string(meta, hdr, methods[m].nameIndex);
                if (!mn || strcmp(mn, method) != 0) continue;
                if (argsCount >= 0 && methods[m].parameterCount != (uint16_t)argsCount) continue;

                match_count++;
                if ((methods[m].flags & 0x0007u) == 0x0001u && idx_private < 0)
                    idx_private = m;
                if (match_count == 2 && idx_second < 0)
                    idx_second = m;
            }

            // Pick best candidate: private flag first, 2nd match as fallback
            int target = (idx_private >= 0) ? idx_private :
                         (idx_second  >= 0) ? idx_second  : -1;
            if (target < 0) continue;

            // Resolve runtime address from in-memory method-pointer table.
            // method_va IS already the absolute runtime VA — return it directly.
            uint64_t method_va = 0;
            if (!Unity::get_method_ptr(&cache->unity, &cache->data_secs, &cache->exec_secs,
                                       cache->code_reg_va, image,
                                       methods[target].token, &method_va)) {
                return nullptr;
            }
            if (method_va < 0x1000000ull) return nullptr; // sanity: reject stub/null values
            return (void*)(uintptr_t)method_va;
        }
    }
    return nullptr;
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

    // AutoMoveAll – private SendMoveDirection(int degree, uint playerId) overload
    // Resolved via metadata private-flag scan to avoid hardcoded RVA
    move_SendDir_Priv = (void(*)(void*,int,unsigned int))
        LagSpam_FindPrivateMethod(pdll, ns, "GameInput", "SendMoveDirection", 2);

    // ActorLinker.get_playerId() – unique, no overload collision
    ama_get_playerId = (unsigned int(*)(void*))
        GetMethodOffset(pdll, "Kyrios.Actor", "ActorLinker", "get_playerId", 0);

    LOGI("[LagSpam] emoji=%p dance=%p combo=%p g2=%p g3=%p chat=%p",
         (void*)spam_SendEmojiByIdx, (void*)spam_SendDanceByIdx,
         (void*)spam_SendEmojiDanceByIdx, (void*)spam_Gesture2,
         (void*)spam_Gesture3, (void*)spam_ChatEmoji);
    LOGI("[AutoMove] SendDir=%p StopInput=%p SendDirPriv=%p GetPlayerId=%p",
         (void*)move_SendDir, (void*)move_StopInput,
         (void*)move_SendDir_Priv, (void*)ama_get_playerId);
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

    // ── AutoMoveAll (tất cả người chơi) ──────────────────────────────────
    // Reset debug snapshot each update tick regardless of enable state
    g_amaDebugActive = AutoMoveAll.enable;
    if (!AutoMoveAll.enable) {
        g_amaDebugCount = 0;
    }

    if (AutoMoveAll.enable && g_gameInputInst && move_SendDir_Priv && ama_get_playerId) {
        // Validate g_gameInputInst address range before ANY dereference
        if ((uintptr_t)g_gameInputInst < 0x1000000ull) goto ama_done;
        // Validate vtable to guard against stale instance pointer
        uint64_t gi_vtable = *(uint64_t*)g_gameInputInst;
        if ((gi_vtable & 0x0000FFFFFFFFFFFFull) < 0x1000000ull) goto ama_done;

        {
            static float lastAll = 0.f;
            if (now - lastAll >= AutoMoveAll.interval) {
                lastAll = now;
                int deg    = 0;
                bool doMove = false;
                if (AutoMoveAll.useCustom) {
                    deg = AutoMoveAll.customDeg; doMove = true;
                } else if (AutoMoveAll.dirN) { deg = 0;   doMove = true; }
                else if (AutoMoveAll.dirS)   { deg = 180; doMove = true; }
                else if (AutoMoveAll.dirE)   { deg = 90;  doMove = true; }
                else if (AutoMoveAll.dirW)   { deg = 270; doMove = true; }

                if (doMove) {
                    g_amaDebugDeg   = deg;
                    g_amaDebugCount = 0;

                    void* mgr = get_actorManager ? get_actorManager() : nullptr;
                    if (mgr && GetAllHeros_ActorManager) {
                        void* heroListRaw = (void*)GetAllHeros_ActorManager(mgr);
                        if (heroListRaw) {
                            // Same raw layout as Hook.h: [+0x08]=items array ptr, [+0x10]=size
                            void* arrPtr = *(void**)((uintptr_t)heroListRaw + 0x08);
                            int listSize = *(int*)  ((uintptr_t)heroListRaw + 0x10);

                            // Clamp listSize to prevent runaway loops on garbage data
                            if (listSize > 20) listSize = 20;

                            if (arrPtr && (uintptr_t)arrPtr >= 0x1000000 && listSize > 0) {
                                // Skip managed-array header (0x18 bytes) to reach element 0
                                void** items = (void**)((uintptr_t)arrPtr + 0x18);
                                for (int i = 0; i < listSize; i++) {
                                    void* al = items[i * 2 + 1];
                                    if (!al || (uintptr_t)al < 0x1000000) continue;

                                    // Validate actor vtable (same pattern as Hook.h)
                                    uint64_t vtable = *(uint64_t*)al;
                                    if ((vtable & 0x0000FFFFFFFFFFFFull) < 0x1000000ull) continue;

                                    bool isHost  = IsHostPlayer ? IsHostPlayer(al) : false;
                                    int  camp    = get_objCamp  ? get_objCamp(al)  : 0;
                                    bool isAlly  = !isHost && campDetected && camp == myPlayerCamp;
                                    bool isEnemy = campDetected && camp != myPlayerCamp;

                                    bool targeted = true;
                                    if (isHost  && !AutoMoveAll.targetSelf)    targeted = false;
                                    if (isAlly  && !AutoMoveAll.targetAllies)  targeted = false;
                                    if (isEnemy && !AutoMoveAll.targetEnemies) targeted = false;

                                    unsigned int pid = ama_get_playerId(al);

                                    // Populate debug snapshot
                                    if (g_amaDebugCount < 20) {
                                        g_amaDebugEntries[g_amaDebugCount].playerID = pid;
                                        g_amaDebugEntries[g_amaDebugCount].camp     = camp;
                                        g_amaDebugEntries[g_amaDebugCount].isHost   = isHost;
                                        g_amaDebugEntries[g_amaDebugCount].targeted = targeted;
                                        g_amaDebugCount++;
                                    }

                                    if (!targeted) continue;
                                    if (pid == 0) continue;
                                    move_SendDir_Priv(g_gameInputInst, deg, pid);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    ama_done:;
}

// ─── ESP overlay: draw AutoMoveAll debug labels ───────────────────────────
// Call from the ImGui render loop, passing the active ImDrawList and screen
// dimensions (glWidth, glHeight from Main.cpp).
static void DrawAutoMoveAllDebug(ImDrawList* draw, float screenWidth, float screenHeight) {
    (void)screenWidth;
    if (!draw) return;
    if (!AutoMoveAll.enable || g_amaDebugCount <= 0) return;

    ImFont* font     = ImGui::GetFont();
    float   fontSize = ImGui::GetFontSize();

    // Header line: degree + target count
    char header[64];
    int targeted_count = 0;
    for (int i = 0; i < g_amaDebugCount; i++) {
        if (g_amaDebugEntries[i].targeted) targeted_count++;
    }
    snprintf(header, sizeof(header), "[AMAAll] deg=%d targets=%d", g_amaDebugDeg, targeted_count);

    float baseY = screenHeight - 20.f - (float)(g_amaDebugCount) * 18.f;
    draw->AddText(font, fontSize, ImVec2(8.f, baseY - 18.f),
                  IM_COL32(255, 220, 60, 230), header);

    for (int i = 0; i < g_amaDebugCount; i++) {
        const AMADebugEntry& e = g_amaDebugEntries[i];
        char label[48];
        snprintf(label, sizeof(label), "PID:%04u CAMP:%d", e.playerID, e.camp);
        float y = screenHeight - 20.f - (float)(g_amaDebugCount - 1 - i) * 18.f;
        ImU32 col = e.targeted
            ? IM_COL32(80, 255, 80, 220)
            : IM_COL32(160, 160, 160, 140);
        draw->AddText(font, fontSize, ImVec2(8.f, y), col, label);
    }
}

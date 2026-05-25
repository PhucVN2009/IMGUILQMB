#pragma once
#include <cmath>
#include <limits>

// ============================================================
//  AUTO MÚA FLORENTINO FEATURE
//  Tự động di chuyển đến hoa (passive Florentino) gần địch
//  rồi dùng skill để thu hoa và gây sát thương.
//
//  Yêu cầu: linkerMap[], linkerMapCount, myPlayerCamp, Lactor,
//            get_position, get_objCamp  (từ Hook.h)
// ============================================================

bool  Muaflo = false;           // bật/tắt auto múa
void *ForE   = nullptr;         // flower-enemy đang nhắm tới
void *Req2   = nullptr;         // SkillSlot instance
void *gameInputSingleton = nullptr; // GameInput singleton (captured từ Move hook)

// Function pointer để auto dùng skill
void (*Reqskill )(void *req) = nullptr;
void (*Reqskill2)(void *req) = nullptr;


// ============================================================
//  ActorLinker_ActorDestroy  –  dọn con trỏ khi actor bị huỷ
// ============================================================

void (*old_ActorLinker_ActorDestroy)(void *instance, void *prm);
void  ActorLinker_ActorDestroy      (void *instance, void *prm) {
    if (instance == nullptr) return;
    old_ActorLinker_ActorDestroy(instance, prm);
    if (ForE == instance) ForE = nullptr;
}


// ============================================================
//  ReqInput hook  –  bắt SkillSlot instance khi player dùng skill
// ============================================================

bool (*_ReqInput)(void *ins, bool force);
bool  ReqInput  (void *ins, bool force) {
    if (ins != nullptr) Req2 = ins;
    return _ReqInput(ins, force);
}


// ============================================================
//  Core logic  –  tìm hoa và tính hướng di chuyển
//  Trả về true nếu tìm thấy, đồng thời cập nhật ForE và outDir
// ============================================================

static bool FindFlowerTarget(Vector2 &outDir) {
    if (!Lactor || linkerMapCount == 0) return false;
    Vector3 MP = get_position(Lactor);
    if (MP.x == 0.0f && MP.y == 0.0f && MP.z == 0.0f) return false;

    for (int i = 0; i < linkerMapCount; i++) {
        if (linkerMap[i].camp == myPlayerCamp) continue;
        if (linkerMap[i].linker == nullptr)    continue;

        void   *Player = linkerMap[i].linker;
        Vector3 HP     = get_position(Player);

        const float eps = 0.1f;
        if (fabsf(MP.x - HP.x) < eps && fabsf(MP.z - HP.z) < eps) continue;

        float Dis2 = Vector3::Distance(MP, HP);

        // Y-range đặc trưng của hoa Florentino trong world-space
        bool inFlowerY = (HP.y >= 0.2f && HP.y < 0.24f)
                      || (HP.y >= 0.1f && HP.y <= 0.14f);

        // Lọc toạ độ cố định ngoài biên (vị trí không hợp lệ)
        bool excluded = (HP.x == -50.000004f || HP.x == -45.50004f || HP.x == -41.000004f ||
                         HP.x ==  50.000004f || HP.x ==  45.50004f || HP.x ==  41.000004f);

        if (!inFlowerY || excluded)         continue;
        if (MP.x == HP.x)                  continue;
        if (Dis2 >= 7.0f || Dis2 <= 1.5f)  continue;

        ForE = Player;

        // Dùng skill để thu hoa
        if (Req2 != nullptr) {
            if (Reqskill2) Reqskill2(Req2);
            if (Reqskill)  Reqskill (Req2);
        }

        // Tính vector hướng (XZ plane)
        Vector2 dir2D = { HP.x - MP.x, HP.z - MP.z };

        // Đổi dấu theo phe (camp 2 ngược trục)
        if (get_objCamp && get_objCamp(Lactor) == 2) {
            dir2D.x = -dir2D.x;
            dir2D.y = -dir2D.y;
        }

        float len = sqrtf(dir2D.x * dir2D.x + dir2D.y * dir2D.y);
        if (len > 0.0f) { dir2D.x /= len; dir2D.y /= len; }

        outDir = dir2D;
        return true;
    }

    ForE = nullptr;
    return false;
}


// ============================================================
//  UpdateFrame hook  –  AUTO chủ động gọi di chuyển mỗi frame
//  Hook GameInput.UpdateFrame() – chạy mỗi frame trong trận
// ============================================================

void (*_UpdateFrame)(void *ins);
void  UpdateFrame  (void *ins) {
    _UpdateFrame(ins);
    if (!Muaflo || !_Move) return;
    if (ins != nullptr) gameInputSingleton = ins;

    Vector2 dir;
    if (!FindFlowerTarget(dir)) return;

    // Gọi SendMoveDirection gốc với hướng đã tính
    // start=(0,0), end=(dir*100,dir*100) → game normalize thành direction
    const float dist = 100.0f;
    Vector2 start = {0.0f, 0.0f};
    Vector2 end   = {dir.x * dist, dir.y * dist};
    _Move(ins, start, end);
}


// ============================================================
//  Move hook  –  redirect khi player dùng joystick thủ công
// ============================================================

void (*_Move)(void *ins, Vector2 a, Vector2 b);
void  Move  (void *ins, Vector2 a, Vector2 b) {
    if (ins != nullptr) gameInputSingleton = ins;

    if (!Muaflo || !Lactor || linkerMapCount == 0)
        goto move_default;

    {
        Vector2 dir;
        if (FindFlowerTarget(dir)) {
            // end = start + direction*speed (đúng offset từ tâm joystick)
            const float speed = 300.0f;
            Vector2 endPos = { a.x + dir.x * speed, a.y + dir.y * speed };
            return _Move(ins, a, endPos);
        }
    }

move_default:
    return _Move(ins, a, b);
}

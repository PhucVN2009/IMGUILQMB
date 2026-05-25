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

bool  Muaflo = false;   // bật/tắt auto múa
void *ForE   = nullptr; // địch gần nhất (ActorLinker)
void *Req2   = nullptr; // đối tượng xử lý input skill

// Hai function pointer tới method yêu cầu dùng skill
// Cần hook/resolve trong Init_Thread – tên class tuỳ dump game
void (*Reqskill )(void *req) = nullptr;
void (*Reqskill2)(void *req) = nullptr;


// ============================================================
//  ActorLinker_ActorDestroy  –  dọn con trỏ khi actor bị huỷ
// ============================================================

void (*old_ActorLinker_ActorDestroy)(void *instance);
void  ActorLinker_ActorDestroy      (void *instance) {
    if (instance == nullptr) return;
    old_ActorLinker_ActorDestroy(instance);
    if (ForE == instance) ForE = nullptr;
    if (Req2 == instance) Req2 = nullptr;
}

void (*old_ActorLinker_ActorDestroy2)(void *instance);
void  ActorLinker_ActorDestroy2      (void *instance) {
    if (instance == nullptr) return;
    old_ActorLinker_ActorDestroy2(instance);
    if (ForE == instance) ForE = nullptr;
    if (Req2 == instance) Req2 = nullptr;
}


// ============================================================
//  Hook lấy Req2 từ input handler
//  (hook vào method nhận input skill / UseSkillInput hoặc tương tự)
// ============================================================

void (*_ReqInput)(void *ins, void *req);
void  ReqInput  (void *ins, void *req) {
    if (req != nullptr) Req2 = req;
    _ReqInput(ins, req);
}


// ============================================================
//  Move hook  –  hướng nhân vật đến vị trí hoa gần địch
// ============================================================

void (*_Move)(void *ins, Vector2 a, Vector2 b);
void  Move  (void *ins, Vector2 a, Vector2 b) {
    if (ins == nullptr || !Muaflo || !Lactor || linkerMapCount == 0)
        goto move_default;

    {
        Vector3 MP = get_position(Lactor);

        // Cập nhật ForE = địch gần nhất từ linkerMap
        {
            float minDist = std::numeric_limits<float>::infinity();
            void *nearest = nullptr;
            for (int i = 0; i < linkerMapCount; i++) {
                if (linkerMap[i].camp == myPlayerCamp) continue;
                if (linkerMap[i].linker == nullptr)    continue;
                Vector3 HP = get_position(linkerMap[i].linker);
                float d = Vector3::Distance(MP, HP);
                if (d < minDist) { minDist = d; nearest = linkerMap[i].linker; }
            }
            ForE = nearest;
        }

        if (ForE == nullptr) goto move_default;

        // Duyệt từng địch, tìm người đang đứng tại vị trí có hoa
        for (int i = 0; i < linkerMapCount; i++) {
            if (linkerMap[i].camp == myPlayerCamp) continue;
            if (linkerMap[i].linker == nullptr)    continue;

            void   *Player = linkerMap[i].linker;
            Vector3 HP     = get_position(Player);

            const float eps = 0.1f;
            if (fabsf(MP.x - HP.x) < eps && fabsf(MP.z - HP.z) < eps) continue;

            float Dis2 = Vector3::Distance(MP, HP);

            // Y-range đặc trưng của hoa Florentino trong world-space
            bool inFlowerY = (HP.y >= 0.2f  && HP.y < 0.24f)
                          || (HP.y >= 0.1f  && HP.y <= 0.14f);

            // Lọc toạ độ cố định ngoài biên (vị trí không hợp lệ)
            bool excluded = (HP.x == -50.000004f || HP.x == -45.50004f || HP.x == -41.000004f ||
                             HP.x ==  50.000004f || HP.x ==  45.50004f || HP.x ==  41.000004f);

            if (!inFlowerY || excluded) continue;
            if (MP.x == HP.x)          continue;
            if (Dis2 >= 7.0f || Dis2 <= 1.5f) continue;

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

            const float speed = 300.0f;
            Vector2 moveDir = { dir2D.x * speed, dir2D.y * speed };
            return _Move(ins, a, moveDir);
        }
    }

move_default:
    return _Move(ins, a, b);
}

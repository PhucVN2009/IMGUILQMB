#pragma once
#include <string>
#include <vector>
#include <utility>

// ============================================================
//  SKIN UNLOCK + BUTTON UNLOCK FEATURE
// ============================================================

bool unlockskin   = false;
bool unlockbutton = false;

int heroid  = 0, skinid  = 0;  // current skin being worn (display only)
int heroid2 = 0, skinid2 = 0;  // button unlock IDs

// Button unlock mode: 0 = Auto sync từ skin đang dùng, 1 = Custom ID tay
static int buttonMode = 0;

// ---- Network protocol class (AovTdr.dll / CSProtocol) ----

enum class TdrErrorType {};

namespace CSProtocol {

    class COMDT_HERO_COMMON_INFO {
    public:
        uint32_t getdwHeroID() {
            if (this == nullptr) return 0;
            static uintptr_t off = 0;
            if (!off) off = GetFieldOffset(OBFUSCATE("AovTdr.dll"), OBFUSCATE("CSProtocol"),
                                           OBFUSCATE("COMDT_HERO_COMMON_INFO"), OBFUSCATE("dwHeroID"));
            if (!off) return 0;
            return *(uint32_t *)((uint64_t)this + off);
        }

        uint16_t getwSkinID() {
            if (this == nullptr) return 0;
            static uintptr_t off = 0;
            if (!off) off = GetFieldOffset(OBFUSCATE("AovTdr.dll"), OBFUSCATE("CSProtocol"),
                                           OBFUSCATE("COMDT_HERO_COMMON_INFO"), OBFUSCATE("wSkinID"));
            if (!off) return 0;
            return *(uint16_t *)((uint64_t)this + off);
        }

        void setdwHeroID(uint32_t val) {
            if (this == nullptr) return;
            static uintptr_t off = 0;
            if (!off) off = GetFieldOffset(OBFUSCATE("AovTdr.dll"), OBFUSCATE("CSProtocol"),
                                           OBFUSCATE("COMDT_HERO_COMMON_INFO"), OBFUSCATE("dwHeroID"));
            if (!off) return;
            *(uint32_t *)((uint64_t)this + off) = val;
        }

        void setwSkinID(uint16_t val) {
            if (this == nullptr) return;
            static uintptr_t off = 0;
            if (!off) off = GetFieldOffset(OBFUSCATE("AovTdr.dll"), OBFUSCATE("CSProtocol"),
                                           OBFUSCATE("COMDT_HERO_COMMON_INFO"), OBFUSCATE("wSkinID"));
            if (!off) return;
            *(uint16_t *)((uint64_t)this + off) = val;
        }
    };

    // ---- Persistent skin state ----
    struct saveData {
        static uint32_t heroId;
        static uint16_t skinId;
        static bool     enable;
        static std::vector<std::pair<COMDT_HERO_COMMON_INFO *, uint16_t>> arrayUnpackSkin;

        static void setData(uint32_t hId, uint16_t sId) { heroId = hId; skinId = sId; }
        static void setEnable(bool eb)                  { enable = eb; }
        static uint32_t getHeroId()                     { return heroId; }
        static uint16_t getSkinId()                     { return skinId; }
        static bool     getEnable()                     { return enable; }

        static void resetArrayUnpackSkin() {
            if (arrayUnpackSkin.empty()) return;
            for (const auto &s : arrayUnpackSkin)
                if (s.first) s.first->setwSkinID(s.second);
            arrayUnpackSkin.clear();
        }
    };

    uint32_t saveData::heroId  = 0;
    uint16_t saveData::skinId  = 0;
    bool     saveData::enable  = false;
    std::vector<std::pair<COMDT_HERO_COMMON_INFO *, uint16_t>> saveData::arrayUnpackSkin;

} // namespace CSProtocol


// ============================================================
//  HOOK 1 – Unpack  (inject skin ID vào gói mạng khi parse)
// ============================================================

static void hook_unpack(CSProtocol::COMDT_HERO_COMMON_INFO *inst) {
    if (!CSProtocol::saveData::enable) return;
    uint32_t hid = inst->getdwHeroID();
    if (hid == 0 || hid != CSProtocol::saveData::heroId) return;
    if (CSProtocol::saveData::skinId == 0) return;
    CSProtocol::saveData::arrayUnpackSkin.emplace_back(inst, inst->getwSkinID());
    inst->setwSkinID(CSProtocol::saveData::skinId);
}

TdrErrorType (*_unpack)(CSProtocol::COMDT_HERO_COMMON_INFO *, void *, int32_t);
TdrErrorType  unpack  (CSProtocol::COMDT_HERO_COMMON_INFO *inst, void *tdr, int32_t cutVer) {
    TdrErrorType res = _unpack(inst, tdr, cutVer);
    if (unlockskin) hook_unpack(inst);
    return res;
}


// ============================================================
//  HOOK 2 – IsCanUseSkin  (luôn cho phép dùng mọi skin)
// ============================================================

bool (*_IsCanUseSkin)(void *, uint32_t, uint32_t);
bool  IsCanUseSkin  (void *instance, uint32_t heroId, uint32_t sId) {
    if (unlockskin) {
        if (heroId != 0) CSProtocol::saveData::setData(heroId, (uint16_t)sId);
        return true;
    }
    return _IsCanUseSkin(instance, heroId, sId);
}


// ============================================================
//  HOOK 3 – IsHaveHeroSkin  (luôn trả về true khi unlock)
// ============================================================

bool (*_IsHaveHeroSkin)(void *, uint32_t, uint32_t, bool);
bool  IsHaveHeroSkin  (void *instance, uint32_t heroId, uint32_t sId, bool inclTimeLimited) {
    if (unlockskin) return true;
    return _IsHaveHeroSkin(instance, heroId, sId, inclTimeLimited);
}


// ============================================================
//  HOOK 4 – WearSkinId  (trả về skin ID đã lưu khi mặc)
// ============================================================

uint32_t (*_WearSkinId)(void *, uint32_t);
uint32_t  WearSkinId  (void *instance, uint32_t heroId) {
    if (unlockskin) {
        CSProtocol::saveData::setEnable(true);
        return (uint32_t)CSProtocol::saveData::getSkinId();
    }
    return _WearSkinId(instance, heroId);
}


// ============================================================
//  HOOK 5 – SetSkin + RefreshHeroPanel  (cập nhật UI skin)
// ============================================================

void *(*_RefreshHeroPanel)(void *, bool, bool, bool);
void (*_Setskin)(void *, uint32_t, uint32_t, bool);
void  Setskin  (void *ins, uint32_t hId, uint32_t sId, bool isShareSkin) {
    if (unlockskin && ins != nullptr && sId != 0 && _RefreshHeroPanel)
        _RefreshHeroPanel(ins, true, true, true);
    _Setskin(ins, hId, sId, isShareSkin);
}


// ============================================================
//  HOOK 6 – IsOpen  (mở khóa tất cả nút bấm skin)
// ============================================================

bool (*_IsOpen)();
bool  IsOpen  () {
    if (unlockbutton) return true;
    return _IsOpen();
}


// ============================================================
//  HOOK 7 – Buttonid  (trả về ID nút bấm skin)
//
//  Mode 0 – Auto : tự lấy heroId/skinId từ saveData
//  Mode 1 – Custom: dùng heroid2 / skinid2 nhập tay
// ============================================================

int (*_Buttonid)();
int  Buttonid  () {
    if (unlockbutton) {
        if (buttonMode == 0) {
            // Auto: đồng bộ từ skin đang dùng
            uint32_t hId = CSProtocol::saveData::getHeroId();
            uint16_t sId = CSProtocol::saveData::getSkinId();
            if (hId != 0 && sId != 0) {
                heroid2 = (int)hId;
                skinid2 = (int)sId;
            }
        }
        if (heroid2 != 0 && skinid2 != 0) {
            std::string combined = std::to_string(heroid2) + std::to_string(skinid2);
            return std::stoi(combined);
        }
    }
    return _Buttonid();
}

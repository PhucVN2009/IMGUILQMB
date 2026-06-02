#pragma once

// ============================================================
//  HIDE MATCH HISTORY  –  Chặn lưu lịch sử trận đấu
//
//  Hooks:
//   1. OnGameOverEvent      – chặn xử lý kết thúc trận (MsgID 1085)
//   2. SendBattleResult     – chặn gửi kết quả lên server
//   3. SaveBattleRecord     – chặn lưu replay/record trận đấu
//   4. SetHasNewFightRecord – chặn đánh dấu có record mới
//   5. OnHeroInfoUpdate     – chặn cập nhật thông tin hero sau trận (MsgID 1810)
// ============================================================

bool hide_history = false;


// ---- 1. OnGameOverEvent ----
// LobbyMsgHandler.OnGameOverEvent(CSPkg msg) [MessageHandlerRelaySvr(1085)]
// Xử lý khi trận đấu kết thúc → lưu kết quả, lịch sử
void (*_OnGameOverEvent)(void *ins, void *msg);
void  OnGameOverEvent  (void *ins, void *msg) {
    if (!hide_history) _OnGameOverEvent(ins, msg);
}


// ---- 2. SendBattleResult ----
// LobbyMsgHandler.SendBattleResult(int iBattleResult)
// Gửi kết quả trận đấu lên server (win/lose/surrender)
void (*_SendBattleResult)(void *ins, int result);
void  SendBattleResult  (void *ins, int result) {
    if (!hide_history) _SendBattleResult(ins, result);
}


// ---- 3. SaveBattleRecord ----
// GameReplaySystem.SaveBattleRecord(out string desc)
// Lưu replay / bản ghi trận đấu vào bộ nhớ client
bool (*_SaveBattleRecord)(void *ins, void *desc);
bool  SaveBattleRecord  (void *ins, void *desc) {
    if (hide_history) return false;
    return _SaveBattleRecord(ins, desc);
}


// ---- 4. SetHasNewFightRecord ----
// CPlayerInfoSystems.SetHasNewFightRecord(bool have)
// Đánh dấu có record trận đấu mới (hiển thị dấu chấm đỏ ở lịch sử)
void (*_SetHasNewFightRecord)(void *ins, bool have);
void  SetHasNewFightRecord  (void *ins, bool have) {
    if (!hide_history) _SetHasNewFightRecord(ins, have);
}


// ---- 5. OnHeroInfoUpdate ----
// LobbyMsgHandler.OnHeroInfoUpdate(CSPkg msg) [MessageHandler(1810)]
// Cập nhật thông tin hero sau trận đấu (điểm MMR, win/lose count)
void (*_OnHeroInfoUpdate)(void *ins, void *msg);
void  OnHeroInfoUpdate  (void *ins, void *msg) {
    if (!hide_history) _OnHeroInfoUpdate(ins, msg);
}

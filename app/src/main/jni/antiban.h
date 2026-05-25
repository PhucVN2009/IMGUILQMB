#pragma once

// ============================================================
//  ANTIBAN BYPASS  –  Bypass client-side anti-cheat reactions
//
//  Hooks:
//   1. OnHashCheckRsp     – ngăn client react khi server báo hash mismatch
//   2. ModifyBantimeInfo  – chặn lệnh ban realtime từ server (MsgID 1043)
//   3. On_GetViolationNotice – chặn thông báo vi phạm (MsgID 20500)
//   4. OnUpload           – chặn server ra lệnh upload log (MsgID 1288)
//   5. SetBanTimeInfo     – ngăn trạng thái ban được lưu vào client
//   6. OnActorAbnormalMove – suppress abnormal move event (teleport/speed detect)
// ============================================================

bool antiban = false;


// ---- 1. OnHashCheckRsp ----
// LSynchrReport / LFrameSyncRelaySvrMsgHandler / SynchrReport
// Client nhận verdict từ server: dwIsSelfNE=1 → game tự kick/upload log
// → hook để không làm gì cả
void (*_OnHashCheckRsp)(void *ins, void *pkg);
void  OnHashCheckRsp  (void *ins, void *pkg) {
    if (!antiban) _OnHashCheckRsp(ins, pkg);
}


// ---- 2. ModifyBantimeInfo ----
// IDIPSys.ModifyBantimeInfo [MessageHandler(1043)]
// Server gửi lệnh thay đổi trạng thái ban của tài khoản theo realtime
void (*_ModifyBantimeInfo)(void *ins, void *msg);
void  ModifyBantimeInfo  (void *ins, void *msg) {
    if (!antiban) _ModifyBantimeInfo(ins, msg);
}


// ---- 3. On_GetViolationNotice ----
// IDIPSys.On_GetViolationNotice [MessageHandler(20500)]
// Nhận thông báo vi phạm từ server → popup "tài khoản bị phạt"
void (*_On_GetViolationNotice)(void *ins, void *msg);
void  On_GetViolationNotice  (void *ins, void *msg) {
    if (!antiban) _On_GetViolationNotice(ins, msg);
}


// ---- 4. OnUpload ----
// LFrameSyncRelaySvrMsgHandler.OnUpload [MessageHandlerRelaySvr(1288)]
// Server ra lệnh client upload log trận đấu để phân tích forensic
void (*_OnUpload)(void *ins, void *pkg);
void  OnUpload  (void *ins, void *pkg) {
    if (!antiban) _OnUpload(ins, pkg);
}


// ---- 5. SetBanTimeInfo ----
// IDIPSys.SetBanTimeInfo(COM_ACNT_BANTIME_TYPE, uint)
// Lưu thời điểm hết hạn ban vào client state
void (*_SetBanTimeInfo)(void *ins, int type, uint32_t expiry);
void  SetBanTimeInfo  (void *ins, int type, uint32_t expiry) {
    if (!antiban) _SetBanTimeInfo(ins, type, expiry);
}


// ---- 6. OnActorAbnormalMove ----
// LActorAbnormalMoveEventNodeRuntime.OnActorAbnormalMove
// Phát hiện di chuyển bất thường (teleport, xuyên tường, speed hack)
void (*_OnActorAbnormalMove)(void *ins, void *prm);
void  OnActorAbnormalMove  (void *ins, void *prm) {
    if (!antiban) _OnActorAbnormalMove(ins, prm);
}

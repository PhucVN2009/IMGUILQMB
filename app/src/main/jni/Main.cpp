#include <EGL/egl.h>
#include <GLES3/gl3.h>
#include "Includes/obfuscate.h"
#include "Includes/Logger.h"
#include "Includes/Macros.h"
#include "Includes/Utils.h"
#include "TuanMeta/Call_Me.h"
#include "UnityResolve.h"
#include "TouchInput.h"
#include "Hook.h"
#include "SaveLoadMenu.h"
#include <sys/stat.h>
#include <ctime>
#include <iostream>
#include <fstream>
#include <chrono>
#include <iomanip>
#include "login.h"
#include "LagGame.h"
#include "LagSpam.h"

static bool keyLoaded = true;
static bool isLogin = true;
static bool showLoginSuccess = false;
static float loginSuccessTimer = 0.0f;
static int Type = 0;
static float progress = 1.0f; 
static auto startTime = std::chrono::steady_clock::now();

void ShowLoginSuccess()
{
    ImGui::Begin("Login Success", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize);

    ImGui::TextColored(ImVec4(0, 1, 0, 1), "Đăng nhập thành công");
    ImGui::Text("Chào mừng đến với HAX - LQMB");

    auto currentTime = std::chrono::steady_clock::now();
    std::chrono::duration<float> elapsedTime = currentTime - startTime;

    float countdownTime = 7.0f;
    progress = 1.0f - (elapsedTime.count() / countdownTime);

    if (progress < 0.0f)
        progress = 0.0f;

    ImGui::PushStyleColor(ImGuiCol_PlotHistogram, ImVec4(0, 1, 0, 1));
    ImGui::ProgressBar(progress, ImVec2(200, 5));
    ImGui::PopStyleColor();

    ImGui::End();
}

EGLBoolean (*orig_eglSwapBuffers)(EGLDisplay dpy, EGLSurface surface);

EGLBoolean _eglSwapBuffers(EGLDisplay dpy, EGLSurface surface) {

    eglQuerySurface(dpy, surface, EGL_WIDTH, &glWidth);
    eglQuerySurface(dpy, surface, EGL_HEIGHT, &glHeight);

    if (glWidth > 0 && glHeight > 0) {
        if (Width == 0) Width = glWidth;
        if (Height == 0) Height = glHeight;
    }

    if (!setup) {
        ImGui::CreateContext();
        ImGuiIO &io = ImGui::GetIO();
        DrawImGuiStyle();

        static const ImWchar icons_ranges[] = {0xe000, 0xf8ff, 0};
        ImFontConfig icons_config;
        icons_config.MergeMode = true;
        icons_config.PixelSnapH = true;
        icons_config.OversampleH = 2.3;
        icons_config.OversampleV = 2.3;

        io.Fonts->AddFontFromMemoryTTF(const_cast<std::uint8_t *>(Custom), sizeof(Custom), 25.f, NULL, io.Fonts->GetGlyphRangesVietnamese());
        io.Fonts->AddFontFromMemoryCompressedTTF(font_awesome_data, font_awesome_size, 25.0f, &icons_config, icons_ranges);

        io.KeyMap[ImGuiKey_UpArrow] = 19;
        io.KeyMap[ImGuiKey_DownArrow] = 20;
        io.KeyMap[ImGuiKey_LeftArrow] = 21;
        io.KeyMap[ImGuiKey_RightArrow] = 22;
        io.KeyMap[ImGuiKey_Enter] = 66;
        io.KeyMap[ImGuiKey_Backspace] = 67;
        io.KeyMap[ImGuiKey_Escape] = 111;
        io.KeyMap[ImGuiKey_Delete] = 112;
        io.KeyMap[ImGuiKey_Home] = 122;
        io.KeyMap[ImGuiKey_End] = 123;

        ImGui_ImplOpenGL3_Init(OBFUSCATE("#version 300 es"));
        ImGui::GetStyle().ScaleAllSizes(3.0f);
        GetIconHero();
        LoadSaveLoadMenu();
        setup = true;
    }

    if (SetResolution && Width != glWidth) {
        SetResolution(Width, Height, true);
    }

    ImGuiIO &io = ImGui::GetIO();
    static bool WantTextInputLast = false;
    if (io.WantTextInput && !WantTextInputLast) ShowSoftKeyboardInput();
    WantTextInputLast = io.WantTextInput;

    LagGame_Update();
    LagSpam_Update();

    ImGui_ImplOpenGL3_NewFrame();
    ImGui_ImplAndroid_NewFrame(glWidth, glHeight);
    ImGui::NewFrame();
    TouchInput::Update();

    static bool AutoLogin = false;
    static std::string err;
    if (!isLogin) {
        ImGui::OpenPopup(OBFUSCATE("##LoginPage"));
        ImVec2 center = ImGui::GetMainViewport()->GetCenter();
        ImGui::SetNextWindowPos(center, ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
        if (ImGui::BeginPopupModal(OBFUSCATE("##LoginPage"), NULL, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove)) {
            ImGui::Text(OBFUSCATE("Please Login Key (Lần Đầu Login Sẽ Bị Văng)"));
            ImGui::PushItemWidth(-1);
            ImGui::InputText(OBFUSCATE("##key"), s, sizeof s);
                 if (!keyLoaded) {
                loadKey();
                keyLoaded = true;
                
            }
            ImGui::PopItemWidth();
            ImGui::PushItemWidth(-1);
            if (ImGui::Button(OBFUSCATE("Dán Key"), ImVec2(ImGui::GetWindowContentRegionWidth(), 0))) {
                auto key = getClipboard();
                strncpy(s, key.c_str(), sizeof s);
            }
            ImGui::PopItemWidth();
            ImGui::PushItemWidth(-1);
            if (ImGui::Button(OBFUSCATE("Đăng Nhập"), ImVec2(ImGui::GetWindowContentRegionWidth(), 0)) || (AutoLogin && err.empty())) {
                
                err = Login(s);
                if (err == "OK") {
                    isLogin = bValid && g_Auth == g_Token;
					saveKey();
                    showLoginSuccess = true;
                    loginSuccessTimer = 0.0f; // Reset lại bộ đếm thời gian khi đăng nhập thành công
                }
            }
            ImGui::Text(OBFUSCATE("Ấn Tăng/Giảm Âm Lượng Để Hiện/Ẩn Menu"));
            if (!err.empty() && err != std::string(OBFUSCATE("OK"))) {
                ImGui::Text(OBFUSCATE("Error: %s"), err.c_str());
            }
            ImGui::EndPopup();
        }
    } else {
      /*  if (!g_Token.empty() && !g_Auth.empty() && g_Token == g_Auth) {*/
            DrawESP(ImGui::GetBackgroundDrawList());
            DrawAutoMoveAllDebug(ImGui::GetBackgroundDrawList(), (float)glWidth, (float)glHeight);
            if (ShowMenu) {
                ImGui::OpenPopup(OBFUSCATE("##MenuMod"));
                ImGui::SetNextWindowSize(ImVec2(900, 0));
                ImGui::SetNextWindowPos(ImGui::GetMainViewport()->GetCenter(), ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
                if (ImGui::BeginPopupModal(OBFUSCATE("##MenuMod"), NULL, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove)) {
                    ImGuiWindow* window = ImGui::GetCurrentWindow();
                    ImDrawList* drawList = window->DrawList;
                    ImVec2 windowPos = window->Pos;
                    ImVec2 windowSize = window->Size;
                    ImVec2 textSize = ImGui::CalcTextSize("ESP MOD " __DATE__ " " __TIME__);
                    ImVec2 textPos = ImVec2(windowPos.x + (windowSize.x - textSize.x) * 0.5f, windowPos.y + 24.0f);
                    drawList->AddText(textPos, IM_COL32_WHITE, "ESP MOD " __DATE__ " " __TIME__);

                    ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(6.f, 6.f));
                    ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, 300.0f);
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(255, 0, 0, 255));
                    if (ImGui::Button(OBFUSCATE("##CloseMenu"), ImVec2(24, 24))) {
                        ShowMenu = false;
                    }
                    ImGui::PopStyleColor();
                    ImGui::PopStyleVar();
                    ImGui::PopStyleVar();

                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();

                    ImGui::Columns(2, NULL, false);
                    ImGui::SetColumnOffset(1, 200.0f);

                    ImGui::Text(OBFUSCATE("LÂM MOD LQ 2.3"));
                    ImGui::Text(OBFUSCATE("FPS: %.1f"), ImGui::GetIO().Framerate);

                    ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 1 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    if (ImGui::Button(OBFUSCATE(ICON_FA_EYE " Visual"), ImVec2(170, 60))) TabMenu = 1;
                    ImGui::PopStyleColor();

                    ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 2 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    if (ImGui::Button(OBFUSCATE(ICON_FA_CAMERA " Camera"), ImVec2(170, 60))) TabMenu = 2;
                    ImGui::PopStyleColor();

                    ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 3 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    if (ImGui::Button(OBFUSCATE(ICON_FA_MICROCHIP " Memory"), ImVec2(170, 60))) TabMenu = 3;
                ImGui::PopStyleColor();

                ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 4 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                if(ImGui::Button(OBFUSCATE(ICON_FA_WRENCH " Setting"), ImVec2(170, 60))) TabMenu = 4;
                ImGui::PopStyleColor();

                ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 5 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                if(ImGui::Button(OBFUSCATE(ICON_FA_USERS " About"), ImVec2(170, 60))) TabMenu = 5;
                ImGui::PopStyleColor();

                ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 7 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                if(ImGui::Button(OBFUSCATE(ICON_FA_WRENCH " Debug"), ImVec2(170, 60))) TabMenu = 7;
                ImGui::PopStyleColor();

                ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 9 ? ImVec4(0.6f,0.1f,0.1f,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                if(ImGui::Button(OBFUSCATE(ICON_FA_BOLT " Hack Lag"), ImVec2(170, 60))) TabMenu = 9;
                ImGui::PopStyleColor();

                ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 10 ? ImVec4(0.1f,0.45f,0.6f,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                if(ImGui::Button(OBFUSCATE(ICON_FA_LOCATION_ARROW " Toa Do"), ImVec2(170, 60))) TabMenu = 10;
                ImGui::PopStyleColor();

                ImGui::NextColumn();

                if(TabMenu == 1){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab1"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    ImGui::BeginTable(OBFUSCATE("##split_table1"), 2);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Enable ESP"), &ESP.Enable);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Line"), &ESP.Line);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Box"), &ESP.Box);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Cooldown"), &ESP.Cooldown);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP HP"), &ESP.HP);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Map"), &ESP.Map);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Visible Check"), &ESP.VisibleCheck);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Show Player Info"), &ESP.PlayerInfo);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Alert"), &ESP.Alert);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Show Hero Image"), &ESP.HeroImage);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Minions"), &ESP.Minions);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("ESP Ultimate"), &ESP.Ultimate);
                    ImGui::EndTable();

                    ImGui::EndChild();
                }

                if(TabMenu == 2){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab2"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    ImGui::Text(OBFUSCATE("Cam Xa:"));
                    ImGui::Checkbox(OBFUSCATE("##EnableCamV1"), &Camera.V1.Enable); ImGui::SameLine(); ImGui::PushItemWidth(-1); ImGui::SliderInt(OBFUSCATE("##SliderCameraV1"), &Camera.V1.Value, 1, 100); ImGui::PopItemWidth();
                    ImGui::EndChild();
                }

                if(TabMenu == 3){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab3"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    ImGui::BeginTable(OBFUSCATE("##split_table2"), 2);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Hack Map"), &MemoryHack.Map);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Hiện Ulti"), &MemoryHack.Unti);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Hiện Tên Cấm Chọn"), &MemoryHack.NameBanPick);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Hiện Avatar"), &MemoryHack.Avatar);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Hiện Lịch Sử Đấu"), &MemoryHack.History);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Hiện Hồi Chiêu"), &MemoryHack.ShowCooldown);
                    ImGui::EndTable();

                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Aimbot Menu"));
                    ImGui::BeginTable(OBFUSCATE("##split_table3"), 2);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Aimbot C2 Elsu"), &MemoryHack.AutoTrungElsu);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Ẩn Tia Elsu"), &MemoryHack.HideLineElsu);
                    ImGui::EndTable();
/*
                    ImGui::Spacing();

                    ImGui::Checkbox(OBFUSCATE("Bật Aim Chiêu 1"), &MemoryHack.Aimbot.C1);
                    ImGui::PushItemWidth(-1);
                    ImGui::SliderFloat(OBFUSCATE("##AimBotC1"), &MemoryHack.Aimbot.Value_1, 0.f, 100.f);
                    ImGui::PopItemWidth();

                    ImGui::Checkbox(OBFUSCATE("Bật Aim Chiêu 2"), &MemoryHack.Aimbot.C2);
                    ImGui::PushItemWidth(-1);
                    ImGui::SliderFloat(OBFUSCATE("##AimBotC2"), &MemoryHack.Aimbot.Value_2, 0.f, 100.f);
                    ImGui::PopItemWidth();

                    ImGui::Checkbox(OBFUSCATE("Bật Aim Chiêu 3"), &MemoryHack.Aimbot.C3);
                    ImGui::PushItemWidth(-1);
                    ImGui::SliderFloat(OBFUSCATE("##AimBotC3"), &MemoryHack.Aimbot.Value_3, 0.f, 100.f);
                    ImGui::PopItemWidth();
*/

                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    if (g_forceTrainingTeleport)
                        ImGui::TextColored(ImVec4(0.2f,1,0.8f,1), OBFUSCATE(ICON_FA_MAP_MARKER " Nut Di Chuyen Minimap [DANG BAT]"));
                    else
                        ImGui::TextColored(ImVec4(0.5f,0.9f,0.8f,1), OBFUSCATE(ICON_FA_MAP_MARKER " Nut Di Chuyen Minimap"));
                    ImGui::Separator();
                    ImGui::TextColored(ImVec4(1,0.7f,0,1),
                        OBFUSCATE("Hien thi nut tele minimap – hoat dong ca PvP va Dau Luyen"));
                    ImGui::TextColored(
                        orig_UpdateTeleportBtnStatus ? ImVec4(0.2f,1,0.4f,1) : ImVec4(1,0.4f,0.2f,1),
                        OBFUSCATE("Hook: %s"),
                        orig_UpdateTeleportBtnStatus ? "OK" : "X (chua resolve)");
                    ImGui::Spacing();
                    ImGui::PushStyleColor(ImGuiCol_Button,
                        g_forceTrainingTeleport ? ImVec4(0.1f,0.5f,0.5f,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.2f,0.7f,0.7f,1));
                    if (ImGui::Button(
                            g_forceTrainingTeleport
                                ? OBFUSCATE(ICON_FA_MAP_MARKER " [BAT] Minimap Teleport Btn")
                                : OBFUSCATE(ICON_FA_MAP_MARKER " [TAT] Bat Minimap Teleport Btn"),
                            ImVec2(-1, 44))) {
                        g_forceTrainingTeleport = !g_forceTrainingTeleport;
                    }
                    ImGui::PopStyleColor(2);

                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    ImGui::TextColored(
                        g_noSaveQuit ? ImVec4(1,0.3f,0.3f,1) : ImVec4(0.9f,0.9f,0.9f,1),
                        OBFUSCATE(ICON_FA_TIMES_CIRCLE " Thoat Tran Khong Luu Lich Su"));
                    ImGui::Separator();
                    ImGui::TextColored(ImVec4(1,0.7f,0,1),
                        OBFUSCATE("Nhan nut – tran ket thuc, ban ve sanh, khong luu lich su dau"));
                    ImGui::TextColored(
                        orig_SendBattleResult ? ImVec4(0.2f,1,0.4f,1) : ImVec4(1,0.4f,0.2f,1),
                        OBFUSCATE("Hook SendBattleResult: %s"),
                        orig_SendBattleResult ? "OK" : "X");
                    ImGui::TextColored(
                        orig_HandleSingleGameSettle ? ImVec4(0.2f,1,0.4f,1) : ImVec4(1,0.4f,0.2f,1),
                        OBFUSCATE("Hook HandleSingleGameSettle: %s"),
                        orig_HandleSingleGameSettle ? "OK" : "X");
                    ImGui::TextColored(
                        lfsbl_DoFightOver_fn ? ImVec4(0.2f,1,0.4f,1) : ImVec4(1,0.4f,0.2f,1),
                        OBFUSCATE("DoFightOver fn: %s"),
                        lfsbl_DoFightOver_fn ? "OK" : "X");
                    ImGui::Spacing();
                    ImGui::PushStyleColor(ImGuiCol_Button,
                        g_noSaveQuit ? ImVec4(0.5f,0.1f,0.1f,1)
                                     : ImVec4(0.7f,0.15f,0.15f,1));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.85f,0.2f,0.2f,1));
                    if (ImGui::Button(
                            g_noSaveQuit
                                ? OBFUSCATE(ICON_FA_TIMES_CIRCLE " [DANG XU LY] Cho ket thuc...")
                                : OBFUSCATE(ICON_FA_TIMES_CIRCLE " Thoat Tran Khong Luu"),
                            ImVec2(-1, 48))) {
                        if (!g_noSaveQuit) {
                            g_noSaveQuit = true;
                            void* logic = get_ActiveBattleLogic_fn ? get_ActiveBattleLogic_fn() : nullptr;
                            __android_log_print(ANDROID_LOG_INFO, "NoSaveQuit",
                                "Button pressed: logic=%p fn=%p", logic, lfsbl_DoFightOver_fn);
                            if (lfsbl_DoFightOver_fn && logic)
                                lfsbl_DoFightOver_fn(logic, false);
                        }
                    }
                    ImGui::PopStyleColor(2);

                    ImGui::EndChild();
                }


                  if(TabMenu == 6){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab6"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

ImGui::Combo("##ddd", (int*)&Type, "Tắt\0Win\0Lose\0");
    
     ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1, 1, 1, 1));
     ImGui::TextWrapped("Chọn Win xong rồi tắt để không văng");
     ImGui::PopStyleColor();
     switch (Type)
        {
        case 0: win = false; lose = false; break;
        case 1: win = true; lose = false; break;
        case 2: win = false; lose = false; break;
        }

                    ImGui::EndChild();
                }


                if(TabMenu == 4){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab4"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    SaveLoad_GUI();
                    ImGui::Checkbox(OBFUSCATE("Ẩn Icon Menu"), &HideIcon);

                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Minimap Offset"));
                    ImGui::SliderFloat(OBFUSCATE("posX"), &minimapPosX, 0.0f, 150.0f);
                    ImGui::SliderFloat(OBFUSCATE("posY"), &minimapPosY, 0.0f, 250.0f);
                    ImGui::SliderFloat(OBFUSCATE("scale"), &minimapScale, 1.0f, 6.0f);
                    if (ImGui::Button(OBFUSCATE("Reset Minimap"), ImVec2(-1, 0))) {
                        minimapPosX = 41.5f;
                        minimapPosY = 75.5f;
                        minimapScale = 3.1f;
                    }
                    ImGui::Spacing();
                    ImGui::SliderFloat(OBFUSCATE("ESP Depth Ref"), &g_espDepthRef, 10.0f, 200.0f);
                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("ESP Ultimate"));
                    ImGui::SliderFloat(OBFUSCATE("Ult Scale"), &g_ultScale, 0.5f, 3.0f);
                    ImGui::SliderFloat(OBFUSCATE("Ult X"), &g_ultPosX, -500.0f, 500.0f);
                    ImGui::SliderFloat(OBFUSCATE("Ult Y"), &g_ultPosY, 0.0f, 500.0f);
                    ImGui::Text("MyCamp: %d (auto)", myPlayerCamp);

                    ImGui::EndChild();
                }

                if(TabMenu == 5){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab5"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    ImGui::Text(OBFUSCATE("Version: 2.3 Release - Patch: 1.62.1.4"));
                    ImGui::Text(OBFUSCATE("Auto-Update via UnityInline.h"));

                    ImGui::EndChild();
                }


                // ═══════════════════════════════════════════════════════
                // TAB 9 – HACK LAG (đầy đủ tất cả tính năng)
                // ═══════════════════════════════════════════════════════
                if(TabMenu == 9){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab9"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    // ── SECTION 1: LAG ENGINE ──────────────────────────
                    if (LagGame.enable)
                        ImGui::TextColored(ImVec4(1,0.15f,0.15f,1), OBFUSCATE(ICON_FA_BOLT " LAG ENGINE [DANG BAT]"));
                    else
                        ImGui::TextColored(ImVec4(1,0.75f,0,1),     OBFUSCATE(ICON_FA_BOLT " Lag Engine"));
                    ImGui::Separator();

                    // Enable toggle
                    ImGui::PushStyleColor(ImGuiCol_CheckMark, LagGame.enable ? ImVec4(1,0.15f,0.15f,1) : ImVec4(0.3f,1,0.3f,1));
                    ImGui::Checkbox(OBFUSCATE("##LagEngEn"), &LagGame.enable);
                    ImGui::PopStyleColor();
                    ImGui::SameLine();
                    ImGui::Text(LagGame.enable ? OBFUSCATE("Dang lag – tat de restore") : OBFUSCATE("Bat de lam lag ca 2 team"));

                    // TimeScale
                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Time Scale  (thap = lag manh):"));
                    ImGui::PushStyleColor(ImGuiCol_SliderGrab, ImVec4(1,0.25f,0.25f,1));
                    ImGui::PushItemWidth(-1);
                    ImGui::SliderFloat(OBFUSCATE("##LagTS9"), &LagGame.timeScale, 0.05f, 1.0f);
                    ImGui::PopItemWidth();
                    ImGui::PopStyleColor();
                    {
                        float pct = (1.0f - LagGame.timeScale) * 100.f;
                        if      (pct >= 85.f) ImGui::TextColored(ImVec4(1,0,0,1),      OBFUSCATE("  Muc do: %.0f%%  [CHET LAG]"), pct);
                        else if (pct >= 60.f) ImGui::TextColored(ImVec4(1,0.45f,0,1),  OBFUSCATE("  Muc do: %.0f%%  [Rat nang]"), pct);
                        else if (pct >= 30.f) ImGui::TextColored(ImVec4(1,1,0,1),      OBFUSCATE("  Muc do: %.0f%%  [Nhe]"), pct);
                        else                  ImGui::TextColored(ImVec4(0.4f,1,0.4f,1),OBFUSCATE("  Muc do: %.0f%%  [Khong dang ke]"), pct);
                    }

                    // FPS Limiter
                    ImGui::Spacing();
                    ImGui::Checkbox(OBFUSCATE("Gioi han FPS"), &LagGame.limitFPS);
                    if (LagGame.limitFPS) {
                        ImGui::SameLine();
                        ImGui::PushItemWidth(140);
                        ImGui::SliderInt(OBFUSCATE("##LagFPS9"), &LagGame.targetFPS, 1, 30);
                        ImGui::PopItemWidth();
                        ImGui::SameLine();
                        ImGui::Text(OBFUSCATE("FPS"));
                    }

                    // Physics slowdown
                    ImGui::Checkbox(OBFUSCATE("Lam cham Physics"), &LagGame.slowPhysics);
                    if (LagGame.slowPhysics) {
                        ImGui::SameLine();
                        ImGui::Text(OBFUSCATE("fixedDelta:"));
                        ImGui::SameLine();
                        ImGui::PushItemWidth(140);
                        ImGui::SliderFloat(OBFUSCATE("##LagFD9"), &LagGame.fixedDelta, 0.05f, 0.5f);
                        ImGui::PopItemWidth();
                    }

                    // Engine pointer status
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(0.45f,0.45f,0.45f,1),
                        OBFUSCATE("set_ts:%s  fps:%s  fix:%s"),
                        lag_set_timeScale       ? "OK" : "X",
                        lag_set_targetFrameRate ? "OK" : "X",
                        lag_set_fixedDeltaTime  ? "OK" : "X");

                    // ── SECTION 2: EMOJI / DANCE / GESTURE SPAM ──────────
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    if (LagSpam.emojiEnable)
                        ImGui::TextColored(ImVec4(1,0.15f,0.15f,1), OBFUSCATE(ICON_FA_STAR " Emoji/Dance/Gesture Spam [DANG SPAM]"));
                    else
                        ImGui::TextColored(ImVec4(0.8f,0.8f,0.2f,1), OBFUSCATE(ICON_FA_STAR " Emoji / Dance / Gesture Spam"));
                    ImGui::Separator();

                    // Instance status
                    if (g_spamEffectComp)
                        ImGui::TextColored(ImVec4(0.2f,1,0.4f,1), OBFUSCATE("Instance: CAPTURED  OK"));
                    else
                        ImGui::TextColored(ImVec4(1,0.6f,0,1),    OBFUSCATE("Instance: CHUA (vao tran roi dung emoji 1 lan)"));

                    ImGui::Spacing();

                    // Enable + interval
                    ImGui::PushStyleColor(ImGuiCol_CheckMark, LagSpam.emojiEnable ? ImVec4(1,0.15f,0.15f,1) : ImVec4(0.3f,1,0.3f,1));
                    ImGui::Checkbox(OBFUSCATE("##SpamEmoEn"), &LagSpam.emojiEnable);
                    ImGui::PopStyleColor();
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("Bat Spam"));
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("  Interval:"));
                    ImGui::SameLine();
                    ImGui::PushItemWidth(130);
                    ImGui::SliderFloat(OBFUSCATE("##SpamEmoInt"), &LagSpam.emojiInterval, 0.01f, 1.0f, "%.2fs");
                    ImGui::PopItemWidth();

                    // Index
                    ImGui::Text(OBFUSCATE("Index:"));
                    ImGui::SameLine();
                    ImGui::PushItemWidth(-1);
                    ImGui::SliderInt(OBFUSCATE("##SpamEmoIdx"), &LagSpam.emojiIndex, 0, 99);
                    ImGui::PopItemWidth();

                    // Type checkboxes
                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Loai spam:"));
                    ImGui::BeginTable(OBFUSCATE("##spamTypes"), 3);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Emoji"),       &LagSpam.typeEmoji);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Dance"),       &LagSpam.typeDance);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("EmojiDance"),  &LagSpam.typeCombo);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Gesture 2"),   &LagSpam.typeGesture2);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("Gesture 3"),   &LagSpam.typeGesture3);
                    ImGui::TableNextColumn(); ImGui::Checkbox(OBFUSCATE("G2 Cancel"),   &LagSpam.typeG2Cancel);
                    ImGui::EndTable();

                    // Pointer status
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(0.45f,0.45f,0.45f,1),
                        OBFUSCATE("emoji:%s  dance:%s  combo:%s  g2:%s  g3:%s  g2c:%s"),
                        spam_SendEmojiByIdx      ? "OK" : "X",
                        spam_SendDanceByIdx      ? "OK" : "X",
                        spam_SendEmojiDanceByIdx ? "OK" : "X",
                        spam_Gesture2            ? "OK" : "X",
                        spam_Gesture3            ? "OK" : "X",
                        spam_Gesture2Cancel      ? "OK" : "X");

                    // ── SECTION 3: CHAT EMOJI SPAM ────────────────────────
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    if (LagSpam.chatEnable)
                        ImGui::TextColored(ImVec4(1,0.15f,0.15f,1), OBFUSCATE(ICON_FA_COMMENTS " Chat Emoji Spam [DANG SPAM]"));
                    else
                        ImGui::TextColored(ImVec4(0.8f,0.8f,0.2f,1), OBFUSCATE(ICON_FA_COMMENTS " Chat Emoji Spam  (static – khong can instance)"));
                    ImGui::Separator();

                    // Enable + interval
                    ImGui::PushStyleColor(ImGuiCol_CheckMark, LagSpam.chatEnable ? ImVec4(1,0.15f,0.15f,1) : ImVec4(0.3f,1,0.3f,1));
                    ImGui::Checkbox(OBFUSCATE("##SpamChatEn"), &LagSpam.chatEnable);
                    ImGui::PopStyleColor();
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("Bat Spam"));
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("  Interval:"));
                    ImGui::SameLine();
                    ImGui::PushItemWidth(130);
                    ImGui::SliderFloat(OBFUSCATE("##SpamChatInt"), &LagSpam.chatInterval, 0.02f, 2.0f, "%.2fs");
                    ImGui::PopItemWidth();

                    // Emoji ID
                    ImGui::Text(OBFUSCATE("Emoji ID:"));
                    ImGui::SameLine();
                    ImGui::PushItemWidth(-1);
                    ImGui::SliderInt(OBFUSCATE("##SpamChatID"), &LagSpam.chatEmojiID, 1, 50);
                    ImGui::PopItemWidth();

                    // Pointer status
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(0.45f,0.45f,0.45f,1),
                        OBFUSCATE("SendEmojiMsgInTeam: %s"), spam_ChatEmoji ? "OK" : "X (chua resolve)");

                    // ── SECTION 4: AUTO-MOVEMENT ──────────────────────────
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    if (AutoMove.enable)
                        ImGui::TextColored(ImVec4(0.2f,0.8f,1,1), OBFUSCATE(ICON_FA_ARROWS " Auto-Movement [DANG CHAY]"));
                    else
                        ImGui::TextColored(ImVec4(0.5f,0.9f,1,1), OBFUSCATE(ICON_FA_ARROWS " Auto-Movement (chi nhan vat cua ban)"));
                    ImGui::Separator();

                    // Cảnh báo kỹ thuật
                    ImGui::TextColored(ImVec4(1,0.7f,0,1),
                        OBFUSCATE("Lockstep cmd mang playerID cua ban – chi move tuong ban"));

                    // Instance status
                    ImGui::Spacing();
                    if (g_gameInputInst)
                        ImGui::TextColored(ImVec4(0.2f,1,0.4f,1), OBFUSCATE("GameInput: CAPTURED  OK"));
                    else
                        ImGui::TextColored(ImVec4(1,0.6f,0,1),    OBFUSCATE("GameInput: CHUA (vao tran se tu dong capture)"));

                    ImGui::Spacing();

                    // Enable + interval
                    ImGui::PushStyleColor(ImGuiCol_CheckMark, AutoMove.enable ? ImVec4(0.2f,0.8f,1,1) : ImVec4(0.3f,1,0.3f,1));
                    ImGui::Checkbox(OBFUSCATE("##AutoMoveEn"), &AutoMove.enable);
                    ImGui::PopStyleColor();
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("Bat Auto-Move"));
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("  Interval:"));
                    ImGui::SameLine();
                    ImGui::PushItemWidth(130);
                    ImGui::SliderFloat(OBFUSCATE("##AutoMoveInt"), &AutoMove.interval, 0.02f, 0.5f, "%.2fs");
                    ImGui::PopItemWidth();

                    // 4 direction buttons (radio behaviour – check one → uncheck others)
                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Huong di chuyen:"));
                    ImGui::Spacing();

                    // North
                    ImGui::PushStyleColor(ImGuiCol_Button,        AutoMove.dirN ? ImVec4(0.1f,0.6f,1,1)   : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered,  ImVec4(0.2f,0.7f,1,1));
                    if (ImGui::Button(OBFUSCATE("  BAC (Truoc)  "), ImVec2(-1, 44))) {
                        AutoMove.dirN = !AutoMove.dirN;
                        if (AutoMove.dirN) { AutoMove.dirS = false; AutoMove.dirE = false; AutoMove.dirW = false; AutoMove.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    // South
                    ImGui::PushStyleColor(ImGuiCol_Button,        AutoMove.dirS ? ImVec4(0.1f,0.6f,1,1)   : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered,  ImVec4(0.2f,0.7f,1,1));
                    if (ImGui::Button(OBFUSCATE("  NAM  (Sau)   "), ImVec2(-1, 44))) {
                        AutoMove.dirS = !AutoMove.dirS;
                        if (AutoMove.dirS) { AutoMove.dirN = false; AutoMove.dirE = false; AutoMove.dirW = false; AutoMove.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    // East / West row
                    float halfW = (ImGui::GetContentRegionAvail().x - 6) * 0.5f;

                    ImGui::PushStyleColor(ImGuiCol_Button,        AutoMove.dirW ? ImVec4(0.1f,0.6f,1,1)   : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered,  ImVec4(0.2f,0.7f,1,1));
                    if (ImGui::Button(OBFUSCATE(" TAY (Trai) "), ImVec2(halfW, 44))) {
                        AutoMove.dirW = !AutoMove.dirW;
                        if (AutoMove.dirW) { AutoMove.dirN = false; AutoMove.dirS = false; AutoMove.dirE = false; AutoMove.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    ImGui::SameLine();

                    ImGui::PushStyleColor(ImGuiCol_Button,        AutoMove.dirE ? ImVec4(0.1f,0.6f,1,1)   : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered,  ImVec4(0.2f,0.7f,1,1));
                    if (ImGui::Button(OBFUSCATE("DONG (Phai)"), ImVec2(halfW, 44))) {
                        AutoMove.dirE = !AutoMove.dirE;
                        if (AutoMove.dirE) { AutoMove.dirN = false; AutoMove.dirS = false; AutoMove.dirW = false; AutoMove.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    // Stop button
                    ImGui::Spacing();
                    ImGui::PushStyleColor(ImGuiCol_Button,        ImVec4(0.5f,0.1f,0.1f,1));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered,  ImVec4(0.7f,0.15f,0.15f,1));
                    if (ImGui::Button(OBFUSCATE(ICON_FA_STOP " DUNG DI CHUYEN"), ImVec2(-1, 40))) {
                        AutoMove.enable = false;
                        AutoMove.dirN = AutoMove.dirS = AutoMove.dirE = AutoMove.dirW = AutoMove.useCustom = false;
                        if (g_gameInputInst && move_StopInput) move_StopInput(g_gameInputInst);
                    }
                    ImGui::PopStyleColor(2);

                    // Custom angle
                    ImGui::Spacing();
                    ImGui::Checkbox(OBFUSCATE("Custom Degree"), &AutoMove.useCustom);
                    if (AutoMove.useCustom) {
                        if (AutoMove.useCustom) { AutoMove.dirN = AutoMove.dirS = AutoMove.dirE = AutoMove.dirW = false; }
                        ImGui::SameLine();
                        ImGui::PushItemWidth(-1);
                        ImGui::SliderInt(OBFUSCATE("##AutoMoveDeg"), &AutoMove.customDeg, 0, 359);
                        ImGui::PopItemWidth();
                        ImGui::TextColored(ImVec4(0.5f,0.8f,1,1),
                            OBFUSCATE("0=Bac  90=Dong  180=Nam  270=Tay"));
                    }

                    // Status
                    ImGui::Spacing();
                    ImGui::TextColored(ImVec4(0.45f,0.45f,0.45f,1),
                        OBFUSCATE("SendMoveDir:%s  StopInput:%s  GameInput:%s"),
                        move_SendDir    ? "OK" : "X",
                        move_StopInput  ? "OK" : "X",
                        g_gameInputInst ? "OK" : "X");
                    ImGui::TextColored(ImVec4(0.45f,0.45f,0.45f,1),
                        OBFUSCATE("SendDirPriv(auto):%s  GetPlayerId(auto):%s"),
                        move_SendDir_Priv ? "OK" : "X (chua resolve)",
                        ama_get_playerId  ? "OK" : "X (chua resolve)");

                    // ── SECTION 5: AUTO-MOVE ALL PLAYERS ─────────────────
                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();
                    if (AutoMoveAll.enable)
                        ImGui::TextColored(ImVec4(1,0.3f,1,1), OBFUSCATE(ICON_FA_USERS " AutoMove TAT CA [DANG CHAY]"));
                    else
                        ImGui::TextColored(ImVec4(0.9f,0.5f,1,1), OBFUSCATE(ICON_FA_USERS " AutoMove Tat Ca Nguoi Choi"));
                    ImGui::Separator();

                    // Cơ chế
                    ImGui::TextColored(ImVec4(1,0.7f,0,1),
                        OBFUSCATE("GameInput.SendMoveDir(deg, playerID) – private overload"));
                    ImGui::TextColored(ImVec4(0.6f,0.6f,0.6f,1),
                        OBFUSCATE("Giong spam emoji: iteration ActorManager → playerID"));

                    // Pointer status
                    ImGui::Spacing();
                    ImGui::TextColored(
                        (move_SendDir_Priv && ama_get_playerId) ? ImVec4(0.2f,1,0.4f,1) : ImVec4(1,0.4f,0.2f,1),
                        OBFUSCATE("SendDirPriv:%s  GetPlayerId:%s  GameInput:%s"),
                        move_SendDir_Priv ? "OK" : "X",
                        ama_get_playerId  ? "OK" : "X",
                        g_gameInputInst   ? "OK" : "X");

                    ImGui::Spacing();

                    // Enable + interval
                    ImGui::PushStyleColor(ImGuiCol_CheckMark, AutoMoveAll.enable ? ImVec4(1,0.3f,1,1) : ImVec4(0.3f,1,0.3f,1));
                    ImGui::Checkbox(OBFUSCATE("##AMAEn"), &AutoMoveAll.enable);
                    ImGui::PopStyleColor();
                    ImGui::SameLine();
                    ImGui::Text(OBFUSCATE("Bat AutoMove All"));
                    ImGui::SameLine();
                    ImGui::PushItemWidth(120);
                    ImGui::SliderFloat(OBFUSCATE("##AMAInt"), &AutoMoveAll.interval, 0.02f, 0.5f, "%.2fs");
                    ImGui::PopItemWidth();

                    // Target filter
                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Muc tieu:"));
                    ImGui::SameLine();
                    ImGui::PushStyleColor(ImGuiCol_CheckMark, ImVec4(0.3f,1,0.7f,1));
                    ImGui::Checkbox(OBFUSCATE("Ban than"), &AutoMoveAll.targetSelf);
                    ImGui::SameLine();
                    ImGui::Checkbox(OBFUSCATE("Dong minh"), &AutoMoveAll.targetAllies);
                    ImGui::SameLine();
                    ImGui::Checkbox(OBFUSCATE("Ke dich"), &AutoMoveAll.targetEnemies);
                    ImGui::PopStyleColor();

                    // 4 direction buttons
                    ImGui::Spacing();
                    ImGui::Text(OBFUSCATE("Huong:"));

                    float ama_halfW = (ImGui::GetContentRegionAvail().x - 6) * 0.5f;

                    // North
                    ImGui::PushStyleColor(ImGuiCol_Button, AutoMoveAll.dirN ? ImVec4(0.7f,0.2f,1,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f,0.3f,1,1));
                    if (ImGui::Button(OBFUSCATE("  BAC (Truoc) [ALL]  "), ImVec2(-1, 40))) {
                        AutoMoveAll.dirN = !AutoMoveAll.dirN;
                        if (AutoMoveAll.dirN) { AutoMoveAll.dirS = false; AutoMoveAll.dirE = false; AutoMoveAll.dirW = false; AutoMoveAll.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    // South
                    ImGui::PushStyleColor(ImGuiCol_Button, AutoMoveAll.dirS ? ImVec4(0.7f,0.2f,1,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f,0.3f,1,1));
                    if (ImGui::Button(OBFUSCATE("  NAM (Sau) [ALL]   "), ImVec2(-1, 40))) {
                        AutoMoveAll.dirS = !AutoMoveAll.dirS;
                        if (AutoMoveAll.dirS) { AutoMoveAll.dirN = false; AutoMoveAll.dirE = false; AutoMoveAll.dirW = false; AutoMoveAll.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    // West / East row
                    ImGui::PushStyleColor(ImGuiCol_Button, AutoMoveAll.dirW ? ImVec4(0.7f,0.2f,1,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f,0.3f,1,1));
                    if (ImGui::Button(OBFUSCATE(" TAY (Trai)[ALL]"), ImVec2(ama_halfW, 40))) {
                        AutoMoveAll.dirW = !AutoMoveAll.dirW;
                        if (AutoMoveAll.dirW) { AutoMoveAll.dirN = false; AutoMoveAll.dirS = false; AutoMoveAll.dirE = false; AutoMoveAll.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    ImGui::SameLine();

                    ImGui::PushStyleColor(ImGuiCol_Button, AutoMoveAll.dirE ? ImVec4(0.7f,0.2f,1,1) : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.8f,0.3f,1,1));
                    if (ImGui::Button(OBFUSCATE("DONG(Phai)[ALL]"), ImVec2(ama_halfW, 40))) {
                        AutoMoveAll.dirE = !AutoMoveAll.dirE;
                        if (AutoMoveAll.dirE) { AutoMoveAll.dirN = false; AutoMoveAll.dirS = false; AutoMoveAll.dirW = false; AutoMoveAll.useCustom = false; }
                    }
                    ImGui::PopStyleColor(2);

                    // Stop all button
                    ImGui::Spacing();
                    ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.5f,0.1f,0.5f,1));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.7f,0.15f,0.7f,1));
                    if (ImGui::Button(OBFUSCATE(ICON_FA_STOP " DUNG MOVE TẤT CA"), ImVec2(-1, 40))) {
                        AutoMoveAll.enable = false;
                        AutoMoveAll.dirN = AutoMoveAll.dirS = AutoMoveAll.dirE = AutoMoveAll.dirW = AutoMoveAll.useCustom = false;
                    }
                    ImGui::PopStyleColor(2);

                    // Custom degree
                    ImGui::Spacing();
                    ImGui::Checkbox(OBFUSCATE("Custom Degree (All)"), &AutoMoveAll.useCustom);
                    if (AutoMoveAll.useCustom) {
                        AutoMoveAll.dirN = AutoMoveAll.dirS = AutoMoveAll.dirE = AutoMoveAll.dirW = false;
                        ImGui::SameLine();
                        ImGui::PushItemWidth(-1);
                        ImGui::SliderInt(OBFUSCATE("##AMADeg"), &AutoMoveAll.customDeg, 0, 359);
                        ImGui::PopItemWidth();
                        ImGui::TextColored(ImVec4(0.8f,0.5f,1,1),
                            OBFUSCATE("0=Bac  90=Dong  180=Nam  270=Tay"));
                    }

                    ImGui::EndChild();
                }

                if(TabMenu == 7){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab7"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    ImGui::TextColored(ImVec4(1,1,0,1), "DEBUG INFO");
                    ImGui::Separator();

                    ImGui::Text("il2cpp: 0x%llx", (unsigned long long)g_il2cpp_base);
                    ImGui::Text("LGameActorMgr: %p", LGameActorMgr);
                    ImGui::Text("Actors: %d", Response.Count);
                    ImGui::Text("MyCamp: %d (detected: %s)", myPlayerCamp, campDetected ? "YES" : "NO");
                    if (Response.Count > 0) {
                        ImGui::Text("P[0] HP: %d/%d", Response.players[0].ActorHP, Response.players[0].ActorHPTotal);
                        ImGui::Text("P[0] Pos: %.1f, %.1f, %.1f", Response.players[0].Position.x, Response.players[0].Position.y, Response.players[0].Position.z);
                        ImGui::Text("P[0] Sc: %.1f, %.1f", Response.players[0].PositionSc.x, Response.players[0].PositionSc.y);
                        ImGui::Text("P[0] Enemy: %d Vis: %d CfgID: %d", Response.players[0].isEnemy, Response.players[0].Visible, Response.players[0].ConfigID);
                    }
                    ImGui::Separator();

                    ImGui::TextColored(ImVec4(0,1,1,1), "METHOD POINTERS");
                    ImGui::Text("get_camera: %p", (void*)get_camera);
                    ImGui::Text("worldToScreen: %p", (void*)worldToScreen);
                    ImGui::Text("get_position: %p", (void*)get_position);
                    ImGui::Text("get_forward: %p", (void*)get_forward);
                    ImGui::Text("get_location: %p", (void*)get_location);
                    ImGui::Text("AsHero: %p", (void*)AsHero);
                    ImGui::Text("GiveMyEnemyCamp: %p", (void*)GiveMyEnemyCamp);
                    ImGui::Text("IsHostPlayer: %p", (void*)IsHostPlayer);
                    ImGui::Text("get_objCamp: %p", (void*)get_objCamp);
                    ImGui::Text("get_actorManager: %p", (void*)get_actorManager);
                    ImGui::Text("GetAllHeros_A: %p", (void*)GetAllHeros_ActorManager);
                    ImGui::Text("GetAllHeros_L: %p", (void*)GetAllHeros_LGameActorMgr);
                    ImGui::Text("actorHP: %p", (void*)actorHP);
                    ImGui::Text("actorMaxHP: %p", (void*)actorMaxHP);
                    ImGui::Text("get_bVisible: %p", (void*)get_bVisible);
                    ImGui::Text("GetHeroWrapSkill: %p", (void*)GetHeroWrapSkillData);
                    ImGui::Separator();

                    ImGui::TextColored(ImVec4(0,1,1,1), "FIELD OFFSETS");
                    ImGui::Text("ValueComponent: 0x%lx", (unsigned long)PlayerESP.ValueComponent);
                    ImGui::Text("ObjLinker: 0x%lx", (unsigned long)PlayerESP.ObjLinker);
                    ImGui::Text("SkillControl: 0x%lx", (unsigned long)g_SkillControlOff);
                    ImGui::Text("SkillSlotArray: 0x%lx", (unsigned long)g_SkillSlotArrayOff);
                    ImGui::Separator();

                    ImGui::TextColored(ImVec4(1,0.5,0,1), "SKILL CD DEBUG");
                    // Show first enemy hero skill data
                    for (int di = 0; di < collected_actor_count; di++) {
                        if (collected_actors[di].isHero && collected_actors[di].enemyCamp == myPlayerCamp && collected_actors[di].hp > 0) {
                            ImGui::Text("Hero cfgID=%d", collected_actors[di].configID);
                            ImGui::Text("  S1: cd=%d unlock=%d", collected_actors[di].skill1CD, collected_actors[di].skill1Unlock);
                            ImGui::Text("  S2: cd=%d unlock=%d", collected_actors[di].skill2CD, collected_actors[di].skill2Unlock);
                            ImGui::Text("  S3: cd=%d unlock=%d", collected_actors[di].skill3CD, collected_actors[di].skill3Unlock);
                            ImGui::Text("  Talent: cd=%d  Heal: cd=%d", collected_actors[di].talentCD, collected_actors[di].healCD);
                            break;
                        }
                    }
                    ImGui::Separator();

                    // ── AutoMoveAll Debug ─────────────────────────────────
                    ImGui::TextColored(ImVec4(0.8f,0.4f,1,1), OBFUSCATE("AUTO-MOVE-ALL DEBUG"));
                    ImGui::Text(OBFUSCATE("SendDirPriv: %p"), (void*)move_SendDir_Priv);
                    ImGui::Text(OBFUSCATE("GetPlayerId: %p"), (void*)ama_get_playerId);
                    ImGui::Text(OBFUSCATE("AMAActive: %s  Deg: %d  Actors: %d"),
                        g_amaDebugActive ? "YES" : "NO", g_amaDebugDeg, g_amaDebugCount);
                    if (g_amaDebugCount > 0) {
                        ImGui::Separator();
                        ImGui::Text(OBFUSCATE("  [i] PID      CAMP  HOST  TARG"));
                        for (int _di = 0; _di < g_amaDebugCount; _di++) {
                            const AMADebugEntry& _e = g_amaDebugEntries[_di];
                            ImGui::TextColored(
                                _e.targeted ? ImVec4(0.3f,1,0.3f,1) : ImVec4(0.5f,0.5f,0.5f,1),
                                OBFUSCATE("  [%d] %04u     %d     %s     %s"),
                                _di, _e.playerID, _e.camp,
                                _e.isHost   ? "Y" : "N",
                                _e.targeted ? "Y" : "N");
                        }
                    } else {
                        ImGui::TextColored(ImVec4(0.5f,0.5f,0.5f,1), OBFUSCATE("  (chua co data – bat AMAAll trong tran)"));
                    }
                    ImGui::Separator();

                    ImGui::Checkbox(OBFUSCATE("Show All IDs on Screen"), &dbg_showAllIDs);

                    ImGui::EndChild();
                }

                // ═══════════════════════════════════════════════════════
                // TAB 10 – TOA DO (Coordinates)
                // ═══════════════════════════════════════════════════════
                if(TabMenu == 10){
                    ImGui::BeginChild(OBFUSCATE("##ChildTab10"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                    ImGui::TextColored(ImVec4(0.3f,0.8f,1,1), OBFUSCATE(ICON_FA_LOCATION_ARROW " TOA DO NHAN VAT"));
                    ImGui::Separator();
                    ImGui::Spacing();

                    // ── Hiện tọa độ thực tế ──────────────────────────────
                    if (Lactor && get_location) {
                        // Lactor là ActorLinker; get_location nhận LActorRoot
                        // Đọc tọa độ qua get_position (Vector3 float, đơn vị Unity)
                    }
                    if (Lactor && get_position) {
                        Vector3 pos = get_position(Lactor);
                        ImGui::TextColored(ImVec4(0.5f,1,0.5f,1), OBFUSCATE("Vi tri hien tai:"));
                        ImGui::BeginTable(OBFUSCATE("##coordTable"), 2);
                        ImGui::TableNextColumn(); ImGui::TextColored(ImVec4(1,0.4f,0.4f,1), OBFUSCATE("X:"));
                        ImGui::TableNextColumn(); ImGui::Text("%.3f", pos.x);
                        ImGui::TableNextColumn(); ImGui::TextColored(ImVec4(0.4f,1,0.4f,1), OBFUSCATE("Y:"));
                        ImGui::TableNextColumn(); ImGui::Text("%.3f", pos.y);
                        ImGui::TableNextColumn(); ImGui::TextColored(ImVec4(0.4f,0.6f,1,1), OBFUSCATE("Z:"));
                        ImGui::TableNextColumn(); ImGui::Text("%.3f", pos.z);
                        ImGui::EndTable();

                        // Đồng bộ giá trị target với vị trí hiện tại (nếu chưa chỉnh)
                        static bool g_coordInit = false;
                        if (!g_coordInit) {
                            g_coordTargetX = pos.x;
                            g_coordTargetY = pos.y;
                            g_coordTargetZ = pos.z;
                            g_coordInit = true;
                        }
                    } else {
                        ImGui::TextColored(ImVec4(1,0.4f,0.2f,1), OBFUSCATE("Chua co du lieu vi tri (chua vao tran)"));
                    }

                    ImGui::Spacing();
                    ImGui::Separator();
                    ImGui::Spacing();

                    // ── Thanh chỉnh tọa độ mục tiêu ─────────────────────
                    ImGui::TextColored(ImVec4(1,0.85f,0,1), OBFUSCATE("Chinh toa do dich chuyen:"));
                    ImGui::Spacing();

                    ImGui::PushItemWidth(-1);
                    ImGui::TextColored(ImVec4(1,0.4f,0.4f,1), OBFUSCATE("X"));
                    ImGui::SliderFloat(OBFUSCATE("##CoordX"), &g_coordTargetX, -5000.f, 5000.f);
                    ImGui::TextColored(ImVec4(0.4f,1,0.4f,1), OBFUSCATE("Y"));
                    ImGui::SliderFloat(OBFUSCATE("##CoordY"), &g_coordTargetY, -500.f, 500.f);
                    ImGui::TextColored(ImVec4(0.4f,0.6f,1,1), OBFUSCATE("Z"));
                    ImGui::SliderFloat(OBFUSCATE("##CoordZ"), &g_coordTargetZ, -5000.f, 5000.f);
                    ImGui::PopItemWidth();

                    ImGui::Spacing();

                    // InputFloat để nhập chính xác
                    ImGui::PushItemWidth(ImGui::GetContentRegionAvail().x / 3.f - 4.f);
                    ImGui::InputFloat(OBFUSCATE("##CX"), &g_coordTargetX, 1.f, 10.f, "%.1f");
                    ImGui::SameLine();
                    ImGui::InputFloat(OBFUSCATE("##CY"), &g_coordTargetY, 0.5f, 5.f, "%.1f");
                    ImGui::SameLine();
                    ImGui::InputFloat(OBFUSCATE("##CZ"), &g_coordTargetZ, 1.f, 10.f, "%.1f");
                    ImGui::PopItemWidth();

                    ImGui::Spacing();

                    // ── Nút đặt vị trí ───────────────────────────────────
                    // Status line: show resolution state
                    ImGui::TextColored(
                        set_location_linker ? ImVec4(0.2f,1,0.4f,1) : ImVec4(1,0.4f,0.2f,1),
                        OBFUSCATE("linker:%s  root:%s  MtpCmd:%s"),
                        set_location_linker ? "OK" : "X",
                        set_location_root   ? "OK" : "X",
                        orig_MtpCmd_Exec    ? "OK" : "X");

                    bool canTeleport = Lactor && (set_location_linker || set_location_root);
                    if (!canTeleport) ImGui::BeginDisabled();
                    ImGui::PushStyleColor(ImGuiCol_Button,        ImVec4(0.1f,0.45f,0.6f,1));
                    ImGui::PushStyleColor(ImGuiCol_ButtonHovered,  ImVec4(0.15f,0.6f,0.8f,1));
                    if (ImGui::Button(OBFUSCATE(ICON_FA_LOCATION_ARROW " Dat Vi Tri"), ImVec2(-1, 48))) {
                        VInt3 dest;
                        dest.X = (int)(g_coordTargetX * 1000.f);
                        dest.Y = (int)(g_coordTargetY * 1000.f);
                        dest.Z = (int)(g_coordTargetZ * 1000.f);
                        // Update both Unity visual layer and game logic layer
                        if (set_location_linker && Lactor)      set_location_linker(Lactor,      dest);
                        if (set_location_root   && Lactor_Root) set_location_root(Lactor_Root, dest);
                        // Also queue for next MoveToPosCommand intercept (syncs to server)
                        g_pendingDest    = dest;
                        g_pendingTeleport = true;
                    }
                    ImGui::PopStyleColor(2);
                    if (!canTeleport) ImGui::EndDisabled();
                    if (Lactor && g_pendingTeleport)
                        ImGui::TextColored(ImVec4(1,0.9f,0,1), OBFUSCATE("Cho MoveToPosCmd de dong bo server..."));
                    if (!Lactor)
                        ImGui::TextColored(ImVec4(1,0.4f,0.2f,1), OBFUSCATE("Chua vao tran"));

                    ImGui::EndChild();
                }

                ImGui::EndPopup();
            }
        }else{
            ImGui::Begin(OBFUSCATE(""), 0, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoBackground);
            ImGui::SetNextWindowSize(ImVec2(screenWidth * 0.30f, screenHeight * 0.70f), ImGuiCond_Once);
            if (!HideIcon) {
            std::string fpsString = std::to_string(static_cast<int>(ImGui::GetIO().Framerate));
            ImGuiStyle &style = ImGui::GetStyle();
            ImVec4 original_button_color = style.Colors[ImGuiCol_Button];
            float original_frame_rounding = style.FrameRounding;
            ImVec4 original_text_color = style.Colors[ImGuiCol_Text];
            style.Colors[ImGuiCol_Button] = ImVec4(ImGui::ColorConvertU32ToFloat4(IM_COL32(255, 255, 255, 100)));
            style.FrameRounding = 64 * 0.5f;
            style.Colors[ImGuiCol_Text] = ImVec4(0.f, 0.f, 0.f, 1.f);
            if(ImGui::Button(fpsString.c_str(), ImVec2(64, 64))){
                ShowMenu = true;
            }
            style.Colors[ImGuiCol_Button] = original_button_color;
            style.FrameRounding = original_frame_rounding;
            style.Colors[ImGuiCol_Text] = original_text_color;
        }
            ImGui::End();
        }
    
    }
    ImGui::Render();
    ImGui::EndFrame();
    
    ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &glWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &glHeight);
    
    io.KeysDown[io.KeyMap[ImGuiKey_UpArrow]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_DownArrow]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_LeftArrow]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_RightArrow]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_Enter]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_Backspace]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_Delete]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_Escape]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_Home]] = false;
    io.KeysDown[io.KeyMap[ImGuiKey_End]] = false;
    
    return orig_eglSwapBuffers(dpy, surface);
}


ProcMap unityMap, il2cppMap;
using KittyScanner::RegisterNativeFn;
void *Init_Thread(void *) {
    while (!il2cppMap.isValid()) {
		il2cppMap = KittyMemory::getLibraryBaseMap("libil2cpp.so");
		sleep(1);
	}
	
    InitUnityResolve();
    TouchInput::Init();
    LagGame_Init();
    LagSpam_Init();

    // Hook EffectPlayComponent để capture instance (cho spam)
    HOOKAU("Project_d.dll", "Assets.Scripts.GameLogic", "EffectPlayComponent", "Awake", 0, hook_spam_Awake, orig_spam_Awake);
    if (!orig_spam_Awake)
        HOOKAU("Project_d.dll", "Assets.Scripts.GameLogic", "EffectPlayComponent", "Start", 0, hook_spam_Awake, orig_spam_Awake);
    // Fallback: capture khi người dùng dùng emoji lần đầu
    HOOKAU("Project_d.dll", "Assets.Scripts.GameLogic", "EffectPlayComponent", "SendEmojiCommandByIndex", 1, hook_spam_SendEmoji, orig_spam_SendEmoji);

    // Auto-Move: capture GameInput instance mỗi frame
    HOOKAU("Project_d.dll", "Assets.Scripts.GameLogic", "GameInput", "UpdateFrame", 0, hook_move_UpdateFrame, orig_move_UpdateFrame);

    // Minimap teleport button – hook UpdateTeleportBtnStatus to force buttons active (works in PvP too)
    HOOKAU("Project_d.dll", "Assets.Scripts.GameSystem", "FightForm", "UpdateTeleportBtnStatus", 0, hook_UpdateTeleportBtnStatus, orig_UpdateTeleportBtnStatus);
    go_SetActive = (void(*)(void*,bool)) GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "GameObject", "SetActive", 1);
    if (!go_SetActive) go_SetActive = (void(*)(void*,bool)) GetMethodOffset("UnityEngine.dll", "UnityEngine", "GameObject", "SetActive", 1);
    off_TeleportLeft  = (int)(uintptr_t) GetFieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "FightForm", "m_TeleportButtonLeft");
    off_TeleportRight = (int)(uintptr_t) GetFieldOffset("Project_d.dll", "Assets.Scripts.GameSystem", "FightForm", "m_TeleportButtonRight");
    // Coordinates tab – set actor world position (both layers)
    set_location_linker = (void(*)(void*,VInt3)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorLinker", "set_location", 1);
    set_location_root   = (void(*)(void*,VInt3)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "set_location", 1);
    // MoveToPosCommand intercept: hook _ExecCommandImpl(LBattleLogic) (1 param)
    HOOKAU("Project.Plugins_d.dll", "NucleusDrive.Logic", "MoveToPosCommand", "_ExecCommandImpl", 1, hook_MtpCmd_Exec, orig_MtpCmd_Exec);
    // Frame sync helpers for command injection (not strictly needed now, resolved for future use)
    get_ActiveBattleLogic_fn = (void*(*)()) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Proxy", "LFrameworkEditorProxy", "get_ActiveBattleLogic", 0);
    get_frameSynchr_fn       = (void*(*)(void*)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LBattleLogic", "get_frameSynchr", 0);
    PushFrameCommand_fn      = (void(*)(void*,void*)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LFrameSynchr", "PushFrameCommand", 1);

    // === No-Save Quit (thoát trận không lưu lịch sử) ===
    lfsbl_DoFightOver_fn = (void(*)(void*,bool)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LFrameSyncBattleLogic", "DoFightOver", 1);
    __android_log_print(ANDROID_LOG_INFO, "NoSaveQuit", "lfsbl_DoFightOver_fn=%p", lfsbl_DoFightOver_fn);
    HOOKAU("Project_d.dll", "Assets.Scripts.GameLogic", "LobbyMsgHandler", "SendBattleResult", 1, hook_SendBattleResult, orig_SendBattleResult);
    HOOKAU("Project_d.dll", "Assets.Scripts.GameLogic", "LobbyMsgHandler", "HandleSingleGameSettle", 1, hook_HandleSingleGameSettle, orig_HandleSingleGameSettle);

    // === ESP Core ===
    get_camera = (void *(*)()) GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "get_main", 0);
    if (!get_camera) get_camera = (void *(*)()) GetMethodOffset("UnityEngine.dll", "UnityEngine", "Camera", "get_main", 0);
    worldToScreen = (Vector3 (*)(void *, Vector3)) GetMethodOffset("UnityEngine.CoreModule.dll", "UnityEngine", "Camera", "WorldToScreenPoint", 1);
    if (!worldToScreen) worldToScreen = (Vector3 (*)(void *, Vector3)) GetMethodOffset("UnityEngine.dll", "UnityEngine", "Camera", "WorldToScreenPoint", 1);
    get_position = (Vector3 (*)(void*)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_position", 0);

    get_forward = (VInt3 (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "get_forward", 0);
    get_location = (VInt3 (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "get_location", 0);
    AsHero = (void* (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "AsHero", 0);
    GiveMyEnemyCamp = (int (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "GiveMyEnemyCamp", 0);
    PlayerESP.ValueComponent = (uintptr_t) GetFieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "ValueComponent");

    IsHostPlayer = (bool (*)(void *)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorLinker", "IsHostPlayer", 0);
    get_objCamp = (int (*)(void *)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_objCamp", 0);
    PlayerESP.ObjLinker = (uintptr_t) GetFieldOffset("Project_d.dll", "Kyrios.Actor", "ActorLinker", "ObjLinker");
    get_bVisible = (bool (*)(void *)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorLinker", "get_bVisible", 0);

    // Visibility for minions/monsters now handled by SetVisible hook cache (no extra resolve needed)

    get_IsDeadState = (bool (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LObjWrapper", "get_IsDeadState", 0);
    GetHeroWrapSkillData = (HeroWrapSkillData (*)(void *, int)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LHeroWrapper", "GetHeroWrapSkillData", 1);

    GetAllHeros_LGameActorMgr = (List<void **> *(*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LGameActorMgr", "GetAllHeros", 0);
    if (!GetAllHeros_LGameActorMgr)
        GetAllHeros_LGameActorMgr = (List<void **> *(*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LGameActorMgr", "GetAllHeros", 1);
    GetAllHeros_ActorManager = (List<void **> *(*)(void *)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorManager", "GetAllHeros", 0);
    if (!GetAllHeros_ActorManager)
        GetAllHeros_ActorManager = (List<void **> *(*)(void *)) GetMethodOffset("Project_d.dll", "Kyrios.Actor", "ActorManager", "GetAllHeros", 1);

    GetAllJungleMonsters_LGameActorMgr = (List<void **> *(*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LGameActorMgr", "GetAllJungleMonsters", 0);
    GetAllMonsters_LGameActorMgr = (List<void **> *(*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LGameActorMgr", "GetAllMonsters", 0);

    get_actorManager = (void *(*)()) GetMethodOffset("Project_d.dll", "Kyrios", "KyriosFramework", "get_actorManager", 0);

    actorHP = (int (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "ValuePropertyComponent", "get_actorHp", 0);
    actorMaxHP = (int (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "ValuePropertyComponent", "get_actorHpTotal", 0);
    get_actorSoulLevel = (int (*)(void *)) GetMethodOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "ValuePropertyComponent", "get_actorSoulLevel", 0);

    // Set globals for Wupdate
    g_ValCompOff = PlayerESP.ValueComponent;
    g_hp = actorHP;
    g_maxhp = actorMaxHP;
    g_level = get_actorSoulLevel;

    __android_log_print(ANDROID_LOG_INFO, "ESP_INIT", "cam=%p w2s=%p pos=%p fwd=%p loc=%p hero=%p enemy=%p host=%p camp=%p mgr=%p",
        get_camera, worldToScreen, get_position, get_forward, get_location, AsHero, GiveMyEnemyCamp, IsHostPlayer, get_objCamp, get_actorManager);
    __android_log_print(ANDROID_LOG_INFO, "ESP_INIT", "allH_L=%p allH_A=%p hp=%p maxhp=%p lvl=%p vis=%p skill=%p valComp=%lu objLink=%lu",
        GetAllHeros_LGameActorMgr, GetAllHeros_ActorManager, actorHP, actorMaxHP, get_actorSoulLevel, get_bVisible, GetHeroWrapSkillData,
        (unsigned long)PlayerESP.ValueComponent, (unsigned long)PlayerESP.ObjLinker);

    // ESP update hooks - DISABLED for crash test
    HOOKAU("Project_d.dll", "", "CameraSystem", "LateUpdate", 0, ESPUpdateResponse, _ESPUpdateResponse);
    if (!_ESPUpdateResponse) HOOKAU("Project_d.dll", "Assets.Scripts.GameSystem", "CameraSystem", "LateUpdate", 0, ESPUpdateResponse, _ESPUpdateResponse);
    HOOKAU("Project.Plugins_d.dll", "NucleusDrive.Logic", "LGameActorMgr", "UpdateLogic", 1, UpdateLogic_LGameActorMgr, _UpdateLogic_LGameActorMgr);
    HOOKAU("Project.Plugins_d.dll", "NucleusDrive.Logic", "LGameActorMgr", "FightOver", 0, FightOver_LGameActorMgr, _FightOver_LGameActorMgr);
    HOOKAU("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "DestroyActor", 1, DestroyActor, _DestroyActor);

    HOOKAU("Project.Plugins_d.dll", "NucleusDrive.Logic", "LActorRoot", "UpdateLogic", 1, Wupdate, _Wupdate);

    // ActorLinker hook for camp detection
    HOOKAU("Project_d.dll", "Kyrios.Actor", "ActorLinker", "UpdateLogic", 1, ActorLinkerUpdate, _ActorLinkerUpdate);
    if (!_ActorLinkerUpdate) HOOKAU("Project_d.dll", "", "ActorLinker", "UpdateLogic", 1, ActorLinkerUpdate, _ActorLinkerUpdate);
    if (!_ActorLinkerUpdate) HOOKAU("Project_d.dll", "Kyrios.Actor", "ActorLinker", "Update", 0, ActorLinkerUpdate, _ActorLinkerUpdate);
    if (!_ActorLinkerUpdate) HOOKAU("Project_d.dll", "Kyrios.Actor", "ActorLinker", "LateUpdate", 0, ActorLinkerUpdate, _ActorLinkerUpdate);
    __android_log_print(ANDROID_LOG_INFO, "CAMP_DETECT", "ActorLinkerUpdate hook: %p", (void*)_ActorLinkerUpdate);

    // === FPS Unlock ===
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_Supported60FPSMode", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_Supported90FPSMode", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_Supported120FPSMode", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_SupportedBoth60FPS_CameraHeight", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "IsIPadDevice", 0, TRUE, _TRUE);

    // === Camera ===
    HOOKAU("Project_d.dll", "", "CameraSystem", "GetCameraHeightRateValue", 1, GetCameraHeightRateValue, _GetCameraHeightRateValue);
    HOOKAU("Project_d.dll", "", "CameraSystem", "OnCameraHeightChanged", 0, OnCameraHeightChanged, _OnCameraHeightChanged);

    // === Minimap ===
    get_MinimapScale = (Vector2 (*)(void *))GetMethodOffset("Project_d.dll", "Assets.Scripts.GameSystem", "MinimapSys", "get_MinimapScale", 0);
    get_BigMapScale = (Vector2 (*)(void *))GetMethodOffset("Project_d.dll", "Assets.Scripts.GameSystem", "MinimapSys", "get_BigMapScale", 0);
    get_mmFinalScreenSize = (Vector2 (*)(void *))GetMethodOffset("Project_d.dll", "Assets.Scripts.GameSystem", "MinimapSys", "get_mmFinalScreenSize", 0);
    GetMMFianlScreenPos = (Vector2 (*)(void *))GetMethodOffset("Project_d.dll", "Assets.Scripts.GameSystem", "MinimapSys", "GetMMFianlScreenPos", 0);
    HOOKAU("Project_d.dll", "Assets.Scripts.GameSystem", "MinimapSys", "Update", 0, MiniMapSys, _MiniMapSys);

    // === Visibility ===
    HOOKAU("Project.Plugins_d.dll", "NucleusDrive.Logic", "LVActorLinker", "SetVisible", 3, SetVisible, _SetVisible);

    // Find LVActorLinker field pointing to LActorRoot
    {
        const char *fieldNames[] = {"actorRoot", "m_actorRoot", "ActorRoot", "m_ActorRoot",
            "owner", "m_owner", "Actor", "m_actor", "logicActor", "m_logicActor",
            "actorPtr", "m_actorPtr", "root", "m_root", "lActorRoot", "m_lActorRoot",
            "actorObj", "m_actorObj", "hostActor", "wrapper", "m_wrapper",
            "objActor", "m_objActor", "actorLogic", "m_actorLogic",
            "LActorRoot", "m_LActorRoot", "actor", "objRoot", "m_objRoot", nullptr};
        for (int i = 0; fieldNames[i]; i++) {
            uintptr_t off = (uintptr_t)GetFieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LVActorLinker", fieldNames[i]);
            if (off > 0 && off < 0x200) {
                __android_log_print(ANDROID_LOG_INFO, "FIELD_DUMP", "FOUND: LVActorLinker.%s = 0x%lx", fieldNames[i], (unsigned long)off);
            }
        }
        // Also try on parent class LObjLinker
        for (int i = 0; fieldNames[i]; i++) {
            uintptr_t off = (uintptr_t)GetFieldOffset("Project.Plugins_d.dll", "NucleusDrive.Logic", "LObjLinker", fieldNames[i]);
            if (off > 0 && off < 0x200) {
                __android_log_print(ANDROID_LOG_INFO, "FIELD_DUMP", "FOUND: LObjLinker.%s = 0x%lx", fieldNames[i], (unsigned long)off);
            }
        }
    }

    __android_log_print(ANDROID_LOG_INFO, "ESP_INIT", "All hooks installed");
    
    
    
    return nullptr;
}


JNIEXPORT jint JNICALL 
JNI_OnLoad(JavaVM *vm, void * reserved) {
	jvm = vm;
	JNIEnv *env;
	
	vm->GetEnv((void **) &env, JNI_VERSION_1_6);
	
    Tools::Hook((void *) DobbySymbolResolver(OBFUSCATE("/system/lib/libandroid.so"), OBFUSCATE("ANativeWindow_getWidth")), (void *) _ANativeWindow_getWidth, (void **) &orig_ANativeWindow_getWidth);
    Tools::Hook((void *) DobbySymbolResolver(OBFUSCATE("/system/lib/libandroid.so"), OBFUSCATE("ANativeWindow_getHeight")), (void *) _ANativeWindow_getHeight, (void **) &orig_ANativeWindow_getHeight);
    Tools::Hook((void *) DobbySymbolResolver(OBFUSCATE("/system/lib/libEGL.so"), OBFUSCATE("eglSwapBuffers")), (void *) _eglSwapBuffers, (void **) &orig_eglSwapBuffers);

	pthread_t myThread;
	pthread_create(&myThread, NULL, Init_Thread, NULL);

	return JNI_VERSION_1_6;
}

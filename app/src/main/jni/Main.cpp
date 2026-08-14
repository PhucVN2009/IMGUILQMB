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
#include <sys/stat.h>
#include <ctime>
#include <iostream>
#include <fstream>
#include <chrono>
#include <iomanip>
#include "login.h"
static bool keyLoaded = true;
static bool isLogin = true;
static bool showLoginSuccess = false;
static float loginSuccessTimer = 0.0f;
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
        setup = true;
    }

    if (SetResolution && Width != glWidth) {
        SetResolution(Width, Height, true);
    }

    ImGuiIO &io = ImGui::GetIO();
    static bool WantTextInputLast = false;
    if (io.WantTextInput && !WantTextInputLast) ShowSoftKeyboardInput();
    WantTextInputLast = io.WantTextInput;

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
                    loginSuccessTimer = 0.0f;
                }
            }
            ImGui::Text(OBFUSCATE("Ấn Tăng/Giảm Âm Lượng Để Hiện/Ẩn Menu"));
            if (!err.empty() && err != std::string(OBFUSCATE("OK"))) {
                ImGui::Text(OBFUSCATE("Error: %s"), err.c_str());
            }
            ImGui::EndPopup();
        }
    } else {
            // Auto Like timer logic
            if (AutoLike.Enable && !AutoLike.IsSending) {
                float now = GetTimeSeconds();
                if (now - g_lastLikeTime >= AutoLike.Interval) {
                    AutoLike.IsSending = true;
                    SendLikeRequest();
                    AutoLike.IsSending = false;
                    g_lastLikeTime = now;
                }
            }

            if (ShowMenu) {
                ImGui::OpenPopup(OBFUSCATE("##MenuMod"));
                ImGui::SetNextWindowSize(ImVec2(900, 0));
                ImGui::SetNextWindowPos(ImGui::GetMainViewport()->GetCenter(), ImGuiCond_Appearing, ImVec2(0.5f, 0.5f));
                if (ImGui::BeginPopupModal(OBFUSCATE("##MenuMod"), NULL, ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoMove)) {
                    ImGuiWindow* window = ImGui::GetCurrentWindow();
                    ImDrawList* drawList = window->DrawList;
                    ImVec2 windowPos = window->Pos;
                    ImVec2 windowSize = window->Size;
                    ImVec2 textSize = ImGui::CalcTextSize("AUTO LIKE " __DATE__ " " __TIME__);
                    ImVec2 textPos = ImVec2(windowPos.x + (windowSize.x - textSize.x) * 0.5f, windowPos.y + 24.0f);
                    drawList->AddText(textPos, IM_COL32_WHITE, "AUTO LIKE " __DATE__ " " __TIME__);

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

                    ImGui::Text(OBFUSCATE("AUTO LIKE"));
                    ImGui::Text(OBFUSCATE("FPS: %.1f"), ImGui::GetIO().Framerate);

                    ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 1 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    if (ImGui::Button(OBFUSCATE(ICON_FA_HEART " Auto Like"), ImVec2(170, 60))) TabMenu = 1;
                    ImGui::PopStyleColor();

                    ImGui::PushStyleColor(ImGuiCol_Button, TabMenu == 2 ? ImGui::GetStyle().Colors[ImGuiCol_ButtonHovered] : ImGui::GetStyle().Colors[ImGuiCol_Button]);
                    if (ImGui::Button(OBFUSCATE(ICON_FA_WRENCH " Debug"), ImVec2(170, 60))) TabMenu = 2;
                    ImGui::PopStyleColor();

                    ImGui::NextColumn();

                    // ===== TAB 1: AUTO LIKE PROFILE =====
                    if (TabMenu == 1) {
                        ImGui::BeginChild(OBFUSCATE("##ChildTab1"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.8f, 0.0f, 1.0f));
                        ImGui::Text(OBFUSCATE("--- Auto Like Profile ---"));
                        ImGui::PopStyleColor();
                        ImGui::Spacing();

                        // UID display
                        ImGui::Text(OBFUSCATE("UID hien tai:"));
                        ImGui::PushItemWidth(-1);
                        ImGui::InputText(OBFUSCATE("##UidInput"), AutoLike.UidStr, sizeof(AutoLike.UidStr), ImGuiInputTextFlags_ReadOnly);
                        ImGui::PopItemWidth();

                        // Paste UID button
                        if (ImGui::Button(OBFUSCATE("Dan UID moi"), ImVec2(-1, 40))) {
                            auto clipText = getClipboard();
                            if (!clipText.empty()) {
                                strncpy(AutoLike.UidStr, clipText.c_str(), sizeof(AutoLike.UidStr) - 1);
                                AutoLike.UidStr[sizeof(AutoLike.UidStr) - 1] = '\0';
                                AddDebugLog("Pasted UID: %s", AutoLike.UidStr);
                            }
                        }

                        // Save UID button
                        if (ImGui::Button(OBFUSCATE("Luu UID"), ImVec2(-1, 40))) {
                            char* endptr = nullptr;
                            uint64_t newUid = strtoull(AutoLike.UidStr, &endptr, 10);
                            if (endptr && *endptr == '\0' && newUid > 0) {
                                AutoLike.TargetUid = newUid;
                                AddDebugLog("Saved UID: %llu", (unsigned long long)newUid);
                                snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "Da luu UID: %llu", (unsigned long long)newUid);
                            } else {
                                snprintf(AutoLike.StatusMsg, sizeof(AutoLike.StatusMsg), "UID khong hop le!");
                                AddDebugLog("Invalid UID string: %s", AutoLike.UidStr);
                            }
                        }

                        ImGui::Spacing();
                        ImGui::Separator();
                        ImGui::Spacing();

                        // LogicWorldId
                        ImGui::Text(OBFUSCATE("Logic World ID:"));
                        ImGui::PushItemWidth(-1);
                        ImGui::InputInt(OBFUSCATE("##WorldId"), (int*)&AutoLike.LogicWorldId);
                        ImGui::PopItemWidth();

                        ImGui::Spacing();
                        ImGui::Separator();
                        ImGui::Spacing();

                        // Enable toggle
                        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.1f, 1.0f, 0.4f, 1.0f));
                        ImGui::Checkbox(OBFUSCATE("BAT AUTO LIKE"), &AutoLike.Enable);
                        ImGui::PopStyleColor();

                        // Interval slider
                        ImGui::Text(OBFUSCATE("Khoang cach (giay):"));
                        ImGui::PushItemWidth(-1);
                        ImGui::SliderFloat(OBFUSCATE("##LikeInterval"), &AutoLike.Interval, 0.5f, 30.0f, "%.1f s");
                        ImGui::PopItemWidth();

                        ImGui::Spacing();
                        ImGui::Separator();
                        ImGui::Spacing();

                        // Status display
                        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.0f, 1.0f, 1.0f, 1.0f));
                        ImGui::Text(OBFUSCATE("Trang thai: %s"), AutoLike.StatusMsg);
                        ImGui::PopStyleColor();
                        ImGui::Text(OBFUSCATE("So like da gui: %d"), AutoLike.LikeCount);
                        ImGui::Text(OBFUSCATE("UID: %llu"), (unsigned long long)AutoLike.TargetUid);
                        ImGui::Text(OBFUSCATE("WorldID: %u"), AutoLike.LogicWorldId);

                        if (AutoLike.Enable) {
                            ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.0f, 1.0f, 0.0f, 1.0f));
                            ImGui::Text(OBFUSCATE(">> DANG CHAY <<"));
                            ImGui::PopStyleColor();
                        }

                        ImGui::EndChild();
                    }

                    // ===== TAB 2: DEBUG =====
                    if (TabMenu == 2) {
                        ImGui::BeginChild(OBFUSCATE("##ChildTab2"), ImVec2(ImGui::GetContentRegionAvail().x, ImGui::GetContentRegionAvail().y), false);

                        ImGui::TextColored(ImVec4(1, 1, 0, 1), "DEBUG INFO");
                        ImGui::Separator();

                        // il2cpp base
                        ImGui::Text("il2cpp base: 0x%llx", (unsigned long long)g_il2cpp_base);
                        ImGui::Separator();

                        // il2cpp API status
                        ImGui::TextColored(ImVec4(0, 1, 1, 1), "IL2CPP API");
                        ImGui::Text("Resolved: %s", g_il2cppApiResolved ? "YES" : "NO");
                        ImGui::Text("domain_get: %p", (void*)fn_il2cpp_domain_get);
                        ImGui::Text("domain_get_assemblies: %p", (void*)fn_il2cpp_domain_get_assemblies);
                        ImGui::Text("assembly_get_image: %p", (void*)fn_il2cpp_assembly_get_image);
                        ImGui::Text("class_from_name: %p", (void*)fn_il2cpp_class_from_name);
                        ImGui::Text("object_new: %p", (void*)fn_il2cpp_object_new);
                        ImGui::Text("field_from_name: %p", (void*)fn_il2cpp_class_get_field_from_name);
                        ImGui::Text("static_get_value: %p", (void*)fn_il2cpp_field_static_get_value);
                        ImGui::Text("class_get_parent: %p", (void*)fn_il2cpp_class_get_parent);
                        ImGui::Separator();

                        // Method pointers
                        ImGui::TextColored(ImVec4(0, 1, 1, 1), "METHOD POINTERS (RVA)");
                        ImGui::Text("new_CSPkg: %p", (void*)fn_new_CSPkg);
                        ImGui::Text("new_COMDT_ACNT_UNIQ: %p", (void*)fn_new_COMDT_ACNT_UNIQ);
                        ImGui::Text("SendLobbyMsg: %p", (void*)fn_SendLobbyMsg);
                        ImGui::Text("GetNetworkModule: %p", (void*)fn_GetNetworkModuleInstance);
                        ImGui::Separator();

                        // Field offsets
                        ImGui::TextColored(ImVec4(0, 1, 1, 1), "FIELD OFFSETS");
                        ImGui::Text("CSPkg.stPkgHead: 0x%lx", (unsigned long)OFF_CSPkg_stPkgHead);
                        ImGui::Text("CSPkg.stPkgData: 0x%lx", (unsigned long)OFF_CSPkg_stPkgData);
                        ImGui::Text("CSPkgHead.dwMsgID: 0x%lx", (unsigned long)OFF_CSPkgHead_dwMsgID);
                        ImGui::Text("CSPkgBody.dataObject: 0x%lx", (unsigned long)OFF_CSPkgBody_dataObject);
                        ImGui::Text("ACNT_UNIQ.ullUid: 0x%lx", (unsigned long)OFF_COMDT_ACNT_UNIQ_ullUid);
                        ImGui::Text("ACNT_UNIQ.dwLogicWorldId: 0x%lx", (unsigned long)OFF_COMDT_ACNT_UNIQ_dwLogicWorldId);
                        ImGui::Text("CSID_HOME_PAGE_LIKE_REQ: %u", CSID_HOME_PAGE_LIKE_REQ);
                        ImGui::Separator();

                        // Auto Like status
                        ImGui::TextColored(ImVec4(1, 0.5, 0, 1), "AUTO LIKE STATUS");
                        ImGui::Text("Enable: %s", AutoLike.Enable ? "ON" : "OFF");
                        ImGui::Text("TargetUid: %llu", (unsigned long long)AutoLike.TargetUid);
                        ImGui::Text("WorldID: %u", AutoLike.LogicWorldId);
                        ImGui::Text("LikeCount: %d", AutoLike.LikeCount);
                        ImGui::Text("Interval: %.1f s", AutoLike.Interval);
                        ImGui::Text("Status: %s", AutoLike.StatusMsg);
                        ImGui::Separator();

                        // Debug log ring buffer
                        ImGui::TextColored(ImVec4(1, 1, 0, 1), "DEBUG LOG (%d entries)", g_debugLogCount);
                        ImGui::BeginChild(OBFUSCATE("##DebugLogScroll"), ImVec2(-1, 300), true);
                        int start = (g_debugLogCount < MAX_DEBUG_LOGS) ? 0 : g_debugLogHead;
                        for (int i = 0; i < g_debugLogCount; i++) {
                            int idx = (start + i) % MAX_DEBUG_LOGS;
                            ImGui::TextWrapped("[%.1f] %s", g_debugLogs[idx].timestamp, g_debugLogs[idx].msg);
                        }
                        if (g_debugLogCount > 0)
                            ImGui::SetScrollHereY(1.0f);
                        ImGui::EndChild();

                        ImGui::Checkbox(OBFUSCATE("An Icon Menu"), &HideIcon);

                        ImGui::EndChild();
                    }

                    ImGui::EndPopup();
                }
            } else {
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
                    if (ImGui::Button(fpsString.c_str(), ImVec2(64, 64))) {
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

    // Resolve il2cpp C API (dlsym)
    ResolveIl2CppApi();

    // Resolve RVA-based method pointers for auto-like
    fn_new_CSPkg = (new_CSPkg_t)(g_il2cpp_base + 0x37A0334);
    fn_new_COMDT_ACNT_UNIQ = (new_COMDT_ACNT_UNIQ_t)(g_il2cpp_base + 0x3758B08);
    fn_SendLobbyMsg = (SendLobbyMsg_t)(g_il2cpp_base + 0x78EC9C8);

    AddDebugLog("RVA resolved: CSPkg=%p ACNT=%p Send=%p base=0x%llx",
        (void*)fn_new_CSPkg, (void*)fn_new_COMDT_ACNT_UNIQ, (void*)fn_SendLobbyMsg,
        (unsigned long long)g_il2cpp_base);

    // FPS Unlock (QoL)
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_Supported60FPSMode", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_Supported90FPSMode", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_Supported120FPSMode", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "get_SupportedBoth60FPS_CameraHeight", 0, TRUE, _TRUE);
    HOOKAU("Project_d.dll", "Assets.Scripts.Framework", "GameSettings", "IsIPadDevice", 0, TRUE, _TRUE);

    __android_log_print(ANDROID_LOG_INFO, "AUTOLIKE", "Init complete - all methods resolved");
    AddDebugLog("Init complete");

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

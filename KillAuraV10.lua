-- ============================================================
-- KILL AURA + ESP MOBILE V10 - UNIVERSAL EDITION
-- Nang cap tu V9: Tab UI, Aimbot, Config Save/Load,
-- Anti-AFK, Infinite Jump, Notification, Target Priority,
-- Skeleton ESP, FOV Circle, Performance Optimization
-- ============================================================

-- ============================================================
-- CLEANUP: Xoa instance cu neu re-execute
-- ============================================================
pcall(function()
    local old = game:GetService("CoreGui"):FindFirstChild("KillAuraV10")
    if old then old:Destroy() end
end)
pcall(function()
    local old = game:GetService("CoreGui"):FindFirstChild("KillAuraV9")
    if old then old:Destroy() end
end)

-- ============================================================
-- SERVICES
-- ============================================================
local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- ============================================================
-- SETTINGS
-- ============================================================
local Settings = {
    -- Kill Aura
    Enabled = false,
    Radius = 150,
    Delay = 0.15,
    TargetPart = "Head",
    WallCheck = false,
    AuraMode = "Auto",
    TargetPriority = "Closest",
    MaxTargets = 5,
    AutoWeaponEquip = true,
    LastAttack = 0,
    DetectedMethod = nil,
    CachedRemotes = {},
    AllDamageRemotes = {},
    SpyRemotes = {},

    -- Aimbot
    AimbotEnabled = false,
    AimbotFOV = 120,
    AimbotSmooth = 0.3,
    AimbotPart = "Head",
    ShowFOVCircle = true,
    AimbotTeamCheck = true,

    -- ESP
    ESPEnabled = false,
    ESPBoxes = true,
    ESPNames = true,
    ESPDistance = true,
    ESPHealth = true,
    ESPTracers = true,
    ESPChams = true,
    ESPSkeleton = false,
    ESPTeamCheck = true,
    ESPColor = Color3.fromRGB(255, 50, 50),
    ESPFriendlyColor = Color3.fromRGB(50, 255, 50),
    ESPMaxDistance = 2000,
    UseDrawingAPI = true,
    UseFallbackESP = false,

    -- Misc
    AntiAFK = true,
    InfiniteJump = false,
    SpeedEnabled = false,
    SpeedValue = 32,
    FlyEnabled = false,
    FlySpeed = 50,
    AntiVoid = false,

    -- UI
    Minimized = false,
    CurrentTab = "KillAura",
    DebugMode = false,
    Theme = "Purple",

    -- Internal
    _Notifications = {},
    _Connections = {},
    _FOVCircle = nil,
}

-- ============================================================
-- THEME COLORS
-- ============================================================
local Themes = {
    Purple = {
        Accent = Color3.fromRGB(120, 60, 200),
        AccentLight = Color3.fromRGB(150, 100, 230),
        Background = Color3.fromRGB(18, 18, 24),
        Surface = Color3.fromRGB(28, 28, 38),
        SurfaceLight = Color3.fromRGB(40, 40, 55),
        Text = Color3.fromRGB(240, 240, 240),
        TextDim = Color3.fromRGB(160, 160, 180),
        Success = Color3.fromRGB(50, 200, 80),
        Danger = Color3.fromRGB(220, 50, 50),
        Warning = Color3.fromRGB(255, 180, 50),
        Info = Color3.fromRGB(80, 160, 255),
    },
    Red = {
        Accent = Color3.fromRGB(200, 40, 40),
        AccentLight = Color3.fromRGB(230, 80, 80),
        Background = Color3.fromRGB(20, 16, 16),
        Surface = Color3.fromRGB(35, 25, 25),
        SurfaceLight = Color3.fromRGB(55, 35, 35),
        Text = Color3.fromRGB(240, 240, 240),
        TextDim = Color3.fromRGB(180, 160, 160),
        Success = Color3.fromRGB(50, 200, 80),
        Danger = Color3.fromRGB(255, 60, 60),
        Warning = Color3.fromRGB(255, 180, 50),
        Info = Color3.fromRGB(80, 160, 255),
    },
    Blue = {
        Accent = Color3.fromRGB(40, 80, 200),
        AccentLight = Color3.fromRGB(80, 120, 230),
        Background = Color3.fromRGB(16, 18, 24),
        Surface = Color3.fromRGB(25, 28, 40),
        SurfaceLight = Color3.fromRGB(35, 40, 58),
        Text = Color3.fromRGB(240, 240, 240),
        TextDim = Color3.fromRGB(160, 170, 190),
        Success = Color3.fromRGB(50, 200, 80),
        Danger = Color3.fromRGB(220, 50, 50),
        Warning = Color3.fromRGB(255, 180, 50),
        Info = Color3.fromRGB(100, 180, 255),
    },
}

local function getTheme()
    return Themes[Settings.Theme] or Themes.Purple
end

-- ============================================================
-- DETECT EXECUTOR CAPABILITIES
-- ============================================================
local hasDrawing = pcall(function()
    local test = Drawing.new("Square")
    test:Remove()
end)
Settings.UseDrawingAPI = hasDrawing
Settings.UseFallbackESP = not hasDrawing

local hasFileSystem = pcall(function() return type(writefile) == "function" and type(readfile) == "function" end)
local hasHookMeta = type(hookmetamethod) == "function"

local function log(msg)
    if Settings.DebugMode then print("[KillAura V10] " .. tostring(msg)) end
end

log("V10 Executor: Drawing=" .. tostring(hasDrawing) .. ", FS=" .. tostring(hasFileSystem) .. ", HookMeta=" .. tostring(hasHookMeta))

-- ============================================================
-- CONFIG SAVE / LOAD
-- ============================================================
local CONFIG_FILE = "KillAuraV10_Config.json"

local function saveConfig()
    if not hasFileSystem then return false end
    local data = {
        Radius = Settings.Radius,
        Delay = Settings.Delay,
        TargetPart = Settings.TargetPart,
        WallCheck = Settings.WallCheck,
        AuraMode = Settings.AuraMode,
        TargetPriority = Settings.TargetPriority,
        MaxTargets = Settings.MaxTargets,
        AimbotFOV = Settings.AimbotFOV,
        AimbotSmooth = Settings.AimbotSmooth,
        AimbotPart = Settings.AimbotPart,
        ShowFOVCircle = Settings.ShowFOVCircle,
        ESPBoxes = Settings.ESPBoxes,
        ESPNames = Settings.ESPNames,
        ESPDistance = Settings.ESPDistance,
        ESPHealth = Settings.ESPHealth,
        ESPTracers = Settings.ESPTracers,
        ESPChams = Settings.ESPChams,
        ESPSkeleton = Settings.ESPSkeleton,
        ESPTeamCheck = Settings.ESPTeamCheck,
        ESPMaxDistance = Settings.ESPMaxDistance,
        AntiAFK = Settings.AntiAFK,
        SpeedValue = Settings.SpeedValue,
        FlySpeed = Settings.FlySpeed,
        Theme = Settings.Theme,
        DebugMode = Settings.DebugMode,
    }
    pcall(function()
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
    return true
end

local function loadConfig()
    if not hasFileSystem then return false end
    local ok, content = pcall(function() return readfile(CONFIG_FILE) end)
    if not ok or not content then return false end
    local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not ok2 or type(data) ~= "table" then return false end
    for key, value in pairs(data) do
        if Settings[key] ~= nil and type(Settings[key]) == type(value) then
            Settings[key] = value
        end
    end
    return true
end

loadConfig()

-- ============================================================
-- NOTIFICATION SYSTEM
-- ============================================================
local NotificationContainer
local function showNotification(text, duration, color)
    duration = duration or 3
    color = color or getTheme().Info

    if not NotificationContainer then return end

    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(1, 0, 0, 0)
    notif.BackgroundColor3 = getTheme().Surface
    notif.BorderSizePixel = 0
    notif.ClipsDescendants = true
    notif.Parent = NotificationContainer
    Instance.new("UICorner", notif).CornerRadius = UDim.new(0, 8)

    local accent = Instance.new("Frame")
    accent.Size = UDim2.new(0, 3, 1, 0)
    accent.BackgroundColor3 = color
    accent.BorderSizePixel = 0
    accent.Parent = notif

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = getTheme().Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.Parent = notif

    TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, 32)}):Play()

    task.delay(duration, function()
        local tween = TweenService:Create(notif, TweenInfo.new(0.3, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, 0)})
        tween:Play()
        tween.Completed:Connect(function() notif:Destroy() end)
    end)
end

-- ============================================================
-- UI HELPERS
-- ============================================================
local function makeButton(parent, props)
    local btn = Instance.new("TextButton")
    btn.Size = props.Size
    btn.Position = props.Position
    btn.BackgroundColor3 = props.Color or getTheme().SurfaceLight
    btn.TextColor3 = props.TextColor or getTheme().Text
    btn.Text = props.Text or ""
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = props.TextSize or 13
    btn.AutoButtonColor = true
    btn.Parent = parent
    if props.ZIndex then btn.ZIndex = props.ZIndex end
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, props.Corner or 8)

    local lastClick = 0
    btn.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick < 0.25 then return end
        lastClick = now
        if props.Callback then props.Callback() end
    end)
    return btn
end

local function makeToggle(parent, props)
    local theme = getTheme()
    local container = Instance.new("Frame")
    container.Size = props.Size or UDim2.new(1, -20, 0, 32)
    container.Position = props.Position
    container.BackgroundTransparency = 1
    container.Parent = parent
    if props.ZIndex then container.ZIndex = props.ZIndex end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = props.Text or ""
    label.TextColor3 = theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    if props.ZIndex then label.ZIndex = props.ZIndex end

    local toggleBg = Instance.new("TextButton")
    toggleBg.Size = UDim2.new(0, 42, 0, 22)
    toggleBg.Position = UDim2.new(1, -42, 0.5, -11)
    toggleBg.BackgroundColor3 = props.Default and theme.Success or Color3.fromRGB(60, 60, 70)
    toggleBg.Text = ""
    toggleBg.AutoButtonColor = false
    toggleBg.Parent = container
    if props.ZIndex then toggleBg.ZIndex = props.ZIndex end
    Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 18, 0, 18)
    knob.Position = props.Default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.Parent = toggleBg
    if props.ZIndex then knob.ZIndex = (props.ZIndex or 0) + 1 end
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local state = props.Default or false
    local lastClick = 0

    local function updateVisual()
        local targetPos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
        local targetColor = state and theme.Success or Color3.fromRGB(60, 60, 70)
        TweenService:Create(knob, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Position = targetPos}):Play()
        TweenService:Create(toggleBg, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {BackgroundColor3 = targetColor}):Play()
    end

    toggleBg.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick < 0.25 then return end
        lastClick = now
        state = not state
        updateVisual()
        if props.OnChanged then props.OnChanged(state) end
    end)

    return {
        SetValue = function(v)
            state = v
            updateVisual()
        end,
        GetValue = function() return state end,
        Container = container,
    }
end

local function makeSlider(parent, props)
    local theme = getTheme()
    local container = Instance.new("Frame")
    container.Size = props.Size or UDim2.new(1, -20, 0, 44)
    container.Position = props.Position
    container.BackgroundTransparency = 1
    container.Parent = parent
    if props.ZIndex then container.ZIndex = props.ZIndex end

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.TextColor3 = theme.Text
    label.Font = Enum.Font.Gotham
    label.TextSize = 11
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    if props.ZIndex then label.ZIndex = props.ZIndex end

    local formatValue = props.Format or function(v) return tostring(math.floor(v)) end
    label.Text = (props.Text or "") .. ": " .. formatValue(props.Default or props.Min)

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, 18)
    sliderBg.Position = UDim2.new(0, 0, 0, 20)
    sliderBg.BackgroundColor3 = theme.SurfaceLight
    sliderBg.BorderSizePixel = 0
    sliderBg.Active = true
    sliderBg.Parent = container
    if props.ZIndex then sliderBg.ZIndex = props.ZIndex end
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 6)

    local initialRel = ((props.Default or props.Min) - props.Min) / (props.Max - props.Min)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(math.clamp(initialRel, 0, 1), 0, 1, 0)
    fill.BackgroundColor3 = props.FillColor or theme.Accent
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    if props.ZIndex then fill.ZIndex = (props.ZIndex or 0) + 1 end
    Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 6)

    local dragging = false
    local function updateFromInput(inputPos)
        local absPos = sliderBg.AbsolutePosition.X
        local absSize = sliderBg.AbsoluteSize.X
        if absSize <= 0 then return end
        local rel = math.clamp((inputPos.X - absPos) / absSize, 0, 1)
        local value = props.Min + (props.Max - props.Min) * rel
        if props.Step then
            value = math.floor(value / props.Step + 0.5) * props.Step
        end
        value = math.clamp(value, props.Min, props.Max)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = (props.Text or "") .. ": " .. formatValue(value)
        if props.OnChanged then props.OnChanged(value) end
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateFromInput(input.Position)
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    local conn = UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.Touch or
            input.UserInputType == Enum.UserInputType.MouseMovement) then
            updateFromInput(input.Position)
        end
    end)
    table.insert(Settings._Connections, conn)

    return {
        SetValue = function(v)
            local rel = math.clamp((v - props.Min) / (props.Max - props.Min), 0, 1)
            fill.Size = UDim2.new(rel, 0, 1, 0)
            label.Text = (props.Text or "") .. ": " .. formatValue(v)
        end,
        Container = container,
    }
end

local function makeDraggable(handle, frame)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    local conn = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    table.insert(Settings._Connections, conn)
end

local function makeDropdown(parent, props)
    local theme = getTheme()
    local container = Instance.new("Frame")
    container.Size = props.Size or UDim2.new(1, -20, 0, 28)
    container.Position = props.Position
    container.BackgroundTransparency = 1
    container.ClipsDescendants = false
    container.Parent = parent
    if props.ZIndex then container.ZIndex = props.ZIndex end

    local mainBtn = Instance.new("TextButton")
    mainBtn.Size = UDim2.new(1, 0, 0, props.ButtonHeight or 26)
    mainBtn.BackgroundColor3 = props.Color or theme.SurfaceLight
    mainBtn.TextColor3 = theme.Text
    mainBtn.Text = "  " .. props.Default
    mainBtn.Font = Enum.Font.GothamBold
    mainBtn.TextSize = props.TextSize or 11
    mainBtn.AutoButtonColor = true
    mainBtn.TextXAlignment = Enum.TextXAlignment.Left
    mainBtn.Parent = container
    if props.ZIndex then mainBtn.ZIndex = props.ZIndex end
    Instance.new("UICorner", mainBtn).CornerRadius = UDim.new(0, 6)

    local arrow = Instance.new("TextLabel")
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -22, 0, 0)
    arrow.BackgroundTransparency = 1
    arrow.Text = "v"
    arrow.TextColor3 = theme.TextDim
    arrow.Font = Enum.Font.GothamBold
    arrow.TextSize = 10
    arrow.Parent = mainBtn
    if props.ZIndex then arrow.ZIndex = (props.ZIndex or 0) + 1 end

    local optionHeight = props.OptionHeight or 26
    local maxVisible = props.MaxVisibleOptions or 6
    local totalHeight = optionHeight * #props.Options
    local menuHeight = math.min(totalHeight, optionHeight * maxVisible)

    local menuFrame = Instance.new("Frame")
    menuFrame.Size = UDim2.new(1, 0, 0, 0)
    menuFrame.Position = UDim2.new(0, 0, 0, (props.ButtonHeight or 26) + 2)
    menuFrame.BackgroundColor3 = theme.Surface
    menuFrame.BorderSizePixel = 0
    menuFrame.Visible = false
    menuFrame.ClipsDescendants = true
    menuFrame.Parent = container
    if props.ZIndex then menuFrame.ZIndex = (props.ZIndex or 0) + 5 end
    Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0, 6)

    local contentFrame
    local needScroll = totalHeight > menuHeight

    if needScroll then
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, 0, 1, 0)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.BorderSizePixel = 0
        scrollFrame.ScrollBarThickness = 3
        scrollFrame.ScrollBarImageColor3 = theme.AccentLight
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
        scrollFrame.ScrollingEnabled = true
        scrollFrame.Parent = menuFrame
        if props.ZIndex then scrollFrame.ZIndex = (props.ZIndex or 0) + 6 end

        contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(1, 0, 0, totalHeight)
        contentFrame.BackgroundTransparency = 1
        contentFrame.Parent = scrollFrame
    else
        contentFrame = menuFrame
    end

    local buttons = {}
    local menuOpen = false
    local currentValue = props.Default
    local lastMainClick = 0

    for i, optionName in ipairs(props.Options) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, optionHeight)
        btn.Position = UDim2.new(0, 0, 0, (i - 1) * optionHeight)
        btn.BackgroundColor3 = optionName == props.Default and theme.Accent or theme.Surface
        btn.TextColor3 = theme.Text
        btn.Text = "  " .. optionName
        btn.Font = Enum.Font.Gotham
        btn.TextSize = (props.TextSize or 11)
        btn.AutoButtonColor = true
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Visible = false
        btn.Parent = contentFrame
        if props.ZIndex then btn.ZIndex = (props.ZIndex or 0) + 7 end
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local lastBtnClick = 0
        local function selectOption()
            local now = tick()
            if now - lastBtnClick < 0.25 then return end
            lastBtnClick = now
            currentValue = optionName
            mainBtn.Text = "  " .. optionName
            for _, b in ipairs(buttons) do
                b.BackgroundColor3 = theme.Surface
            end
            btn.BackgroundColor3 = theme.Accent
            menuOpen = false
            menuFrame.Visible = false
            TweenService:Create(menuFrame, TweenInfo.new(0.15), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            for _, b in ipairs(buttons) do b.Visible = false end
            arrow.Text = "v"
            if props.OnChanged then props.OnChanged(optionName) end
        end

        btn.MouseButton1Click:Connect(selectOption)
        btn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.Touch then
                task.wait(0.05)
                selectOption()
            end
        end)
        table.insert(buttons, btn)
    end

    local function toggleMenu()
        local now = tick()
        if now - lastMainClick < 0.25 then return end
        lastMainClick = now
        menuOpen = not menuOpen
        if menuOpen then
            menuFrame.Visible = true
            for _, b in ipairs(buttons) do b.Visible = true end
            TweenService:Create(menuFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quint), {Size = UDim2.new(1, 0, 0, menuHeight)}):Play()
            arrow.Text = "^"
        else
            TweenService:Create(menuFrame, TweenInfo.new(0.15), {Size = UDim2.new(1, 0, 0, 0)}):Play()
            task.delay(0.15, function()
                if not menuOpen then
                    menuFrame.Visible = false
                    for _, b in ipairs(buttons) do b.Visible = false end
                end
            end)
            arrow.Text = "v"
        end
    end

    mainBtn.MouseButton1Click:Connect(toggleMenu)
    mainBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            task.wait(0.05)
            toggleMenu()
        end
    end)

    return {
        SetValue = function(value)
            currentValue = value
            mainBtn.Text = "  " .. value
            for _, b in ipairs(buttons) do
                b.BackgroundColor3 = (b.Text == "  " .. value) and theme.Accent or theme.Surface
            end
        end,
        GetValue = function() return currentValue end,
        Close = function()
            menuOpen = false
            menuFrame.Visible = false
            for _, b in ipairs(buttons) do b.Visible = false end
            arrow.Text = "v"
        end,
    }
end

-- ============================================================
-- MAIN UI
-- ============================================================
local theme = getTheme()

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "KillAuraV10"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 10
ScreenGui.Parent = CoreGui

-- Notification container (top right)
NotificationContainer = Instance.new("Frame")
NotificationContainer.Size = UDim2.new(0, 200, 0, 300)
NotificationContainer.Position = UDim2.new(1, -210, 0, 40)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Parent = ScreenGui

local notifLayout = Instance.new("UIListLayout")
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 4)
notifLayout.VerticalAlignment = Enum.VerticalAlignment.Top
notifLayout.Parent = NotificationContainer

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 380)
MainFrame.Position = UDim2.new(0, 10, 0.2, 0)
MainFrame.BackgroundColor3 = theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.ZIndex = 5
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = theme.Accent
mainStroke.Thickness = 2

-- Title bar
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 34)
TitleBar.BackgroundColor3 = theme.Surface
TitleBar.BorderSizePixel = 0
TitleBar.Active = true
TitleBar.ZIndex = 6
TitleBar.Parent = MainFrame
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 12)

local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 14)
titleFix.Position = UDim2.new(0, 0, 1, -14)
titleFix.BackgroundColor3 = theme.Surface
titleFix.BorderSizePixel = 0
titleFix.ZIndex = 6
titleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Kill Aura V10"
Title.TextColor3 = theme.AccentLight
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 7
Title.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -30, 0, 5)
MinimizeBtn.BackgroundColor3 = theme.SurfaceLight
MinimizeBtn.TextColor3 = theme.Text
MinimizeBtn.Text = "-"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.AutoButtonColor = true
MinimizeBtn.ZIndex = 8
MinimizeBtn.Parent = TitleBar
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

-- Tab buttons
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.BackgroundColor3 = theme.Surface
TabBar.BorderSizePixel = 0
TabBar.ZIndex = 6
TabBar.Parent = MainFrame

local tabNames = {"KillAura", "ESP", "Aimbot", "Misc"}
local tabButtons = {}
local tabFrames = {}

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabNames, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabNames, 0, 0, 0)
    btn.BackgroundColor3 = name == Settings.CurrentTab and theme.Accent or theme.Surface
    btn.TextColor3 = theme.Text
    btn.Text = name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = true
    btn.ZIndex = 7
    btn.Parent = TabBar

    if i == 1 then
        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 0)
    end

    tabButtons[name] = btn
end

-- Tab content area
local ContentArea = Instance.new("ScrollingFrame")
ContentArea.Size = UDim2.new(1, 0, 1, -62)
ContentArea.Position = UDim2.new(0, 0, 0, 62)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel = 0
ContentArea.ScrollBarThickness = 3
ContentArea.ScrollBarImageColor3 = theme.Accent
ContentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentArea.ZIndex = 6
ContentArea.Parent = MainFrame

-- ============================================================
-- TAB: KILL AURA
-- ============================================================
local KillAuraTab = Instance.new("Frame")
KillAuraTab.Size = UDim2.new(1, 0, 0, 460)
KillAuraTab.BackgroundTransparency = 1
KillAuraTab.Visible = true
KillAuraTab.ZIndex = 6
KillAuraTab.Parent = ContentArea
tabFrames["KillAura"] = KillAuraTab

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 16)
StatusLabel.Position = UDim2.new(0, 10, 0, 4)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Initializing..."
StatusLabel.TextColor3 = theme.TextDim
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 6
StatusLabel.Parent = KillAuraTab

local SpyStatusLabel = Instance.new("TextLabel")
SpyStatusLabel.Size = UDim2.new(1, -20, 0, 14)
SpyStatusLabel.Position = UDim2.new(0, 10, 0, 20)
SpyStatusLabel.BackgroundTransparency = 1
SpyStatusLabel.Text = "Spy: 0 remotes"
SpyStatusLabel.TextColor3 = theme.Warning
SpyStatusLabel.Font = Enum.Font.Gotham
SpyStatusLabel.TextSize = 9
SpyStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
SpyStatusLabel.ZIndex = 6
SpyStatusLabel.Parent = KillAuraTab

-- Kill Aura Toggle Button
local KillAuraBtn
KillAuraBtn = makeButton(KillAuraTab, {
    Size = UDim2.new(0.55, -5, 0, 36),
    Position = UDim2.new(0.04, 0, 0, 40),
    Color = theme.Danger,
    Text = "Aura: OFF",
    TextSize = 13,
    ZIndex = 6,
    Callback = function()
        Settings.Enabled = not Settings.Enabled
        if Settings.Enabled then
            KillAuraBtn.Text = "Aura: ON"
            KillAuraBtn.BackgroundColor3 = theme.Success
            showNotification("Kill Aura ON - " .. Settings.AuraMode, 2, theme.Success)
        else
            KillAuraBtn.Text = "Aura: OFF"
            KillAuraBtn.BackgroundColor3 = theme.Danger
            showNotification("Kill Aura OFF", 2, theme.Danger)
        end
    end
})

local RescanBtn = makeButton(KillAuraTab, {
    Size = UDim2.new(0.35, 0, 0, 36),
    Position = UDim2.new(0.61, 0, 0, 40),
    Color = theme.SurfaceLight,
    Text = "Rescan",
    TextSize = 11,
    ZIndex = 6,
    Callback = function()
        scanRemotes()
        showNotification("Rescan complete", 2, theme.Info)
    end
})

-- Kill Aura Settings
local auraY = 86

local radiusSlider = makeSlider(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Radius",
    Min = 10, Max = 1500, Default = Settings.Radius, Step = 5,
    Format = function(v) return math.floor(v) .. " studs" end,
    ZIndex = 6,
    OnChanged = function(v) Settings.Radius = math.floor(v) end,
})
auraY = auraY + 50

local delaySlider = makeSlider(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Delay",
    Min = 0.02, Max = 1.0, Default = Settings.Delay, Step = 0.01,
    FillColor = theme.Info,
    Format = function(v) return string.format("%.2fs", v) end,
    ZIndex = 6,
    OnChanged = function(v) Settings.Delay = math.floor(v * 100) / 100 end,
})
auraY = auraY + 50

local maxTargetSlider = makeSlider(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Max Targets",
    Min = 1, Max = 20, Default = Settings.MaxTargets, Step = 1,
    FillColor = theme.Warning,
    ZIndex = 6,
    OnChanged = function(v) Settings.MaxTargets = math.floor(v) end,
})
auraY = auraY + 54

local partLabel = Instance.new("TextLabel")
partLabel.Size = UDim2.new(1, -20, 0, 14)
partLabel.Position = UDim2.new(0, 10, 0, auraY)
partLabel.BackgroundTransparency = 1
partLabel.Text = "Target Part:"
partLabel.TextColor3 = theme.TextDim
partLabel.Font = Enum.Font.Gotham
partLabel.TextSize = 11
partLabel.TextXAlignment = Enum.TextXAlignment.Left
partLabel.ZIndex = 6
partLabel.Parent = KillAuraTab
auraY = auraY + 16

local PartDropdown = makeDropdown(KillAuraTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, auraY),
    Default = Settings.TargetPart,
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso"},
    ZIndex = 6,
    OnChanged = function(v) Settings.TargetPart = v end,
})
auraY = auraY + 34

local priorityLabel = Instance.new("TextLabel")
priorityLabel.Size = UDim2.new(1, -20, 0, 14)
priorityLabel.Position = UDim2.new(0, 10, 0, auraY)
priorityLabel.BackgroundTransparency = 1
priorityLabel.Text = "Target Priority:"
priorityLabel.TextColor3 = theme.TextDim
priorityLabel.Font = Enum.Font.Gotham
priorityLabel.TextSize = 11
priorityLabel.TextXAlignment = Enum.TextXAlignment.Left
priorityLabel.ZIndex = 6
priorityLabel.Parent = KillAuraTab
auraY = auraY + 16

local PriorityDropdown = makeDropdown(KillAuraTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, auraY),
    Default = Settings.TargetPriority,
    Options = {"Closest", "LowestHP", "HighestHP", "Random"},
    ZIndex = 6,
    OnChanged = function(v) Settings.TargetPriority = v end,
})
auraY = auraY + 34

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(1, -20, 0, 14)
modeLabel.Position = UDim2.new(0, 10, 0, auraY)
modeLabel.BackgroundTransparency = 1
modeLabel.Text = "Aura Mode:"
modeLabel.TextColor3 = theme.Warning
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 11
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.ZIndex = 6
modeLabel.Parent = KillAuraTab
auraY = auraY + 16

local AuraModeDropdown = makeDropdown(KillAuraTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, auraY),
    Default = Settings.AuraMode,
    Options = {
        "Auto", "Normal", "SpyReplay", "Silent", "ClientDamage",
        "ToolActivate", "TeleportHit", "HitboxExpand", "FlingKill",
        "RaycastSpam", "MultiHit", "RemoteSpam", "NetworkBrute", "Universal",
    },
    MaxVisibleOptions = 6,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.AuraMode = v
        showNotification("Mode: " .. v, 2, theme.Warning)
    end,
})
auraY = auraY + 34

local wallCheckToggle = makeToggle(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Wall Check",
    Default = Settings.WallCheck,
    ZIndex = 6,
    OnChanged = function(v) Settings.WallCheck = v end,
})
auraY = auraY + 36

local autoEquipToggle = makeToggle(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Auto Equip Weapon",
    Default = Settings.AutoWeaponEquip,
    ZIndex = 6,
    OnChanged = function(v) Settings.AutoWeaponEquip = v end,
})
auraY = auraY + 36

KillAuraTab.Size = UDim2.new(1, 0, 0, auraY + 10)

-- ============================================================
-- TAB: ESP
-- ============================================================
local ESPTab = Instance.new("Frame")
ESPTab.Size = UDim2.new(1, 0, 0, 350)
ESPTab.BackgroundTransparency = 1
ESPTab.Visible = false
ESPTab.ZIndex = 6
ESPTab.Parent = ContentArea
tabFrames["ESP"] = ESPTab

local espY = 6

local ESPBtn
ESPBtn = makeButton(ESPTab, {
    Size = UDim2.new(0.92, 0, 0, 36),
    Position = UDim2.new(0.04, 0, 0, espY),
    Color = theme.SurfaceLight,
    Text = "ESP: OFF",
    TextSize = 14,
    ZIndex = 6,
    Callback = function()
        Settings.ESPEnabled = not Settings.ESPEnabled
        if Settings.ESPEnabled then
            ESPBtn.Text = "ESP: ON"
            ESPBtn.BackgroundColor3 = theme.Info
            showNotification("ESP ON", 2, theme.Info)
        else
            ESPBtn.Text = "ESP: OFF"
            ESPBtn.BackgroundColor3 = theme.SurfaceLight
            showNotification("ESP OFF", 2, theme.TextDim)
        end
    end
})
espY = espY + 44

local espToggles = {
    {text = "Boxes", key = "ESPBoxes"},
    {text = "Names", key = "ESPNames"},
    {text = "Distance", key = "ESPDistance"},
    {text = "Health Bar", key = "ESPHealth"},
    {text = "Tracers", key = "ESPTracers"},
    {text = "Chams (Highlight)", key = "ESPChams"},
    {text = "Skeleton", key = "ESPSkeleton"},
    {text = "Team Check", key = "ESPTeamCheck"},
}

for _, toggle in ipairs(espToggles) do
    makeToggle(ESPTab, {
        Position = UDim2.new(0, 10, 0, espY),
        Text = toggle.text,
        Default = Settings[toggle.key],
        ZIndex = 6,
        OnChanged = function(v) Settings[toggle.key] = v end,
    })
    espY = espY + 32
end

local espDistSlider = makeSlider(ESPTab, {
    Position = UDim2.new(0, 10, 0, espY),
    Text = "Max Distance",
    Min = 100, Max = 5000, Default = Settings.ESPMaxDistance, Step = 50,
    FillColor = theme.Info,
    ZIndex = 6,
    OnChanged = function(v) Settings.ESPMaxDistance = math.floor(v) end,
})
espY = espY + 50

ESPTab.Size = UDim2.new(1, 0, 0, espY + 10)

-- ============================================================
-- TAB: AIMBOT
-- ============================================================
local AimbotTab = Instance.new("Frame")
AimbotTab.Size = UDim2.new(1, 0, 0, 280)
AimbotTab.BackgroundTransparency = 1
AimbotTab.Visible = false
AimbotTab.ZIndex = 6
AimbotTab.Parent = ContentArea
tabFrames["Aimbot"] = AimbotTab

local aimY = 6

local AimbotBtn
AimbotBtn = makeButton(AimbotTab, {
    Size = UDim2.new(0.92, 0, 0, 36),
    Position = UDim2.new(0.04, 0, 0, aimY),
    Color = theme.SurfaceLight,
    Text = "Aimbot: OFF",
    TextSize = 14,
    ZIndex = 6,
    Callback = function()
        Settings.AimbotEnabled = not Settings.AimbotEnabled
        if Settings.AimbotEnabled then
            AimbotBtn.Text = "Aimbot: ON"
            AimbotBtn.BackgroundColor3 = theme.Warning
            showNotification("Aimbot ON", 2, theme.Warning)
        else
            AimbotBtn.Text = "Aimbot: OFF"
            AimbotBtn.BackgroundColor3 = theme.SurfaceLight
            showNotification("Aimbot OFF", 2, theme.TextDim)
        end
    end
})
aimY = aimY + 44

local fovSlider = makeSlider(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY),
    Text = "FOV Radius",
    Min = 20, Max = 500, Default = Settings.AimbotFOV, Step = 5,
    FillColor = theme.Warning,
    ZIndex = 6,
    OnChanged = function(v) Settings.AimbotFOV = math.floor(v) end,
})
aimY = aimY + 50

local smoothSlider = makeSlider(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY),
    Text = "Smoothing",
    Min = 0.05, Max = 1.0, Default = Settings.AimbotSmooth, Step = 0.05,
    FillColor = theme.AccentLight,
    Format = function(v) return string.format("%.0f%%", v * 100) end,
    ZIndex = 6,
    OnChanged = function(v) Settings.AimbotSmooth = math.floor(v * 100) / 100 end,
})
aimY = aimY + 50

local aimPartLabel = Instance.new("TextLabel")
aimPartLabel.Size = UDim2.new(1, -20, 0, 14)
aimPartLabel.Position = UDim2.new(0, 10, 0, aimY)
aimPartLabel.BackgroundTransparency = 1
aimPartLabel.Text = "Aim Part:"
aimPartLabel.TextColor3 = theme.TextDim
aimPartLabel.Font = Enum.Font.Gotham
aimPartLabel.TextSize = 11
aimPartLabel.TextXAlignment = Enum.TextXAlignment.Left
aimPartLabel.ZIndex = 6
aimPartLabel.Parent = AimbotTab
aimY = aimY + 16

local AimPartDropdown = makeDropdown(AimbotTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, aimY),
    Default = Settings.AimbotPart,
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    ZIndex = 6,
    OnChanged = function(v) Settings.AimbotPart = v end,
})
aimY = aimY + 34

local fovCircleToggle = makeToggle(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY),
    Text = "Show FOV Circle",
    Default = Settings.ShowFOVCircle,
    ZIndex = 6,
    OnChanged = function(v) Settings.ShowFOVCircle = v end,
})
aimY = aimY + 34

local aimTeamToggle = makeToggle(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY),
    Text = "Team Check",
    Default = Settings.AimbotTeamCheck,
    ZIndex = 6,
    OnChanged = function(v) Settings.AimbotTeamCheck = v end,
})
aimY = aimY + 34

AimbotTab.Size = UDim2.new(1, 0, 0, aimY + 10)

-- ============================================================
-- TAB: MISC
-- ============================================================
local MiscTab = Instance.new("Frame")
MiscTab.Size = UDim2.new(1, 0, 0, 350)
MiscTab.BackgroundTransparency = 1
MiscTab.Visible = false
MiscTab.ZIndex = 6
MiscTab.Parent = ContentArea
tabFrames["Misc"] = MiscTab

local miscY = 6

local antiAfkToggle = makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Anti-AFK",
    Default = Settings.AntiAFK,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.AntiAFK = v
        showNotification("Anti-AFK " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
    end,
})
miscY = miscY + 36

local infJumpToggle = makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Infinite Jump",
    Default = Settings.InfiniteJump,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.InfiniteJump = v
        showNotification("Infinite Jump " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
    end,
})
miscY = miscY + 36

local speedToggle = makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Speed Hack",
    Default = Settings.SpeedEnabled,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.SpeedEnabled = v
        showNotification("Speed " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
    end,
})
miscY = miscY + 36

local speedSlider = makeSlider(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Walk Speed",
    Min = 16, Max = 200, Default = Settings.SpeedValue, Step = 2,
    ZIndex = 6,
    OnChanged = function(v) Settings.SpeedValue = math.floor(v) end,
})
miscY = miscY + 50

local flyToggle = makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Fly",
    Default = Settings.FlyEnabled,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.FlyEnabled = v
        showNotification("Fly " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
    end,
})
miscY = miscY + 36

local flySpeedSlider = makeSlider(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Fly Speed",
    Min = 10, Max = 200, Default = Settings.FlySpeed, Step = 5,
    FillColor = theme.Info,
    ZIndex = 6,
    OnChanged = function(v) Settings.FlySpeed = math.floor(v) end,
})
miscY = miscY + 50

local antiVoidToggle = makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Anti-Void",
    Default = Settings.AntiVoid,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.AntiVoid = v
        showNotification("Anti-Void " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
    end,
})
miscY = miscY + 36

local debugToggle = makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY),
    Text = "Debug Mode",
    Default = Settings.DebugMode,
    ZIndex = 6,
    OnChanged = function(v) Settings.DebugMode = v end,
})
miscY = miscY + 40

-- Theme dropdown
local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -20, 0, 14)
themeLabel.Position = UDim2.new(0, 10, 0, miscY)
themeLabel.BackgroundTransparency = 1
themeLabel.Text = "Theme (next re-execute):"
themeLabel.TextColor3 = theme.TextDim
themeLabel.Font = Enum.Font.Gotham
themeLabel.TextSize = 11
themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.ZIndex = 6
themeLabel.Parent = MiscTab
miscY = miscY + 16

local ThemeDropdown = makeDropdown(MiscTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, miscY),
    Default = Settings.Theme,
    Options = {"Purple", "Red", "Blue"},
    ZIndex = 6,
    OnChanged = function(v)
        Settings.Theme = v
        saveConfig()
    end,
})
miscY = miscY + 38

-- Save/Load buttons
local SaveBtn = makeButton(MiscTab, {
    Size = UDim2.new(0.44, 0, 0, 32),
    Position = UDim2.new(0.04, 0, 0, miscY),
    Color = theme.Success,
    Text = "Save Config",
    TextSize = 11,
    ZIndex = 6,
    Callback = function()
        if saveConfig() then
            showNotification("Config saved!", 2, theme.Success)
        else
            showNotification("Save failed (no filesystem)", 3, theme.Danger)
        end
    end
})

local LoadBtn = makeButton(MiscTab, {
    Size = UDim2.new(0.44, 0, 0, 32),
    Position = UDim2.new(0.52, 0, 0, miscY),
    Color = theme.Info,
    Text = "Load Config",
    TextSize = 11,
    ZIndex = 6,
    Callback = function()
        if loadConfig() then
            showNotification("Config loaded!", 2, theme.Info)
        else
            showNotification("No config found", 2, theme.Warning)
        end
    end
})
miscY = miscY + 40

-- Destroy button
local DestroyBtn = makeButton(MiscTab, {
    Size = UDim2.new(0.92, 0, 0, 32),
    Position = UDim2.new(0.04, 0, 0, miscY),
    Color = theme.Danger,
    Text = "Destroy Script",
    TextSize = 12,
    ZIndex = 6,
    Callback = function()
        for _, conn in ipairs(Settings._Connections) do
            pcall(function() conn:Disconnect() end)
        end
        if Settings._FOVCircle then
            pcall(function() Settings._FOVCircle:Remove() end)
        end
        for char, _ in pairs(ESP_Cache or {}) do
            pcall(function() RemoveESP(char) end)
        end
        ScreenGui:Destroy()
        showNotification = function() end
    end
})
miscY = miscY + 40

MiscTab.Size = UDim2.new(1, 0, 0, miscY + 10)

-- ============================================================
-- TAB SWITCHING LOGIC
-- ============================================================
local function switchTab(tabName)
    Settings.CurrentTab = tabName
    for name, frame in pairs(tabFrames) do
        frame.Visible = (name == tabName)
    end
    for name, btn in pairs(tabButtons) do
        btn.BackgroundColor3 = (name == tabName) and theme.Accent or theme.Surface
    end
    local activeFrame = tabFrames[tabName]
    if activeFrame then
        ContentArea.CanvasSize = UDim2.new(0, 0, 0, activeFrame.Size.Y.Offset)
    end
end

for name, btn in pairs(tabButtons) do
    local lastClick = 0
    btn.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick < 0.25 then return end
        lastClick = now
        switchTab(name)
    end)
end

switchTab(Settings.CurrentTab)

-- ============================================================
-- MINI ICON
-- ============================================================
local MiniIcon = Instance.new("Frame")
MiniIcon.Size = UDim2.new(0, 50, 0, 50)
MiniIcon.Position = UDim2.new(0, 10, 0.5, -25)
MiniIcon.BackgroundColor3 = theme.Accent
MiniIcon.BorderSizePixel = 0
MiniIcon.Active = true
MiniIcon.Visible = false
MiniIcon.ZIndex = 100
MiniIcon.Parent = ScreenGui
Instance.new("UICorner", MiniIcon).CornerRadius = UDim.new(1, 0)

local miniStroke = Instance.new("UIStroke", MiniIcon)
miniStroke.Color = theme.Text
miniStroke.Thickness = 2

local MiniIconText = Instance.new("TextLabel")
MiniIconText.Size = UDim2.new(1, 0, 0.7, 0)
MiniIconText.BackgroundTransparency = 1
MiniIconText.Text = "V10"
MiniIconText.TextColor3 = theme.Text
MiniIconText.Font = Enum.Font.GothamBold
MiniIconText.TextSize = 14
MiniIconText.ZIndex = 102
MiniIconText.Parent = MiniIcon

local MiniStatusDot = Instance.new("Frame")
MiniStatusDot.Size = UDim2.new(0, 12, 0, 12)
MiniStatusDot.Position = UDim2.new(1, -6, 0, -4)
MiniStatusDot.BackgroundColor3 = Color3.fromRGB(255, 100, 100)
MiniStatusDot.BorderSizePixel = 0
MiniStatusDot.ZIndex = 103
MiniStatusDot.Parent = MiniIcon
Instance.new("UICorner", MiniStatusDot).CornerRadius = UDim.new(1, 0)

local MiniStatusLabel = Instance.new("TextLabel")
MiniStatusLabel.Size = UDim2.new(1, 0, 0, 12)
MiniStatusLabel.Position = UDim2.new(0, 0, 0.7, 0)
MiniStatusLabel.BackgroundTransparency = 1
MiniStatusLabel.Text = "OFF"
MiniStatusLabel.TextColor3 = theme.Text
MiniStatusLabel.Font = Enum.Font.GothamBold
MiniStatusLabel.TextSize = 9
MiniStatusLabel.ZIndex = 102
MiniStatusLabel.Parent = MiniIcon

local function updateMiniIcon()
    if Settings.Enabled then
        MiniStatusLabel.Text = "ON"
        MiniStatusDot.BackgroundColor3 = theme.Success
        MiniIcon.BackgroundColor3 = theme.Success
    else
        MiniStatusLabel.Text = "OFF"
        MiniStatusDot.BackgroundColor3 = theme.Danger
        MiniIcon.BackgroundColor3 = theme.Accent
    end
end

local MiniDragHandle = Instance.new("Frame")
MiniDragHandle.Size = UDim2.new(1, 0, 1, 0)
MiniDragHandle.BackgroundTransparency = 1
MiniDragHandle.Active = true
MiniDragHandle.ZIndex = 105
MiniDragHandle.Parent = MiniIcon

MiniDragHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        Settings.Minimized = false
        MiniIcon.Visible = false
        MainFrame.Visible = true
    end
end)

makeDraggable(MiniDragHandle, MiniIcon)

-- Minimize handler
local minimizeLastClick = 0
MinimizeBtn.MouseButton1Click:Connect(function()
    local now = tick()
    if now - minimizeLastClick < 0.25 then return end
    minimizeLastClick = now
    Settings.Minimized = true
    MainFrame.Visible = false
    MiniIcon.Visible = true
    updateMiniIcon()
end)

makeDraggable(TitleBar, MainFrame)

-- ============================================================
-- REMOTE SPY
-- ============================================================
local RemoteSpyData = {}

local function startRemoteSpy()
    if not hasHookMeta then
        log("hookmetamethod missing - RemoteSpy disabled")
        return
    end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local name = self.Name:lower()
            local keywords = {
                "fire", "hit", "damage", "weapon", "shoot", "attack",
                "gun", "bullet", "raycast", "combat", "melee", "sword",
                "slash", "strike", "impact", "projectile", "shot",
                "hurt", "kill", "wound", "critical"
            }
            local found = false
            for _, kw in ipairs(keywords) do
                if name:find(kw, 1, true) then found = true; break end
            end

            if found then
                local args = {...}
                if not RemoteSpyData[self] then
                    RemoteSpyData[self] = {args = {}, count = 0, name = self.Name}
                    Settings.SpyRemotes[self] = RemoteSpyData[self]
                    showNotification("Spy: " .. self.Name, 3, theme.Warning)
                    local count = 0
                    for _ in pairs(Settings.SpyRemotes) do count = count + 1 end
                    SpyStatusLabel.Text = "Spy: " .. count .. " remotes"
                end
                RemoteSpyData[self].args = args
                RemoteSpyData[self].count = RemoteSpyData[self].count + 1
            end
        end
        return oldNamecall(self, ...)
    end)

    log("RemoteSpy started")
end

task.spawn(startRemoteSpy)

-- ============================================================
-- AUTO DETECT REMOTE
-- ============================================================
local DAMAGE_KEYWORDS = {
    "damage", "hit", "fire", "shoot", "weapon", "gun", "attack",
    "melee", "sword", "bullet", "raycast", "combat", "strike",
    "slash", "hurt", "wound", "kill", "projectile", "shot",
    "blaster", "rifle", "pistol", "weaponfired", "weaponhit",
    "applydamage", "dealdamage", "takedamage", "gunremote",
    "actionsync", "replicate", "muzzle", "impact", "critical"
}

local function isDamageRemoteName(name)
    local lower = name:lower()
    for _, kw in ipairs(DAMAGE_KEYWORDS) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

local function findRemoteInPath(path, names)
    local current = ReplicatedStorage
    for _, folderName in ipairs(path) do
        local next = current:FindFirstChild(folderName)
        if not next then return nil end
        current = next
    end
    for _, name in ipairs(names) do
        local remote = current:FindFirstChild(name)
        if remote and (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then
            return remote
        end
    end
    return nil
end

local function deepScanAllRemotes()
    local found = {}
    local scanned = {}
    local containers = {ReplicatedStorage, Workspace}
    pcall(function() table.insert(containers, LocalPlayer.PlayerGui) end)
    pcall(function() table.insert(containers, game:GetService("ReplicatedFirst")) end)

    for _, container in ipairs(containers) do
        if container then
            pcall(function()
                for _, obj in ipairs(container:GetDescendants()) do
                    if not scanned[obj] then
                        scanned[obj] = true
                        if (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction"))
                           and isDamageRemoteName(obj.Name) then
                            table.insert(found, obj)
                        end
                    end
                end
            end)
        end
    end
    return found
end

function scanRemotes()
    Settings.CachedRemotes = {}
    Settings.AllDamageRemotes = {}
    Settings.DetectedMethod = nil
    StatusLabel.Text = "Status: Scanning..."

    local knownPaths = {
        {path = {"Eventos"}, names = {"WeaponFired", "WeaponHit"}, method = "WeaponHit", keys = {"WeaponFired", "WeaponHit"}},
        {path = {"SystemResources", "BufferCache"}, names = {"RequestActionSync"}, method = "RequestActionSync", keys = {"RequestActionSync"}},
        {path = {"Remotes"}, names = {"GunRemote"}, method = "GunRemote", keys = {"GunRemote"}},
        {path = {"WeaponsSystem", "Network"}, names = {"WeaponFired", "WeaponHit"}, method = "WeaponsSystem", keys = {"WSFired", "WSHit"}},
        {path = {"Events"}, names = {"FireWeapon"}, method = "FireWeapon", keys = {"FireWeapon"}},
    }

    for _, entry in ipairs(knownPaths) do
        local remotes = {}
        for i, name in ipairs(entry.names) do
            local r = findRemoteInPath(entry.path, {name})
            if r then
                remotes[i] = r
                Settings.CachedRemotes[entry.keys[i]] = r
            end
        end
        if remotes[1] and not Settings.DetectedMethod then
            Settings.DetectedMethod = entry.method
        end
    end

    local damagePaths = {
        {"Remotes"}, {"Events"}, {"Combat"}, {"Network"},
        {"Game"}, {"Shared"}, {"Modules"}, {"Client"}, {"Server"}
    }
    local damageNames = {
        "DamageRemote", "DealDamage", "Damage", "ApplyDamage",
        "HitEvent", "OnHit", "TakeDamage", "Hurt", "Wound",
        "SwordHit", "MeleeHit", "Slash", "CombatEvent",
        "AttackEvent", "Attack", "RaycastHit", "Shoot",
        "ProjectileHit", "BulletHit", "Impact", "Strike"
    }

    for _, path in ipairs(damagePaths) do
        for _, name in ipairs(damageNames) do
            local r = findRemoteInPath(path, {name})
            if r and not Settings.CachedRemotes[name] then
                Settings.CachedRemotes[name] = r
                if not Settings.DetectedMethod then Settings.DetectedMethod = name end
            end
        end
    end

    local allDamage = deepScanAllRemotes()
    Settings.AllDamageRemotes = allDamage

    for _, r in ipairs(allDamage) do
        if not Settings.CachedRemotes[r.Name] then
            Settings.CachedRemotes[r.Name] = r
            if not Settings.DetectedMethod then Settings.DetectedMethod = "DeepScan:" .. r.Name end
        end
    end

    local spyCount = 0
    for _ in pairs(Settings.SpyRemotes) do spyCount = spyCount + 1 end
    local totalRemotes = #allDamage + spyCount

    if Settings.DetectedMethod then
        StatusLabel.Text = "Method: " .. Settings.DetectedMethod
        StatusLabel.TextColor3 = theme.Success
    elseif totalRemotes > 0 then
        StatusLabel.Text = "Generic (" .. totalRemotes .. " remotes)"
        StatusLabel.TextColor3 = theme.Warning
    else
        StatusLabel.Text = "No remote found"
        StatusLabel.TextColor3 = theme.Danger
    end

    SpyStatusLabel.Text = "Spy: " .. spyCount .. " | Scan: " .. #allDamage
    log("Scan done: " .. #allDamage .. " remotes, " .. spyCount .. " spy")
end

task.spawn(scanRemotes)

-- ============================================================
-- WEAPON + WALL CHECK
-- ============================================================
local function findWeapon()
    local char = LocalPlayer.Character
    if char then
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then return tool end
    end
    if Settings.AutoWeaponEquip then
        local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
        if backpack then
            local tool = backpack:FindFirstChildOfClass("Tool")
            if tool then
                pcall(function()
                    tool.Parent = LocalPlayer.Character
                end)
                return tool
            end
        end
    end
    return nil
end

local function isVisible(targetPart)
    if not Settings.WallCheck then return true end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetPart then return false end
    local origin = myRoot.Position
    local dir = targetPart.Position - origin
    if dir.Magnitude <= 0 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = myChar and {myChar} or {}
    local result = Workspace:Raycast(origin, dir, params)
    return result == nil or result.Instance:IsDescendantOf(targetPart.Parent)
end

-- ============================================================
-- ATTACK METHODS (14 modes)
-- ============================================================
local function fireMethod(t, targetPart, weapon, myRoot)
    local method = Settings.DetectedMethod
    local R = Settings.CachedRemotes
    local dir = (targetPart.Position - myRoot.Position).Unit

    if method == "WeaponHit" and R.WeaponFired and R.WeaponHit then
        R.WeaponFired:FireServer(weapon, {id = math.random(1, 99), charge = 0, origin = myRoot.Position, dir = dir})
        R.WeaponHit:FireServer(weapon, {
            p = targetPart.Position, pid = 1, part = targetPart,
            d = t.distance, maxDist = t.distance + 1, h = t.humanoid,
            m = Enum.Material.Plastic, n = Vector3.new(0, 1, 0), t = 0.1, sid = math.random(1, 99)
        })
        return true
    elseif method == "RequestActionSync" and R.RequestActionSync then
        R.RequestActionSync:FireServer({{
            direction = dir, hitPosition = targetPart.Position, origin = myRoot.Position,
            hitInstance = targetPart, hitHumanoid = t.humanoid, IsHeadshot = (Settings.TargetPart == "Head")
        }})
        return true
    elseif method == "GunRemote" and R.GunRemote then
        R.GunRemote:FireServer(1, weapon, targetPart.Position, Vector3.yAxis, targetPart)
        return true
    elseif method == "WeaponsSystem" and R.WSFired and R.WSHit then
        local sid = math.random(10, 999)
        R.WSFired:FireServer(weapon, {id = sid, charge = 0, origin = myRoot.Position, dir = dir})
        R.WSHit:FireServer(weapon, {
            p = targetPart.Position, pid = 1, part = targetPart,
            d = t.distance, maxDist = t.distance + 1, h = t.humanoid,
            m = Enum.Material.Plastic, n = Vector3.new(0, 1, 0), t = 0.1, sid = sid
        })
        return true
    elseif method == "FireWeapon" and R.FireWeapon then
        local origin = myRoot.Position + Vector3.new(0, 1.5, 0)
        R.FireWeapon:FireServer("Main", origin, dir, {
            [1] = {Normal = Vector3.new(0, 1, 0), Direction = dir,
                   Position = targetPart.Position, Hit = targetPart, Bounce = 0, Origin = origin}
        })
        return true
    end

    local genericRemote = R[method]
    if genericRemote then
        local signatures = {
            function() genericRemote:FireServer(t.humanoid, 100, targetPart) end,
            function() genericRemote:FireServer(targetPart, 100) end,
            function() genericRemote:FireServer(t.humanoid, targetPart, 100) end,
            function() genericRemote:FireServer(targetPart, dir, 100) end,
            function() genericRemote:FireServer(weapon, targetPart, dir) end,
            function() genericRemote:FireServer(targetPart, t.humanoid) end,
            function() genericRemote:FireServer("Attack", targetPart, t.humanoid) end,
            function() genericRemote:FireServer("Hit", targetPart, dir) end,
            function() genericRemote:FireServer(myRoot.Position, dir, targetPart, t.humanoid) end,
        }
        for _, sig in ipairs(signatures) do
            if pcall(sig) then return true end
        end
    end
    return false
end

local function spyReplayAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    local origin = myRoot.Position
    local successAny = false

    for remote, data in pairs(Settings.SpyRemotes) do
        if remote and remote.Parent then
            local args = data.args
            if args and #args > 0 then
                task.spawn(function()
                    pcall(function()
                        local newArgs = {}
                        for i, arg in ipairs(args) do
                            if type(arg) == "table" then
                                local cloned = {}
                                for k, v in pairs(arg) do cloned[k] = v end
                                if cloned.hitPosition then cloned.hitPosition = targetPart.Position end
                                if cloned.Position then cloned.Position = targetPart.Position end
                                if cloned.hitInstance then cloned.hitInstance = targetPart end
                                if cloned.hitHumanoid then cloned.hitHumanoid = t.humanoid end
                                if cloned.part then cloned.part = targetPart end
                                if cloned.h then cloned.h = t.humanoid end
                                if cloned.origin then cloned.origin = origin end
                                if cloned.dir then cloned.dir = dir end
                                if cloned.direction then cloned.direction = dir end
                                newArgs[i] = cloned
                            elseif typeof(arg) == "Vector3" then
                                if arg.Magnitude > 0.5 and arg.Magnitude < 1.5 then
                                    newArgs[i] = dir
                                else
                                    newArgs[i] = targetPart.Position
                                end
                            elseif typeof(arg) == "Instance" then
                                if arg:IsA("Humanoid") then newArgs[i] = t.humanoid
                                elseif arg:IsA("BasePart") then newArgs[i] = targetPart
                                elseif arg:IsA("Tool") then newArgs[i] = weapon or arg
                                else newArgs[i] = arg end
                            else
                                newArgs[i] = arg
                            end
                        end
                        remote:FireServer(unpack(newArgs))
                    end)
                end)
                successAny = true
            end
        end
    end
    return successAny
end

local function silentAttack(t, targetPart, myRoot)
    for _, remote in pairs(Settings.CachedRemotes) do
        pcall(function() remote:FireServer(t.humanoid, 100, targetPart) end)
        pcall(function() remote:FireServer(targetPart, 100) end)
        pcall(function() remote:FireServer(t.humanoid, targetPart) end)
    end
end

local function clientDamageAttack(t)
    pcall(function()
        if t.humanoid then
            t.humanoid.Health = 0
        end
    end)
end

local function toolActivateAttack(t, targetPart, weapon)
    if not weapon then return end
    pcall(function()
        local handle = weapon:FindFirstChild("Handle")
        if handle then handle.CFrame = targetPart.CFrame end
        weapon:Activate()
    end)
end

local function teleportHitAttack(t, targetPart, weapon, myRoot)
    local originalCF = myRoot.CFrame
    myRoot.CFrame = targetPart.CFrame * CFrame.new(0, 0, 3)
    task.wait(0.03)
    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)
    task.wait(0.03)
    myRoot.CFrame = originalCF
end

local function hitboxExpandAttack(t, targetPart, weapon, myRoot)
    pcall(function()
        if targetPart and targetPart:IsA("BasePart") then
            targetPart.Size = Vector3.new(15, 15, 15)
            targetPart.Transparency = 0.8
            targetPart.CanCollide = false
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
    if weapon then pcall(function() weapon:Activate() end) end
end

local function flingKillAttack(t, targetPart, weapon, myRoot)
    pcall(function()
        local root = t.root
        if root then
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(math.random(-5000, 5000), 10000, math.random(-5000, 5000))
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = math.huge
            bv.Parent = root
            task.delay(0.5, function() if bv and bv.Parent then bv:Destroy() end end)
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
end

local function raycastSpamAttack(t, targetPart, weapon, myRoot)
    for _ = 1, 5 do
        task.spawn(function()
            pcall(function() fireMethod(t, targetPart, weapon, myRoot) end)
            if weapon then pcall(function() weapon:Activate() end) end
        end)
    end
end

local function multiHitAttack(t, targetPart, weapon, myRoot)
    for _ = 1, 3 do
        fireMethod(t, targetPart, weapon, myRoot)
        if weapon then pcall(function() weapon:Activate() end) end
        task.wait(0.02)
    end
end

local function remoteSpamAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    for _, remote in ipairs(Settings.AllDamageRemotes) do
        task.spawn(function()
            pcall(function() remote:FireServer(t.humanoid, 100, targetPart) end)
            pcall(function() remote:FireServer(targetPart, 100) end)
            pcall(function() remote:FireServer(targetPart, dir, 100) end)
        end)
    end
    if weapon then pcall(function() weapon:Activate() end) end
end

local function networkBruteAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    local allRemotes = {}
    for _, r in pairs(Settings.CachedRemotes) do table.insert(allRemotes, r) end
    for _, r in ipairs(Settings.AllDamageRemotes) do table.insert(allRemotes, r) end

    for _, remote in ipairs(allRemotes) do
        task.spawn(function()
            pcall(function() remote:FireServer(targetPart) end)
            pcall(function() remote:FireServer(t.humanoid, 100, targetPart) end)
            pcall(function() remote:FireServer(targetPart, 100) end)
            pcall(function() remote:FireServer(weapon, targetPart, dir) end)
            pcall(function() remote:FireServer(myRoot.Position, dir, targetPart, t.humanoid) end)
        end)
    end
    if weapon then pcall(function() weapon:Activate() end) end
end

local function universalAttack(t, targetPart, weapon, myRoot)
    fireMethod(t, targetPart, weapon, myRoot)
    spyReplayAttack(t, targetPart, weapon, myRoot)
    silentAttack(t, targetPart, myRoot)
    clientDamageAttack(t)
    if weapon then pcall(function() weapon:Activate() end) end
end

local function autoAttack(t, targetPart, weapon, myRoot)
    if fireMethod(t, targetPart, weapon, myRoot) then return end
    if spyReplayAttack(t, targetPart, weapon, myRoot) then return end
    silentAttack(t, targetPart, myRoot)
    if weapon then pcall(function() weapon:Activate() end) end
end

-- ============================================================
-- TARGET SORTING
-- ============================================================
local function sortTargets(targets)
    local priority = Settings.TargetPriority
    if priority == "Closest" then
        table.sort(targets, function(a, b) return a.distance < b.distance end)
    elseif priority == "LowestHP" then
        table.sort(targets, function(a, b) return a.humanoid.Health < b.humanoid.Health end)
    elseif priority == "HighestHP" then
        table.sort(targets, function(a, b) return a.humanoid.Health > b.humanoid.Health end)
    elseif priority == "Random" then
        for i = #targets, 2, -1 do
            local j = math.random(i)
            targets[i], targets[j] = targets[j], targets[i]
        end
    end
    return targets
end

-- ============================================================
-- KILL AURA MAIN LOOP
-- ============================================================
local auraConn = RunService.Heartbeat:Connect(function()
    if not Settings.Enabled then return end

    local spyCount = 0
    for _ in pairs(Settings.SpyRemotes) do spyCount = spyCount + 1 end

    if not Settings.DetectedMethod and #Settings.AllDamageRemotes == 0 and spyCount == 0 then
        if tick() - Settings.LastAttack > 5 then
            task.spawn(scanRemotes)
            Settings.LastAttack = tick()
        end
    end

    local now = tick()
    if now - Settings.LastAttack < Settings.Delay then return end

    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    Settings.LastAttack = now
    local weapon = findWeapon()

    local targets = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            if tRoot and tHum and tHum.Health > 0 then
                local sameTeam = LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team
                if not sameTeam then
                    local dist = (myRoot.Position - tRoot.Position).Magnitude
                    if dist <= Settings.Radius and isVisible(tRoot) then
                        table.insert(targets, {
                            player = plr, character = plr.Character,
                            root = tRoot, humanoid = tHum, distance = dist
                        })
                    end
                end
            end
        end
    end

    targets = sortTargets(targets)

    local attackCount = 0
    for _, t in ipairs(targets) do
        if attackCount >= Settings.MaxTargets then break end
        local targetPart = t.character:FindFirstChild(Settings.TargetPart) or t.root
        if targetPart then
            attackCount = attackCount + 1
            task.spawn(function()
                pcall(function()
                    local mode = Settings.AuraMode
                    if mode == "Auto" then autoAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "Normal" then fireMethod(t, targetPart, weapon, myRoot)
                    elseif mode == "SpyReplay" then spyReplayAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "Silent" then silentAttack(t, targetPart, myRoot)
                    elseif mode == "ClientDamage" then clientDamageAttack(t)
                    elseif mode == "ToolActivate" then toolActivateAttack(t, targetPart, weapon)
                    elseif mode == "TeleportHit" then teleportHitAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "HitboxExpand" then hitboxExpandAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "FlingKill" then flingKillAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "RaycastSpam" then raycastSpamAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "MultiHit" then multiHitAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "RemoteSpam" then remoteSpamAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "NetworkBrute" then networkBruteAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "Universal" then universalAttack(t, targetPart, weapon, myRoot)
                    end
                end)
            end)
        end
    end
end)
table.insert(Settings._Connections, auraConn)

-- ============================================================
-- AIMBOT
-- ============================================================
if hasDrawing then
    Settings._FOVCircle = Drawing.new("Circle")
    Settings._FOVCircle.Radius = Settings.AimbotFOV
    Settings._FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    Settings._FOVCircle.Thickness = 1
    Settings._FOVCircle.Filled = false
    Settings._FOVCircle.Transparency = 0.5
    Settings._FOVCircle.Visible = false
    Settings._FOVCircle.ZIndex = 10
end

local aimConn = RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera or Camera

    if Settings._FOVCircle then
        Settings._FOVCircle.Radius = Settings.AimbotFOV
        Settings._FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        Settings._FOVCircle.Visible = Settings.AimbotEnabled and Settings.ShowFOVCircle
    end

    if not Settings.AimbotEnabled then return end

    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local bestTarget = nil
    local bestDist = Settings.AimbotFOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            local aimPart = plr.Character:FindFirstChild(Settings.AimbotPart) or plr.Character:FindFirstChild("Head")
            if tHum and tHum.Health > 0 and aimPart then
                local sameTeam = Settings.AimbotTeamCheck and LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team
                if not sameTeam then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
                    if onScreen then
                        local distFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if distFromCenter < bestDist then
                            bestDist = distFromCenter
                            bestTarget = aimPart
                        end
                    end
                end
            end
        end
    end

    if bestTarget then
        local targetCF = CFrame.lookAt(Camera.CFrame.Position, bestTarget.Position)
        Camera.CFrame = Camera.CFrame:Lerp(targetCF, Settings.AimbotSmooth)
    end
end)
table.insert(Settings._Connections, aimConn)

-- ============================================================
-- ESP ENGINE
-- ============================================================
ESP_Cache = {}

local SKELETON_PAIRS = {
    {"Head", "UpperTorso"},
    {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"},
    {"LeftUpperArm", "LeftLowerArm"},
    {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"},
    {"RightUpperArm", "RightLowerArm"},
    {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"},
    {"LeftUpperLeg", "LeftLowerLeg"},
    {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"},
    {"RightUpperLeg", "RightLowerLeg"},
    {"RightLowerLeg", "RightFoot"},
}

local function CreateESP_Drawing(char)
    local esp = {
        Box = Drawing.new("Square"),
        BoxOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"),
        HealthBarOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        Highlight = nil,
        SkeletonLines = {},
        Type = "Drawing"
    }

    esp.Box.Color = Settings.ESPColor
    esp.Box.Thickness = 1; esp.Box.Filled = false; esp.Box.ZIndex = 2
    esp.BoxOutline.Color = Color3.new(0, 0, 0)
    esp.BoxOutline.Thickness = 3; esp.BoxOutline.Filled = false; esp.BoxOutline.ZIndex = 1
    esp.HealthBar.Color = Color3.new(0, 1, 0)
    esp.HealthBar.Thickness = 1; esp.HealthBar.Filled = true; esp.HealthBar.ZIndex = 2
    esp.HealthBarOutline.Color = Color3.new(0, 0, 0)
    esp.HealthBarOutline.Thickness = 1; esp.HealthBarOutline.Filled = true; esp.HealthBarOutline.ZIndex = 1
    esp.Name.Color = Color3.new(1, 1, 1)
    esp.Name.Size = 14; esp.Name.Center = true; esp.Name.Outline = true; esp.Name.ZIndex = 3
    esp.Distance.Color = Color3.new(1, 1, 1)
    esp.Distance.Size = 12; esp.Distance.Center = true; esp.Distance.Outline = true; esp.Distance.ZIndex = 3
    esp.Tracer.Color = Settings.ESPColor
    esp.Tracer.Thickness = 1; esp.Tracer.ZIndex = 1

    for _ = 1, #SKELETON_PAIRS do
        local line = Drawing.new("Line")
        line.Color = Settings.ESPColor
        line.Thickness = 1
        line.Visible = false
        line.ZIndex = 2
        table.insert(esp.SkeletonLines, line)
    end

    return esp
end

local function CreateESP_Billboard(char)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_V10"
    billboard.Size = UDim2.new(4, 0, 5, 0)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 0
    billboard.ResetOnSpawn = false

    local head = char:FindFirstChild("Head")
    billboard.Parent = head or char

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(1, 0, 1, 0)
    mainFrame.BackgroundTransparency = 1
    mainFrame.Parent = billboard

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Size = UDim2.new(1, 0, 0.2, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.TextColor3 = Color3.new(1, 1, 1)
    nameLabel.TextStrokeTransparency = 0
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 14
    nameLabel.Text = ""
    nameLabel.Parent = mainFrame

    local boxTop = Instance.new("Frame", mainFrame)
    boxTop.Size = UDim2.new(1, 0, 0, 2); boxTop.Position = UDim2.new(0, 0, 0.2, 0)
    boxTop.BackgroundColor3 = Settings.ESPColor; boxTop.BorderSizePixel = 0

    local boxBottom = Instance.new("Frame", mainFrame)
    boxBottom.Size = UDim2.new(1, 0, 0, 2); boxBottom.Position = UDim2.new(0, 0, 0.8, 0)
    boxBottom.BackgroundColor3 = Settings.ESPColor; boxBottom.BorderSizePixel = 0

    local boxLeft = Instance.new("Frame", mainFrame)
    boxLeft.Size = UDim2.new(0, 2, 0.6, 0); boxLeft.Position = UDim2.new(0, 0, 0.2, 0)
    boxLeft.BackgroundColor3 = Settings.ESPColor; boxLeft.BorderSizePixel = 0

    local boxRight = Instance.new("Frame", mainFrame)
    boxRight.Size = UDim2.new(0, 2, 0.6, 0); boxRight.Position = UDim2.new(1, -2, 0.2, 0)
    boxRight.BackgroundColor3 = Settings.ESPColor; boxRight.BorderSizePixel = 0

    local healthBg = Instance.new("Frame", mainFrame)
    healthBg.Size = UDim2.new(0.05, 0, 0.6, 0); healthBg.Position = UDim2.new(-0.08, 0, 0.2, 0)
    healthBg.BackgroundColor3 = Color3.new(0, 0, 0); healthBg.BorderSizePixel = 0

    local healthBar = Instance.new("Frame", healthBg)
    healthBar.Size = UDim2.new(1, 0, 1, 0)
    healthBar.BackgroundColor3 = Color3.new(0, 1, 0); healthBar.BorderSizePixel = 0

    local distLabel = Instance.new("TextLabel", mainFrame)
    distLabel.Size = UDim2.new(1, 0, 0.15, 0); distLabel.Position = UDim2.new(0, 0, 0.85, 0)
    distLabel.BackgroundTransparency = 1; distLabel.TextColor3 = Color3.new(1, 1, 1)
    distLabel.TextStrokeTransparency = 0; distLabel.Font = Enum.Font.Gotham
    distLabel.TextSize = 12; distLabel.Text = ""

    local highlight = Instance.new("Highlight")
    highlight.Name = "ESPCham"
    highlight.FillTransparency = 0.5
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Settings.ESPColor
    highlight.OutlineColor = Color3.new(1, 1, 1)
    highlight.Parent = char

    return {
        Billboard = billboard,
        NameLabel = nameLabel,
        HealthBar = healthBar,
        DistLabel = distLabel,
        Highlight = highlight,
        Boxes = {boxTop, boxBottom, boxLeft, boxRight},
        Type = "Billboard"
    }
end

local function CreateESP(char)
    if Settings.UseDrawingAPI then
        ESP_Cache[char] = CreateESP_Drawing(char)
    else
        ESP_Cache[char] = CreateESP_Billboard(char)
    end
end

function RemoveESP(char)
    if ESP_Cache[char] then
        local esp = ESP_Cache[char]
        if esp.Type == "Drawing" then
            for k, v in pairs(esp) do
                if k == "SkeletonLines" then
                    for _, line in ipairs(v) do pcall(function() line:Remove() end) end
                elseif k == "Highlight" and v then
                    pcall(function() v:Destroy() end)
                elseif type(v) == "userdata" then
                    pcall(function() v.Visible = false; v:Remove() end)
                end
            end
        elseif esp.Type == "Billboard" then
            pcall(function() if esp.Billboard then esp.Billboard:Destroy() end end)
            pcall(function() if esp.Highlight then esp.Highlight:Destroy() end end)
        end
        ESP_Cache[char] = nil
    end
end

local espConn = RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera or Camera
    if not Camera then return end

    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local char = plr.Character
            local hum = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and root then
                local dist = myRoot and (myRoot.Position - root.Position).Magnitude or 0
                if dist <= Settings.ESPMaxDistance then
                    if not ESP_Cache[char] then CreateESP(char) end
                else
                    if ESP_Cache[char] then RemoveESP(char) end
                end
            end
        end
    end

    for char, esp in pairs(ESP_Cache) do
        local isValid = char and char.Parent and char:IsDescendantOf(Workspace)
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local head = char and char:FindFirstChild("Head")

        if not isValid or not hum or hum.Health <= 0 or not root then
            RemoveESP(char)
        else
            local plr = Players:GetPlayerFromCharacter(char)
            local isTeammate = Settings.ESPTeamCheck and plr and LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team
            local shouldShow = Settings.ESPEnabled and not isTeammate
            local espColor = isTeammate and Settings.ESPFriendlyColor or Settings.ESPColor

            if esp.Type == "Drawing" then
                if shouldShow then
                    local rootPos, onScreen = Camera:WorldToViewportPoint(root.Position)
                    local headPos = Camera:WorldToViewportPoint(head and head.Position + Vector3.new(0, 0.5, 0) or root.Position + Vector3.new(0, 3, 0))
                    local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))

                    if onScreen then
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2

                        if Settings.ESPBoxes then
                            esp.Box.Size = Vector2.new(width, height)
                            esp.Box.Position = Vector2.new(rootPos.X - width / 2, rootPos.Y - height / 2)
                            esp.Box.Color = espColor
                            esp.Box.Visible = true
                            esp.BoxOutline.Size = esp.Box.Size
                            esp.BoxOutline.Position = esp.Box.Position
                            esp.BoxOutline.Visible = true
                        else esp.Box.Visible = false; esp.BoxOutline.Visible = false end

                        if Settings.ESPHealth then
                            local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                            local hh = height * hp
                            esp.HealthBarOutline.Size = Vector2.new(4, height + 2)
                            esp.HealthBarOutline.Position = Vector2.new(rootPos.X - width / 2 - 6, rootPos.Y - height / 2 - 1)
                            esp.HealthBarOutline.Visible = true
                            esp.HealthBar.Size = Vector2.new(2, hh)
                            esp.HealthBar.Position = Vector2.new(rootPos.X - width / 2 - 5, rootPos.Y + height / 2 - hh)
                            esp.HealthBar.Color = Color3.fromHSV(hp * 0.3, 1, 1)
                            esp.HealthBar.Visible = true
                        else esp.HealthBar.Visible = false; esp.HealthBarOutline.Visible = false end

                        if Settings.ESPNames then
                            esp.Name.Text = plr and plr.Name or char.Name
                            esp.Name.Position = Vector2.new(rootPos.X, rootPos.Y - height / 2 - 16)
                            esp.Name.Visible = true
                        else esp.Name.Visible = false end

                        if Settings.ESPDistance then
                            local dist = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
                            esp.Distance.Text = "[" .. dist .. "m]"
                            esp.Distance.Position = Vector2.new(rootPos.X, rootPos.Y + height / 2 + 2)
                            esp.Distance.Visible = true
                        else esp.Distance.Visible = false end

                        if Settings.ESPTracers then
                            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                            esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y + height / 2)
                            esp.Tracer.Color = espColor
                            esp.Tracer.Visible = true
                        else esp.Tracer.Visible = false end

                        if Settings.ESPSkeleton then
                            for idx, pair in ipairs(SKELETON_PAIRS) do
                                local line = esp.SkeletonLines[idx]
                                if line then
                                    local p1 = char:FindFirstChild(pair[1])
                                    local p2 = char:FindFirstChild(pair[2])
                                    if p1 and p2 then
                                        local s1, v1 = Camera:WorldToViewportPoint(p1.Position)
                                        local s2, v2 = Camera:WorldToViewportPoint(p2.Position)
                                        if v1 and v2 then
                                            line.From = Vector2.new(s1.X, s1.Y)
                                            line.To = Vector2.new(s2.X, s2.Y)
                                            line.Color = espColor
                                            line.Visible = true
                                        else
                                            line.Visible = false
                                        end
                                    else
                                        line.Visible = false
                                    end
                                end
                            end
                        else
                            for _, line in ipairs(esp.SkeletonLines) do line.Visible = false end
                        end

                        if Settings.ESPChams then
                            if not esp.Highlight or esp.Highlight.Parent ~= char then
                                if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
                                local hl = Instance.new("Highlight")
                                hl.Name = "ESPCham"
                                hl.FillTransparency = 0.5
                                hl.OutlineTransparency = 0
                                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                                hl.Parent = char
                                esp.Highlight = hl
                            end
                            esp.Highlight.FillColor = espColor
                            esp.Highlight.OutlineColor = Color3.new(1, 1, 1)
                        else
                            if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                        end
                    else
                        esp.Box.Visible = false; esp.BoxOutline.Visible = false
                        esp.HealthBar.Visible = false; esp.HealthBarOutline.Visible = false
                        esp.Name.Visible = false; esp.Distance.Visible = false
                        esp.Tracer.Visible = false
                        for _, line in ipairs(esp.SkeletonLines) do line.Visible = false end
                        if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                    end
                else
                    esp.Box.Visible = false; esp.BoxOutline.Visible = false
                    esp.HealthBar.Visible = false; esp.HealthBarOutline.Visible = false
                    esp.Name.Visible = false; esp.Distance.Visible = false
                    esp.Tracer.Visible = false
                    for _, line in ipairs(esp.SkeletonLines) do line.Visible = false end
                    if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                end
            elseif esp.Type == "Billboard" then
                if shouldShow then
                    esp.Billboard.Enabled = true
                    if Settings.ESPNames then
                        esp.NameLabel.Text = plr and plr.Name or char.Name
                        esp.NameLabel.Visible = true
                    else esp.NameLabel.Visible = false end

                    if Settings.ESPHealth then
                        local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                        esp.HealthBar.Size = UDim2.new(1, 0, hp, 0)
                        esp.HealthBar.BackgroundColor3 = Color3.fromHSV(hp * 0.3, 1, 1)
                    end

                    if Settings.ESPDistance then
                        local dist = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
                        esp.DistLabel.Text = "[" .. dist .. "m]"
                        esp.DistLabel.Visible = true
                    else esp.DistLabel.Visible = false end

                    for _, box in ipairs(esp.Boxes) do
                        box.Visible = Settings.ESPBoxes
                        box.BackgroundColor3 = espColor
                    end

                    if Settings.ESPChams then
                        if not esp.Highlight or esp.Highlight.Parent ~= char then
                            if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
                            local hl = Instance.new("Highlight")
                            hl.Name = "ESPCham"; hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = char
                            esp.Highlight = hl
                        end
                        esp.Highlight.FillColor = espColor
                    else
                        if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                    end
                else
                    esp.Billboard.Enabled = false
                    if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                end
            end
        end
    end
end)
table.insert(Settings._Connections, espConn)

-- ============================================================
-- MISC FEATURES
-- ============================================================

-- Anti-AFK
local afkConn
pcall(function()
    afkConn = LocalPlayer.Idled:Connect(function()
        if Settings.AntiAFK then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
    table.insert(Settings._Connections, afkConn)
end)

-- Infinite Jump
local jumpConn = UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump then
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)
table.insert(Settings._Connections, jumpConn)

-- Speed Hack + Fly + Anti-Void
local flyBV, flyBG
local miscConn = RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if Settings.SpeedEnabled then
        hum.WalkSpeed = Settings.SpeedValue
    end

    if Settings.FlyEnabled then
        if not flyBV or not flyBV.Parent then
            flyBV = Instance.new("BodyVelocity")
            flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBV.Parent = root
        end
        if not flyBG or not flyBG.Parent then
            flyBG = Instance.new("BodyGyro")
            flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            flyBG.P = 9e4
            flyBG.Parent = root
        end
        local moveDir = hum.MoveDirection
        if moveDir.Magnitude > 0 then
            flyBV.Velocity = moveDir * Settings.FlySpeed + Vector3.new(0, 0, 0)
        else
            flyBV.Velocity = Vector3.new(0, 0, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            flyBV.Velocity = flyBV.Velocity + Vector3.new(0, Settings.FlySpeed, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            flyBV.Velocity = flyBV.Velocity - Vector3.new(0, Settings.FlySpeed, 0)
        end
        flyBG.CFrame = Camera.CFrame
    else
        if flyBV and flyBV.Parent then flyBV:Destroy(); flyBV = nil end
        if flyBG and flyBG.Parent then flyBG:Destroy(); flyBG = nil end
    end

    if Settings.AntiVoid then
        if root.Position.Y < -50 then
            root.CFrame = CFrame.new(root.Position.X, 100, root.Position.Z)
            root.Velocity = Vector3.new(0, 0, 0)
        end
    end
end)
table.insert(Settings._Connections, miscConn)

-- ============================================================
-- CLEANUP HANDLERS
-- ============================================================
local removeConn = Workspace.DescendantRemoving:Connect(function(desc)
    if desc:IsA("Model") and ESP_Cache[desc] then RemoveESP(desc) end
end)
table.insert(Settings._Connections, removeConn)

local charConn = LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    task.spawn(scanRemotes)
end)
table.insert(Settings._Connections, charConn)

Players.PlayerRemoving:Connect(function(plr)
    if plr.Character and ESP_Cache[plr.Character] then
        RemoveESP(plr.Character)
    end
end)

-- ============================================================
-- STARTUP
-- ============================================================
updateMiniIcon()
showNotification("Kill Aura V10 loaded!", 3, theme.Success)
showNotification("Drawing=" .. tostring(hasDrawing) .. " | Spy=" .. tostring(hasHookMeta), 4, theme.Info)
if hasFileSystem then
    showNotification("Config system ready", 2, theme.TextDim)
end

log("V10 Universal loaded")

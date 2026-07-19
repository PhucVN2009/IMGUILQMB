-- ============================================================
-- KILL AURA + ESP MOBILE V10 ULTRA - TRUE UNIVERSAL EDITION
-- Work ALL game types: Shooter, Sword, RPG, Simulator,
-- Fighting, Anime, Horror, Tycoon, Custom Framework
-- ALL methods: Remote, Spy, Touch, Module, Physics, CFrame,
-- Tool, Animation, Click, Proximity, Network, Brute
-- ============================================================

-- ============================================================
-- CLEANUP
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
local StarterGui = game:GetService("StarterGui")
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
    TargetNPCs = true,
    TargetPlayers = true,
    LastAttack = 0,
    DetectedMethod = nil,
    CachedRemotes = {},
    AllDamageRemotes = {},
    AllRemotes = {},
    SpyRemotes = {},
    SpyCapturedArgs = {},
    ModuleFunctions = {},
    TouchConnections = {},
    DetectedGameType = "Unknown",
    CustomWeapons = {},
    HotbarRemotes = {},
    CustomCombatRemotes = {},
    HasCustomInventory = false,

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

    -- Hitbox
    HitboxEnabled = false,
    HitboxX = 10,
    HitboxY = 10,
    HitboxZ = 10,
    HitboxTransparency = 0.7,
    HitboxCanCollide = false,
    HitboxVisible = true,

    -- Misc
    AntiAFK = true,
    InfiniteJump = false,
    SpeedEnabled = false,
    SpeedValue = 32,
    FlyEnabled = false,
    FlySpeed = 50,
    SwordFlyEnabled = false,
    SwordFlySpeed = 80,
    AntiVoid = false,
    NoClip = false,

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
local hasGetGC = type(getgc) == "function"
local hasGetNilInstances = type(getnilinstances) == "function"
local hasFireTouchInterest = type(firetouchinterest) == "function"
local hasGetConnections = type(getconnections) == "function"
local hasGetHiddenProp = type(gethiddenproperty) == "function"
local hasNewCClosure = type(newcclosure) == "function"
local hasGetRawMeta = type(getrawmetatable) == "function"
local hasFireClickDetector = type(fireclickdetector) == "function"
local hasGetLoadedModules = type(getloadedmodules) == "function" or type(debug) == "table"
local hasFireProximity = type(fireproximityprompt) == "function"
local hasSethiddenproperty = type(sethiddenproperty) == "function"

local function log(msg)
    if Settings.DebugMode then print("[KillAura V10U] " .. tostring(msg)) end
end

log("Capabilities: Drawing=" .. tostring(hasDrawing) ..
    " FS=" .. tostring(hasFileSystem) ..
    " Hook=" .. tostring(hasHookMeta) ..
    " GC=" .. tostring(hasGetGC) ..
    " Touch=" .. tostring(hasFireTouchInterest) ..
    " Click=" .. tostring(hasFireClickDetector) ..
    " Prox=" .. tostring(hasFireProximity) ..
    " Modules=" .. tostring(hasGetLoadedModules))

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
        TargetNPCs = Settings.TargetNPCs,
        TargetPlayers = Settings.TargetPlayers,
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
    pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(data)) end)
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
        SetValue = function(v) state = v; updateVisual() end,
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
        if props.Step then value = math.floor(value / props.Step + 0.5) * props.Step end
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
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
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
    return { SetValue = function(v)
        local rel = math.clamp((v - props.Min) / (props.Max - props.Min), 0, 1)
        fill.Size = UDim2.new(rel, 0, 1, 0)
        label.Text = (props.Text or "") .. ": " .. formatValue(v)
    end, Container = container }
end

local function makeDraggable(handle, frame)
    local dragging, dragInput, dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
    end)
    local conn = UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    table.insert(Settings._Connections, conn)
end

local allDropdowns = {}

local function closeAllDropdowns(except)
    for _, dd in ipairs(allDropdowns) do
        if dd ~= except then dd.Close() end
    end
end

local _dropdownOverlay = nil

local function getDropdownOverlay()
    return _dropdownOverlay
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

    -- Menu popup lives in ScreenGui overlay so it's never clipped by ScrollingFrame
    local menuFrame = Instance.new("Frame")
    menuFrame.Size = UDim2.new(0, 0, 0, 0)
    menuFrame.BackgroundColor3 = theme.Surface
    menuFrame.BorderSizePixel = 0
    menuFrame.Visible = false
    menuFrame.ClipsDescendants = true
    menuFrame.Active = true
    menuFrame.ZIndex = 200
    Instance.new("UICorner", menuFrame).CornerRadius = UDim.new(0, 6)
    local menuStroke = Instance.new("UIStroke", menuFrame)
    menuStroke.Color = theme.Accent; menuStroke.Thickness = 1

    local contentFrame
    if totalHeight > menuHeight then
        local scrollFrame = Instance.new("ScrollingFrame")
        scrollFrame.Size = UDim2.new(1, 0, 1, 0)
        scrollFrame.BackgroundTransparency = 1
        scrollFrame.BorderSizePixel = 0
        scrollFrame.ScrollBarThickness = 4
        scrollFrame.ScrollBarImageColor3 = theme.AccentLight
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
        scrollFrame.ScrollingEnabled = true
        scrollFrame.Parent = menuFrame
        scrollFrame.ZIndex = 201
        contentFrame = Instance.new("Frame")
        contentFrame.Size = UDim2.new(1, 0, 0, totalHeight)
        contentFrame.BackgroundTransparency = 1
        contentFrame.Parent = scrollFrame
        contentFrame.ZIndex = 201
    else
        contentFrame = menuFrame
    end

    local buttons = {}
    local menuOpen = false
    local currentValue = props.Default
    local lastMainClick = 0
    local dropdown

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
        btn.ZIndex = 202
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        local lastBtnClick = 0
        local function selectOption()
            local now = tick()
            if now - lastBtnClick < 0.2 then return end
            lastBtnClick = now
            currentValue = optionName
            mainBtn.Text = "  " .. optionName
            for _, b in ipairs(buttons) do b.BackgroundColor3 = theme.Surface end
            btn.BackgroundColor3 = theme.Accent
            menuOpen = false
            menuFrame.Visible = false
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

    local function closeMenu()
        if not menuOpen then return end
        menuOpen = false
        menuFrame.Visible = false
        for _, b in ipairs(buttons) do b.Visible = false end
        arrow.Text = "v"
    end

    local function openMenu()
        closeAllDropdowns(dropdown)

        if _dropdownOverlay then
            menuFrame.Parent = _dropdownOverlay
        end
        local absPos = mainBtn.AbsolutePosition
        local absSize = mainBtn.AbsoluteSize
        menuFrame.Position = UDim2.new(0, absPos.X, 0, absPos.Y + absSize.Y + 2)
        menuFrame.Size = UDim2.new(0, absSize.X, 0, menuHeight)

        menuOpen = true
        menuFrame.Visible = true
        for _, b in ipairs(buttons) do b.Visible = true end
        arrow.Text = "^"
    end

    local function toggleMenu()
        local now = tick()
        if now - lastMainClick < 0.2 then return end
        lastMainClick = now
        if menuOpen then closeMenu() else openMenu() end
    end
    mainBtn.MouseButton1Click:Connect(toggleMenu)
    mainBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            task.wait(0.05)
            toggleMenu()
        end
    end)

    dropdown = {
        SetValue = function(value)
            currentValue = value; mainBtn.Text = "  " .. value
            for _, b in ipairs(buttons) do
                b.BackgroundColor3 = (b.Text == "  " .. value) and theme.Accent or theme.Surface
            end
        end,
        GetValue = function() return currentValue end,
        Close = closeMenu,
    }
    table.insert(allDropdowns, dropdown)
    return dropdown
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

_dropdownOverlay = ScreenGui

NotificationContainer = Instance.new("Frame")
NotificationContainer.Size = UDim2.new(0, 200, 0, 300)
NotificationContainer.Position = UDim2.new(1, -210, 0, 40)
NotificationContainer.BackgroundTransparency = 1
NotificationContainer.Parent = ScreenGui
local notifLayout = Instance.new("UIListLayout")
notifLayout.SortOrder = Enum.SortOrder.LayoutOrder
notifLayout.Padding = UDim.new(0, 4)
notifLayout.Parent = NotificationContainer

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 260, 0, 400)
MainFrame.Position = UDim2.new(0, 10, 0.15, 0)
MainFrame.BackgroundColor3 = theme.Background
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Visible = true
MainFrame.ZIndex = 5
MainFrame.Parent = ScreenGui
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
local mainStroke = Instance.new("UIStroke", MainFrame)
mainStroke.Color = theme.Accent; mainStroke.Thickness = 2

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
titleFix.BorderSizePixel = 0; titleFix.ZIndex = 6; titleFix.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -60, 1, 0)
Title.Position = UDim2.new(0, 10, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "V10 Ultra"
Title.TextColor3 = theme.AccentLight
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 7; Title.Parent = TitleBar

local MinimizeBtn = Instance.new("TextButton")
MinimizeBtn.Size = UDim2.new(0, 24, 0, 24)
MinimizeBtn.Position = UDim2.new(1, -30, 0, 5)
MinimizeBtn.BackgroundColor3 = theme.SurfaceLight
MinimizeBtn.TextColor3 = theme.Text
MinimizeBtn.Text = "-"
MinimizeBtn.Font = Enum.Font.GothamBold
MinimizeBtn.TextSize = 16
MinimizeBtn.AutoButtonColor = true
MinimizeBtn.ZIndex = 8; MinimizeBtn.Parent = TitleBar
Instance.new("UICorner", MinimizeBtn).CornerRadius = UDim.new(0, 6)

-- Tab bar
local TabBar = Instance.new("Frame")
TabBar.Size = UDim2.new(1, 0, 0, 28)
TabBar.Position = UDim2.new(0, 0, 0, 34)
TabBar.BackgroundColor3 = theme.Surface
TabBar.BorderSizePixel = 0; TabBar.ZIndex = 6; TabBar.Parent = MainFrame

local tabNames = {"KillAura", "ESP", "Aimbot", "Hitbox", "Misc"}
local tabButtons = {}
local tabFrames = {}

for i, name in ipairs(tabNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1 / #tabNames, 0, 1, 0)
    btn.Position = UDim2.new((i - 1) / #tabNames, 0, 0, 0)
    btn.BackgroundColor3 = name == Settings.CurrentTab and theme.Accent or theme.Surface
    btn.TextColor3 = theme.Text
    btn.Text = name == "KillAura" and "Aura" or (name == "Hitbox" and "HBox" or name)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 10
    btn.AutoButtonColor = true
    btn.ZIndex = 7; btn.Parent = TabBar
    tabButtons[name] = btn
end

local ContentArea = Instance.new("ScrollingFrame")
ContentArea.Size = UDim2.new(1, 0, 1, -62)
ContentArea.Position = UDim2.new(0, 0, 0, 62)
ContentArea.BackgroundTransparency = 1
ContentArea.BorderSizePixel = 0
ContentArea.ScrollBarThickness = 3
ContentArea.ScrollBarImageColor3 = theme.Accent
ContentArea.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentArea.ZIndex = 6; ContentArea.Parent = MainFrame
ContentArea.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        closeAllDropdowns()
    end
end)

-- ============================================================
-- TAB: KILL AURA
-- ============================================================
local KillAuraTab = Instance.new("Frame")
KillAuraTab.Size = UDim2.new(1, 0, 0, 900)
KillAuraTab.BackgroundTransparency = 1
KillAuraTab.Visible = true; KillAuraTab.ZIndex = 6; KillAuraTab.Parent = ContentArea
tabFrames["KillAura"] = KillAuraTab

local auraY = 4

-- ======= SECTION: KILL AURA CONTROLS =======
local auraHeader = Instance.new("TextLabel")
auraHeader.Size = UDim2.new(1, -20, 0, 16)
auraHeader.Position = UDim2.new(0, 10, 0, auraY)
auraHeader.BackgroundTransparency = 1; auraHeader.Text = "-- Kill Aura --"
auraHeader.TextColor3 = theme.AccentLight; auraHeader.Font = Enum.Font.GothamBold
auraHeader.TextSize = 12; auraHeader.TextXAlignment = Enum.TextXAlignment.Center
auraHeader.ZIndex = 6; auraHeader.Parent = KillAuraTab
auraY = auraY + 20

local KillAuraBtn
KillAuraBtn = makeButton(KillAuraTab, {
    Size = UDim2.new(0.92, 0, 0, 36),
    Position = UDim2.new(0.04, 0, 0, auraY),
    Color = theme.Danger,
    Text = "KILL AURA: OFF", TextSize = 14, ZIndex = 6,
    Callback = function()
        Settings.Enabled = not Settings.Enabled
        if Settings.Enabled then
            KillAuraBtn.Text = "KILL AURA: ON"
            KillAuraBtn.BackgroundColor3 = theme.Success
            showNotification("Kill Aura ON - " .. Settings.AuraMode, 2, theme.Success)
        else
            KillAuraBtn.Text = "KILL AURA: OFF"
            KillAuraBtn.BackgroundColor3 = theme.Danger
            showNotification("Kill Aura OFF", 2, theme.Danger)
        end
    end
})
auraY = auraY + 42

-- Toggles FIRST (before dropdowns so dropdown opens over empty space below)
local wallCheckToggle = makeToggle(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY), Text = "Wall Check",
    Default = Settings.WallCheck, ZIndex = 6,
    OnChanged = function(v) Settings.WallCheck = v end,
})
auraY = auraY + 28

local autoEquipToggle = makeToggle(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY), Text = "Auto Equip Weapon",
    Default = Settings.AutoWeaponEquip, ZIndex = 6,
    OnChanged = function(v) Settings.AutoWeaponEquip = v end,
})
auraY = auraY + 32

local targetPlayersToggle = makeToggle(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY), Text = "Target Players",
    Default = Settings.TargetPlayers, ZIndex = 6,
    OnChanged = function(v) Settings.TargetPlayers = v end,
})
auraY = auraY + 28

local targetNPCsToggle = makeToggle(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY), Text = "Target NPCs/Mobs",
    Default = Settings.TargetNPCs, ZIndex = 6,
    OnChanged = function(v) Settings.TargetNPCs = v end,
})
auraY = auraY + 32

-- Sliders
local radiusSlider = makeSlider(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Radius", Min = 10, Max = 2000, Default = Settings.Radius, Step = 5,
    Format = function(v) return math.floor(v) .. " studs" end,
    ZIndex = 6, OnChanged = function(v) Settings.Radius = math.floor(v) end,
})
auraY = auraY + 46

local delaySlider = makeSlider(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Delay", Min = 0.01, Max = 1.0, Default = Settings.Delay, Step = 0.01,
    FillColor = theme.Info,
    Format = function(v) return string.format("%.2fs", v) end,
    ZIndex = 6, OnChanged = function(v) Settings.Delay = math.floor(v * 100) / 100 end,
})
auraY = auraY + 46

local maxTargetSlider = makeSlider(KillAuraTab, {
    Position = UDim2.new(0, 10, 0, auraY),
    Text = "Max Targets", Min = 1, Max = 50, Default = Settings.MaxTargets, Step = 1,
    FillColor = theme.Warning,
    ZIndex = 6, OnChanged = function(v) Settings.MaxTargets = math.floor(v) end,
})
auraY = auraY + 50

-- Dropdowns at bottom (opens downward over empty space in scroll area)
local partLabel = Instance.new("TextLabel")
partLabel.Size = UDim2.new(1, -20, 0, 14)
partLabel.Position = UDim2.new(0, 10, 0, auraY)
partLabel.BackgroundTransparency = 1; partLabel.Text = "Target Part:"
partLabel.TextColor3 = theme.TextDim; partLabel.Font = Enum.Font.Gotham
partLabel.TextSize = 11; partLabel.TextXAlignment = Enum.TextXAlignment.Left
partLabel.ZIndex = 6; partLabel.Parent = KillAuraTab
auraY = auraY + 16

local PartDropdown = makeDropdown(KillAuraTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, auraY),
    Default = Settings.TargetPart,
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "LeftHand", "RightHand"},
    ZIndex = 6, OnChanged = function(v) Settings.TargetPart = v end,
})
auraY = auraY + 34

local priorityLabel = Instance.new("TextLabel")
priorityLabel.Size = UDim2.new(1, -20, 0, 14)
priorityLabel.Position = UDim2.new(0, 10, 0, auraY)
priorityLabel.BackgroundTransparency = 1; priorityLabel.Text = "Target Priority:"
priorityLabel.TextColor3 = theme.TextDim; priorityLabel.Font = Enum.Font.Gotham
priorityLabel.TextSize = 11; priorityLabel.TextXAlignment = Enum.TextXAlignment.Left
priorityLabel.ZIndex = 6; priorityLabel.Parent = KillAuraTab
auraY = auraY + 16

local PriorityDropdown = makeDropdown(KillAuraTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, auraY),
    Default = Settings.TargetPriority,
    Options = {"Closest", "LowestHP", "HighestHP", "Random"},
    ZIndex = 6, OnChanged = function(v) Settings.TargetPriority = v end,
})
auraY = auraY + 34

local modeLabel = Instance.new("TextLabel")
modeLabel.Size = UDim2.new(1, -20, 0, 14)
modeLabel.Position = UDim2.new(0, 10, 0, auraY)
modeLabel.BackgroundTransparency = 1; modeLabel.Text = "Aura Mode (25 modes):"
modeLabel.TextColor3 = theme.Warning; modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextSize = 11; modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.ZIndex = 6; modeLabel.Parent = KillAuraTab
auraY = auraY + 16

local AuraModeDropdown = makeDropdown(KillAuraTab, {
    Size = UDim2.new(1, -20, 0, 26),
    Position = UDim2.new(0, 10, 0, auraY),
    Default = Settings.AuraMode,
    Options = {
        "Auto",               -- 1. Tu dong chon method tot nhat
        "Normal",             -- 2. Detected remote
        "SpyReplay",          -- 3. Replay remote da hoc
        "Silent",             -- 4. Fire all cached remotes
        "ClientDamage",       -- 5. Set Health = 0 client
        "ToolActivate",       -- 6. Equip + Activate tool
        "TeleportHit",        -- 7. TP den + attack + TP ve
        "HitboxExpand",       -- 8. Mo rong hitbox target
        "FlingKill",          -- 9. Physics fling
        "RaycastSpam",        -- 10. Spam 5 lan
        "MultiHit",           -- 11. 3 hit lien tiep
        "RemoteSpam",         -- 12. Spam ALL remotes
        "NetworkBrute",       -- 13. Thu tat ca signature
        "Universal",          -- 14. Ket hop tat ca
        "TouchDamage",        -- 15. firetouchinterest
        "ClickDetector",      -- 16. fireclickdetector
        "ProximityPrompt",    -- 17. fireproximityprompt
        "ModuleExploit",      -- 18. Goi ham tu ModuleScript
        "AnimationAbuse",     -- 19. Play attack animation
        "VelocityKill",       -- 20. BodyVelocity crush
        "CFrameSnap",         -- 21. CFrame overlap kill
        "GodModeKill",        -- 22. God mode + fling
        "AllToolsSpam",       -- 23. Equip + activate ALL tools
        "BruteForceAll",      -- 24. Thu TAT CA methods
        "CustomSystem",       -- 25. Custom inventory/hotbar games
    },
    MaxVisibleOptions = 6,
    ZIndex = 6,
    OnChanged = function(v)
        Settings.AuraMode = v
        showNotification("Mode: " .. v, 2, theme.Warning)
    end,
})
auraY = auraY + 40

-- ======= SECTION: AUTO SCAN =======
local scanHeader = Instance.new("Frame")
scanHeader.Size = UDim2.new(1, -20, 0, 2)
scanHeader.Position = UDim2.new(0, 10, 0, auraY)
scanHeader.BackgroundColor3 = theme.SurfaceLight
scanHeader.BorderSizePixel = 0; scanHeader.ZIndex = 6; scanHeader.Parent = KillAuraTab
auraY = auraY + 6

local scanTitle = Instance.new("TextLabel")
scanTitle.Size = UDim2.new(1, -20, 0, 16)
scanTitle.Position = UDim2.new(0, 10, 0, auraY)
scanTitle.BackgroundTransparency = 1; scanTitle.Text = "-- Auto Scan --"
scanTitle.TextColor3 = theme.AccentLight; scanTitle.Font = Enum.Font.GothamBold
scanTitle.TextSize = 12; scanTitle.TextXAlignment = Enum.TextXAlignment.Center
scanTitle.ZIndex = 6; scanTitle.Parent = KillAuraTab
auraY = auraY + 20

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -20, 0, 14)
StatusLabel.Position = UDim2.new(0, 10, 0, auraY)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Initializing..."
StatusLabel.TextColor3 = theme.TextDim
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.ZIndex = 6; StatusLabel.Parent = KillAuraTab
auraY = auraY + 15

local GameTypeLabel = Instance.new("TextLabel")
GameTypeLabel.Size = UDim2.new(1, -20, 0, 14)
GameTypeLabel.Position = UDim2.new(0, 10, 0, auraY)
GameTypeLabel.BackgroundTransparency = 1
GameTypeLabel.Text = "Game: Detecting..."
GameTypeLabel.TextColor3 = theme.Info
GameTypeLabel.Font = Enum.Font.Gotham
GameTypeLabel.TextSize = 9
GameTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
GameTypeLabel.ZIndex = 6; GameTypeLabel.Parent = KillAuraTab
auraY = auraY + 15

local SpyStatusLabel = Instance.new("TextLabel")
SpyStatusLabel.Size = UDim2.new(1, -20, 0, 14)
SpyStatusLabel.Position = UDim2.new(0, 10, 0, auraY)
SpyStatusLabel.BackgroundTransparency = 1
SpyStatusLabel.Text = "Spy: 0 | Scan: 0"
SpyStatusLabel.TextColor3 = theme.Warning
SpyStatusLabel.Font = Enum.Font.Gotham
SpyStatusLabel.TextSize = 9
SpyStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
SpyStatusLabel.ZIndex = 6; SpyStatusLabel.Parent = KillAuraTab
auraY = auraY + 18

local RescanBtn = makeButton(KillAuraTab, {
    Size = UDim2.new(0.92, 0, 0, 32),
    Position = UDim2.new(0.04, 0, 0, auraY),
    Color = theme.SurfaceLight,
    Text = "Rescan Remotes", TextSize = 11, ZIndex = 6,
    Callback = function()
        task.spawn(function() scanRemotes(); showNotification("Scan complete", 2, theme.Info) end)
    end
})
auraY = auraY + 38

KillAuraTab.Size = UDim2.new(1, 0, 0, auraY + 10)

-- ============================================================
-- TAB: ESP
-- ============================================================
local ESPTab = Instance.new("Frame")
ESPTab.Size = UDim2.new(1, 0, 0, 350)
ESPTab.BackgroundTransparency = 1; ESPTab.Visible = false
ESPTab.ZIndex = 6; ESPTab.Parent = ContentArea
tabFrames["ESP"] = ESPTab

local espY = 6

local ESPBtn
ESPBtn = makeButton(ESPTab, {
    Size = UDim2.new(0.92, 0, 0, 36),
    Position = UDim2.new(0.04, 0, 0, espY),
    Color = theme.SurfaceLight, Text = "ESP: OFF", TextSize = 14, ZIndex = 6,
    Callback = function()
        Settings.ESPEnabled = not Settings.ESPEnabled
        ESPBtn.Text = Settings.ESPEnabled and "ESP: ON" or "ESP: OFF"
        ESPBtn.BackgroundColor3 = Settings.ESPEnabled and theme.Info or theme.SurfaceLight
        showNotification("ESP " .. (Settings.ESPEnabled and "ON" or "OFF"), 2, Settings.ESPEnabled and theme.Info or theme.TextDim)
    end
})
espY = espY + 44

local espToggles = {
    {text = "Boxes", key = "ESPBoxes"}, {text = "Names", key = "ESPNames"},
    {text = "Distance", key = "ESPDistance"}, {text = "Health Bar", key = "ESPHealth"},
    {text = "Tracers", key = "ESPTracers"}, {text = "Chams", key = "ESPChams"},
    {text = "Skeleton", key = "ESPSkeleton"}, {text = "Team Check", key = "ESPTeamCheck"},
}
for _, toggle in ipairs(espToggles) do
    makeToggle(ESPTab, {
        Position = UDim2.new(0, 10, 0, espY), Text = toggle.text,
        Default = Settings[toggle.key], ZIndex = 6,
        OnChanged = function(v) Settings[toggle.key] = v end,
    })
    espY = espY + 32
end

makeSlider(ESPTab, {
    Position = UDim2.new(0, 10, 0, espY), Text = "Max Distance",
    Min = 100, Max = 5000, Default = Settings.ESPMaxDistance, Step = 50,
    FillColor = theme.Info, ZIndex = 6,
    OnChanged = function(v) Settings.ESPMaxDistance = math.floor(v) end,
})
espY = espY + 50
ESPTab.Size = UDim2.new(1, 0, 0, espY + 10)

-- ============================================================
-- TAB: AIMBOT
-- ============================================================
local AimbotTab = Instance.new("Frame")
AimbotTab.Size = UDim2.new(1, 0, 0, 280)
AimbotTab.BackgroundTransparency = 1; AimbotTab.Visible = false
AimbotTab.ZIndex = 6; AimbotTab.Parent = ContentArea
tabFrames["Aimbot"] = AimbotTab

local aimY = 6

local AimbotBtn
AimbotBtn = makeButton(AimbotTab, {
    Size = UDim2.new(0.92, 0, 0, 36),
    Position = UDim2.new(0.04, 0, 0, aimY),
    Color = theme.SurfaceLight, Text = "Aimbot: OFF", TextSize = 14, ZIndex = 6,
    Callback = function()
        Settings.AimbotEnabled = not Settings.AimbotEnabled
        AimbotBtn.Text = Settings.AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
        AimbotBtn.BackgroundColor3 = Settings.AimbotEnabled and theme.Warning or theme.SurfaceLight
        showNotification("Aimbot " .. (Settings.AimbotEnabled and "ON" or "OFF"), 2, Settings.AimbotEnabled and theme.Warning or theme.TextDim)
    end
})
aimY = aimY + 44

makeSlider(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY), Text = "FOV Radius",
    Min = 20, Max = 500, Default = Settings.AimbotFOV, Step = 5,
    FillColor = theme.Warning, ZIndex = 6,
    OnChanged = function(v) Settings.AimbotFOV = math.floor(v) end,
})
aimY = aimY + 50

makeSlider(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY), Text = "Smoothing",
    Min = 0.05, Max = 1.0, Default = Settings.AimbotSmooth, Step = 0.05,
    FillColor = theme.AccentLight,
    Format = function(v) return string.format("%.0f%%", v * 100) end,
    ZIndex = 6, OnChanged = function(v) Settings.AimbotSmooth = math.floor(v * 100) / 100 end,
})
aimY = aimY + 50

local aimPartLabel = Instance.new("TextLabel")
aimPartLabel.Size = UDim2.new(1, -20, 0, 14)
aimPartLabel.Position = UDim2.new(0, 10, 0, aimY)
aimPartLabel.BackgroundTransparency = 1; aimPartLabel.Text = "Aim Part:"
aimPartLabel.TextColor3 = theme.TextDim; aimPartLabel.Font = Enum.Font.Gotham
aimPartLabel.TextSize = 11; aimPartLabel.TextXAlignment = Enum.TextXAlignment.Left
aimPartLabel.ZIndex = 6; aimPartLabel.Parent = AimbotTab
aimY = aimY + 16

makeDropdown(AimbotTab, {
    Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, aimY),
    Default = Settings.AimbotPart,
    Options = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    ZIndex = 6, OnChanged = function(v) Settings.AimbotPart = v end,
})
aimY = aimY + 34

makeToggle(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY), Text = "Show FOV Circle",
    Default = Settings.ShowFOVCircle, ZIndex = 6,
    OnChanged = function(v) Settings.ShowFOVCircle = v end,
})
aimY = aimY + 34

makeToggle(AimbotTab, {
    Position = UDim2.new(0, 10, 0, aimY), Text = "Team Check",
    Default = Settings.AimbotTeamCheck, ZIndex = 6,
    OnChanged = function(v) Settings.AimbotTeamCheck = v end,
})
aimY = aimY + 34
AimbotTab.Size = UDim2.new(1, 0, 0, aimY + 10)

-- ============================================================
-- TAB: HITBOX
-- ============================================================
local HitboxTab = Instance.new("Frame")
HitboxTab.Size = UDim2.new(1, 0, 0, 500)
HitboxTab.BackgroundTransparency = 1; HitboxTab.Visible = false
HitboxTab.ZIndex = 6; HitboxTab.Parent = ContentArea
tabFrames["Hitbox"] = HitboxTab

local hbY = 6

local hbTitle = Instance.new("TextLabel")
hbTitle.Size = UDim2.new(1, -20, 0, 16)
hbTitle.Position = UDim2.new(0, 10, 0, hbY)
hbTitle.BackgroundTransparency = 1; hbTitle.Text = "Hitbox Expander - All Players"
hbTitle.TextColor3 = theme.Warning; hbTitle.Font = Enum.Font.GothamBold
hbTitle.TextSize = 12; hbTitle.TextXAlignment = Enum.TextXAlignment.Left
hbTitle.ZIndex = 6; hbTitle.Parent = HitboxTab
hbY = hbY + 20

local HitboxBtn = makeButton(HitboxTab, {
    Size = UDim2.new(1, -20, 0, 36),
    Position = UDim2.new(0, 10, 0, hbY),
    Color = theme.Danger, Text = "HITBOX: OFF", TextSize = 14, ZIndex = 6,
    Callback = function()
        Settings.HitboxEnabled = not Settings.HitboxEnabled
        HitboxBtn.Text = Settings.HitboxEnabled and "HITBOX: ON" or "HITBOX: OFF"
        HitboxBtn.BackgroundColor3 = Settings.HitboxEnabled and theme.Success or theme.Danger
        showNotification("Hitbox " .. (Settings.HitboxEnabled and "ON" or "OFF"), 2, Settings.HitboxEnabled and theme.Success or theme.Danger)
    end
})
hbY = hbY + 44

local hbInfoLabel = Instance.new("TextLabel")
hbInfoLabel.Size = UDim2.new(1, -20, 0, 28)
hbInfoLabel.Position = UDim2.new(0, 10, 0, hbY)
hbInfoLabel.BackgroundTransparency = 1
hbInfoLabel.Text = "Expand all players' hitbox (except you)\nWalk through + shoot from inside hitbox"
hbInfoLabel.TextColor3 = theme.TextDim; hbInfoLabel.Font = Enum.Font.Gotham
hbInfoLabel.TextSize = 9; hbInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
hbInfoLabel.TextWrapped = true; hbInfoLabel.ZIndex = 6; hbInfoLabel.Parent = HitboxTab
hbY = hbY + 34

local hbXLabel = Instance.new("TextLabel")
hbXLabel.Size = UDim2.new(1, -20, 0, 14)
hbXLabel.Position = UDim2.new(0, 10, 0, hbY)
hbXLabel.BackgroundTransparency = 1; hbXLabel.Text = "Hitbox X Size:"
hbXLabel.TextColor3 = theme.TextDim; hbXLabel.Font = Enum.Font.Gotham
hbXLabel.TextSize = 11; hbXLabel.TextXAlignment = Enum.TextXAlignment.Left
hbXLabel.ZIndex = 6; hbXLabel.Parent = HitboxTab
hbY = hbY + 14

local hbXSlider = makeSlider(HitboxTab, {
    Position = UDim2.new(0, 10, 0, hbY), Text = "X",
    Min = 0, Max = 3000, Default = Settings.HitboxX, Step = 10,
    FillColor = Color3.fromRGB(255, 80, 80), ZIndex = 6,
    OnChanged = function(v) Settings.HitboxX = math.floor(v) end,
})
hbY = hbY + 50

local hbYLabel = Instance.new("TextLabel")
hbYLabel.Size = UDim2.new(1, -20, 0, 14)
hbYLabel.Position = UDim2.new(0, 10, 0, hbY)
hbYLabel.BackgroundTransparency = 1; hbYLabel.Text = "Hitbox Y Size:"
hbYLabel.TextColor3 = theme.TextDim; hbYLabel.Font = Enum.Font.Gotham
hbYLabel.TextSize = 11; hbYLabel.TextXAlignment = Enum.TextXAlignment.Left
hbYLabel.ZIndex = 6; hbYLabel.Parent = HitboxTab
hbY = hbY + 14

local hbYSlider = makeSlider(HitboxTab, {
    Position = UDim2.new(0, 10, 0, hbY), Text = "Y",
    Min = 0, Max = 3000, Default = Settings.HitboxY, Step = 10,
    FillColor = Color3.fromRGB(80, 255, 80), ZIndex = 6,
    OnChanged = function(v) Settings.HitboxY = math.floor(v) end,
})
hbY = hbY + 50

local hbZLabel = Instance.new("TextLabel")
hbZLabel.Size = UDim2.new(1, -20, 0, 14)
hbZLabel.Position = UDim2.new(0, 10, 0, hbY)
hbZLabel.BackgroundTransparency = 1; hbZLabel.Text = "Hitbox Z Size:"
hbZLabel.TextColor3 = theme.TextDim; hbZLabel.Font = Enum.Font.Gotham
hbZLabel.TextSize = 11; hbZLabel.TextXAlignment = Enum.TextXAlignment.Left
hbZLabel.ZIndex = 6; hbZLabel.Parent = HitboxTab
hbY = hbY + 14

local hbZSlider = makeSlider(HitboxTab, {
    Position = UDim2.new(0, 10, 0, hbY), Text = "Z",
    Min = 0, Max = 3000, Default = Settings.HitboxZ, Step = 10,
    FillColor = Color3.fromRGB(80, 80, 255), ZIndex = 6,
    OnChanged = function(v) Settings.HitboxZ = math.floor(v) end,
})
hbY = hbY + 50

makeSlider(HitboxTab, {
    Position = UDim2.new(0, 10, 0, hbY), Text = "Transparency",
    Min = 0, Max = 1, Default = Settings.HitboxTransparency, Step = 0.05,
    FillColor = theme.AccentLight, ZIndex = 6,
    OnChanged = function(v) Settings.HitboxTransparency = v end,
})
hbY = hbY + 50

makeToggle(HitboxTab, {
    Position = UDim2.new(0, 10, 0, hbY), Text = "Walk Through (NoCollide)",
    Default = not Settings.HitboxCanCollide, ZIndex = 6,
    OnChanged = function(v) Settings.HitboxCanCollide = not v end,
})
hbY = hbY + 32

makeToggle(HitboxTab, {
    Position = UDim2.new(0, 10, 0, hbY), Text = "Show Hitbox (Visible)",
    Default = Settings.HitboxVisible, ZIndex = 6,
    OnChanged = function(v) Settings.HitboxVisible = v end,
})
hbY = hbY + 32

local hbPresetLabel = Instance.new("TextLabel")
hbPresetLabel.Size = UDim2.new(1, -20, 0, 14)
hbPresetLabel.Position = UDim2.new(0, 10, 0, hbY)
hbPresetLabel.BackgroundTransparency = 1; hbPresetLabel.Text = "Quick Presets:"
hbPresetLabel.TextColor3 = theme.TextDim; hbPresetLabel.Font = Enum.Font.GothamBold
hbPresetLabel.TextSize = 11; hbPresetLabel.TextXAlignment = Enum.TextXAlignment.Left
hbPresetLabel.ZIndex = 6; hbPresetLabel.Parent = HitboxTab
hbY = hbY + 18

local presets = {
    {name = "Small (20)", x = 20, y = 20, z = 20},
    {name = "Medium (50)", x = 50, y = 50, z = 50},
    {name = "Large (200)", x = 200, y = 200, z = 200},
    {name = "MEGA (1000)", x = 1000, y = 1000, z = 1000},
    {name = "MAX (3000)", x = 3000, y = 3000, z = 3000},
}
for pi, preset in ipairs(presets) do
    local col = (pi - 1) % 3
    local row = math.floor((pi - 1) / 3)
    makeButton(HitboxTab, {
        Size = UDim2.new(0.3, -4, 0, 28),
        Position = UDim2.new(col * 0.33 + 0.02, 0, 0, hbY + row * 34),
        Color = theme.SurfaceLight, Text = preset.name, TextSize = 9, ZIndex = 6,
        Callback = function()
            Settings.HitboxX = preset.x; Settings.HitboxY = preset.y; Settings.HitboxZ = preset.z
            if hbXSlider and hbXSlider.SetValue then hbXSlider.SetValue(preset.x) end
            if hbYSlider and hbYSlider.SetValue then hbYSlider.SetValue(preset.y) end
            if hbZSlider and hbZSlider.SetValue then hbZSlider.SetValue(preset.z) end
            showNotification("Hitbox: " .. preset.name, 2, theme.Info)
        end
    })
end
hbY = hbY + 72

local hbStatusLabel = Instance.new("TextLabel")
hbStatusLabel.Size = UDim2.new(1, -20, 0, 14)
hbStatusLabel.Position = UDim2.new(0, 10, 0, hbY)
hbStatusLabel.BackgroundTransparency = 1
hbStatusLabel.Text = "Hitbox: OFF"
hbStatusLabel.TextColor3 = theme.TextDim; hbStatusLabel.Font = Enum.Font.Gotham
hbStatusLabel.TextSize = 10; hbStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
hbStatusLabel.ZIndex = 6; hbStatusLabel.Parent = HitboxTab
hbY = hbY + 20

HitboxTab.Size = UDim2.new(1, 0, 0, hbY + 10)

-- ============================================================
-- TAB: MISC
-- ============================================================
local MiscTab = Instance.new("Frame")
MiscTab.Size = UDim2.new(1, 0, 0, 450)
MiscTab.BackgroundTransparency = 1; MiscTab.Visible = false
MiscTab.ZIndex = 6; MiscTab.Parent = ContentArea
tabFrames["Misc"] = MiscTab

local miscY = 6

local miscToggles = {
    {text = "Anti-AFK", key = "AntiAFK"},
    {text = "Infinite Jump", key = "InfiniteJump"},
    {text = "Speed Hack", key = "SpeedEnabled"},
}
for _, t in ipairs(miscToggles) do
    makeToggle(MiscTab, {
        Position = UDim2.new(0, 10, 0, miscY), Text = t.text,
        Default = Settings[t.key], ZIndex = 6,
        OnChanged = function(v)
            Settings[t.key] = v
            showNotification(t.text .. " " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
        end,
    })
    miscY = miscY + 32
end

makeSlider(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Walk Speed",
    Min = 16, Max = 200, Default = Settings.SpeedValue, Step = 2,
    ZIndex = 6, OnChanged = function(v) Settings.SpeedValue = math.floor(v) end,
})
miscY = miscY + 50

makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Fly",
    Default = Settings.FlyEnabled, ZIndex = 6,
    OnChanged = function(v) Settings.FlyEnabled = v; showNotification("Fly " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim) end,
})
miscY = miscY + 32

makeSlider(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Fly Speed",
    Min = 10, Max = 200, Default = Settings.FlySpeed, Step = 5,
    FillColor = theme.Info, ZIndex = 6,
    OnChanged = function(v) Settings.FlySpeed = math.floor(v) end,
})
miscY = miscY + 50

-- Sword Flying separator
local swordSep = Instance.new("Frame")
swordSep.Size = UDim2.new(1, -20, 0, 1); swordSep.Position = UDim2.new(0, 10, 0, miscY)
swordSep.BackgroundColor3 = theme.Border; swordSep.BorderSizePixel = 0; swordSep.ZIndex = 6; swordSep.Parent = MiscTab
miscY = miscY + 8

local swordLabel = Instance.new("TextLabel")
swordLabel.Size = UDim2.new(1, -20, 0, 16); swordLabel.Position = UDim2.new(0, 10, 0, miscY)
swordLabel.BackgroundTransparency = 1; swordLabel.Text = "Ngu Kiem Phi Hanh (Sword Fly)"
swordLabel.TextColor3 = theme.Accent; swordLabel.Font = Enum.Font.GothamBold
swordLabel.TextSize = 12; swordLabel.TextXAlignment = Enum.TextXAlignment.Left
swordLabel.ZIndex = 6; swordLabel.Parent = MiscTab
miscY = miscY + 20

makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Sword Fly",
    Default = Settings.SwordFlyEnabled, ZIndex = 6,
    OnChanged = function(v)
        Settings.SwordFlyEnabled = v
        if v then Settings.FlyEnabled = false end
        showNotification("Ngu Kiem Phi Hanh " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim)
    end,
})
miscY = miscY + 32

makeSlider(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Sword Speed",
    Min = 20, Max = 300, Default = Settings.SwordFlySpeed, Step = 5,
    FillColor = theme.Accent, ZIndex = 6,
    OnChanged = function(v) Settings.SwordFlySpeed = math.floor(v) end,
})
miscY = miscY + 50

-- End sword fly section separator
local swordSep2 = Instance.new("Frame")
swordSep2.Size = UDim2.new(1, -20, 0, 1); swordSep2.Position = UDim2.new(0, 10, 0, miscY)
swordSep2.BackgroundColor3 = theme.Border; swordSep2.BorderSizePixel = 0; swordSep2.ZIndex = 6; swordSep2.Parent = MiscTab
miscY = miscY + 8

makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Anti-Void",
    Default = Settings.AntiVoid, ZIndex = 6,
    OnChanged = function(v) Settings.AntiVoid = v end,
})
miscY = miscY + 32

makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "NoClip",
    Default = Settings.NoClip, ZIndex = 6,
    OnChanged = function(v) Settings.NoClip = v; showNotification("NoClip " .. (v and "ON" or "OFF"), 2, v and theme.Success or theme.TextDim) end,
})
miscY = miscY + 32

makeToggle(MiscTab, {
    Position = UDim2.new(0, 10, 0, miscY), Text = "Debug Mode",
    Default = Settings.DebugMode, ZIndex = 6,
    OnChanged = function(v) Settings.DebugMode = v end,
})
miscY = miscY + 36

local themeLabel = Instance.new("TextLabel")
themeLabel.Size = UDim2.new(1, -20, 0, 14)
themeLabel.Position = UDim2.new(0, 10, 0, miscY)
themeLabel.BackgroundTransparency = 1; themeLabel.Text = "Theme:"
themeLabel.TextColor3 = theme.TextDim; themeLabel.Font = Enum.Font.Gotham
themeLabel.TextSize = 11; themeLabel.TextXAlignment = Enum.TextXAlignment.Left
themeLabel.ZIndex = 6; themeLabel.Parent = MiscTab
miscY = miscY + 16

makeDropdown(MiscTab, {
    Size = UDim2.new(1, -20, 0, 26), Position = UDim2.new(0, 10, 0, miscY),
    Default = Settings.Theme, Options = {"Purple", "Red", "Blue"},
    ZIndex = 6, OnChanged = function(v) Settings.Theme = v; saveConfig() end,
})
miscY = miscY + 38

makeButton(MiscTab, {
    Size = UDim2.new(0.44, 0, 0, 32),
    Position = UDim2.new(0.04, 0, 0, miscY),
    Color = theme.Success, Text = "Save", TextSize = 11, ZIndex = 6,
    Callback = function()
        showNotification(saveConfig() and "Config saved!" or "Save failed", 2, saveConfig() and theme.Success or theme.Danger)
    end
})
makeButton(MiscTab, {
    Size = UDim2.new(0.44, 0, 0, 32),
    Position = UDim2.new(0.52, 0, 0, miscY),
    Color = theme.Info, Text = "Load", TextSize = 11, ZIndex = 6,
    Callback = function()
        showNotification(loadConfig() and "Config loaded!" or "No config", 2, loadConfig() and theme.Info or theme.Warning)
    end
})
miscY = miscY + 40

makeButton(MiscTab, {
    Size = UDim2.new(0.92, 0, 0, 32),
    Position = UDim2.new(0.04, 0, 0, miscY),
    Color = theme.Danger, Text = "Destroy Script", TextSize = 12, ZIndex = 6,
    Callback = function()
        for _, conn in ipairs(Settings._Connections) do pcall(function() conn:Disconnect() end) end
        for _, conn in ipairs(Settings.TouchConnections) do pcall(function() conn:Disconnect() end) end
        if Settings._FOVCircle then pcall(function() Settings._FOVCircle:Remove() end) end
        for char, _ in pairs(ESP_Cache or {}) do pcall(function() RemoveESP(char) end) end
        pcall(resetHitboxes)
        pcall(destroySwordModel)
        if swordBV then pcall(function() swordBV:Destroy() end) end
        if swordBG then pcall(function() swordBG:Destroy() end) end
        ScreenGui:Destroy()
        showNotification = function() end
    end
})
miscY = miscY + 40
MiscTab.Size = UDim2.new(1, 0, 0, miscY + 10)

-- ============================================================
-- TAB SWITCHING
-- ============================================================
local function switchTab(tabName)
    Settings.CurrentTab = tabName
    for name, frame in pairs(tabFrames) do frame.Visible = (name == tabName) end
    for name, btn in pairs(tabButtons) do
        btn.BackgroundColor3 = (name == tabName) and theme.Accent or theme.Surface
    end
    local activeFrame = tabFrames[tabName]
    if activeFrame then ContentArea.CanvasSize = UDim2.new(0, 0, 0, activeFrame.Size.Y.Offset) end
end
for name, btn in pairs(tabButtons) do
    local lastClick = 0
    btn.MouseButton1Click:Connect(function()
        local now = tick()
        if now - lastClick < 0.25 then return end
        lastClick = now; switchTab(name)
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
MiniIcon.BorderSizePixel = 0; MiniIcon.Active = true; MiniIcon.Visible = false
MiniIcon.ZIndex = 100; MiniIcon.Parent = ScreenGui
Instance.new("UICorner", MiniIcon).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", MiniIcon).Color = theme.Text

local MiniIconText = Instance.new("TextLabel")
MiniIconText.Size = UDim2.new(1, 0, 0.7, 0)
MiniIconText.BackgroundTransparency = 1; MiniIconText.Text = "V10"
MiniIconText.TextColor3 = theme.Text; MiniIconText.Font = Enum.Font.GothamBold
MiniIconText.TextSize = 14; MiniIconText.ZIndex = 102; MiniIconText.Parent = MiniIcon

local MiniStatusDot = Instance.new("Frame")
MiniStatusDot.Size = UDim2.new(0, 12, 0, 12)
MiniStatusDot.Position = UDim2.new(1, -6, 0, -4)
MiniStatusDot.BackgroundColor3 = theme.Danger; MiniStatusDot.BorderSizePixel = 0
MiniStatusDot.ZIndex = 103; MiniStatusDot.Parent = MiniIcon
Instance.new("UICorner", MiniStatusDot).CornerRadius = UDim.new(1, 0)

local MiniStatusLabel = Instance.new("TextLabel")
MiniStatusLabel.Size = UDim2.new(1, 0, 0, 12)
MiniStatusLabel.Position = UDim2.new(0, 0, 0.7, 0)
MiniStatusLabel.BackgroundTransparency = 1; MiniStatusLabel.Text = "OFF"
MiniStatusLabel.TextColor3 = theme.Text; MiniStatusLabel.Font = Enum.Font.GothamBold
MiniStatusLabel.TextSize = 9; MiniStatusLabel.ZIndex = 102; MiniStatusLabel.Parent = MiniIcon

local function updateMiniIcon()
    MiniStatusLabel.Text = Settings.Enabled and "ON" or "OFF"
    MiniStatusDot.BackgroundColor3 = Settings.Enabled and theme.Success or theme.Danger
    MiniIcon.BackgroundColor3 = Settings.Enabled and theme.Success or theme.Accent
end

local MiniDrag = Instance.new("Frame")
MiniDrag.Size = UDim2.new(1, 0, 1, 0); MiniDrag.BackgroundTransparency = 1
MiniDrag.Active = true; MiniDrag.ZIndex = 105; MiniDrag.Parent = MiniIcon

do
    local miniDragging = false
    local miniDragStart = nil
    local miniStartPos = nil
    local miniDragInput = nil
    local miniMoved = false

    MiniDrag.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseButton1 then
            miniDragging = true
            miniMoved = false
            miniDragStart = input.Position
            miniStartPos = MiniIcon.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    if not miniMoved then
                        Settings.Minimized = false; MiniIcon.Visible = false; MainFrame.Visible = true
                    end
                    miniDragging = false
                end
            end)
        end
    end)
    MiniDrag.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or
           input.UserInputType == Enum.UserInputType.MouseMovement then
            miniDragInput = input
        end
    end)
    local miniConn = UserInputService.InputChanged:Connect(function(input)
        if input == miniDragInput and miniDragging then
            local delta = input.Position - miniDragStart
            if delta.Magnitude > 5 then miniMoved = true end
            MiniIcon.Position = UDim2.new(miniStartPos.X.Scale, miniStartPos.X.Offset + delta.X,
                miniStartPos.Y.Scale, miniStartPos.Y.Offset + delta.Y)
        end
    end)
    table.insert(Settings._Connections, miniConn)
end

local minimizeLastClick = 0
MinimizeBtn.MouseButton1Click:Connect(function()
    local now = tick()
    if now - minimizeLastClick < 0.25 then return end
    minimizeLastClick = now
    Settings.Minimized = true; MainFrame.Visible = false; MiniIcon.Visible = true; updateMiniIcon()
end)
makeDraggable(TitleBar, MainFrame)

-- ============================================================
-- ADVANCED REMOTE SPY (spy ALL remotes, not just damage keywords)
-- ============================================================
local RemoteSpyData = {}

local function startRemoteSpy()
    if not hasHookMeta then log("hookmetamethod missing"); return end

    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if method == "FireServer" or method == "InvokeServer" then
            local name = self.Name:lower()
            local damageKW = {
                "fire", "hit", "damage", "weapon", "shoot", "attack",
                "gun", "bullet", "raycast", "combat", "melee", "sword",
                "slash", "strike", "impact", "projectile", "shot",
                "hurt", "kill", "wound", "critical", "punch", "kick",
                "ability", "skill", "spell", "cast", "use", "action",
                "interact", "click", "activate", "trigger", "execute",
                "deal", "apply", "inflict", "combat", "fight", "war",
                "battle", "duel", "pvp", "pve", "mob", "boss", "npc",
                "enemy", "target", "victim", "health", "hp", "die",
                "death", "destroy", "remove", "delete", "eliminate",
                "slay", "smash", "crush", "break", "smite", "blast",
                "boom", "explode", "detonate", "burst", "nova", "beam",
                "laser", "bolt", "arrow", "throw", "toss", "launch",
                "push", "pull", "grab", "catch", "block", "parry",
                "dodge", "evade", "counter", "reflect", "absorb",
                "replication", "sync", "request", "server", "remote",
                "event", "function", "rpc", "net", "network", "send",
                "receive", "process", "handle", "update", "change",
                "modify", "set", "get", "move", "position", "velocity",
            }
            local found = false
            for _, kw in ipairs(damageKW) do
                if name:find(kw, 1, true) then found = true; break end
            end

            if found then
                local args = {...}
                if not RemoteSpyData[self] then
                    RemoteSpyData[self] = {args = {}, count = 0, name = self.Name, path = self:GetFullName()}
                    Settings.SpyRemotes[self] = RemoteSpyData[self]
                    showNotification("Spy: " .. self.Name, 3, theme.Warning)
                    local count = 0
                    for _ in pairs(Settings.SpyRemotes) do count = count + 1 end
                    SpyStatusLabel.Text = "Spy: " .. count .. " | Scan: " .. #Settings.AllDamageRemotes .. " | Touch: " .. #Settings.TouchConnections
                end
                RemoteSpyData[self].args = args
                RemoteSpyData[self].count = RemoteSpyData[self].count + 1

                if not Settings.SpyCapturedArgs[self.Name] then
                    Settings.SpyCapturedArgs[self.Name] = {}
                end
                table.insert(Settings.SpyCapturedArgs[self.Name], args)
                if #Settings.SpyCapturedArgs[self.Name] > 10 then
                    table.remove(Settings.SpyCapturedArgs[self.Name], 1)
                end
            end
        end
        return oldNamecall(self, ...)
    end)
    log("RemoteSpy started (extended keywords)")
end

task.spawn(startRemoteSpy)

-- ============================================================
-- UNIVERSAL REMOTE SCANNER - SCAN EVERYTHING
-- ============================================================
local DAMAGE_KEYWORDS = {
    "damage", "hit", "fire", "shoot", "weapon", "gun", "attack",
    "melee", "sword", "bullet", "raycast", "combat", "strike",
    "slash", "hurt", "wound", "kill", "projectile", "shot",
    "blaster", "rifle", "pistol", "weaponfired", "weaponhit",
    "applydamage", "dealdamage", "takedamage", "gunremote",
    "actionsync", "replicate", "muzzle", "impact", "critical",
    "punch", "kick", "ability", "skill", "spell", "cast",
    "action", "interact", "activate", "trigger", "execute",
    "deal", "apply", "inflict", "slay", "smash", "crush",
    "blast", "explode", "beam", "arrow", "throw", "launch",
    "combat", "fight", "battle", "pvp", "pve", "mob", "boss",
    "health", "hp", "die", "death", "destroy", "eliminate",
    "request", "sync", "replication", "server", "remote",
    "event", "function", "rpc", "network", "send", "process",
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
        local next_ = current:FindFirstChild(folderName)
        if not next_ then return nil end
        current = next_
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

    -- Priority scan: ReplicatedStorage first (most games store remotes here)
    local priorityContainers = {ReplicatedStorage}
    local secondaryContainers = {}
    pcall(function() table.insert(priorityContainers, Workspace) end)
    pcall(function() table.insert(secondaryContainers, LocalPlayer.PlayerGui) end)
    pcall(function() table.insert(secondaryContainers, game:GetService("ReplicatedFirst")) end)
    pcall(function() table.insert(secondaryContainers, game:GetService("StarterPlayer")) end)
    pcall(function() table.insert(secondaryContainers, game:GetService("StarterPack")) end)
    pcall(function() table.insert(secondaryContainers, StarterGui) end)
    pcall(function() table.insert(secondaryContainers, game:GetService("Lighting")) end)

    local function scanContainer(container)
        if not container then return end
        pcall(function()
            for _, obj in ipairs(container:GetDescendants()) do
                if not scanned[obj] and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                    scanned[obj] = true
                    table.insert(Settings.AllRemotes, obj)
                    if isDamageRemoteName(obj.Name) then
                        table.insert(found, obj)
                    end
                end
            end
        end)
    end

    -- Scan priority containers first
    for _, c in ipairs(priorityContainers) do scanContainer(c) end

    -- Scan nil instances
    if hasGetNilInstances then
        pcall(function()
            for _, obj in ipairs(getnilinstances()) do
                if not scanned[obj] and (obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction")) then
                    scanned[obj] = true
                    table.insert(found, obj)
                    table.insert(Settings.AllRemotes, obj)
                end
            end
        end)
    end

    -- Secondary containers in background
    task.spawn(function()
        for _, c in ipairs(secondaryContainers) do scanContainer(c) end
    end)

    return found
end

-- Game type detection
local function detectGameType()
    local gameType = "Unknown"
    local indicators = {
        Sword = {"Sword", "Blade", "Katana", "Slash", "Melee", "ClassicSword"},
        Shooter = {"Gun", "Rifle", "Pistol", "Ammo", "Bullet", "Magazine", "Scope", "ADS"},
        Fighting = {"Punch", "Kick", "Block", "Combo", "Stance", "Ki", "Chakra", "Stand", "Quirk", "Devil", "Fruit", "Haki"},
        RPG = {"Level", "XP", "Quest", "NPC", "Shop", "Inventory", "Dungeon", "Boss", "Loot"},
        Simulator = {"Rebirth", "Pet", "Collect", "Sell", "Upgrade", "Auto", "Hatch", "Egg"},
        Tycoon = {"Dropper", "Conveyor", "Collector", "Button", "Tycoon", "Factory"},
        Horror = {"Killer", "Survivor", "Sprint", "Battery", "Flashlight", "Hide", "Monster"},
    }

    for type_, keywords in pairs(indicators) do
        for _, kw in ipairs(keywords) do
            for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
                if obj.Name:lower():find(kw:lower(), 1, true) then
                    gameType = type_
                    break
                end
            end
            if gameType ~= "Unknown" then break end
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Tool") and obj.Name:lower():find(kw:lower(), 1, true) then
                    gameType = type_
                    break
                end
            end
            if gameType ~= "Unknown" then break end
        end
        if gameType ~= "Unknown" then break end
    end

    Settings.DetectedGameType = gameType
    return gameType
end

function scanRemotes()
    Settings.CachedRemotes = {}
    Settings.AllDamageRemotes = {}
    Settings.AllRemotes = {}
    Settings.DetectedMethod = nil
    StatusLabel.Text = "Status: Deep scanning ALL..."

    -- Known game framework paths
    local knownPaths = {
        {path = {"Eventos"}, names = {"WeaponFired", "WeaponHit"}, method = "WeaponHit", keys = {"WeaponFired", "WeaponHit"}},
        {path = {"SystemResources", "BufferCache"}, names = {"RequestActionSync"}, method = "RequestActionSync", keys = {"RequestActionSync"}},
        {path = {"Remotes"}, names = {"GunRemote"}, method = "GunRemote", keys = {"GunRemote"}},
        {path = {"WeaponsSystem", "Network"}, names = {"WeaponFired", "WeaponHit"}, method = "WeaponsSystem", keys = {"WSFired", "WSHit"}},
        {path = {"Events"}, names = {"FireWeapon"}, method = "FireWeapon", keys = {"FireWeapon"}},
        {path = {"Remotes"}, names = {"Damage", "DealDamage", "ApplyDamage", "TakeDamage"}, method = "GenericDamage", keys = {"GenericDamage"}},
        {path = {"Events"}, names = {"Damage", "DealDamage", "Attack", "Hit"}, method = "EventDamage", keys = {"EventDamage"}},
        {path = {"Combat"}, names = {"Attack", "Hit", "Damage", "Swing", "Slash"}, method = "CombatAttack", keys = {"CombatAttack"}},
        {path = {"Network"}, names = {"Damage", "Attack", "Hit", "Fire", "Shoot"}, method = "NetworkAttack", keys = {"NetworkAttack"}},
        {path = {"Game", "Remotes"}, names = {"Damage", "Attack", "Hit"}, method = "GameRemote", keys = {"GameRemote"}},
        {path = {"Shared", "Remotes"}, names = {"Damage", "Attack", "Hit"}, method = "SharedRemote", keys = {"SharedRemote"}},
        {path = {"Client"}, names = {"Damage", "Attack", "DealDamage"}, method = "ClientRemote", keys = {"ClientRemote"}},
        {path = {"Server"}, names = {"Damage", "Attack", "TakeDamage"}, method = "ServerRemote", keys = {"ServerRemote"}},
        {path = {"ReplicatedModules"}, names = {"Damage", "Combat", "Attack"}, method = "ReplicatedModule", keys = {"ReplicatedModule"}},
    }

    for _, entry in ipairs(knownPaths) do
        for i, name in ipairs(entry.names) do
            local r = findRemoteInPath(entry.path, {name})
            if r then
                local key = entry.keys[math.min(i, #entry.keys)]
                Settings.CachedRemotes[key] = r
                if not Settings.DetectedMethod then Settings.DetectedMethod = entry.method end
            end
        end
    end

    -- Deep scan ALL remotes
    local allDamage = deepScanAllRemotes()
    Settings.AllDamageRemotes = allDamage

    for _, r in ipairs(allDamage) do
        if not Settings.CachedRemotes[r.Name] then
            Settings.CachedRemotes[r.Name] = r
            if not Settings.DetectedMethod then Settings.DetectedMethod = "DeepScan:" .. r.Name end
        end
    end

    -- Scan custom inventory/combat systems
    scanCustomSystems()

    -- Detect game type
    local gameType = detectGameType()
    local customInfo = Settings.HasCustomInventory and " [CUSTOM]" or ""
    GameTypeLabel.Text = "Game: " .. gameType .. customInfo .. " | R:" .. #Settings.AllRemotes
    GameTypeLabel.TextColor3 = theme.Info

    local spyCount = 0
    for _ in pairs(Settings.SpyRemotes) do spyCount = spyCount + 1 end
    local totalRemotes = #allDamage + spyCount

    if Settings.DetectedMethod then
        StatusLabel.Text = "Method: " .. Settings.DetectedMethod
        StatusLabel.TextColor3 = theme.Success
    elseif totalRemotes > 0 then
        StatusLabel.Text = "Generic (" .. totalRemotes .. " remotes)"
        StatusLabel.TextColor3 = theme.Warning
    elseif Settings.HasCustomInventory and #Settings.HotbarRemotes > 0 then
        StatusLabel.Text = "Custom System (" .. #Settings.HotbarRemotes .. " hotbar)"
        StatusLabel.TextColor3 = theme.Info
    else
        StatusLabel.Text = "No remote - fire weapon to learn"
        StatusLabel.TextColor3 = theme.Danger
    end

    SpyStatusLabel.Text = "Spy:" .. spyCount .. " Scan:" .. #allDamage .. " Cust:" .. #Settings.HotbarRemotes .. " All:" .. #Settings.AllRemotes
    log("Scan: " .. #allDamage .. " damage, " .. #Settings.AllRemotes .. " total, " .. spyCount .. " spy, " ..
        #Settings.HotbarRemotes .. " hotbar, " .. #Settings.CustomCombatRemotes .. " framework, type=" .. gameType)
end

task.spawn(scanRemotes)

-- ============================================================
-- WEAPON FINDING
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
            if tool then pcall(function() tool.Parent = LocalPlayer.Character end); return tool end
        end
    end
    -- Check custom weapon folders (games that store weapons in non-standard locations)
    if Settings.AutoWeaponEquip then
        local weaponFolders = {"Weapons", "Items", "Equipment", "Loadout", "Arsenal"}
        for _, folderName in ipairs(weaponFolders) do
            pcall(function()
                local folder = LocalPlayer:FindFirstChild(folderName)
                if folder then
                    local tool = folder:FindFirstChildOfClass("Tool")
                    if tool then
                        pcall(function() tool.Parent = LocalPlayer.Character end)
                        return tool
                    end
                end
            end)
        end
        -- Check StarterPack clones
        pcall(function()
            local sp = game:GetService("StarterPack")
            for _, tool in ipairs(sp:GetChildren()) do
                if tool:IsA("Tool") then
                    local clone = tool:Clone()
                    clone.Parent = LocalPlayer.Character
                    return clone
                end
            end
        end)
    end
    return nil
end

local function findAllTools()
    local tools = {}
    local char = LocalPlayer.Character
    local backpack = LocalPlayer:FindFirstChildWhichIsA("Backpack")
    if char then
        for _, obj in ipairs(char:GetChildren()) do
            if obj:IsA("Tool") then table.insert(tools, obj) end
        end
    end
    if backpack then
        for _, obj in ipairs(backpack:GetChildren()) do
            if obj:IsA("Tool") then table.insert(tools, obj) end
        end
    end
    return tools
end

-- ============================================================
-- CUSTOM INVENTORY/HOTBAR SYSTEM DETECTION
-- Games that don't use default Roblox Backpack/Tool system
-- ============================================================

local COMBAT_REMOTE_KEYWORDS = {
    "attack", "swing", "slash", "punch", "kick", "hit", "strike",
    "combat", "fight", "use", "activate", "ability", "skill",
    "weapon", "equip", "m1", "m2", "click", "light", "heavy",
    "basic", "combo", "action", "cast", "spell", "throw",
    "shoot", "fire", "damage", "hurt", "block", "parry",
    "dodge", "dash", "barrage", "rush", "special", "ultimate",
    "ult", "z", "x", "c", "v", "e", "f", "q", "r",
    "input", "keybind", "hotbar", "slot", "useskill",
    "useability", "useweapon", "attackremote", "combatremote",
    "swingremote", "meleeattack", "rangedattack",
}

local function isLikelyCombatRemote(name)
    local lower = name:lower()
    for _, kw in ipairs(COMBAT_REMOTE_KEYWORDS) do
        if lower:find(kw, 1, true) then return true end
    end
    return false
end

local function findCustomWeapons()
    local customWeapons = {}

    -- Scan PlayerGui for custom hotbar/inventory UI elements
    pcall(function()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if gui then
            for _, desc in ipairs(gui:GetDescendants()) do
                -- Look for ViewportFrame items (3D weapon previews in custom hotbars)
                if desc:IsA("ViewportFrame") then
                    local parent = desc.Parent
                    if parent and (parent:IsA("ImageButton") or parent:IsA("TextButton") or parent:IsA("Frame")) then
                        table.insert(customWeapons, {
                            type = "UISlot",
                            button = parent,
                            name = parent.Name,
                            source = "PlayerGui"
                        })
                    end
                end
                -- Look for buttons with weapon/skill names
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
                    local nameLower = desc.Name:lower()
                    if nameLower:find("slot") or nameLower:find("weapon") or nameLower:find("skill")
                       or nameLower:find("ability") or nameLower:find("attack") or nameLower:find("hotbar")
                       or nameLower:find("item") or nameLower:find("equip") or nameLower:find("tool")
                       or nameLower:find("btn") or nameLower:find("action") then
                        table.insert(customWeapons, {
                            type = "UIButton",
                            button = desc,
                            name = desc.Name,
                            source = "PlayerGui"
                        })
                    end
                end
            end
        end
    end)

    -- Scan for weapon models in character that aren't Tools
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Model") and not obj:IsA("Tool") then
                    local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                    if handle then
                        table.insert(customWeapons, {
                            type = "CharModel",
                            model = obj,
                            handle = handle,
                            name = obj.Name,
                            source = "Character"
                        })
                    end
                end
                if obj:IsA("Accessory") then
                    local handle = obj:FindFirstChild("Handle")
                    if handle and handle:FindFirstChild("TouchInterest") then
                        table.insert(customWeapons, {
                            type = "WeaponAccessory",
                            accessory = obj,
                            handle = handle,
                            name = obj.Name,
                            source = "Character"
                        })
                    end
                end
            end
        end
    end)

    -- Scan ReplicatedStorage for weapon data/models
    pcall(function()
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("Model") or obj:IsA("Tool") then
                local nameLower = obj.Name:lower()
                if nameLower:find("weapon") or nameLower:find("sword") or nameLower:find("gun")
                   or nameLower:find("blade") or nameLower:find("staff") or nameLower:find("bow") then
                    table.insert(customWeapons, {
                        type = "StoredWeapon",
                        object = obj,
                        name = obj.Name,
                        source = "ReplicatedStorage"
                    })
                end
            end
        end
    end)

    -- Check for custom "Weapons" or "Items" folder in player
    pcall(function()
        local weaponFolders = {"Weapons", "Items", "Inventory", "Equipment", "Skills", "Abilities", "Loadout", "Arsenal"}
        for _, folderName in ipairs(weaponFolders) do
            local folder = LocalPlayer:FindFirstChild(folderName)
                or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild(folderName)
            if folder then
                for _, item in ipairs(folder:GetChildren()) do
                    table.insert(customWeapons, {
                        type = "CustomFolder",
                        object = item,
                        name = item.Name,
                        folder = folderName,
                        source = "CustomFolder:" .. folderName
                    })
                end
            end
        end
    end)

    Settings.CustomWeapons = customWeapons
    Settings.HasCustomInventory = #customWeapons > 0 or
        (not LocalPlayer:FindFirstChildWhichIsA("Backpack") or #LocalPlayer.Backpack:GetChildren() == 0)
    return customWeapons
end

local function findHotbarRemotes()
    local hotbarRemotes = {}

    -- Method 1: Scan for RemoteEvents with combat-related names
    pcall(function()
        for _, remote in ipairs(Settings.AllRemotes) do
            if remote:IsA("RemoteEvent") and isLikelyCombatRemote(remote.Name) then
                table.insert(hotbarRemotes, remote)
            end
        end
    end)

    -- Method 2: Use getconnections to find remotes connected to UI buttons
    if hasGetConnections then
        pcall(function()
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            if gui then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                        local connections = getconnections(desc.Activated) or {}
                        for _, conn in ipairs(connections) do
                            pcall(function()
                                local func = conn.Function or conn.function_
                                if func then
                                    table.insert(hotbarRemotes, {
                                        type = "ButtonConnection",
                                        button = desc,
                                        fire = function()
                                            pcall(function() conn:Fire() end)
                                        end
                                    })
                                end
                            end)
                        end
                        local connections2 = getconnections(desc.MouseButton1Click) or {}
                        for _, conn in ipairs(connections2) do
                            pcall(function()
                                table.insert(hotbarRemotes, {
                                    type = "ButtonConnection",
                                    button = desc,
                                    fire = function()
                                        pcall(function() conn:Fire() end)
                                    end
                                })
                            end)
                        end
                    end
                end
            end
        end)
    end

    -- Method 3: getgc to find combat-related functions
    if hasGetGC then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    for key, func in pairs(v) do
                        if type(key) == "string" and type(func) == "function" then
                            local keyLower = key:lower()
                            if keyLower == "attack" or keyLower == "swing" or keyLower == "m1"
                               or keyLower == "lightattack" or keyLower == "heavyattack"
                               or keyLower == "basicattack" or keyLower == "combatattack"
                               or keyLower == "useweapon" or keyLower == "slash"
                               or keyLower == "punchattack" or keyLower == "kickattack" then
                                table.insert(hotbarRemotes, {
                                    type = "GCFunction",
                                    name = key,
                                    fire = function()
                                        pcall(func)
                                    end
                                })
                            end
                        end
                    end
                end
            end
        end)
    end

    -- Method 4: Scan for BindableEvents that trigger attacks
    pcall(function()
        local containers = {ReplicatedStorage, LocalPlayer:FindFirstChild("PlayerScripts")}
        for _, container in ipairs(containers) do
            if container then
                for _, obj in ipairs(container:GetDescendants()) do
                    if obj:IsA("BindableEvent") and isLikelyCombatRemote(obj.Name) then
                        table.insert(hotbarRemotes, {
                            type = "BindableEvent",
                            event = obj,
                            name = obj.Name,
                            fire = function()
                                pcall(function() obj:Fire() end)
                            end
                        })
                    end
                end
            end
        end
    end)

    Settings.HotbarRemotes = hotbarRemotes
    return hotbarRemotes
end

local function simulateCustomAttack(t, targetPart, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    local success = false

    -- 1. Fire all discovered hotbar/combat remotes
    for _, entry in ipairs(Settings.HotbarRemotes) do
        task.spawn(function()
            if entry.fire then
                pcall(entry.fire)
                success = true
            elseif entry:IsA("RemoteEvent") then
                -- Try multiple arg patterns for custom combat systems
                pcall(function() entry:FireServer() end)
                pcall(function() entry:FireServer("Attack") end)
                pcall(function() entry:FireServer(targetPart.Position) end)
                pcall(function() entry:FireServer(targetPart, dir) end)
                pcall(function() entry:FireServer("M1") end)
                pcall(function() entry:FireServer("LightAttack") end)
                pcall(function() entry:FireServer(1) end)
                pcall(function() entry:FireServer(true) end)
                pcall(function() entry:FireServer({Position = targetPart.Position, Direction = dir}) end)
                pcall(function() entry:FireServer(targetPart.Parent) end)
                pcall(function() entry:FireServer(CFrame.lookAt(myRoot.Position, targetPart.Position)) end)
                pcall(function() entry:FireServer("Swing", targetPart.Position) end)
                pcall(function() entry:FireServer("Hit", targetPart, t.humanoid) end)
                pcall(function() entry:FireServer(targetPart.Parent.Name) end)
                success = true
            end
        end)
    end

    -- 2. Simulate UI button clicks on custom hotbar
    for _, weapon in ipairs(Settings.CustomWeapons) do
        task.spawn(function()
            if weapon.type == "UISlot" or weapon.type == "UIButton" then
                pcall(function()
                    -- Fire virtual input on the button
                    if hasGetConnections then
                        local btn = weapon.button
                        local conns = getconnections(btn.Activated)
                        for _, conn in ipairs(conns or {}) do pcall(function() conn:Fire() end) end
                        local conns2 = getconnections(btn.MouseButton1Click)
                        for _, conn in ipairs(conns2 or {}) do pcall(function() conn:Fire() end) end
                    end
                end)
                success = true
            elseif weapon.type == "CharModel" or weapon.type == "WeaponAccessory" then
                -- Touch the target with the weapon part
                local handle = weapon.handle
                if handle and hasFireTouchInterest then
                    pcall(function()
                        firetouchinterest(handle, targetPart, 0)
                        task.wait()
                        firetouchinterest(handle, targetPart, 1)
                    end)
                    success = true
                end
            end
        end)
    end

    -- 3. Fire UserInputService simulation for attack keybinds
    pcall(function()
        -- Many custom systems listen for specific key inputs
        local viu = game:GetService("VirtualInputManager")
        if viu then
            pcall(function() viu:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
            task.wait(0.02)
            pcall(function() viu:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
        end
    end)

    -- 4. Try firing all combat-keyword remotes with no args (many custom systems just need :FireServer())
    if not success then
        for _, remote in ipairs(Settings.AllRemotes) do
            if remote:IsA("RemoteEvent") and isLikelyCombatRemote(remote.Name) then
                task.spawn(function()
                    pcall(function() remote:FireServer() end)
                    pcall(function() remote:FireServer(targetPart.Position) end)
                    pcall(function() remote:FireServer(targetPart, dir) end)
                    pcall(function() remote:FireServer("Attack", targetPart.Position, dir) end)
                end)
            end
        end
    end

    return success
end

-- Scan for custom combat systems (run once on init + periodically)
local function scanCustomSystems()
    findCustomWeapons()
    findHotbarRemotes()

    -- Check for common custom frameworks
    pcall(function()
        local customFrameworks = {
            {path = "ReplicatedStorage.Modules.Combat", method = "CustomCombat"},
            {path = "ReplicatedStorage.Combat", method = "CustomCombat"},
            {path = "ReplicatedStorage.Systems.Combat", method = "CustomCombat"},
            {path = "ReplicatedStorage.Shared.Combat", method = "CustomCombat"},
            {path = "ReplicatedStorage.Framework", method = "CustomFramework"},
            {path = "ReplicatedStorage.Knit", method = "KnitFramework"},
            {path = "ReplicatedStorage.Packages", method = "WallyPackage"},
        }
        for _, fw in ipairs(customFrameworks) do
            local parts = fw.path:split(".")
            local current = game
            local found = true
            for _, part in ipairs(parts) do
                current = current:FindFirstChild(part)
                if not current then found = false; break end
            end
            if found and current then
                -- Scan this framework folder for remotes
                for _, obj in ipairs(current:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        table.insert(Settings.CustomCombatRemotes, obj)
                    end
                end
            end
        end
    end)

    log("Custom scan: " .. #Settings.CustomWeapons .. " weapons, " ..
        #Settings.HotbarRemotes .. " hotbar remotes, " ..
        #Settings.CustomCombatRemotes .. " framework remotes, " ..
        "hasCustomInv=" .. tostring(Settings.HasCustomInventory))
end

local function isVisible(targetPart)
    if not Settings.WallCheck then return true end
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetPart then return false end
    local dir = targetPart.Position - myRoot.Position
    if dir.Magnitude <= 0 then return false end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = myChar and {myChar} or {}
    local result = Workspace:Raycast(myRoot.Position, dir, params)
    return result == nil or result.Instance:IsDescendantOf(targetPart.Parent)
end

-- ============================================================
-- 24 ATTACK MODES - ALL METHODS
-- ============================================================

-- 1-14: Original modes (improved)
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
        R.WSHit:FireServer(weapon, {p = targetPart.Position, pid = 1, part = targetPart,
            d = t.distance, maxDist = t.distance + 1, h = t.humanoid,
            m = Enum.Material.Plastic, n = Vector3.new(0, 1, 0), t = 0.1, sid = sid})
        return true
    elseif method == "FireWeapon" and R.FireWeapon then
        local origin = myRoot.Position + Vector3.new(0, 1.5, 0)
        R.FireWeapon:FireServer("Main", origin, dir, {
            [1] = {Normal = Vector3.new(0, 1, 0), Direction = dir,
                   Position = targetPart.Position, Hit = targetPart, Bounce = 0, Origin = origin}
        })
        return true
    end

    -- Generic: try ALL cached remotes with multiple signatures
    local tried = false
    for _, remote in pairs(R) do
        if typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
            tried = true
            local sigs = {
                function() remote:FireServer(t.humanoid, 100, targetPart) end,
                function() remote:FireServer(targetPart, 100) end,
                function() remote:FireServer(t.humanoid, targetPart, 100) end,
                function() remote:FireServer(targetPart, dir, 100) end,
                function() remote:FireServer(weapon, targetPart, dir) end,
                function() remote:FireServer(targetPart, t.humanoid) end,
                function() remote:FireServer("Attack", targetPart, t.humanoid) end,
                function() remote:FireServer("Hit", targetPart, dir) end,
                function() remote:FireServer(myRoot.Position, dir, targetPart, t.humanoid) end,
                function() remote:FireServer("Damage", t.humanoid, 100) end,
                function() remote:FireServer(targetPart.Parent, targetPart, 100) end,
                function() remote:FireServer({Target = targetPart, Damage = 100, Attacker = LocalPlayer}) end,
                function() remote:FireServer(targetPart.Parent.Name, targetPart.Position) end,
                function() remote:FireServer(t.humanoid, targetPart.Position, dir) end,
                function() remote:FireServer("Hit", {Part = targetPart, Position = targetPart.Position, Normal = dir}) end,
            }
            for _, sig in ipairs(sigs) do
                if pcall(sig) then return true end
            end
        end
    end
    return tried
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
                                if cloned.Target then cloned.Target = targetPart end
                                if cloned.Humanoid then cloned.Humanoid = t.humanoid end
                                if cloned.Character then cloned.Character = targetPart.Parent end
                                if cloned.Player then cloned.Player = t.player end
                                newArgs[i] = cloned
                            elseif typeof(arg) == "Vector3" then
                                newArgs[i] = arg.Magnitude > 0.5 and arg.Magnitude < 1.5 and dir or targetPart.Position
                            elseif typeof(arg) == "CFrame" then
                                newArgs[i] = targetPart.CFrame
                            elseif typeof(arg) == "Instance" then
                                if arg:IsA("Humanoid") then newArgs[i] = t.humanoid
                                elseif arg:IsA("BasePart") then newArgs[i] = targetPart
                                elseif arg:IsA("Tool") then newArgs[i] = weapon or arg
                                elseif arg:IsA("Model") then newArgs[i] = targetPart.Parent
                                elseif arg:IsA("Player") then newArgs[i] = t.player or arg
                                else newArgs[i] = arg end
                            else newArgs[i] = arg end
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
        if typeof(remote) == "Instance" then
            pcall(function() remote:FireServer(t.humanoid, 100, targetPart) end)
            pcall(function() remote:FireServer(targetPart, 100) end)
            pcall(function() remote:FireServer(t.humanoid, targetPart) end)
            pcall(function() remote:FireServer("Damage", t.humanoid, 9999) end)
            pcall(function() remote:FireServer({Target = targetPart.Parent, Damage = 100}) end)
        end
    end
end

local function clientDamageAttack(t)
    pcall(function() if t.humanoid then t.humanoid.Health = 0 end end)
    pcall(function() if t.humanoid then t.humanoid:TakeDamage(t.humanoid.MaxHealth * 10) end end)
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
            targetPart.Size = Vector3.new(20, 20, 20)
            targetPart.Transparency = 0.9
            targetPart.CanCollide = false
        end
        if t.root then
            t.root.Size = Vector3.new(15, 15, 15)
            t.root.Transparency = 0.9
            t.root.CanCollide = false
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
    if weapon then pcall(function() weapon:Activate() end) end
end

local function flingKillAttack(t, targetPart, weapon, myRoot)
    pcall(function()
        if t.root then
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(math.random(-9999, 9999), 99999, math.random(-9999, 9999))
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.P = math.huge; bv.Parent = t.root
            task.delay(0.3, function() if bv and bv.Parent then bv:Destroy() end end)
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
end

local function raycastSpamAttack(t, targetPart, weapon, myRoot)
    for _ = 1, 10 do
        task.spawn(function()
            pcall(function() fireMethod(t, targetPart, weapon, myRoot) end)
            if weapon then pcall(function() weapon:Activate() end) end
        end)
    end
end

local function multiHitAttack(t, targetPart, weapon, myRoot)
    for _ = 1, 5 do
        fireMethod(t, targetPart, weapon, myRoot)
        if weapon then pcall(function() weapon:Activate() end) end
        task.wait(0.01)
    end
end

local function remoteSpamAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    for _, remote in ipairs(Settings.AllDamageRemotes) do
        task.spawn(function()
            pcall(function() remote:FireServer(t.humanoid, 100, targetPart) end)
            pcall(function() remote:FireServer(targetPart, 100) end)
            pcall(function() remote:FireServer(targetPart, dir, 100) end)
            pcall(function() remote:FireServer("Hit", targetPart, t.humanoid) end)
            pcall(function() remote:FireServer({Target = targetPart, Damage = 100}) end)
        end)
    end
    if weapon then pcall(function() weapon:Activate() end) end
end

local function networkBruteAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    local allRemotes = {}
    for _, r in pairs(Settings.CachedRemotes) do if typeof(r) == "Instance" then table.insert(allRemotes, r) end end
    for _, r in ipairs(Settings.AllDamageRemotes) do table.insert(allRemotes, r) end

    for _, remote in ipairs(allRemotes) do
        task.spawn(function()
            pcall(function() remote:FireServer(targetPart) end)
            pcall(function() remote:FireServer(t.humanoid, 100, targetPart) end)
            pcall(function() remote:FireServer(targetPart, 100) end)
            pcall(function() remote:FireServer(weapon, targetPart, dir) end)
            pcall(function() remote:FireServer(myRoot.Position, dir, targetPart, t.humanoid) end)
            pcall(function() remote:FireServer("Damage", 100, targetPart) end)
            pcall(function() remote:FireServer({Target = targetPart.Parent, Part = targetPart, Damage = 100, Direction = dir}) end)
            pcall(function() remote:FireServer(targetPart.Parent.Name, 100) end)
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

-- 15. Touch Damage - firetouchinterest
local function touchDamageAttack(t, targetPart, weapon, myRoot)
    if not hasFireTouchInterest then
        fireMethod(t, targetPart, weapon, myRoot)
        return
    end

    local char = LocalPlayer.Character
    if not char then return end

    -- touch with weapon handle
    if weapon then
        local handle = weapon:FindFirstChild("Handle")
        if handle then
            pcall(function()
                firetouchinterest(handle, targetPart, 0)
                task.wait()
                firetouchinterest(handle, targetPart, 1)
            end)
        end
    end

    -- touch with all character parts
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            pcall(function()
                firetouchinterest(part, targetPart, 0)
                task.wait()
                firetouchinterest(part, targetPart, 1)
            end)
        end
    end

    -- touch target root with our root
    if t.root then
        pcall(function()
            firetouchinterest(myRoot, t.root, 0)
            task.wait()
            firetouchinterest(myRoot, t.root, 1)
        end)
    end

    -- touch all target parts
    if t.character then
        for _, part in ipairs(t.character:GetChildren()) do
            if part:IsA("BasePart") then
                pcall(function()
                    firetouchinterest(myRoot, part, 0)
                    task.wait()
                    firetouchinterest(myRoot, part, 1)
                end)
            end
        end
    end
end

-- 16. Click Detector
local function clickDetectorAttack(t, targetPart, weapon, myRoot)
    if not hasFireClickDetector then
        fireMethod(t, targetPart, weapon, myRoot)
        return
    end

    if t.character then
        for _, obj in ipairs(t.character:GetDescendants()) do
            if obj:IsA("ClickDetector") then
                pcall(function() fireclickdetector(obj) end)
            end
        end
    end

    fireMethod(t, targetPart, weapon, myRoot)
end

-- 17. Proximity Prompt
local function proximityPromptAttack(t, targetPart, weapon, myRoot)
    if not hasFireProximity then
        fireMethod(t, targetPart, weapon, myRoot)
        return
    end

    if t.character then
        for _, obj in ipairs(t.character:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                pcall(function() fireproximityprompt(obj) end)
            end
        end
    end

    fireMethod(t, targetPart, weapon, myRoot)
end

-- 18. Module Exploit - find and call damage functions from modules
local function moduleExploitAttack(t, targetPart, weapon, myRoot)
    if hasGetGC then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    for key, func in pairs(v) do
                        if type(key) == "string" and type(func) == "function" then
                            local keyLower = key:lower()
                            if keyLower:find("damage") or keyLower:find("hit") or keyLower:find("attack")
                               or keyLower:find("kill") or keyLower:find("hurt") then
                                pcall(function() func(t.humanoid, 100) end)
                                pcall(function() func(targetPart, 100) end)
                                pcall(function() func(t.character, 100) end)
                            end
                        end
                    end
                end
            end
        end)
    end

    fireMethod(t, targetPart, weapon, myRoot)
end

-- 19. Animation Abuse - play attack animations
local function animationAbuseAttack(t, targetPart, weapon, myRoot)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local attackAnimIds = {
        "rbxassetid://218504594",   -- slash
        "rbxassetid://218504441",   -- thrust
        "rbxassetid://522635514",   -- punch
        "rbxassetid://507770453",   -- kick
        "rbxassetid://507776879",   -- swing
    }

    for _, animId in ipairs(attackAnimIds) do
        pcall(function()
            local anim = Instance.new("Animation")
            anim.AnimationId = animId
            local track = hum:LoadAnimation(anim)
            track:Play()
            task.delay(0.3, function() track:Stop() end)
        end)
    end

    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)

    -- fire touch during animation
    if hasFireTouchInterest and weapon then
        local handle = weapon:FindFirstChild("Handle")
        if handle then
            pcall(function()
                firetouchinterest(handle, targetPart, 0)
                task.wait()
                firetouchinterest(handle, targetPart, 1)
            end)
        end
    end
end

-- 20. Velocity Kill - crush with physics
local function velocityKillAttack(t, targetPart, weapon, myRoot)
    pcall(function()
        if t.root then
            -- slam down
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(0, -99999, 0)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = t.root
            task.delay(0.2, function() if bv.Parent then bv:Destroy() end end)

            -- also spin
            local bg = Instance.new("BodyAngularVelocity")
            bg.AngularVelocity = Vector3.new(99999, 99999, 99999)
            bg.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bg.Parent = t.root
            task.delay(0.3, function() if bg.Parent then bg:Destroy() end end)
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
end

-- 21. CFrame Snap - overlap kill
local function cframeSnapAttack(t, targetPart, weapon, myRoot)
    local originalCF = myRoot.CFrame
    -- snap inside target
    pcall(function()
        myRoot.CFrame = t.root.CFrame
        myRoot.Velocity = Vector3.new(0, 0, 0)
    end)
    task.wait(0.02)

    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)

    -- fire touch
    if hasFireTouchInterest then
        for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                for _, tpart in ipairs(t.character:GetChildren()) do
                    if tpart:IsA("BasePart") then
                        pcall(function()
                            firetouchinterest(part, tpart, 0)
                            task.wait()
                            firetouchinterest(part, tpart, 1)
                        end)
                    end
                end
            end
        end
    end

    task.wait(0.02)
    pcall(function() myRoot.CFrame = originalCF end)
end

-- 22. God Mode Kill - make self invincible then fling
local function godModeKillAttack(t, targetPart, weapon, myRoot)
    local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local origHealth
    if myHum then
        origHealth = myHum.Health
        pcall(function() myHum.Health = math.huge end)
    end

    -- fling at target
    pcall(function()
        local dir = (targetPart.Position - myRoot.Position).Unit
        myRoot.CFrame = targetPart.CFrame * CFrame.new(0, 0, 2)
        myRoot.Velocity = dir * 500
    end)

    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)

    if hasFireTouchInterest and t.root then
        pcall(function()
            firetouchinterest(myRoot, t.root, 0)
            task.wait()
            firetouchinterest(myRoot, t.root, 1)
        end)
    end

    task.wait(0.1)
    if myHum and origHealth then
        pcall(function() myHum.Health = origHealth end)
    end
end

-- 23. All Tools Spam - equip and activate every tool
local function allToolsSpamAttack(t, targetPart, weapon, myRoot)
    local tools = findAllTools()
    for _, tool in ipairs(tools) do
        task.spawn(function()
            pcall(function()
                tool.Parent = LocalPlayer.Character
                local handle = tool:FindFirstChild("Handle")
                if handle then handle.CFrame = targetPart.CFrame end
                tool:Activate()
            end)
            if hasFireTouchInterest then
                local handle = tool:FindFirstChild("Handle")
                if handle then
                    pcall(function()
                        firetouchinterest(handle, targetPart, 0)
                        task.wait()
                        firetouchinterest(handle, targetPart, 1)
                    end)
                end
            end
        end)
    end
    fireMethod(t, targetPart, weapon, myRoot)
end

-- 24. Brute Force All - try EVERY single method
local function bruteForceAllAttack(t, targetPart, weapon, myRoot)
    task.spawn(function() pcall(function() fireMethod(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() spyReplayAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() silentAttack(t, targetPart, myRoot) end) end)
    task.spawn(function() pcall(function() clientDamageAttack(t) end) end)
    task.spawn(function() pcall(function() toolActivateAttack(t, targetPart, weapon) end) end)
    task.spawn(function() pcall(function() touchDamageAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() clickDetectorAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() animationAbuseAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() velocityKillAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() moduleExploitAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() simulateCustomAttack(t, targetPart, myRoot) end) end)

    -- fire ALL remotes with ALL signatures
    local dir = (targetPart.Position - myRoot.Position).Unit
    for _, remote in ipairs(Settings.AllRemotes) do
        if remote:IsA("RemoteEvent") then
            task.spawn(function()
                pcall(function() remote:FireServer(targetPart) end)
                pcall(function() remote:FireServer(t.humanoid, 100) end)
                pcall(function() remote:FireServer(targetPart, 100) end)
                pcall(function() remote:FireServer(t.humanoid, targetPart, 100) end)
                pcall(function() remote:FireServer(weapon, targetPart, dir) end)
                pcall(function() remote:FireServer("Hit", targetPart, t.humanoid) end)
                pcall(function() remote:FireServer("Damage", t.humanoid, 9999) end)
                pcall(function() remote:FireServer({Target = targetPart.Parent, Damage = 100}) end)
                pcall(function() remote:FireServer(myRoot.Position, dir, targetPart, t.humanoid) end)
                pcall(function() remote:FireServer(targetPart.Parent.Name, targetPart.Position, 100) end)
            end)
        end
    end
end

-- 25. Custom System Attack - for games with custom inventory/hotbar
local function customSystemAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit

    -- Re-scan if we haven't found custom weapons yet
    if #Settings.HotbarRemotes == 0 and #Settings.CustomWeapons == 0 then
        scanCustomSystems()
    end

    -- Fire all custom combat system remotes
    simulateCustomAttack(t, targetPart, myRoot)

    -- Also fire custom framework remotes with combat signatures
    for _, remote in ipairs(Settings.CustomCombatRemotes) do
        task.spawn(function()
            if remote:IsA("RemoteEvent") then
                pcall(function() remote:FireServer() end)
                pcall(function() remote:FireServer("Attack") end)
                pcall(function() remote:FireServer(targetPart.Position) end)
                pcall(function() remote:FireServer(targetPart, dir) end)
                pcall(function() remote:FireServer(t.humanoid, 100) end)
                pcall(function() remote:FireServer("M1", targetPart.Position) end)
                pcall(function() remote:FireServer({Action = "Attack", Target = targetPart.Parent, Position = targetPart.Position}) end)
                pcall(function() remote:FireServer(CFrame.lookAt(myRoot.Position, targetPart.Position)) end)
                pcall(function() remote:FireServer(targetPart.Parent.Name, targetPart.Position, dir) end)
            elseif remote:IsA("RemoteFunction") then
                pcall(function() remote:InvokeServer() end)
                pcall(function() remote:InvokeServer("Attack") end)
                pcall(function() remote:InvokeServer(targetPart.Position, dir) end)
                pcall(function() remote:InvokeServer(t.humanoid, targetPart) end)
            end
        end)
    end

    -- Also try touch if available (works on any game)
    if hasFireTouchInterest then
        -- Touch with all character parts against target
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(part, targetPart, 0)
                        task.wait()
                        firetouchinterest(part, targetPart, 1)
                    end)
                end
            end
        end
        -- Touch all target parts
        if t.character then
            for _, part in ipairs(t.character:GetChildren()) do
                if part:IsA("BasePart") then
                    pcall(function()
                        firetouchinterest(myRoot, part, 0)
                        task.wait()
                        firetouchinterest(myRoot, part, 1)
                    end)
                end
            end
        end
    end

    -- Fire standard remotes too as fallback
    fireMethod(t, targetPart, weapon, myRoot)
end

-- Auto mode: smart method selection
local function autoAttack(t, targetPart, weapon, myRoot)
    -- 1. Try detected method first
    if fireMethod(t, targetPart, weapon, myRoot) then return end
    -- 2. Spy replay
    if spyReplayAttack(t, targetPart, weapon, myRoot) then return end
    -- 3. Custom system (if no standard tool found)
    if not weapon and Settings.HasCustomInventory then
        simulateCustomAttack(t, targetPart, myRoot)
    end
    -- 4. Touch damage
    if hasFireTouchInterest then touchDamageAttack(t, targetPart, weapon, myRoot) end
    -- 5. Tool activate
    if weapon then pcall(function() weapon:Activate() end) end
    -- 6. Custom combat remotes (always try if no weapon)
    if not weapon and #Settings.CustomCombatRemotes > 0 then
        local dir = (targetPart.Position - myRoot.Position).Unit
        for _, remote in ipairs(Settings.CustomCombatRemotes) do
            if remote:IsA("RemoteEvent") then
                pcall(function() remote:FireServer() end)
                pcall(function() remote:FireServer(targetPart.Position, dir) end)
            end
        end
    end
    -- 7. Silent
    silentAttack(t, targetPart, myRoot)
    -- 8. Client damage
    clientDamageAttack(t)
end

-- ============================================================
-- TARGET SORTING
-- ============================================================
local function sortTargets(targets)
    local p = Settings.TargetPriority
    if p == "Closest" then
        table.sort(targets, function(a, b) return a.distance < b.distance end)
    elseif p == "LowestHP" then
        table.sort(targets, function(a, b) return a.humanoid.Health < b.humanoid.Health end)
    elseif p == "HighestHP" then
        table.sort(targets, function(a, b) return a.humanoid.Health > b.humanoid.Health end)
    elseif p == "Random" then
        for i = #targets, 2, -1 do
            local j = math.random(i); targets[i], targets[j] = targets[j], targets[i]
        end
    end
    return targets
end

-- ============================================================
-- NPC/MOB FINDER
-- ============================================================
local function getNPCTargets(myRoot)
    local targets = {}
    if not Settings.TargetNPCs then return targets end

    for _, model in ipairs(Workspace:GetDescendants()) do
        if model:IsA("Model") and model ~= LocalPlayer.Character then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso") or model:FindFirstChild("Head")
            if hum and root and hum.Health > 0 then
                local isPlayer = Players:GetPlayerFromCharacter(model)
                if not isPlayer then
                    local dist = (myRoot.Position - root.Position).Magnitude
                    if dist <= Settings.Radius and isVisible(root) then
                        table.insert(targets, {
                            player = nil, character = model,
                            root = root, humanoid = hum, distance = dist,
                            isNPC = true,
                        })
                    end
                end
            end
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
            task.spawn(scanRemotes); Settings.LastAttack = tick()
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

    -- Player targets
    if Settings.TargetPlayers then
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
                                root = tRoot, humanoid = tHum, distance = dist,
                                isNPC = false,
                            })
                        end
                    end
                end
            end
        end
    end

    -- NPC/Mob targets
    local npcTargets = getNPCTargets(myRoot)
    for _, t in ipairs(npcTargets) do table.insert(targets, t) end

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
                    elseif mode == "TouchDamage" then touchDamageAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "ClickDetector" then clickDetectorAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "ProximityPrompt" then proximityPromptAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "ModuleExploit" then moduleExploitAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "AnimationAbuse" then animationAbuseAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "VelocityKill" then velocityKillAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "CFrameSnap" then cframeSnapAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "GodModeKill" then godModeKillAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "AllToolsSpam" then allToolsSpamAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "BruteForceAll" then bruteForceAllAttack(t, targetPart, weapon, myRoot)
                    elseif mode == "CustomSystem" then customSystemAttack(t, targetPart, weapon, myRoot)
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
    Settings._FOVCircle.Thickness = 1; Settings._FOVCircle.Filled = false
    Settings._FOVCircle.Transparency = 0.5; Settings._FOVCircle.Visible = false; Settings._FOVCircle.ZIndex = 10
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
    local bestTarget, bestDist = nil, Settings.AimbotFOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
            local aimPart = plr.Character:FindFirstChild(Settings.AimbotPart) or plr.Character:FindFirstChild("Head")
            if tHum and tHum.Health > 0 and aimPart then
                local sameTeam = Settings.AimbotTeamCheck and LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team
                if not sameTeam then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(aimPart.Position)
                    if onScreen then
                        local d = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if d < bestDist then bestDist = d; bestTarget = aimPart end
                    end
                end
            end
        end
    end

    if bestTarget then
        Camera.CFrame = Camera.CFrame:Lerp(CFrame.lookAt(Camera.CFrame.Position, bestTarget.Position), Settings.AimbotSmooth)
    end
end)
table.insert(Settings._Connections, aimConn)

-- ============================================================
-- ESP ENGINE
-- ============================================================
ESP_Cache = {}

local SKELETON_PAIRS = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}

local function CreateESP_Drawing(char)
    local esp = {
        Box = Drawing.new("Square"), BoxOutline = Drawing.new("Square"),
        HealthBar = Drawing.new("Square"), HealthBarOutline = Drawing.new("Square"),
        Name = Drawing.new("Text"), Distance = Drawing.new("Text"),
        Tracer = Drawing.new("Line"), Highlight = nil, SkeletonLines = {}, Type = "Drawing"
    }
    esp.Box.Color = Settings.ESPColor; esp.Box.Thickness = 1; esp.Box.Filled = false; esp.Box.ZIndex = 2
    esp.BoxOutline.Color = Color3.new(0,0,0); esp.BoxOutline.Thickness = 3; esp.BoxOutline.Filled = false; esp.BoxOutline.ZIndex = 1
    esp.HealthBar.Color = Color3.new(0,1,0); esp.HealthBar.Thickness = 1; esp.HealthBar.Filled = true; esp.HealthBar.ZIndex = 2
    esp.HealthBarOutline.Color = Color3.new(0,0,0); esp.HealthBarOutline.Thickness = 1; esp.HealthBarOutline.Filled = true; esp.HealthBarOutline.ZIndex = 1
    esp.Name.Color = Color3.new(1,1,1); esp.Name.Size = 14; esp.Name.Center = true; esp.Name.Outline = true; esp.Name.ZIndex = 3
    esp.Distance.Color = Color3.new(1,1,1); esp.Distance.Size = 12; esp.Distance.Center = true; esp.Distance.Outline = true; esp.Distance.ZIndex = 3
    esp.Tracer.Color = Settings.ESPColor; esp.Tracer.Thickness = 1; esp.Tracer.ZIndex = 1
    for _ = 1, #SKELETON_PAIRS do
        local line = Drawing.new("Line"); line.Color = Settings.ESPColor; line.Thickness = 1; line.Visible = false; line.ZIndex = 2
        table.insert(esp.SkeletonLines, line)
    end
    return esp
end

local function CreateESP_Billboard(char)
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP_V10"; billboard.Size = UDim2.new(4,0,5,0); billboard.StudsOffset = Vector3.new(0,3,0)
    billboard.AlwaysOnTop = true; billboard.LightInfluence = 0; billboard.ResetOnSpawn = false
    billboard.Parent = char:FindFirstChild("Head") or char

    local mf = Instance.new("Frame", billboard); mf.Size = UDim2.new(1,0,1,0); mf.BackgroundTransparency = 1

    local nl = Instance.new("TextLabel", mf); nl.Size = UDim2.new(1,0,0.2,0); nl.BackgroundTransparency = 1
    nl.TextColor3 = Color3.new(1,1,1); nl.TextStrokeTransparency = 0; nl.Font = Enum.Font.GothamBold; nl.TextSize = 14

    for _, data in ipairs({
        {UDim2.new(1,0,0,2), UDim2.new(0,0,0.2,0)}, {UDim2.new(1,0,0,2), UDim2.new(0,0,0.8,0)},
        {UDim2.new(0,2,0.6,0), UDim2.new(0,0,0.2,0)}, {UDim2.new(0,2,0.6,0), UDim2.new(1,-2,0.2,0)},
    }) do
        local f = Instance.new("Frame", mf); f.Size = data[1]; f.Position = data[2]
        f.BackgroundColor3 = Settings.ESPColor; f.BorderSizePixel = 0
    end

    local hbg = Instance.new("Frame", mf); hbg.Size = UDim2.new(0.05,0,0.6,0); hbg.Position = UDim2.new(-0.08,0,0.2,0)
    hbg.BackgroundColor3 = Color3.new(0,0,0); hbg.BorderSizePixel = 0
    local hb = Instance.new("Frame", hbg); hb.Size = UDim2.new(1,0,1,0); hb.BackgroundColor3 = Color3.new(0,1,0); hb.BorderSizePixel = 0

    local dl = Instance.new("TextLabel", mf); dl.Size = UDim2.new(1,0,0.15,0); dl.Position = UDim2.new(0,0,0.85,0)
    dl.BackgroundTransparency = 1; dl.TextColor3 = Color3.new(1,1,1); dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.Gotham; dl.TextSize = 12

    local hl = Instance.new("Highlight", char); hl.Name = "ESPCham"; hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = Settings.ESPColor; hl.OutlineColor = Color3.new(1,1,1)

    return {Billboard = billboard, NameLabel = nl, HealthBar = hb, DistLabel = dl, Highlight = hl,
        Boxes = {mf:GetChildren()[2], mf:GetChildren()[3], mf:GetChildren()[4], mf:GetChildren()[5]}, Type = "Billboard"}
end

local function CreateESP(char)
    if Settings.UseDrawingAPI then ESP_Cache[char] = CreateESP_Drawing(char)
    else ESP_Cache[char] = CreateESP_Billboard(char) end
end

function RemoveESP(char)
    if not ESP_Cache[char] then return end
    local esp = ESP_Cache[char]
    if esp.Type == "Drawing" then
        for k, v in pairs(esp) do
            if k == "SkeletonLines" then for _, l in ipairs(v) do pcall(function() l:Remove() end) end
            elseif k == "Highlight" and v then pcall(function() v:Destroy() end)
            elseif type(v) == "userdata" then pcall(function() v.Visible = false; v:Remove() end) end
        end
    elseif esp.Type == "Billboard" then
        pcall(function() if esp.Billboard then esp.Billboard:Destroy() end end)
        pcall(function() if esp.Highlight then esp.Highlight:Destroy() end end)
    end
    ESP_Cache[char] = nil
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
                    local headPos = Camera:WorldToViewportPoint(head and head.Position + Vector3.new(0,0.5,0) or root.Position + Vector3.new(0,3,0))
                    local legPos = Camera:WorldToViewportPoint(root.Position - Vector3.new(0,3,0))
                    if onScreen then
                        local height = math.abs(headPos.Y - legPos.Y)
                        local width = height / 2
                        if Settings.ESPBoxes then
                            esp.Box.Size = Vector2.new(width, height); esp.Box.Position = Vector2.new(rootPos.X - width/2, rootPos.Y - height/2)
                            esp.Box.Color = espColor; esp.Box.Visible = true
                            esp.BoxOutline.Size = esp.Box.Size; esp.BoxOutline.Position = esp.Box.Position; esp.BoxOutline.Visible = true
                        else esp.Box.Visible = false; esp.BoxOutline.Visible = false end
                        if Settings.ESPHealth then
                            local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1); local hh = height * hp
                            esp.HealthBarOutline.Size = Vector2.new(4, height+2); esp.HealthBarOutline.Position = Vector2.new(rootPos.X - width/2 - 6, rootPos.Y - height/2 - 1); esp.HealthBarOutline.Visible = true
                            esp.HealthBar.Size = Vector2.new(2, hh); esp.HealthBar.Position = Vector2.new(rootPos.X - width/2 - 5, rootPos.Y + height/2 - hh)
                            esp.HealthBar.Color = Color3.fromHSV(hp * 0.3, 1, 1); esp.HealthBar.Visible = true
                        else esp.HealthBar.Visible = false; esp.HealthBarOutline.Visible = false end
                        if Settings.ESPNames then
                            esp.Name.Text = plr and plr.Name or char.Name
                            esp.Name.Position = Vector2.new(rootPos.X, rootPos.Y - height/2 - 16); esp.Name.Visible = true
                        else esp.Name.Visible = false end
                        if Settings.ESPDistance then
                            local dist = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
                            esp.Distance.Text = "[" .. dist .. "m]"; esp.Distance.Position = Vector2.new(rootPos.X, rootPos.Y + height/2 + 2); esp.Distance.Visible = true
                        else esp.Distance.Visible = false end
                        if Settings.ESPTracers then
                            esp.Tracer.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y)
                            esp.Tracer.To = Vector2.new(rootPos.X, rootPos.Y + height/2); esp.Tracer.Color = espColor; esp.Tracer.Visible = true
                        else esp.Tracer.Visible = false end
                        if Settings.ESPSkeleton then
                            for idx, pair in ipairs(SKELETON_PAIRS) do
                                local line = esp.SkeletonLines[idx]
                                if line then
                                    local p1 = char:FindFirstChild(pair[1]); local p2 = char:FindFirstChild(pair[2])
                                    if p1 and p2 then
                                        local s1, v1 = Camera:WorldToViewportPoint(p1.Position)
                                        local s2, v2 = Camera:WorldToViewportPoint(p2.Position)
                                        if v1 and v2 then line.From = Vector2.new(s1.X, s1.Y); line.To = Vector2.new(s2.X, s2.Y); line.Color = espColor; line.Visible = true
                                        else line.Visible = false end
                                    else line.Visible = false end
                                end
                            end
                        else for _, line in ipairs(esp.SkeletonLines) do line.Visible = false end end
                        if Settings.ESPChams then
                            if not esp.Highlight or esp.Highlight.Parent ~= char then
                                if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
                                local hl = Instance.new("Highlight"); hl.Name = "ESPCham"; hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
                                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; hl.Parent = char; esp.Highlight = hl
                            end
                            esp.Highlight.FillColor = espColor; esp.Highlight.OutlineColor = Color3.new(1,1,1)
                        else if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end end
                    else
                        esp.Box.Visible = false; esp.BoxOutline.Visible = false; esp.HealthBar.Visible = false; esp.HealthBarOutline.Visible = false
                        esp.Name.Visible = false; esp.Distance.Visible = false; esp.Tracer.Visible = false
                        for _, line in ipairs(esp.SkeletonLines) do line.Visible = false end
                        if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                    end
                else
                    esp.Box.Visible = false; esp.BoxOutline.Visible = false; esp.HealthBar.Visible = false; esp.HealthBarOutline.Visible = false
                    esp.Name.Visible = false; esp.Distance.Visible = false; esp.Tracer.Visible = false
                    for _, line in ipairs(esp.SkeletonLines) do line.Visible = false end
                    if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end
                end
            elseif esp.Type == "Billboard" then
                if shouldShow then
                    esp.Billboard.Enabled = true
                    if Settings.ESPNames then esp.NameLabel.Text = plr and plr.Name or char.Name; esp.NameLabel.Visible = true
                    else esp.NameLabel.Visible = false end
                    if Settings.ESPHealth then
                        local hp = math.clamp(hum.Health/hum.MaxHealth, 0, 1)
                        esp.HealthBar.Size = UDim2.new(1, 0, hp, 0); esp.HealthBar.BackgroundColor3 = Color3.fromHSV(hp * 0.3, 1, 1)
                    end
                    if Settings.ESPDistance then
                        local dist = myRoot and math.floor((myRoot.Position - root.Position).Magnitude) or 0
                        esp.DistLabel.Text = "[" .. dist .. "m]"; esp.DistLabel.Visible = true
                    else esp.DistLabel.Visible = false end
                    if Settings.ESPChams then
                        if not esp.Highlight or esp.Highlight.Parent ~= char then
                            if esp.Highlight then pcall(function() esp.Highlight:Destroy() end) end
                            local hl = Instance.new("Highlight", char); hl.Name = "ESPCham"; hl.FillTransparency = 0.5; hl.OutlineTransparency = 0
                            hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop; esp.Highlight = hl
                        end
                        esp.Highlight.FillColor = espColor
                    else if esp.Highlight then pcall(function() esp.Highlight:Destroy() end); esp.Highlight = nil end end
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
-- HITBOX EXPANDER
-- ============================================================
local hitboxOriginals = {}

local function resetHitboxes()
    for part, data in pairs(hitboxOriginals) do
        pcall(function()
            if part and part.Parent then
                part.Size = data.size
                part.Transparency = data.transparency
                part.CanCollide = data.canCollide
            end
        end)
    end
    hitboxOriginals = {}
end

local hitboxConn = RunService.Heartbeat:Connect(function()
    if not Settings.HitboxEnabled then
        if next(hitboxOriginals) then resetHitboxes() end
        if hbStatusLabel then hbStatusLabel.Text = "Hitbox: OFF" end
        return
    end

    local targetSize = Vector3.new(Settings.HitboxX, Settings.HitboxY, Settings.HitboxZ)
    local trans = Settings.HitboxVisible and Settings.HitboxTransparency or 1
    local noCollide = not Settings.HitboxCanCollide
    local count = 0

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                for _, part in ipairs(plr.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        if not hitboxOriginals[part] then
                            hitboxOriginals[part] = {
                                size = part.Size,
                                transparency = part.Transparency,
                                canCollide = part.CanCollide,
                            }
                        end
                        pcall(function()
                            part.Size = targetSize
                            part.Transparency = trans
                            if noCollide then part.CanCollide = false end
                        end)
                        count = count + 1
                    end
                end
            end
        end
    end

    if hbStatusLabel then
        hbStatusLabel.Text = "Hitbox: ON | " .. count .. " parts | " ..
            Settings.HitboxX .. "x" .. Settings.HitboxY .. "x" .. Settings.HitboxZ
        hbStatusLabel.TextColor3 = theme.Success
    end
end)
table.insert(Settings._Connections, hitboxConn)

-- ============================================================
-- MISC FEATURES
-- ============================================================

-- Anti-AFK
pcall(function()
    local c = LocalPlayer.Idled:Connect(function()
        if Settings.AntiAFK then VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new()) end
    end)
    table.insert(Settings._Connections, c)
end)

-- Infinite Jump
local jc = UserInputService.JumpRequest:Connect(function()
    if Settings.InfiniteJump then
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)
table.insert(Settings._Connections, jc)

-- Speed + Fly + Sword Fly + Anti-Void + NoClip
local flyBV, flyBG
local swordModel, swordBV, swordBG, swordTrail, swordGlow, swordParticles
local swordTiltAngle = 0

local function createSwordModel(root)
    if swordModel and swordModel.Parent then return swordModel end

    swordModel = Instance.new("Model")
    swordModel.Name = "FlyingSword"

    local blade = Instance.new("Part")
    blade.Name = "Blade"; blade.Size = Vector3.new(0.3, 0.15, 6)
    blade.Material = Enum.Material.Neon; blade.Color = Color3.fromRGB(180, 220, 255)
    blade.CanCollide = false; blade.Anchored = true; blade.Massless = true
    blade.CastShadow = false; blade.Parent = swordModel

    local bladeEdge = Instance.new("Part")
    bladeEdge.Name = "BladeEdge"; bladeEdge.Size = Vector3.new(0.08, 0.2, 5.6)
    bladeEdge.Material = Enum.Material.ForceField; bladeEdge.Color = Color3.fromRGB(140, 180, 255)
    bladeEdge.CanCollide = false; bladeEdge.Anchored = true; bladeEdge.Massless = true
    bladeEdge.Transparency = 0.3; bladeEdge.CastShadow = false; bladeEdge.Parent = swordModel

    local guard = Instance.new("Part")
    guard.Name = "Guard"; guard.Size = Vector3.new(1.2, 0.25, 0.3)
    guard.Material = Enum.Material.Metal; guard.Color = Color3.fromRGB(255, 200, 50)
    guard.CanCollide = false; guard.Anchored = true; guard.Massless = true
    guard.CastShadow = false; guard.Parent = swordModel

    local handle = Instance.new("Part")
    handle.Name = "Handle"; handle.Size = Vector3.new(0.25, 0.25, 1.8)
    handle.Material = Enum.Material.SmoothPlastic; handle.Color = Color3.fromRGB(80, 40, 20)
    handle.CanCollide = false; handle.Anchored = true; handle.Massless = true
    handle.CastShadow = false; handle.Parent = swordModel

    local pommel = Instance.new("Part")
    pommel.Name = "Pommel"; pommel.Shape = Enum.PartType.Ball
    pommel.Size = Vector3.new(0.4, 0.4, 0.4)
    pommel.Material = Enum.Material.Neon; pommel.Color = Color3.fromRGB(255, 100, 255)
    pommel.CanCollide = false; pommel.Anchored = true; pommel.Massless = true
    pommel.CastShadow = false; pommel.Parent = swordModel

    swordGlow = Instance.new("PointLight")
    swordGlow.Color = Color3.fromRGB(150, 180, 255); swordGlow.Brightness = 2
    swordGlow.Range = 12; swordGlow.Parent = blade

    local att0 = Instance.new("Attachment"); att0.Position = Vector3.new(0, 0, -2.8); att0.Parent = blade
    local att1 = Instance.new("Attachment"); att1.Position = Vector3.new(0, 0, 2.8); att1.Parent = blade
    swordTrail = Instance.new("Trail")
    swordTrail.Attachment0 = att0; swordTrail.Attachment1 = att1
    swordTrail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 100, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    swordTrail.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.5),
        NumberSequenceKeypoint.new(1, 1)
    })
    swordTrail.Lifetime = 0.8; swordTrail.MinLength = 0.1
    swordTrail.WidthScale = NumberSequence.new(1); swordTrail.LightEmission = 0.8
    swordTrail.Parent = blade

    swordParticles = Instance.new("ParticleEmitter")
    swordParticles.Color = ColorSequence.new(Color3.fromRGB(180, 200, 255))
    swordParticles.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0)
    })
    swordParticles.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 1)
    })
    swordParticles.Lifetime = NumberRange.new(0.5, 1.2)
    swordParticles.Rate = 30; swordParticles.Speed = NumberRange.new(1, 3)
    swordParticles.SpreadAngle = Vector2.new(180, 180)
    swordParticles.LightEmission = 0.6; swordParticles.Parent = blade

    swordModel.Parent = Workspace
    return swordModel
end

local function destroySwordModel()
    if swordModel then pcall(function() swordModel:Destroy() end); swordModel = nil end
    swordTrail = nil; swordGlow = nil; swordParticles = nil
end

local function updateSwordPosition(root, velocity)
    if not swordModel or not swordModel.Parent then return end
    local blade = swordModel:FindFirstChild("Blade")
    local bladeEdge = swordModel:FindFirstChild("BladeEdge")
    local guard = swordModel:FindFirstChild("Guard")
    local handle = swordModel:FindFirstChild("Handle")
    local pommel = swordModel:FindFirstChild("Pommel")
    if not blade then return end

    local basePos = root.Position - Vector3.new(0, 3.2, 0)
    local speed = velocity.Magnitude

    local targetTilt = 0
    if speed > 5 then
        targetTilt = math.clamp(speed / Settings.SwordFlySpeed * 25, 0, 25)
    end
    swordTiltAngle = swordTiltAngle + (targetTilt - swordTiltAngle) * 0.1

    local lookDir
    if speed > 2 then
        lookDir = velocity.Unit
    else
        lookDir = root.CFrame.LookVector
    end

    local swordCF = CFrame.lookAt(basePos, basePos + lookDir)
        * CFrame.Angles(math.rad(swordTiltAngle), 0, 0)

    blade.CFrame = swordCF
    if bladeEdge then bladeEdge.CFrame = swordCF end
    if guard then guard.CFrame = swordCF * CFrame.new(0, 0, -2.8) end
    if handle then handle.CFrame = swordCF * CFrame.new(0, 0, -3.8) end
    if pommel then pommel.CFrame = swordCF * CFrame.new(0, 0, -4.8) end

    if swordGlow then
        swordGlow.Brightness = 1.5 + math.sin(tick() * 3) * 0.5
    end
    if swordParticles then
        swordParticles.Rate = speed > 10 and 60 or 20
    end
end

local miscConn = RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if Settings.SpeedEnabled then hum.WalkSpeed = Settings.SpeedValue end

    if Settings.SwordFlyEnabled then
        if not swordBV or not swordBV.Parent then
            swordBV = Instance.new("BodyVelocity"); swordBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge); swordBV.Parent = root
        end
        if not swordBG or not swordBG.Parent then
            swordBG = Instance.new("BodyGyro"); swordBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); swordBG.P = 9e4; swordBG.Parent = root
        end
        createSwordModel(root)
        local moveDir = hum.MoveDirection
        local vel = moveDir.Magnitude > 0 and moveDir * Settings.SwordFlySpeed or Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, Settings.SwordFlySpeed, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, Settings.SwordFlySpeed, 0) end
        swordBV.Velocity = vel
        swordBG.CFrame = CFrame.lookAt(root.Position, root.Position + (vel.Magnitude > 1 and vel.Unit or root.CFrame.LookVector))
        updateSwordPosition(root, vel)

        if hum:GetState() ~= Enum.HumanoidStateType.Physics then
            hum:ChangeState(Enum.HumanoidStateType.Physics)
        end
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    else
        if swordBV and swordBV.Parent then swordBV:Destroy(); swordBV = nil end
        if swordBG and swordBG.Parent then swordBG:Destroy(); swordBG = nil end
        if swordModel and swordModel.Parent then destroySwordModel() end
    end

    if Settings.FlyEnabled and not Settings.SwordFlyEnabled then
        if not flyBV or not flyBV.Parent then
            flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flyBV.Parent = root
        end
        if not flyBG or not flyBG.Parent then
            flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flyBG.P = 9e4; flyBG.Parent = root
        end
        local moveDir = hum.MoveDirection
        flyBV.Velocity = moveDir.Magnitude > 0 and moveDir * Settings.FlySpeed or Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyBV.Velocity = flyBV.Velocity + Vector3.new(0, Settings.FlySpeed, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyBV.Velocity = flyBV.Velocity - Vector3.new(0, Settings.FlySpeed, 0) end
        flyBG.CFrame = Camera.CFrame
    elseif not Settings.FlyEnabled then
        if flyBV and flyBV.Parent then flyBV:Destroy(); flyBV = nil end
        if flyBG and flyBG.Parent then flyBG:Destroy(); flyBG = nil end
    end

    if Settings.AntiVoid and root.Position.Y < -50 then
        root.CFrame = CFrame.new(root.Position.X, 100, root.Position.Z); root.Velocity = Vector3.zero
    end

    if Settings.NoClip then
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)
table.insert(Settings._Connections, miscConn)

-- Cleanup
local rc = Workspace.DescendantRemoving:Connect(function(d) if d:IsA("Model") and ESP_Cache[d] then RemoveESP(d) end end)
table.insert(Settings._Connections, rc)
local cc = LocalPlayer.CharacterAdded:Connect(function()
    destroySwordModel()
    if swordBV then pcall(function() swordBV:Destroy() end); swordBV = nil end
    if swordBG then pcall(function() swordBG:Destroy() end); swordBG = nil end
    task.wait(1); task.spawn(scanRemotes)
end)
table.insert(Settings._Connections, cc)
Players.PlayerRemoving:Connect(function(p) if p.Character and ESP_Cache[p.Character] then RemoveESP(p.Character) end end)

-- ============================================================
-- STARTUP
-- ============================================================
updateMiniIcon()
showNotification("V10 Ultra loaded!", 3, theme.Success)
showNotification("25 Aura modes | Hitbox | NPC", 4, theme.Info)
showNotification("Drawing=" .. tostring(hasDrawing) .. " Touch=" .. tostring(hasFireTouchInterest) .. " GC=" .. tostring(hasGetGC), 5, theme.TextDim)

log("V10 Ultra Universal loaded - 25 modes + Hitbox")

-- ============================================================
-- KILL AURA + ESP MOBILE V10 ULTRA - FLUENT UI EDITION
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
-- LOAD FLUENT UI LIBRARY
-- ============================================================
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

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

    -- Tele Enemy
    TeleEnemyEnabled = false,
    TeleEnemyDistance = 5,
    TeleEnemyPosition = nil,

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

    -- Internal
    DebugMode = false,
    _Connections = {},
    _FOVCircle = nil,
}

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

-- ============================================================
-- FLUENT UI WINDOW
-- ============================================================
local Window = Fluent:CreateWindow({
    Title = "Kill Aura V10 Ultra",
    SubTitle = "by PhucVN",
    TabWidth = 100,
    Size = UDim2.fromOffset(420, 340),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl
})

local Tabs = {
    KillAura = Window:AddTab({ Title = "Aura", Icon = "sword" }),
    ESP = Window:AddTab({ Title = "ESP", Icon = "eye" }),
    Aimbot = Window:AddTab({ Title = "Aimbot", Icon = "crosshair" }),
    Hitbox = Window:AddTab({ Title = "Hitbox", Icon = "box" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "settings" }),
}

local Options = Fluent.Options

-- ============================================================
-- TAB: KILL AURA
-- ============================================================
Tabs.KillAura:AddParagraph({
    Title = "Kill Aura",
    Content = "25 attack modes - Universal"
})

local KillAuraToggle = Tabs.KillAura:AddToggle("KillAura", {
    Title = "Kill Aura",
    Description = "Enable kill aura",
    Default = false,
})
KillAuraToggle:OnChanged(function()
    Settings.Enabled = Options.KillAura.Value
end)

Tabs.KillAura:AddDropdown("AuraMode", {
    Title = "Aura Mode (25 modes)",
    Values = {
        "Auto", "Normal", "SpyReplay", "Silent", "ClientDamage",
        "ToolActivate", "TeleportHit", "HitboxExpand", "FlingKill",
        "RaycastSpam", "MultiHit", "RemoteSpam", "NetworkBrute",
        "Universal", "TouchDamage", "ClickDetector", "ProximityPrompt",
        "ModuleExploit", "AnimationAbuse", "VelocityKill", "CFrameSnap",
        "GodModeKill", "AllToolsSpam", "BruteForceAll", "CustomSystem",
    },
    Multi = false,
    Default = 1,
})
Options.AuraMode:OnChanged(function(Value)
    Settings.AuraMode = Value
end)

Tabs.KillAura:AddSlider("Radius", {
    Title = "Radius (studs)",
    Default = 150,
    Min = 10,
    Max = 2000,
    Rounding = 0,
})
Options.Radius:OnChanged(function(Value)
    Settings.Radius = Value
end)

Tabs.KillAura:AddSlider("Delay", {
    Title = "Delay (seconds)",
    Default = 0.15,
    Min = 0.01,
    Max = 1.0,
    Rounding = 2,
})
Options.Delay:OnChanged(function(Value)
    Settings.Delay = Value
end)

Tabs.KillAura:AddSlider("MaxTargets", {
    Title = "Max Targets",
    Default = 5,
    Min = 1,
    Max = 50,
    Rounding = 0,
})
Options.MaxTargets:OnChanged(function(Value)
    Settings.MaxTargets = Value
end)

Tabs.KillAura:AddDropdown("TargetPart", {
    Title = "Target Part",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "Torso", "LowerTorso", "LeftHand", "RightHand"},
    Multi = false,
    Default = 1,
})
Options.TargetPart:OnChanged(function(Value)
    Settings.TargetPart = Value
end)

Tabs.KillAura:AddDropdown("TargetPriority", {
    Title = "Target Priority",
    Values = {"Closest", "LowestHP", "HighestHP", "Random"},
    Multi = false,
    Default = 1,
})
Options.TargetPriority:OnChanged(function(Value)
    Settings.TargetPriority = Value
end)

Tabs.KillAura:AddToggle("WallCheck", {Title = "Wall Check", Default = false})
Options.WallCheck:OnChanged(function(Value) Settings.WallCheck = Value end)

Tabs.KillAura:AddToggle("AutoEquip", {Title = "Auto Equip Weapon", Default = true})
Options.AutoEquip:OnChanged(function(Value) Settings.AutoWeaponEquip = Value end)

Tabs.KillAura:AddToggle("TargetPlayers", {Title = "Target Players", Default = true})
Options.TargetPlayers:OnChanged(function(Value) Settings.TargetPlayers = Value end)

Tabs.KillAura:AddToggle("TargetNPCs", {Title = "Target NPCs/Mobs", Default = true})
Options.TargetNPCs:OnChanged(function(Value) Settings.TargetNPCs = Value end)

-- Tele Enemy section
Tabs.KillAura:AddParagraph({
    Title = "Tele Enemy",
    Content = "Teleport enemies to fixed position"
})

Tabs.KillAura:AddToggle("TeleEnemy", {
    Title = "Tele Enemy (Fixed Pos)",
    Description = "Tele all enemies to saved position",
    Default = false,
})
Options.TeleEnemy:OnChanged(function(Value)
    if Value and not Settings.TeleEnemyPosition then
        Fluent:Notify({Title = "Warning", Content = "Chua luu toa do! Bam Save Position truoc", Duration = 3})
        Options.TeleEnemy:SetValue(false)
        return
    end
    Settings.TeleEnemyEnabled = Value
end)

Tabs.KillAura:AddButton({
    Title = "Save Position",
    Description = "Save current position for Tele Enemy",
    Callback = function()
        local char = LocalPlayer.Character
        local myRoot = char and char:FindFirstChild("HumanoidRootPart")
        if myRoot then
            Settings.TeleEnemyPosition = myRoot.Position
            local p = Settings.TeleEnemyPosition
            Fluent:Notify({
                Title = "Saved!",
                Content = string.format("Pos: %.0f, %.0f, %.0f", p.X, p.Y, p.Z),
                Duration = 3
            })
        end
    end
})

Tabs.KillAura:AddButton({
    Title = "Rescan Remotes",
    Description = "Re-scan all game remotes",
    Callback = function()
        task.spawn(function()
            scanRemotes()
            Fluent:Notify({Title = "Scan", Content = "Scan complete!", Duration = 2})
        end)
    end
})

-- ============================================================
-- TAB: ESP
-- ============================================================
Tabs.ESP:AddToggle("ESP", {Title = "ESP", Description = "Enable ESP overlay", Default = false})
Options.ESP:OnChanged(function(Value) Settings.ESPEnabled = Value end)

Tabs.ESP:AddToggle("ESPBoxes", {Title = "Boxes", Default = true})
Options.ESPBoxes:OnChanged(function(Value) Settings.ESPBoxes = Value end)

Tabs.ESP:AddToggle("ESPNames", {Title = "Names", Default = true})
Options.ESPNames:OnChanged(function(Value) Settings.ESPNames = Value end)

Tabs.ESP:AddToggle("ESPDistance", {Title = "Distance", Default = true})
Options.ESPDistance:OnChanged(function(Value) Settings.ESPDistance = Value end)

Tabs.ESP:AddToggle("ESPHealth", {Title = "Health Bar", Default = true})
Options.ESPHealth:OnChanged(function(Value) Settings.ESPHealth = Value end)

Tabs.ESP:AddToggle("ESPTracers", {Title = "Tracers", Default = true})
Options.ESPTracers:OnChanged(function(Value) Settings.ESPTracers = Value end)

Tabs.ESP:AddToggle("ESPChams", {Title = "Chams", Default = true})
Options.ESPChams:OnChanged(function(Value) Settings.ESPChams = Value end)

Tabs.ESP:AddToggle("ESPSkeleton", {Title = "Skeleton", Default = false})
Options.ESPSkeleton:OnChanged(function(Value) Settings.ESPSkeleton = Value end)

Tabs.ESP:AddToggle("ESPTeamCheck", {Title = "Team Check", Default = true})
Options.ESPTeamCheck:OnChanged(function(Value) Settings.ESPTeamCheck = Value end)

Tabs.ESP:AddSlider("ESPMaxDistance", {
    Title = "Max Distance",
    Default = 2000,
    Min = 100,
    Max = 5000,
    Rounding = 0,
})
Options.ESPMaxDistance:OnChanged(function(Value) Settings.ESPMaxDistance = Value end)

-- ============================================================
-- TAB: AIMBOT
-- ============================================================
Tabs.Aimbot:AddToggle("Aimbot", {Title = "Aimbot", Description = "Auto aim at enemies", Default = false})
Options.Aimbot:OnChanged(function(Value) Settings.AimbotEnabled = Value end)

Tabs.Aimbot:AddSlider("AimbotFOV", {
    Title = "FOV Radius",
    Default = 120,
    Min = 20,
    Max = 500,
    Rounding = 0,
})
Options.AimbotFOV:OnChanged(function(Value) Settings.AimbotFOV = Value end)

Tabs.Aimbot:AddSlider("AimbotSmooth", {
    Title = "Smoothing (%)",
    Default = 30,
    Min = 5,
    Max = 100,
    Rounding = 0,
})
Options.AimbotSmooth:OnChanged(function(Value) Settings.AimbotSmooth = Value / 100 end)

Tabs.Aimbot:AddDropdown("AimbotPart", {
    Title = "Aim Part",
    Values = {"Head", "HumanoidRootPart", "UpperTorso", "Torso"},
    Multi = false,
    Default = 1,
})
Options.AimbotPart:OnChanged(function(Value) Settings.AimbotPart = Value end)

Tabs.Aimbot:AddToggle("ShowFOV", {Title = "Show FOV Circle", Default = true})
Options.ShowFOV:OnChanged(function(Value) Settings.ShowFOVCircle = Value end)

Tabs.Aimbot:AddToggle("AimbotTeamCheck", {Title = "Team Check", Default = true})
Options.AimbotTeamCheck:OnChanged(function(Value) Settings.AimbotTeamCheck = Value end)

-- ============================================================
-- TAB: HITBOX
-- ============================================================
Tabs.Hitbox:AddParagraph({
    Title = "Hitbox Expander",
    Content = "Expand all players' hitbox (except you)"
})

Tabs.Hitbox:AddToggle("Hitbox", {Title = "Hitbox Expander", Description = "Expand enemy hitbox", Default = false})
Options.Hitbox:OnChanged(function(Value) Settings.HitboxEnabled = Value end)

Tabs.Hitbox:AddSlider("HitboxX", {Title = "X Size", Default = 10, Min = 0, Max = 3000, Rounding = 0})
Options.HitboxX:OnChanged(function(Value) Settings.HitboxX = Value end)

Tabs.Hitbox:AddSlider("HitboxY", {Title = "Y Size", Default = 10, Min = 0, Max = 3000, Rounding = 0})
Options.HitboxY:OnChanged(function(Value) Settings.HitboxY = Value end)

Tabs.Hitbox:AddSlider("HitboxZ", {Title = "Z Size", Default = 10, Min = 0, Max = 3000, Rounding = 0})
Options.HitboxZ:OnChanged(function(Value) Settings.HitboxZ = Value end)

Tabs.Hitbox:AddSlider("HitboxTransp", {Title = "Transparency", Default = 70, Min = 0, Max = 100, Rounding = 0})
Options.HitboxTransp:OnChanged(function(Value) Settings.HitboxTransparency = Value / 100 end)

Tabs.Hitbox:AddToggle("HitboxNoCollide", {Title = "Walk Through (NoCollide)", Default = true})
Options.HitboxNoCollide:OnChanged(function(Value) Settings.HitboxCanCollide = not Value end)

Tabs.Hitbox:AddToggle("HitboxVisible", {Title = "Show Hitbox", Default = true})
Options.HitboxVisible:OnChanged(function(Value) Settings.HitboxVisible = Value end)

Tabs.Hitbox:AddDropdown("HitboxPreset", {
    Title = "Quick Preset",
    Values = {"Small (20)", "Medium (50)", "Large (200)", "MEGA (1000)", "MAX (3000)"},
    Multi = false,
    Default = 1,
})
Options.HitboxPreset:OnChanged(function(Value)
    local presets = {
        ["Small (20)"] = 20, ["Medium (50)"] = 50, ["Large (200)"] = 200,
        ["MEGA (1000)"] = 1000, ["MAX (3000)"] = 3000,
    }
    local size = presets[Value] or 10
    Settings.HitboxX = size; Settings.HitboxY = size; Settings.HitboxZ = size
    Options.HitboxX:SetValue(size)
    Options.HitboxY:SetValue(size)
    Options.HitboxZ:SetValue(size)
end)

-- ============================================================
-- TAB: MISC
-- ============================================================
Tabs.Misc:AddToggle("AntiAFK", {Title = "Anti-AFK", Default = true})
Options.AntiAFK:OnChanged(function(Value) Settings.AntiAFK = Value end)

Tabs.Misc:AddToggle("InfiniteJump", {Title = "Infinite Jump", Default = false})
Options.InfiniteJump:OnChanged(function(Value) Settings.InfiniteJump = Value end)

Tabs.Misc:AddToggle("SpeedHack", {Title = "Speed Hack", Default = false})
Options.SpeedHack:OnChanged(function(Value) Settings.SpeedEnabled = Value end)

Tabs.Misc:AddSlider("WalkSpeed", {Title = "Walk Speed", Default = 32, Min = 16, Max = 200, Rounding = 0})
Options.WalkSpeed:OnChanged(function(Value) Settings.SpeedValue = Value end)

Tabs.Misc:AddToggle("Fly", {Title = "Fly", Default = false})
Options.Fly:OnChanged(function(Value) Settings.FlyEnabled = Value end)

Tabs.Misc:AddSlider("FlySpeed", {Title = "Fly Speed", Default = 50, Min = 10, Max = 200, Rounding = 0})
Options.FlySpeed:OnChanged(function(Value) Settings.FlySpeed = Value end)

Tabs.Misc:AddParagraph({
    Title = "Ngu Kiem Phi Hanh",
    Content = "Sword Flying - Wuxia style"
})

Tabs.Misc:AddToggle("SwordFly", {Title = "Sword Fly", Description = "Fly on a sword", Default = false})
Options.SwordFly:OnChanged(function(Value)
    Settings.SwordFlyEnabled = Value
    if Value then Settings.FlyEnabled = false; Options.Fly:SetValue(false) end
end)

Tabs.Misc:AddSlider("SwordSpeed", {Title = "Sword Speed", Default = 80, Min = 20, Max = 300, Rounding = 0})
Options.SwordSpeed:OnChanged(function(Value) Settings.SwordFlySpeed = Value end)

Tabs.Misc:AddToggle("AntiVoid", {Title = "Anti-Void", Default = false})
Options.AntiVoid:OnChanged(function(Value) Settings.AntiVoid = Value end)

Tabs.Misc:AddToggle("NoClip", {Title = "NoClip", Default = false})
Options.NoClip:OnChanged(function(Value) Settings.NoClip = Value end)

Tabs.Misc:AddToggle("DebugMode", {Title = "Debug Mode", Default = false})
Options.DebugMode:OnChanged(function(Value) Settings.DebugMode = Value end)

-- SaveManager / InterfaceManager
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({})
InterfaceManager:SetFolder("KillAuraV10")
SaveManager:SetFolder("KillAuraV10/config")
InterfaceManager:BuildInterfaceSection(Tabs.Misc)
SaveManager:BuildConfigSection(Tabs.Misc)

Window:SelectTab(1)

-- ============================================================
-- ADVANCED REMOTE SPY
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
    log("RemoteSpy started")
end

task.spawn(startRemoteSpy)

-- ============================================================
-- UNIVERSAL REMOTE SCANNER
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

    for _, c in ipairs(priorityContainers) do scanContainer(c) end

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

    task.spawn(function()
        for _, c in ipairs(secondaryContainers) do scanContainer(c) end
    end)

    return found
end

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
                    gameType = type_; break
                end
            end
            if gameType ~= "Unknown" then break end
            for _, obj in ipairs(Workspace:GetDescendants()) do
                if obj:IsA("Tool") and obj.Name:lower():find(kw:lower(), 1, true) then
                    gameType = type_; break
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

    local allDamage = deepScanAllRemotes()
    Settings.AllDamageRemotes = allDamage

    for _, r in ipairs(allDamage) do
        if not Settings.CachedRemotes[r.Name] then
            Settings.CachedRemotes[r.Name] = r
            if not Settings.DetectedMethod then Settings.DetectedMethod = "DeepScan:" .. r.Name end
        end
    end

    scanCustomSystems()
    detectGameType()

    log("Scan: " .. #allDamage .. " damage, " .. #Settings.AllRemotes .. " total, type=" .. Settings.DetectedGameType)
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
    if Settings.AutoWeaponEquip then
        local weaponFolders = {"Weapons", "Items", "Equipment", "Loadout", "Arsenal"}
        for _, folderName in ipairs(weaponFolders) do
            pcall(function()
                local folder = LocalPlayer:FindFirstChild(folderName)
                if folder then
                    local tool = folder:FindFirstChildOfClass("Tool")
                    if tool then pcall(function() tool.Parent = LocalPlayer.Character end) end
                end
            end)
        end
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
    pcall(function()
        local gui = LocalPlayer:FindFirstChild("PlayerGui")
        if gui then
            for _, desc in ipairs(gui:GetDescendants()) do
                if desc:IsA("ViewportFrame") then
                    local parent = desc.Parent
                    if parent and (parent:IsA("ImageButton") or parent:IsA("TextButton") or parent:IsA("Frame")) then
                        table.insert(customWeapons, {type = "UISlot", button = parent, name = parent.Name, source = "PlayerGui"})
                    end
                end
                if (desc:IsA("TextButton") or desc:IsA("ImageButton")) then
                    local nameLower = desc.Name:lower()
                    if nameLower:find("slot") or nameLower:find("weapon") or nameLower:find("skill")
                       or nameLower:find("ability") or nameLower:find("attack") or nameLower:find("hotbar")
                       or nameLower:find("item") or nameLower:find("equip") or nameLower:find("tool")
                       or nameLower:find("btn") or nameLower:find("action") then
                        table.insert(customWeapons, {type = "UIButton", button = desc, name = desc.Name, source = "PlayerGui"})
                    end
                end
            end
        end
    end)
    pcall(function()
        local char = LocalPlayer.Character
        if char then
            for _, obj in ipairs(char:GetChildren()) do
                if obj:IsA("Model") and not obj:IsA("Tool") then
                    local handle = obj:FindFirstChild("Handle") or obj:FindFirstChildWhichIsA("BasePart")
                    if handle then
                        table.insert(customWeapons, {type = "CharModel", model = obj, handle = handle, name = obj.Name, source = "Character"})
                    end
                end
                if obj:IsA("Accessory") then
                    local handle = obj:FindFirstChild("Handle")
                    if handle and handle:FindFirstChild("TouchInterest") then
                        table.insert(customWeapons, {type = "WeaponAccessory", accessory = obj, handle = handle, name = obj.Name, source = "Character"})
                    end
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
    pcall(function()
        for _, remote in ipairs(Settings.AllRemotes) do
            if remote:IsA("RemoteEvent") and isLikelyCombatRemote(remote.Name) then
                table.insert(hotbarRemotes, remote)
            end
        end
    end)
    if hasGetConnections then
        pcall(function()
            local gui = LocalPlayer:FindFirstChild("PlayerGui")
            if gui then
                for _, desc in ipairs(gui:GetDescendants()) do
                    if desc:IsA("TextButton") or desc:IsA("ImageButton") then
                        local connections = getconnections(desc.Activated) or {}
                        for _, conn in ipairs(connections) do
                            pcall(function()
                                table.insert(hotbarRemotes, {type = "ButtonConnection", button = desc, fire = function() pcall(function() conn:Fire() end) end})
                            end)
                        end
                    end
                end
            end
        end)
    end
    if hasGetGC then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    for key, func in pairs(v) do
                        if type(key) == "string" and type(func) == "function" then
                            local keyLower = key:lower()
                            if keyLower == "attack" or keyLower == "swing" or keyLower == "m1"
                               or keyLower == "lightattack" or keyLower == "heavyattack"
                               or keyLower == "basicattack" or keyLower == "slash" then
                                table.insert(hotbarRemotes, {type = "GCFunction", name = key, fire = function() pcall(func) end})
                            end
                        end
                    end
                end
            end
        end)
    end
    Settings.HotbarRemotes = hotbarRemotes
    return hotbarRemotes
end

local function simulateCustomAttack(t, targetPart, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
    for _, entry in ipairs(Settings.HotbarRemotes) do
        task.spawn(function()
            if entry.fire then
                pcall(entry.fire)
            elseif entry:IsA("RemoteEvent") then
                pcall(function() entry:FireServer() end)
                pcall(function() entry:FireServer("Attack") end)
                pcall(function() entry:FireServer(targetPart.Position) end)
                pcall(function() entry:FireServer(targetPart, dir) end)
            end
        end)
    end
    for _, weapon in ipairs(Settings.CustomWeapons) do
        task.spawn(function()
            if weapon.type == "UISlot" or weapon.type == "UIButton" then
                if hasGetConnections then
                    pcall(function()
                        local conns = getconnections(weapon.button.Activated)
                        for _, conn in ipairs(conns or {}) do pcall(function() conn:Fire() end) end
                    end)
                end
            elseif (weapon.type == "CharModel" or weapon.type == "WeaponAccessory") and hasFireTouchInterest then
                local handle = weapon.handle
                if handle then
                    pcall(function() firetouchinterest(handle, targetPart, 0); task.wait(); firetouchinterest(handle, targetPart, 1) end)
                end
            end
        end)
    end
end

function scanCustomSystems()
    findCustomWeapons()
    findHotbarRemotes()
    pcall(function()
        local customFrameworks = {
            {path = "ReplicatedStorage.Modules.Combat"}, {path = "ReplicatedStorage.Combat"},
            {path = "ReplicatedStorage.Systems.Combat"}, {path = "ReplicatedStorage.Framework"},
            {path = "ReplicatedStorage.Knit"},
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
                for _, obj in ipairs(current:GetDescendants()) do
                    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
                        table.insert(Settings.CustomCombatRemotes, obj)
                    end
                end
            end
        end
    end)
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
-- 25 ATTACK MODES
-- ============================================================
local function fireMethod(t, targetPart, weapon, myRoot)
    local method = Settings.DetectedMethod
    local R = Settings.CachedRemotes
    local dir = (targetPart.Position - myRoot.Position).Unit

    if method == "WeaponHit" and R.WeaponFired and R.WeaponHit then
        R.WeaponFired:FireServer(weapon, {id = math.random(1, 99), charge = 0, origin = myRoot.Position, dir = dir})
        R.WeaponHit:FireServer(weapon, {p = targetPart.Position, pid = 1, part = targetPart, d = t.distance, maxDist = t.distance + 1, h = t.humanoid, m = Enum.Material.Plastic, n = Vector3.new(0, 1, 0), t = 0.1, sid = math.random(1, 99)})
        return true
    elseif method == "RequestActionSync" and R.RequestActionSync then
        R.RequestActionSync:FireServer({{direction = dir, hitPosition = targetPart.Position, origin = myRoot.Position, hitInstance = targetPart, hitHumanoid = t.humanoid, IsHeadshot = (Settings.TargetPart == "Head")}})
        return true
    elseif method == "GunRemote" and R.GunRemote then
        R.GunRemote:FireServer(1, weapon, targetPart.Position, Vector3.yAxis, targetPart)
        return true
    elseif method == "WeaponsSystem" and R.WSFired and R.WSHit then
        local sid = math.random(10, 999)
        R.WSFired:FireServer(weapon, {id = sid, charge = 0, origin = myRoot.Position, dir = dir})
        R.WSHit:FireServer(weapon, {p = targetPart.Position, pid = 1, part = targetPart, d = t.distance, maxDist = t.distance + 1, h = t.humanoid, m = Enum.Material.Plastic, n = Vector3.new(0, 1, 0), t = 0.1, sid = sid})
        return true
    elseif method == "FireWeapon" and R.FireWeapon then
        local origin = myRoot.Position + Vector3.new(0, 1.5, 0)
        R.FireWeapon:FireServer("Main", origin, dir, {[1] = {Normal = Vector3.new(0, 1, 0), Direction = dir, Position = targetPart.Position, Hit = targetPart, Bounce = 0, Origin = origin}})
        return true
    end

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
            }
            for _, sig in ipairs(sigs) do if pcall(sig) then return true end end
        end
    end
    return tried
end

local function spyReplayAttack(t, targetPart, weapon, myRoot)
    local dir = (targetPart.Position - myRoot.Position).Unit
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
                                if cloned.origin then cloned.origin = myRoot.Position end
                                if cloned.dir then cloned.dir = dir end
                                if cloned.direction then cloned.direction = dir end
                                if cloned.Target then cloned.Target = targetPart end
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
            targetPart.Size = Vector3.new(20, 20, 20); targetPart.Transparency = 0.9; targetPart.CanCollide = false
        end
        if t.root then t.root.Size = Vector3.new(15, 15, 15); t.root.Transparency = 0.9; t.root.CanCollide = false end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
end

local function flingKillAttack(t, targetPart, weapon, myRoot)
    pcall(function()
        if t.root then
            local bv = Instance.new("BodyVelocity")
            bv.Velocity = Vector3.new(math.random(-9999, 9999), 99999, math.random(-9999, 9999))
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bv.Parent = t.root
            task.delay(0.3, function() if bv and bv.Parent then bv:Destroy() end end)
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
end

local function raycastSpamAttack(t, targetPart, weapon, myRoot)
    for _ = 1, 10 do
        task.spawn(function() pcall(function() fireMethod(t, targetPart, weapon, myRoot) end) end)
    end
end

local function multiHitAttack(t, targetPart, weapon, myRoot)
    for _ = 1, 5 do fireMethod(t, targetPart, weapon, myRoot); task.wait(0.01) end
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
            pcall(function() remote:FireServer(weapon, targetPart, dir) end)
        end)
    end
end

local function universalAttack(t, targetPart, weapon, myRoot)
    fireMethod(t, targetPart, weapon, myRoot)
    spyReplayAttack(t, targetPart, weapon, myRoot)
    silentAttack(t, targetPart, myRoot)
    clientDamageAttack(t)
    if weapon then pcall(function() weapon:Activate() end) end
end

local function touchDamageAttack(t, targetPart, weapon, myRoot)
    if not hasFireTouchInterest then fireMethod(t, targetPart, weapon, myRoot); return end
    local char = LocalPlayer.Character
    if not char then return end
    if weapon then
        local handle = weapon:FindFirstChild("Handle")
        if handle then pcall(function() firetouchinterest(handle, targetPart, 0); task.wait(); firetouchinterest(handle, targetPart, 1) end) end
    end
    for _, part in ipairs(char:GetChildren()) do
        if part:IsA("BasePart") then
            pcall(function() firetouchinterest(part, targetPart, 0); task.wait(); firetouchinterest(part, targetPart, 1) end)
        end
    end
end

local function clickDetectorAttack(t, targetPart, weapon, myRoot)
    if hasFireClickDetector and t.character then
        for _, obj in ipairs(t.character:GetDescendants()) do
            if obj:IsA("ClickDetector") then pcall(function() fireclickdetector(obj) end) end
        end
    end
    fireMethod(t, targetPart, weapon, myRoot)
end

local function proximityPromptAttack(t, targetPart, weapon, myRoot)
    if hasFireProximity and t.character then
        for _, obj in ipairs(t.character:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then pcall(function() fireproximityprompt(obj) end) end
        end
    end
    fireMethod(t, targetPart, weapon, myRoot)
end

local function moduleExploitAttack(t, targetPart, weapon, myRoot)
    if hasGetGC then
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    for key, func in pairs(v) do
                        if type(key) == "string" and type(func) == "function" then
                            local kl = key:lower()
                            if kl:find("damage") or kl:find("hit") or kl:find("attack") then
                                pcall(function() func(t.humanoid, 100) end)
                                pcall(function() func(targetPart, 100) end)
                            end
                        end
                    end
                end
            end
        end)
    end
    fireMethod(t, targetPart, weapon, myRoot)
end

local function animationAbuseAttack(t, targetPart, weapon, myRoot)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        for _, animId in ipairs({"rbxassetid://218504594", "rbxassetid://218504441", "rbxassetid://522635514"}) do
            pcall(function()
                local anim = Instance.new("Animation"); anim.AnimationId = animId
                local track = hum:LoadAnimation(anim); track:Play()
                task.delay(0.3, function() track:Stop() end)
            end)
        end
    end
    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)
end

local function velocityKillAttack(t, targetPart, weapon, myRoot)
    pcall(function()
        if t.root then
            local bv = Instance.new("BodyVelocity"); bv.Velocity = Vector3.new(0, -99999, 0)
            bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Parent = t.root
            task.delay(0.2, function() if bv.Parent then bv:Destroy() end end)
        end
    end)
    fireMethod(t, targetPart, weapon, myRoot)
end

local function cframeSnapAttack(t, targetPart, weapon, myRoot)
    local originalCF = myRoot.CFrame
    pcall(function() myRoot.CFrame = t.root.CFrame end)
    task.wait(0.02)
    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)
    if hasFireTouchInterest then
        for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
            if part:IsA("BasePart") then
                for _, tpart in ipairs(t.character:GetChildren()) do
                    if tpart:IsA("BasePart") then
                        pcall(function() firetouchinterest(part, tpart, 0); task.wait(); firetouchinterest(part, tpart, 1) end)
                    end
                end
            end
        end
    end
    task.wait(0.02)
    pcall(function() myRoot.CFrame = originalCF end)
end

local function godModeKillAttack(t, targetPart, weapon, myRoot)
    local myHum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local origHealth
    if myHum then origHealth = myHum.Health; pcall(function() myHum.Health = math.huge end) end
    pcall(function()
        local dir = (targetPart.Position - myRoot.Position).Unit
        myRoot.CFrame = targetPart.CFrame * CFrame.new(0, 0, 2); myRoot.Velocity = dir * 500
    end)
    if weapon then pcall(function() weapon:Activate() end) end
    fireMethod(t, targetPart, weapon, myRoot)
    task.wait(0.1)
    if myHum and origHealth then pcall(function() myHum.Health = origHealth end) end
end

local function allToolsSpamAttack(t, targetPart, weapon, myRoot)
    for _, tool in ipairs(findAllTools()) do
        task.spawn(function()
            pcall(function() tool.Parent = LocalPlayer.Character; tool:Activate() end)
            if hasFireTouchInterest then
                local handle = tool:FindFirstChild("Handle")
                if handle then pcall(function() firetouchinterest(handle, targetPart, 0); task.wait(); firetouchinterest(handle, targetPart, 1) end) end
            end
        end)
    end
    fireMethod(t, targetPart, weapon, myRoot)
end

local function bruteForceAllAttack(t, targetPart, weapon, myRoot)
    task.spawn(function() pcall(function() fireMethod(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() spyReplayAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() silentAttack(t, targetPart, myRoot) end) end)
    task.spawn(function() pcall(function() clientDamageAttack(t) end) end)
    task.spawn(function() pcall(function() touchDamageAttack(t, targetPart, weapon, myRoot) end) end)
    task.spawn(function() pcall(function() simulateCustomAttack(t, targetPart, myRoot) end) end)
    local dir = (targetPart.Position - myRoot.Position).Unit
    for _, remote in ipairs(Settings.AllRemotes) do
        if remote:IsA("RemoteEvent") then
            task.spawn(function()
                pcall(function() remote:FireServer(targetPart) end)
                pcall(function() remote:FireServer(t.humanoid, 100) end)
                pcall(function() remote:FireServer(targetPart, 100) end)
                pcall(function() remote:FireServer(weapon, targetPart, dir) end)
            end)
        end
    end
end

local function customSystemAttack(t, targetPart, weapon, myRoot)
    if #Settings.HotbarRemotes == 0 and #Settings.CustomWeapons == 0 then scanCustomSystems() end
    simulateCustomAttack(t, targetPart, myRoot)
    for _, remote in ipairs(Settings.CustomCombatRemotes) do
        task.spawn(function()
            if remote:IsA("RemoteEvent") then
                pcall(function() remote:FireServer() end)
                pcall(function() remote:FireServer("Attack") end)
                pcall(function() remote:FireServer(targetPart.Position) end)
            end
        end)
    end
    if hasFireTouchInterest then
        local char = LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") then
                    pcall(function() firetouchinterest(part, targetPart, 0); task.wait(); firetouchinterest(part, targetPart, 1) end)
                end
            end
        end
    end
    fireMethod(t, targetPart, weapon, myRoot)
end

local function autoAttack(t, targetPart, weapon, myRoot)
    if fireMethod(t, targetPart, weapon, myRoot) then return end
    if spyReplayAttack(t, targetPart, weapon, myRoot) then return end
    if not weapon and Settings.HasCustomInventory then simulateCustomAttack(t, targetPart, myRoot) end
    if hasFireTouchInterest then touchDamageAttack(t, targetPart, weapon, myRoot) end
    if weapon then pcall(function() weapon:Activate() end) end
    silentAttack(t, targetPart, myRoot)
    clientDamageAttack(t)
end

-- ============================================================
-- TARGET SORTING
-- ============================================================
local function sortTargets(targets)
    local p = Settings.TargetPriority
    if p == "Closest" then table.sort(targets, function(a, b) return a.distance < b.distance end)
    elseif p == "LowestHP" then table.sort(targets, function(a, b) return a.humanoid.Health < b.humanoid.Health end)
    elseif p == "HighestHP" then table.sort(targets, function(a, b) return a.humanoid.Health > b.humanoid.Health end)
    elseif p == "Random" then for i = #targets, 2, -1 do local j = math.random(i); targets[i], targets[j] = targets[j], targets[i] end
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
                        table.insert(targets, {player = nil, character = model, root = root, humanoid = hum, distance = dist, isNPC = true})
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
        if tick() - Settings.LastAttack > 5 then task.spawn(scanRemotes); Settings.LastAttack = tick() end
    end

    local now = tick()
    if now - Settings.LastAttack < Settings.Delay then return end

    local char = LocalPlayer.Character
    local myRoot = char and char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    Settings.LastAttack = now
    local weapon = findWeapon()
    local targets = {}

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
                            table.insert(targets, {player = plr, character = plr.Character, root = tRoot, humanoid = tHum, distance = dist, isNPC = false})
                        end
                    end
                end
            end
        end
    end

    for _, t in ipairs(getNPCTargets(myRoot)) do table.insert(targets, t) end
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

    local hl = Instance.new("Highlight", char); hl.Name = "ESPCham"; hl.FillTransparency = 0.5
    hl.OutlineTransparency = 0; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.FillColor = Settings.ESPColor; hl.OutlineColor = Color3.new(1,1,1)

    local dl = Instance.new("TextLabel", mf); dl.Size = UDim2.new(1,0,0.15,0); dl.Position = UDim2.new(0,0,0.85,0)
    dl.BackgroundTransparency = 1; dl.TextColor3 = Color3.new(1,1,1); dl.TextStrokeTransparency = 0
    dl.Font = Enum.Font.Gotham; dl.TextSize = 12

    local hbg = Instance.new("Frame", mf); hbg.Size = UDim2.new(0.05,0,0.6,0); hbg.Position = UDim2.new(-0.08,0,0.2,0)
    hbg.BackgroundColor3 = Color3.new(0,0,0); hbg.BorderSizePixel = 0
    local hb = Instance.new("Frame", hbg); hb.Size = UDim2.new(1,0,1,0); hb.BackgroundColor3 = Color3.new(0,1,0); hb.BorderSizePixel = 0

    return {Billboard = billboard, NameLabel = nl, HealthBar = hb, DistLabel = dl, Highlight = hl, Type = "Billboard"}
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
                            esp.Highlight.FillColor = espColor
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
                    if Settings.ESPNames then esp.NameLabel.Text = plr and plr.Name or char.Name; esp.NameLabel.Visible = true else esp.NameLabel.Visible = false end
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
                part.Size = data.size; part.Transparency = data.transparency; part.CanCollide = data.canCollide
            end
        end)
    end
    hitboxOriginals = {}
end

local hitboxConn = RunService.Heartbeat:Connect(function()
    if not Settings.HitboxEnabled then
        if next(hitboxOriginals) then resetHitboxes() end
        return
    end

    local targetSize = Vector3.new(Settings.HitboxX, Settings.HitboxY, Settings.HitboxZ)
    local trans = Settings.HitboxVisible and Settings.HitboxTransparency or 1
    local noCollide = not Settings.HitboxCanCollide

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then
                for _, part in ipairs(plr.Character:GetChildren()) do
                    if part:IsA("BasePart") then
                        if not hitboxOriginals[part] then
                            hitboxOriginals[part] = {size = part.Size, transparency = part.Transparency, canCollide = part.CanCollide}
                        end
                        pcall(function()
                            part.Size = targetSize; part.Transparency = trans
                            if noCollide then part.CanCollide = false end
                        end)
                    end
                end
            end
        end
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
    swordModel = Instance.new("Model"); swordModel.Name = "FlyingSword"

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
    swordGlow.Color = Color3.fromRGB(150, 180, 255); swordGlow.Brightness = 2; swordGlow.Range = 12; swordGlow.Parent = blade

    local att0 = Instance.new("Attachment"); att0.Position = Vector3.new(0, 0, -2.8); att0.Parent = blade
    local att1 = Instance.new("Attachment"); att1.Position = Vector3.new(0, 0, 2.8); att1.Parent = blade
    swordTrail = Instance.new("Trail")
    swordTrail.Attachment0 = att0; swordTrail.Attachment1 = att1
    swordTrail.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 220, 255)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(140, 100, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))
    })
    swordTrail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.5, 0.5), NumberSequenceKeypoint.new(1, 1)})
    swordTrail.Lifetime = 0.8; swordTrail.MinLength = 0.1; swordTrail.LightEmission = 0.8; swordTrail.Parent = blade

    swordParticles = Instance.new("ParticleEmitter")
    swordParticles.Color = ColorSequence.new(Color3.fromRGB(180, 200, 255))
    swordParticles.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0)})
    swordParticles.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
    swordParticles.Lifetime = NumberRange.new(0.5, 1.2); swordParticles.Rate = 30
    swordParticles.Speed = NumberRange.new(1, 3); swordParticles.SpreadAngle = Vector2.new(180, 180)
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
    local targetTilt = speed > 5 and math.clamp(speed / Settings.SwordFlySpeed * 25, 0, 25) or 0
    swordTiltAngle = swordTiltAngle + (targetTilt - swordTiltAngle) * 0.1

    local lookDir = speed > 2 and velocity.Unit or root.CFrame.LookVector
    local swordCF = CFrame.lookAt(basePos, basePos + lookDir) * CFrame.Angles(math.rad(swordTiltAngle), 0, 0)

    blade.CFrame = swordCF
    if bladeEdge then bladeEdge.CFrame = swordCF end
    if guard then guard.CFrame = swordCF * CFrame.new(0, 0, -2.8) end
    if handle then handle.CFrame = swordCF * CFrame.new(0, 0, -3.8) end
    if pommel then pommel.CFrame = swordCF * CFrame.new(0, 0, -4.8) end
    if swordGlow then swordGlow.Brightness = 1.5 + math.sin(tick() * 3) * 0.5 end
    if swordParticles then swordParticles.Rate = speed > 10 and 60 or 20 end
end

-- Mobile fly buttons
local flyUpHeld = false
local flyDownHeld = false
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local FlyButtonsGui
if isMobile then
    FlyButtonsGui = Instance.new("ScreenGui")
    FlyButtonsGui.Name = "FlyButtons"; FlyButtonsGui.ResetOnSpawn = false; FlyButtonsGui.Parent = CoreGui

    local frame = Instance.new("Frame", FlyButtonsGui)
    frame.Size = UDim2.new(0, 55, 0, 120); frame.Position = UDim2.new(1, -65, 0.5, -60)
    frame.BackgroundTransparency = 1; frame.Visible = false; frame.Name = "BtnFrame"

    local upBtn = Instance.new("TextButton", frame)
    upBtn.Size = UDim2.new(1, 0, 0, 52); upBtn.Position = UDim2.new(0, 0, 0, 0)
    upBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 255); upBtn.BackgroundTransparency = 0.3
    upBtn.Text = "UP"; upBtn.TextColor3 = Color3.new(1, 1, 1); upBtn.Font = Enum.Font.GothamBold; upBtn.TextSize = 13
    Instance.new("UICorner", upBtn).CornerRadius = UDim.new(0, 10)

    local downBtn = Instance.new("TextButton", frame)
    downBtn.Size = UDim2.new(1, 0, 0, 52); downBtn.Position = UDim2.new(0, 0, 0, 62)
    downBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 60); downBtn.BackgroundTransparency = 0.3
    downBtn.Text = "DOWN"; downBtn.TextColor3 = Color3.new(1, 1, 1); downBtn.Font = Enum.Font.GothamBold; downBtn.TextSize = 13
    Instance.new("UICorner", downBtn).CornerRadius = UDim.new(0, 10)

    upBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then flyUpHeld = true end end)
    upBtn.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then flyUpHeld = false end end)
    downBtn.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then flyDownHeld = true end end)
    downBtn.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.Touch then flyDownHeld = false end end)
end

local miscConn = RunService.Heartbeat:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    if Settings.SpeedEnabled then hum.WalkSpeed = Settings.SpeedValue end

    -- Tele Enemy
    if Settings.TeleEnemyEnabled and Settings.TeleEnemyPosition then
        local pos = Settings.TeleEnemyPosition
        local teleCount = 0
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                local tHum = plr.Character:FindFirstChildOfClass("Humanoid")
                if tRoot and tHum and tHum.Health > 0 then
                    local sameTeam = LocalPlayer.Team and plr.Team and LocalPlayer.Team == plr.Team
                    if not sameTeam then
                        teleCount = teleCount + 1
                        local offset = Vector3.new((teleCount % 3 - 1) * 2, 0, (math.floor(teleCount / 3)) * 2)
                        tRoot.CFrame = CFrame.new(pos + offset)
                        tRoot.Anchored = true
                        pcall(function() tHum.WalkSpeed = 0; tHum.JumpPower = 0 end)
                    end
                end
            end
        end
    elseif not Settings.TeleEnemyEnabled then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local tRoot = plr.Character:FindFirstChild("HumanoidRootPart")
                if tRoot and tRoot.Anchored then tRoot.Anchored = false end
            end
        end
    end

    -- Mobile fly buttons visibility
    local isFlying = Settings.SwordFlyEnabled or Settings.FlyEnabled
    if FlyButtonsGui then
        local btnFrame = FlyButtonsGui:FindFirstChild("BtnFrame")
        if btnFrame then btnFrame.Visible = isFlying end
    end

    -- Sword Fly
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
        if flyUpHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) then vel = vel + Vector3.new(0, Settings.SwordFlySpeed, 0) end
        if flyDownHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then vel = vel - Vector3.new(0, Settings.SwordFlySpeed, 0) end
        swordBV.Velocity = vel
        swordBG.CFrame = CFrame.lookAt(root.Position, root.Position + (vel.Magnitude > 1 and vel.Unit or root.CFrame.LookVector))
        updateSwordPosition(root, vel)
        if hum:GetState() ~= Enum.HumanoidStateType.Physics then hum:ChangeState(Enum.HumanoidStateType.Physics) end
        for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
    else
        if swordBV and swordBV.Parent then swordBV:Destroy(); swordBV = nil end
        if swordBG and swordBG.Parent then swordBG:Destroy(); swordBG = nil end
        if swordModel and swordModel.Parent then destroySwordModel() end
    end

    -- Normal Fly
    if Settings.FlyEnabled and not Settings.SwordFlyEnabled then
        if not flyBV or not flyBV.Parent then
            flyBV = Instance.new("BodyVelocity"); flyBV.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flyBV.Parent = root
        end
        if not flyBG or not flyBG.Parent then
            flyBG = Instance.new("BodyGyro"); flyBG.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flyBG.P = 9e4; flyBG.Parent = root
        end
        local moveDir = hum.MoveDirection
        flyBV.Velocity = moveDir.Magnitude > 0 and moveDir * Settings.FlySpeed or Vector3.zero
        if flyUpHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) then flyBV.Velocity = flyBV.Velocity + Vector3.new(0, Settings.FlySpeed, 0) end
        if flyDownHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then flyBV.Velocity = flyBV.Velocity - Vector3.new(0, Settings.FlySpeed, 0) end
        flyBG.CFrame = Camera.CFrame
    elseif not Settings.FlyEnabled then
        if flyBV and flyBV.Parent then flyBV:Destroy(); flyBV = nil end
        if flyBG and flyBG.Parent then flyBG:Destroy(); flyBG = nil end
    end

    if Settings.AntiVoid and root.Position.Y < -50 then
        root.CFrame = CFrame.new(root.Position.X, 100, root.Position.Z); root.Velocity = Vector3.zero
    end

    if Settings.NoClip then
        for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = false end end
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
Fluent:Notify({
    Title = "Kill Aura V10 Ultra",
    Content = "Loaded! 25 modes | ESP | Aimbot | Hitbox",
    Duration = 5
})
Fluent:Notify({
    Title = "Info",
    Content = "Drawing=" .. tostring(hasDrawing) .. " Touch=" .. tostring(hasFireTouchInterest) .. " GC=" .. tostring(hasGetGC),
    Duration = 5
})

SaveManager:LoadAutoloadConfig()
log("V10 Ultra Fluent UI loaded - 25 modes")

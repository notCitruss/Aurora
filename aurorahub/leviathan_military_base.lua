--// Aurora v5 — [LEVIATHAN] Build a Military Base
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 91440994157417 · Creator: Phantomline
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// Features: Auto Collect · Auto Purchase Structures · Auto Open Loot Crate · Exploit probes

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraPill", "TestAurora"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORAHUB_LEVIATHAN_CFG then
    for k, v in pairs(getgenv().__AURORAHUB_LEVIATHAN_CFG) do
        if type(v) == "boolean" then getgenv().__AURORAHUB_LEVIATHAN_CFG[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORAHUB_LEVIATHAN_SESSION = tick()
local _mySession = getgenv().__AURORAHUB_LEVIATHAN_SESSION
local function alive() return getgenv().__AURORAHUB_LEVIATHAN_SESSION == _mySession end

---------- COMPAT (cross-executor support) ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    firepp    = fireproximityprompt ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
    vim       = pcall(function() return game:GetService("VirtualInputManager") end),
}

---------- REMOTE RESOLVERS ----------
local function safeRE(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteEvent")) and obj or nil
end
local function safeRF(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteFunction")) and obj or nil
end

-- Walk a path like "Shared.Resources.PlotResources.Remotes.Collect"
local function resolveByPath(pathStr)
    local parts = string.split(pathStr, ".")
    local cur = RS
    for _, p in ipairs(parts) do
        if not cur then return nil end
        cur = cur:FindFirstChild(p)
    end
    return cur
end

-- Root resource folders
local Shared       = RS:WaitForChild("Shared", 15)
local Resources    = Shared and Shared:WaitForChild("Resources", 15)
if not Resources then warn("[Aurora Leviathan] Shared.Resources missing"); return end

local PlotRes      = Resources:WaitForChild("PlotResources", 10)
local VendorRes    = Resources:WaitForChild("VendorResources", 10)
local CrateRes     = Resources:WaitForChild("LootCrateResources", 10)
local RewardRes    = Resources:WaitForChild("RewardResources", 10)
local UnitRes      = Resources:WaitForChild("UnitResources", 10)
local ModifierRes  = Resources:WaitForChild("ModifierResources", 10)
local RebirthRes   = Resources:WaitForChild("RebirthResources", 10)
local TraitRes     = Resources:WaitForChild("TraitResources", 10)
local TutorialRes  = Resources:WaitForChild("TutorialResources", 10)
local GameMasterRes = Resources:WaitForChild("GameMaster", 10)

local PlotRemotes     = PlotRes     and PlotRes:FindFirstChild("Remotes")
local VendorRemotes   = VendorRes   and VendorRes:FindFirstChild("Remotes")
local CrateRemotes    = CrateRes    and CrateRes:FindFirstChild("Remotes")
local RewardRemotes   = RewardRes   and RewardRes:FindFirstChild("Remotes")
local UnitRemotes     = UnitRes     and UnitRes:FindFirstChild("Remotes")
local ModifierRemotes = ModifierRes and ModifierRes:FindFirstChild("Remotes")
local RebirthRemotes  = RebirthRes  and RebirthRes:FindFirstChild("Remotes")
local TraitRemotes    = TraitRes    and TraitRes:FindFirstChild("Remotes")
local TutorialRemotes = TutorialRes and TutorialRes:FindFirstChild("Remotes")
local GameMasterRemotes = GameMasterRes and GameMasterRes:FindFirstChild("Remotes")

-- All remotes under a single R table to stay under Luau's 200-local limit
local R = {
    Collect           = safeRE(PlotRemotes, "Collect"),
    PurchaseStructure = safeRE(VendorRemotes, "PurchaseStructure"),
    PlaceStructure    = safeRE(PlotRemotes, "PlaceStructure"),
    DestroyStructure  = safeRE(PlotRemotes, "DestroyStructure"),
    OpenLootCrate     = safeRE(CrateRemotes, "OpenLootCrate"),
    ToggleTenOpen     = safeRE(CrateRemotes, "ToggleTenOpen"),
    PurchasePlot      = safeRE(PlotRemotes, "PurchasePlot"),
    UpdateCollectors  = safeRE(PlotRemotes, "UpdateCollectors"),
    ClaimDaily        = safeRE(RewardRemotes, "ClaimDailyLoginReward"),
    ClaimPlaytime     = safeRE(RewardRemotes, "ClaimPlaytimeReward"),
    ClaimGroup        = safeRE(RewardRemotes, "ClaimGroupReward"),
    RedeemCode        = safeRE(RewardRemotes, "RedeemCode"),
    RunCommand        = safeRE(GameMasterRemotes, "RunCommand"),
    Rebirth           = safeRE(RebirthRemotes, "Rebirth"),
    SkipTutorial      = safeRE(TutorialRemotes, "SkipTutorial"),
    UpdateModifiers   = safeRE(ModifierRemotes, "UpdateModifiers"),
    UpdateStructureMods = safeRE(ModifierRemotes, "UpdateStructureModifiers"),
    UpdateUnitCap     = safeRE(UnitRemotes, "UpdateUnitCap"),
    RerollTraits      = safeRE(TraitRemotes, "RerollTraits"),
    DismantleRebirth  = safeRE(VendorRemotes, "DismantleRebirthStructure"),
    DismantleMythic   = safeRE(VendorRemotes, "DismantleMythicStructure"),
    PurchaseMythic    = safeRE(VendorRemotes, "PurchaseMythicStructure"),
    PurchaseRebirthSt = safeRE(VendorRemotes, "PurchaseRebirthStructure"),
    PurchaseProduct   = safeRE(VendorRemotes, "PurchaseProduct"),
    AttackTarget      = safeRE(UnitRemotes, "AttackTarget"),
    RallyUnits        = safeRE(UnitRemotes, "RallyUnits"),
}

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().__AURORAHUB_LEVIATHAN_CFG then
    getgenv().__AURORAHUB_LEVIATHAN_CFG = {
        -- Core autos
        AutoCollect         = false,
        CollectTypes        = {},     -- multi-select filter; empty = all
        AutoPurchase        = false,
        PurchaseStructures  = {},     -- multi-select set of structure names
        AutoPlaceAfterBuy   = false,  -- fire PlaceStructure at a computed offset after each purchase
        AutoOpenCrates      = false,
        CrateTypes          = {},     -- multi-select crate names
        UseTenOpen          = false,  -- try 10x bulk open alongside OpenLootCrate
        AutoRewards         = true,   -- daily + playtime + group claims (passive)
        AutoAntiAFK         = true,

        -- Delay presets (seconds)
        CollectDelay        = "0.5s",
        PurchaseDelay       = "1.0s",
        CrateDelay          = "0.5s",

        -- Misc
        AutoSpeed           = false,
        SpeedValue          = 28,
        AutoInfJump         = false,

        -- Exploits (all OFF, require master gate)
        ExploitMaster            = false,  -- master gate — must be ON for any below to fire
        ExploitAdminProbe        = false,
        ExploitCollectorOverride = false,
        ExploitUnitCapBoost      = false,
        ExploitModifierInjection = false,
        ExploitRewardSpam        = false,
        ExploitFreeRebirth       = false,
        ExploitFreeReroll        = false,
        ExploitPlaceFree         = false,  -- PlaceStructure without Purchase
        ExploitDismantleDupe     = false,  -- place + dismantle loop to test refund dupe

        -- Persistence
        AutoSave = false,

        -- UI state
        ActiveTab  = "Main",
        PanelOpen  = true,
    }
else
    local c = getgenv().__AURORAHUB_LEVIATHAN_CFG
    if c.ActiveTab == nil then c.ActiveTab = "Main" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    if type(c.CollectTypes) ~= "table" then c.CollectTypes = {} end
    if type(c.PurchaseStructures) ~= "table" then c.PurchaseStructures = {} end
    if type(c.CrateTypes) ~= "table" then c.CrateTypes = {} end
    if c.CollectDelay == nil then c.CollectDelay = "0.5s" end
    if c.PurchaseDelay == nil then c.PurchaseDelay = "1.0s" end
    if c.CrateDelay == nil then c.CrateDelay = "0.5s" end
    if c.SpeedValue == nil then c.SpeedValue = 28 end
    if c.AutoAntiAFK == nil then c.AutoAntiAFK = true end
    if c.AutoRewards == nil then c.AutoRewards = true end
end
local CFG = getgenv().__AURORAHUB_LEVIATHAN_CFG

---------- CFG SAVE/LOAD ----------
local _cfgFileName = "aurorahub_cfg_leviathan_military_base.json"

local function deepCopySets(src)
    local out = {}
    for k, v in pairs(src) do
        if type(v) == "table" then
            local t = {}
            for k2, v2 in pairs(v) do t[k2] = v2 end
            out[k] = t
        else
            out[k] = v
        end
    end
    return out
end

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AurorahubCFG_leviathan_military_base"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil then
                if type(CFG[k]) == "table" and type(v) == "table" then
                    -- restore set-table
                    CFG[k] = {}
                    for kk, vv in pairs(v) do CFG[k][kk] = vv end
                elseif type(CFG[k]) == type(v) then
                    CFG[k] = v
                end
            end
        end
    end
end

local function saveCFG()
    pcall(function()
        if _HAS.writefile then
            writefile(_cfgFileName, HttpService:JSONEncode(deepCopySets(CFG)))
        end
    end)
    getgenv()["AurorahubCFG_leviathan_military_base"] = CFG
end

loadSavedCFG()

---------- STATE ----------
local S = {
    collects = 0, purchases = 0, crates = 0, rewards = 0,
    exploitAttempts = 0, exploitHits = 0,
    currentPlotStructures = 0,
}
local _sessionStart = tick()

local DELAY_PRESETS = {"0.1s", "0.25s", "0.5s", "1.0s", "2.0s", "5.0s"}
local function parseDelay(s)
    local n = tonumber((s or ""):gsub("s", ""))
    return n or 0.5
end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- DYNAMIC ENUMERATION ----------
-- Purchasable structure names — read from PlotResources.Structures (canonical), fallback to known
local STATIC_STRUCTURES = {
    "Radar Complex","Storage Facility","Refinery","Light Tank Factory","Sentinel Listening Post",
    "Wind Turbine","Power Plant","Logistics Warehouse","Iron Mines","Steel Factory",
    "Hydroponics Facility","Oil Drill","Supply Depot","Solar Array","Advanced Solar Array",
    "Logistics Hub","Rally Center","Huey Helipad","Air Defense Compound","Crane",
    "Decorative Chinook",
}

local STRUCTURE_NAMES = {}
local function buildStructureList()
    local seen = {}
    local out = {}
    local templates = PlotRes and PlotRes:FindFirstChild("Structures")
    if templates then
        for _, m in ipairs(templates:GetChildren()) do
            if not seen[m.Name] then seen[m.Name] = true; table.insert(out, m.Name) end
        end
    end
    if #out == 0 then
        for _, n in ipairs(STATIC_STRUCTURES) do
            if not seen[n] then seen[n] = true; table.insert(out, n) end
        end
    end
    table.sort(out)
    STRUCTURE_NAMES = out
end
buildStructureList()

-- Crate types — read from LootCrateResources.Crates, fallback to known
local STATIC_CRATES = {"Standard", "Elite", "Decorative"}
local CRATE_NAMES = {}
local function buildCrateList()
    local seen = {}
    local out = {}
    local folder = CrateRes and CrateRes:FindFirstChild("Crates")
    if folder then
        for _, m in ipairs(folder:GetChildren()) do
            if not seen[m.Name] then seen[m.Name] = true; table.insert(out, m.Name) end
        end
    end
    if #out == 0 then
        for _, n in ipairs(STATIC_CRATES) do
            if not seen[n] then seen[n] = true; table.insert(out, n) end
        end
    end
    table.sort(out)
    CRATE_NAMES = out
end
buildCrateList()

---------- PLOT HELPERS ----------
local function getMyPlot()
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local p = plots:FindFirstChild(Player.Name .. "'s plot")
    if not p then
        for _, c in ipairs(plots:GetChildren()) do
            if c:GetAttribute("Owner") == Player.UserId then p = c; break end
        end
    end
    return p
end

local function getMyStructuresFolder()
    local plot = getMyPlot()
    if not plot then return nil end
    local base = plot:FindFirstChild("baseplate") or plot:FindFirstChild("Baseplate")
    if not base then return nil end
    return base:FindFirstChild("Structures")
end

local function getPlotOriginCFrame()
    local plot = getMyPlot()
    if not plot then return nil end
    local base = plot:FindFirstChild("baseplate") or plot:FindFirstChild("Baseplate")
    if not base then return nil end
    if base:IsA("BasePart") then return base.CFrame end
    local primary = base:IsA("Model") and base.PrimaryPart
    if primary then return primary.CFrame end
    for _, c in ipairs(base:GetChildren()) do
        if c:IsA("BasePart") then return c.CFrame end
    end
    return nil
end

---------- CORE FEATURE FUNCTIONS ----------
local function doCollectOnce()
    if not R.Collect then return end
    local folder = getMyStructuresFolder()
    if not folder then return end
    local structs = folder:GetChildren()
    S.currentPlotStructures = #structs
    local hasFilter = next(CFG.CollectTypes) ~= nil
    for _, m in ipairs(structs) do
        if not alive() or not CFG.AutoCollect then break end
        if (not hasFilter) or CFG.CollectTypes[m.Name] then
            pcall(function() R.Collect:FireServer(m) end)
            S.collects = S.collects + 1
            task.wait(0.02)
        end
    end
end

local _placeCursor = 0
local function doPurchaseOnce()
    if not R.PurchaseStructure then return end
    local anyFired = false
    for name, on in pairs(CFG.PurchaseStructures) do
        if not alive() or not CFG.AutoPurchase then break end
        if on then
            pcall(function() R.PurchaseStructure:FireServer(name) end)
            S.purchases = S.purchases + 1
            anyFired = true
            task.wait(0.05)

            -- Optional auto-place right after purchase
            if CFG.AutoPlaceAfterBuy and R.PlaceStructure then
                task.wait(0.1)
                local origin = getPlotOriginCFrame()
                if origin then
                    _placeCursor = (_placeCursor + 1) % 400
                    local col = _placeCursor % 20
                    local row = math.floor(_placeCursor / 20)
                    local offset = origin * CFrame.new(
                        (col - 10) * 8,
                        3.2,
                        (row - 10) * 8
                    )
                    pcall(function() R.PlaceStructure:FireServer(name, offset) end)
                end
            end
        end
    end
    return anyFired
end

local function doOpenCratesOnce()
    if not R.OpenLootCrate then return end
    if CFG.UseTenOpen and R.ToggleTenOpen then
        pcall(function() R.ToggleTenOpen:FireServer(true) end)
    end
    for name, on in pairs(CFG.CrateTypes) do
        if not alive() or not CFG.AutoOpenCrates then break end
        if on then
            pcall(function() R.OpenLootCrate:FireServer(name) end)
            S.crates = S.crates + 1
            task.wait(0.05)
        end
    end
end

local function doClaimRewards()
    if R.ClaimDaily then pcall(function() R.ClaimDaily:FireServer() end); S.rewards = S.rewards + 1 end
    if R.ClaimPlaytime then pcall(function() R.ClaimPlaytime:FireServer() end); S.rewards = S.rewards + 1 end
    if R.ClaimGroup then pcall(function() R.ClaimGroup:FireServer() end); S.rewards = S.rewards + 1 end
end

local function doSkipTutorial()
    if R.SkipTutorial then pcall(function() R.SkipTutorial:FireServer() end) end
end

local function doRebirth()
    if R.Rebirth then pcall(function() R.Rebirth:FireServer() end) end
end

---------- EXPLOIT PROBES ----------
local _expLog = {}
local function logExp(tag, detail)
    table.insert(_expLog, 1, os.date("%H:%M:%S") .. "  " .. tag .. "  " .. detail)
    while #_expLog > 60 do table.remove(_expLog) end
end

local ADMIN_CMDS = {
    "/help", "/admin", "/give money 999999", "/give cash 999999",
    "/add 999999", "/cash 999999", "/money 999999",
    "/set money 999999", "/god", "/speed 99", "/whoami",
}

local function expAdminProbe()
    if not R.RunCommand then logExp("admin", "remote missing"); return end
    for _, cmd in ipairs(ADMIN_CMDS) do
        if not CFG.ExploitMaster or not CFG.ExploitAdminProbe then break end
        pcall(function() R.RunCommand:FireServer(cmd) end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.2)
    end
    logExp("admin", "probed " .. #ADMIN_CMDS .. " cmds")
end

local function expCollectorOverride()
    if not R.UpdateCollectors then logExp("collectors", "remote missing"); return end
    -- Try a few arg shapes — server will reject unknown
    local shapes = {
        {999},
        {"set", 999},
        {{count = 999, rate = 999}},
        {Player, 999},
    }
    for _, args in ipairs(shapes) do
        if not CFG.ExploitMaster or not CFG.ExploitCollectorOverride then break end
        pcall(function() R.UpdateCollectors:FireServer(table.unpack(args)) end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.2)
    end
    logExp("collectors", "tried 4 shapes")
end

local function expUnitCapBoost()
    if not R.UpdateUnitCap then logExp("unitcap", "remote missing"); return end
    local shapes = { {999}, {{cap = 999}}, {"cap", 999} }
    for _, args in ipairs(shapes) do
        if not CFG.ExploitMaster or not CFG.ExploitUnitCapBoost then break end
        pcall(function() R.UpdateUnitCap:FireServer(table.unpack(args)) end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.2)
    end
    logExp("unitcap", "tried 3 shapes")
end

local function expModifierInjection()
    if not R.UpdateModifiers then logExp("modifiers", "remote missing"); return end
    local shapes = {
        {{CollectionMultiplier = 100}},
        {"CollectionMultiplier", 100},
        {"set", {CollectionMultiplier = 100}},
        {{Income = 100, Speed = 100}},
    }
    for _, args in ipairs(shapes) do
        if not CFG.ExploitMaster or not CFG.ExploitModifierInjection then break end
        pcall(function() R.UpdateModifiers:FireServer(table.unpack(args)) end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.2)
    end
    logExp("modifiers", "tried 4 shapes")
end

local function expRewardSpam()
    for _ = 1, 15 do
        if not CFG.ExploitMaster or not CFG.ExploitRewardSpam then break end
        if R.ClaimDaily    then pcall(function() R.ClaimDaily:FireServer() end)    end
        if R.ClaimPlaytime then pcall(function() R.ClaimPlaytime:FireServer() end) end
        if R.ClaimGroup    then pcall(function() R.ClaimGroup:FireServer() end)    end
        S.exploitAttempts = S.exploitAttempts + 3
        task.wait(0.3)
    end
    logExp("reward-spam", "fired 15 rounds")
end

local function expFreeRebirth()
    if not R.Rebirth then logExp("rebirth", "remote missing"); return end
    for _ = 1, 3 do
        if not CFG.ExploitMaster or not CFG.ExploitFreeRebirth then break end
        pcall(function() R.Rebirth:FireServer() end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.4)
    end
    logExp("rebirth", "fired 3x")
end

local function expFreeReroll()
    if not R.RerollTraits then logExp("reroll", "remote missing"); return end
    for _ = 1, 10 do
        if not CFG.ExploitMaster or not CFG.ExploitFreeReroll then break end
        pcall(function() R.RerollTraits:FireServer() end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.3)
    end
    logExp("reroll", "fired 10x")
end

local function expPlaceFree()
    if not R.PlaceStructure then logExp("place-free", "remote missing"); return end
    local origin = getPlotOriginCFrame()
    if not origin then logExp("place-free", "no plot origin"); return end
    -- Try placing each known structure without purchasing first
    for i, name in ipairs(STRUCTURE_NAMES) do
        if not CFG.ExploitMaster or not CFG.ExploitPlaceFree then break end
        local offset = origin * CFrame.new(i * 4 - 40, 3.2, 40)
        pcall(function() R.PlaceStructure:FireServer(name, offset) end)
        S.exploitAttempts = S.exploitAttempts + 1
        task.wait(0.1)
        if i >= 5 then break end  -- sample only
    end
    logExp("place-free", "tried 5 structures")
end

local function expDismantleDupe()
    if not R.PurchaseStructure or not R.DismantleRebirth then logExp("dupe", "remotes missing"); return end
    -- Buy → dismantle loop on cheapest known
    local testName = STRUCTURE_NAMES[1] or "Storage Facility"
    for _ = 1, 5 do
        if not CFG.ExploitMaster or not CFG.ExploitDismantleDupe then break end
        pcall(function() R.PurchaseStructure:FireServer(testName) end)
        task.wait(0.15)
        pcall(function() R.DismantleRebirth:FireServer(testName) end)
        S.exploitAttempts = S.exploitAttempts + 2
        task.wait(0.3)
    end
    logExp("dupe", "tried 5 purchase+dismantle cycles on " .. testName)
end

---------- GAME LOOPS ----------
task.spawn(function()
    while alive() do
        if CFG.AutoCollect then pcall(doCollectOnce) end
        task.wait(jitter(parseDelay(CFG.CollectDelay), 0.1))
        if not alive() then break end
    end
end)

task.spawn(function()
    while alive() do
        if CFG.AutoPurchase then pcall(doPurchaseOnce) end
        task.wait(jitter(parseDelay(CFG.PurchaseDelay), 0.2))
        if not alive() then break end
    end
end)

task.spawn(function()
    while alive() do
        if CFG.AutoOpenCrates then pcall(doOpenCratesOnce) end
        task.wait(jitter(parseDelay(CFG.CrateDelay), 0.1))
        if not alive() then break end
    end
end)

-- Passive rewards — every 60s
task.spawn(function()
    while alive() do
        if CFG.AutoRewards then pcall(doClaimRewards) end
        task.wait(jitter(60, 10))
        if not alive() then break end
    end
end)

-- Anti-AFK
task.spawn(function()
    while alive() do
        if CFG.AutoAntiAFK then
            pcall(function()
                local vim = game:GetService("VirtualInputManager")
                vim:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
                task.wait(0.1)
                vim:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
            end)
        end
        task.wait(120)
        if not alive() then break end
    end
end)

-- Auto speed
task.spawn(function()
    while alive() do
        if CFG.AutoSpeed then
            pcall(function()
                local char = Player.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then hum.WalkSpeed = CFG.SpeedValue or 28 end
                end
            end)
        end
        task.wait(0.5)
        if not alive() then break end
    end
end)

-- Inf jump
UIS.JumpRequest:Connect(function()
    if alive() and CFG.AutoInfJump then
        pcall(function()
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
            end
        end)
    end
end)

-- Exploit probe loops — only run if master gate + individual toggle both ON
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitAdminProbe then pcall(expAdminProbe) end
        task.wait(jitter(10, 3))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitCollectorOverride then pcall(expCollectorOverride) end
        task.wait(jitter(8, 3))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitUnitCapBoost then pcall(expUnitCapBoost) end
        task.wait(jitter(8, 3))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitModifierInjection then pcall(expModifierInjection) end
        task.wait(jitter(10, 3))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitRewardSpam then pcall(expRewardSpam) end
        task.wait(jitter(30, 8))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitFreeRebirth then pcall(expFreeRebirth) end
        task.wait(jitter(30, 8))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitFreeReroll then pcall(expFreeReroll) end
        task.wait(jitter(15, 5))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitPlaceFree then pcall(expPlaceFree) end
        task.wait(jitter(20, 5))
        if not alive() then break end
    end
end)
task.spawn(function()
    while alive() do
        if CFG.ExploitMaster and CFG.ExploitDismantleDupe then pcall(expDismantleDupe) end
        task.wait(jitter(10, 3))
        if not alive() then break end
    end
end)

-- Claim rewards on load (once)
task.spawn(function()
    task.wait(2)
    if alive() then pcall(doClaimRewards) end
end)

-- ========================================================================
-- V5 3-COLUMN UI
-- ========================================================================
local U = {}

local C = {
    bg       = Color3.fromRGB(8,   8,  15),
    bg2      = Color3.fromRGB(12, 12,  24),
    bg3      = Color3.fromRGB(19, 19,  42),
    panel    = Color3.fromRGB(12, 12,  24),
    border   = Color3.fromRGB(22, 22,  42),
    border2  = Color3.fromRGB(42, 42,  68),
    text     = Color3.fromRGB(245,245, 250),
    text2    = Color3.fromRGB(160,160, 180),
    text3    = Color3.fromRGB(98,  98, 122),
    pink     = Color3.fromRGB(252,110, 142),
    purple   = Color3.fromRGB(192,132, 252),
    green    = Color3.fromRGB(0,  200, 100),
    red      = Color3.fromRGB(255,80,  80),
    white    = Color3.fromRGB(255,255, 255),
}
local F_SANS      = Enum.Font.Gotham
local F_SANS_SEMI = Enum.Font.GothamMedium
local F_SANS_BOLD = Enum.Font.GothamBold
local F_MONO      = Enum.Font.Code

local function create(cls, props, parent)
    local i = Instance.new(cls)
    if props then for k, v in pairs(props) do i[k] = v end end
    if parent then i.Parent = parent end
    return i
end
local function corner(p, r)
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c
end
local function stroke(p, col, th, tr)
    local s = Instance.new("UIStroke")
    s.Color = col or C.border; s.Thickness = th or 1; s.Transparency = tr or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
end
local function grad(p, c1, c2, rot)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, c1),
        ColorSequenceKeypoint.new(1, c2),
    })
    g.Rotation = rot or 0; g.Parent = p; return g
end
local function padAll(p, v)
    local pp = Instance.new("UIPadding")
    pp.PaddingTop = UDim.new(0, v); pp.PaddingBottom = UDim.new(0, v)
    pp.PaddingLeft = UDim.new(0, v); pp.PaddingRight = UDim.new(0, v); pp.Parent = p; return pp
end

local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

-- LAYOUT
local TOTAL_W   = 1080
local TOTAL_H   = 620
local SIDEBAR_W = 168
local PA_W      = 350
local PB_W      = 350
local LG_W      = TOTAL_W - SIDEBAR_W - PA_W - PB_W  -- 212

local screenGui = create("ScreenGui", {
    Name = "Aurora", DisplayOrder = 9999, ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
local _pOk = false
if _HAS.gethui then _pOk = pcall(function() screenGui.Parent = gethui() end) end
if not _pOk then _pOk = pcall(function() screenGui.Parent = game:GetService("CoreGui") end) end
if not _pOk then pcall(function() screenGui.Parent = Player:WaitForChild("PlayerGui") end) end

local _vp     = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _mobile = UIS.TouchEnabled and (_vp.X < 1200)
local _scale  = _mobile and math.clamp(_vp.X / 1200, 0.5, 0.85) or 1

local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundColor3 = C.bg, BorderSizePixel = 0,
    ClipsDescendants = true, Visible = CFG.PanelOpen,
}, screenGui)
corner(main, 14)
stroke(main, C.border2, 1, 0)
if _scale ~= 1 then
    local sc = Instance.new("UIScale"); sc.Scale = _scale; sc.Parent = main
end

-- Watermark
local watermark = create("TextLabel", {
    Name = "Watermark",
    Size = UDim2.fromOffset(800, 120),
    Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Font = F_SANS_BOLD, TextSize = 72,
    TextColor3 = C.pink,
    TextTransparency = 0.82, TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 1,
}, main)
watermark.RichText = true
watermark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

local content = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2,
}, main)

-- Sidebar
local sidebar = create("Frame", {
    Name = "Sidebar", Size = UDim2.fromOffset(SIDEBAR_W, TOTAL_H),
    BackgroundColor3 = C.bg2, BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true,
}, content)
create("Frame", {
    Size = UDim2.fromOffset(1, TOTAL_H), Position = UDim2.fromOffset(SIDEBAR_W - 1, 0),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, content)

local wordmarkRow = create("Frame", {
    Name = "Wordmark", Size = UDim2.fromOffset(SIDEBAR_W, 54),
    BackgroundTransparency = 1, Active = true,
}, sidebar)
create("ImageLabel", {
    Name = "Logo", Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(14, 15),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit, ImageColor3 = C.white,
}, wordmarkRow)
local wordmark = create("TextLabel", {
    Size = UDim2.fromOffset(SIDEBAR_W - 44, 24), Position = UDim2.fromOffset(42, 15),
    BackgroundTransparency = 1, Font = F_SANS_BOLD, TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    TextColor3 = C.text,
}, wordmarkRow)
wordmark.RichText = true
wordmark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, 54),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)

-- TABS
local TABS = {
    { name = "Main",     icon = "●" },
    { name = "Vendor",   icon = "▣" },
    { name = "Crates",   icon = "◆" },
    { name = "Exploits", icon = "⚠" },
    { name = "Misc",     icon = "≡" },
}

local tabMap = {}
local function paintTabs()
    for name, t in pairs(tabMap) do
        local on     = (CFG.ActiveTab == name)
        local offCol = t.dimInactive and C.text3 or C.text2
        t.accent.Visible            = on
        t.bg.BackgroundTransparency = on and 0.85 or 1
        t.label.TextColor3          = on and C.text or offCol
        t.label.Font                = on and F_SANS_SEMI or F_SANS
        t.icon.TextColor3           = on and C.pink or C.text3
    end
end

local TAB_Y0  = 66
local TAB_H   = 34
local TAB_GAP = 3
local function makeTabRow(tinfo, yPos, dimInactive)
    local row = create("Frame", {
        Name = "Tab_" .. tinfo.name, Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H),
        Position = UDim2.fromOffset(10, yPos),
        BackgroundColor3 = C.pink, BackgroundTransparency = 1,
        BorderSizePixel = 0, Active = true,
    }, sidebar)
    corner(row, 6)
    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.pink),
        ColorSequenceKeypoint.new(1, C.bg2),
    })
    bgGrad.Rotation = 0; bgGrad.Parent = row

    local accent = create("Frame", {
        Size = UDim2.fromOffset(2, TAB_H - 14), Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = C.pink, BorderSizePixel = 0, Visible = false,
    }, row)
    corner(accent, 1)
    local icon = create("TextLabel", {
        Size = UDim2.fromOffset(18, TAB_H), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = tinfo.icon,
        Font = F_SANS_BOLD, TextSize = 12, TextColor3 = C.text3,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, row)
    local label = create("TextLabel", {
        Size = UDim2.fromOffset(SIDEBAR_W - 64, TAB_H), Position = UDim2.fromOffset(36, 0),
        BackgroundTransparency = 1, Text = tinfo.name,
        Font = F_SANS, TextSize = 12, TextColor3 = C.text2,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    tabMap[tinfo.name] = {
        bg = row, accent = accent, icon = icon, label = label, dimInactive = dimInactive or false,
    }
    return row
end

local switchTab        = function(_) end
local _openPopup       = nil
local _skipNextOutside = false
local closeOpenPopup   = function() end

for idx, tinfo in ipairs(TABS) do
    local y = TAB_Y0 + (idx - 1) * (TAB_H + TAB_GAP)
    local row = makeTabRow(tinfo, y, false)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            switchTab(tinfo.name)
        end
    end)
end

local SET_H    = 36
local SET_PAD  = 10
local SET_Y    = TOTAL_H - SET_H - SET_PAD
create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, SET_Y - 6),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)
local setRow = makeTabRow({ name = "Settings", icon = "⚙" }, SET_Y, true)
setRow.Size = UDim2.fromOffset(SIDEBAR_W - 20, SET_H)
setRow.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        switchTab("Settings")
    end
end)

-- PANEL FACTORY
local panels = {}
local liveScroll

local function makePanel(tabName, which, xPos, width, accent, title)
    local p = create("Frame", {
        Name = tabName .. "_" .. which, Size = UDim2.fromOffset(width, TOTAL_H),
        Position = UDim2.fromOffset(xPos, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
        Visible = (tabName == CFG.ActiveTab),
    }, content)
    if xPos > SIDEBAR_W then
        create("Frame", {
            Size = UDim2.fromOffset(1, TOTAL_H),
            BackgroundColor3 = C.border, BorderSizePixel = 0,
        }, p)
    end
    create("TextLabel", {
        Size = UDim2.fromOffset(width - 32, 36), Position = UDim2.fromOffset(16, 14),
        BackgroundTransparency = 1, Text = title,
        Font = F_MONO, TextSize = 10, TextColor3 = accent,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, p)
    create("Frame", {
        Size = UDim2.fromOffset(width, 1), Position = UDim2.fromOffset(0, 48),
        BackgroundColor3 = C.border, BorderSizePixel = 0,
    }, p)
    local scroll = create("ScrollingFrame", {
        Size = UDim2.fromOffset(width, TOTAL_H - 50), Position = UDim2.fromOffset(0, 50),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = accent,
        CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
    }, p)
    padAll(scroll, 14)
    local list = Instance.new("UIListLayout")
    list.Padding = UDim.new(0, 2); list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = scroll
    panels[tabName] = panels[tabName] or {}
    panels[tabName][which] = { frame = p, scroll = scroll }
    return scroll
end

local TAB_NAMES = { "Main", "Vendor", "Crates", "Exploits", "Misc", "Settings" }
local TAB_ACCENT = {
    Main     = C.pink,
    Vendor   = C.purple,
    Crates   = C.pink,
    Exploits = C.red,
    Misc     = C.purple,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Main     = { alpha = "COLLECT",    beta = "FARM STATUS" },
    Vendor   = { alpha = "PURCHASE",   beta = "VENDOR INFO"  },
    Crates   = { alpha = "LOOT CRATES", beta = "CRATE STATS"  },
    Exploits = { alpha = "EXPLOIT PROBES", beta = "PROBE LOG" },
    Misc     = { alpha = "UTILITY",    beta = "MANUAL"        },
    Settings = { alpha = "CONFIG",     beta = "ABOUT"         },
}

local scrolls = {}
for _, tn in ipairs(TAB_NAMES) do
    local acc = TAB_ACCENT[tn]
    local t   = PANEL_TITLES[tn]
    scrolls[tn .. "_alpha"] = makePanel(tn, "alpha", SIDEBAR_W,        PA_W, acc, t.alpha)
    scrolls[tn .. "_beta"]  = makePanel(tn, "beta",  SIDEBAR_W + PA_W, PB_W, acc, t.beta)
end

-- LIVE GAME panel
local liveFrame = create("Frame", {
    Name = "LiveGame", Size = UDim2.fromOffset(LG_W, TOTAL_H),
    Position = UDim2.fromOffset(SIDEBAR_W + PA_W + PB_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
}, content)
create("Frame", {
    Size = UDim2.fromOffset(1, TOTAL_H),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, liveFrame)
create("TextLabel", {
    Size = UDim2.fromOffset(LG_W - 32, 36), Position = UDim2.fromOffset(16, 14),
    BackgroundTransparency = 1, Text = "LIVE GAME",
    Font = F_MONO, TextSize = 10, TextColor3 = C.pink,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
}, liveFrame)
create("Frame", {
    Size = UDim2.fromOffset(LG_W, 1), Position = UDim2.fromOffset(0, 48),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, liveFrame)
liveScroll = create("ScrollingFrame", {
    Size = UDim2.fromOffset(LG_W, TOTAL_H - 50), Position = UDim2.fromOffset(0, 50),
    BackgroundTransparency = 1, BorderSizePixel = 0,
    ScrollBarThickness = 2, ScrollBarImageColor3 = C.pink,
    CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, liveFrame)
padAll(liveScroll, 14)
local _liveList = Instance.new("UIListLayout")
_liveList.Padding = UDim.new(0, 2); _liveList.SortOrder = Enum.SortOrder.LayoutOrder
_liveList.Parent = liveScroll

-- TAB SWITCHER
switchTab = function(tabName)
    if not panels[tabName] then tabName = "Main" end
    CFG.ActiveTab = tabName
    paintTabs()
    for _, tn in ipairs(TAB_NAMES) do
        local pair = panels[tn]
        if pair then
            if pair.alpha then pair.alpha.frame.Visible = (tn == tabName) end
            if pair.beta  then pair.beta.frame.Visible  = (tn == tabName) end
        end
    end
    closeOpenPopup()
    if CFG.AutoSave then saveCFG() end
end

-- COMPONENTS
local function sectionHeader(parent, icon, label, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order,
    }, parent)
    create("Frame", {
        Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 35),
        BackgroundColor3 = C.border, BorderSizePixel = 0,
    }, row)
    local bar = create("Frame", {
        Size = UDim2.fromOffset(3, 12), Position = UDim2.fromOffset(0, 14),
        BackgroundColor3 = C.white, BorderSizePixel = 0,
    }, row)
    corner(bar, 1); grad(bar, C.pink, C.purple, 90)
    create("TextLabel", {
        Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1, Text = icon .. "  " .. label,
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
    }, row)
    return row
end

local function toggleRow(parent, label, cfgKey, order, cb)
    if CFG[cfgKey] == nil then CFG[cfgKey] = false end
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local track = create("Frame", {
        Size = UDim2.fromOffset(36, 20), Position = UDim2.new(1, -36, 0.5, -10),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(track, 10)
    local trackStroke = stroke(track, C.border2, 1, 0)
    local trackGrad = Instance.new("UIGradient")
    trackGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, C.pink), ColorSequenceKeypoint.new(1, C.purple),
    })
    trackGrad.Rotation = 0; trackGrad.Enabled = false; trackGrad.Parent = track
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.fromOffset(3, 3),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
    }, track)
    corner(knob, 7)
    local function paint()
        local on = CFG[cfgKey] == true
        if on then
            track.BackgroundColor3 = C.white
            trackGrad.Enabled = true; trackStroke.Transparency = 1
        else
            track.BackgroundColor3 = C.bg3
            trackGrad.Enabled = false; trackStroke.Transparency = 0
        end
        TweenService:Create(knob, TweenInfo.new(0.15),
            { Position = UDim2.fromOffset(on and 19 or 3, 3) }):Play()
    end
    paint()
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            CFG[cfgKey] = not CFG[cfgKey]; paint()
            if CFG.AutoSave then saveCFG() end
            if cb then cb(CFG[cfgKey]) end
        end
    end)
    return row, paint
end

closeOpenPopup = function()
    if _openPopup and _openPopup.frame then
        _openPopup.frame.Visible = false
        if _openPopup.onClose then _openPopup.onClose() end
    end
    _openPopup = nil
end

local function actionBtn(parent, label, color, order, cb)
    local btn = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color or C.bg3,
        BorderSizePixel = 0, LayoutOrder = order, Active = true,
    }, parent)
    corner(btn, 6); stroke(btn, C.border2, 1, 0)
    local lbl = create("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Center,
    }, btn)
    btn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            if cb then pcall(cb) end
            local orig = lbl.Text; lbl.Text = label .. " ..."
            lbl.TextColor3 = C.green
            task.delay(1.2, function()
                if lbl.Parent then lbl.Text = orig; lbl.TextColor3 = C.text end
            end)
        end
    end)
    return btn
end

local function infoRow(parent, label, initialVal, valColor, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order,
    }, parent)
    create("TextLabel", {
        Size = UDim2.fromScale(0.55, 1), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local val = create("TextLabel", {
        Size = UDim2.fromScale(0.45, 1), Position = UDim2.fromScale(0.55, 0),
        BackgroundTransparency = 1, Text = tostring(initialVal or "—"),
        Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text2,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    return val
end

-- Multi-select dropdown (popup lives at screenGui root)
local function dropdownRow(parent, label, cfgKey, options, order, multi)
    if multi then
        if type(CFG[cfgKey]) ~= "table" then CFG[cfgKey] = {} end
    else
        if CFG[cfgKey] == nil then CFG[cfgKey] = options[1] end
    end

    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -100, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = create("Frame", {
        Size = UDim2.fromOffset(92, 22), Position = UDim2.new(1, -92, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)

    local function displayText()
        if multi then
            local count, firstKey = 0, nil
            for k in pairs(CFG[cfgKey]) do
                count = count + 1
                if not firstKey then firstKey = k end
            end
            if count == 0 then return "All" end
            if count == 1 then return tostring(firstKey) end
            return count .. " selected"
        else
            return tostring(CFG[cfgKey] or "—")
        end
    end

    local valLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = displayText(),
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    local arrow = create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▼",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)

    local POPUP_W = 180
    local OPT_H   = 26
    local POPUP_H = math.min(300, #options * (OPT_H + 2) + 8)

    local popup = create("Frame", {
        Name = "DropdownPopup_" .. cfgKey,
        Size = UDim2.fromOffset(POPUP_W, POPUP_H),
        BackgroundColor3 = C.bg, BorderSizePixel = 0,
        Visible = false, ZIndex = 50,
    }, screenGui)
    corner(popup, 8); stroke(popup, C.border2, 1, 0)

    local popScroll = create("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 2, ScrollBarImageColor3 = C.pink,
        CanvasSize = UDim2.fromOffset(0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ZIndex = 51,
    }, popup)
    padAll(popScroll, 4)
    local popList = Instance.new("UIListLayout")
    popList.Padding = UDim.new(0, 2); popList.SortOrder = Enum.SortOrder.LayoutOrder
    popList.Parent = popScroll

    local optBtns = {}
    local function isSelected(opt)
        if multi then return CFG[cfgKey][opt] == true end
        return CFG[cfgKey] == opt
    end

    for i, opt in ipairs(options) do
        local btn = create("Frame", {
            Name = "Opt_" .. tostring(opt),
            Size = UDim2.new(1, 0, 0, OPT_H),
            BackgroundColor3 = C.bg3, BackgroundTransparency = 1,
            BorderSizePixel = 0, Active = true,
            LayoutOrder = i, ZIndex = 52,
        }, popScroll)
        corner(btn, 4)
        local check = create("Frame", {
            Size = UDim2.fromOffset(12, 12),
            Position = UDim2.new(0, 6, 0.5, -6),
            BackgroundColor3 = C.bg3, BorderSizePixel = 0, ZIndex = 53,
        }, btn)
        corner(check, multi and 2 or 6)
        stroke(check, C.border2, 1, 0)
        local fill = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = C.pink, BorderSizePixel = 0,
            Visible = false, ZIndex = 54,
        }, check)
        corner(fill, multi and 2 or 6)
        create("TextLabel", {
            Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0),
            BackgroundTransparency = 1, Text = tostring(opt),
            Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, btn)
        optBtns[i] = { frame = btn, fill = fill, opt = opt }
    end

    local function paintOpts()
        for _, o in ipairs(optBtns) do
            local sel = isSelected(o.opt)
            o.fill.Visible = sel
            o.frame.BackgroundTransparency = sel and 0.85 or 1
        end
    end
    paintOpts()

    for _, o in ipairs(optBtns) do
        o.frame.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                if multi then
                    if CFG[cfgKey][o.opt] then CFG[cfgKey][o.opt] = nil
                    else CFG[cfgKey][o.opt] = true end
                else
                    CFG[cfgKey] = o.opt
                end
                paintOpts()
                valLabel.Text = displayText()
                if CFG.AutoSave then saveCFG() end
                if not multi then closeOpenPopup() end
            end
        end)
    end

    local function openPopup()
        if _openPopup and _openPopup.frame ~= popup then closeOpenPopup() end
        local pp = pill.AbsolutePosition
        local ps = pill.AbsoluteSize
        popup.Position = UDim2.fromOffset(
            pp.X + ps.X - POPUP_W,
            pp.Y + ps.Y + 4
        )
        popup.Visible = true
        arrow.Text = "▲"
        paintOpts()
        _openPopup = {
            frame = popup,
            onClose = function() arrow.Text = "▼"; valLabel.Text = displayText() end,
        }
        _skipNextOutside = true
    end

    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            if _openPopup and _openPopup.frame == popup then
                closeOpenPopup()
            else
                openPopup()
            end
        end
    end)
    return row, valLabel
end

-- Cycle row (for delay presets / speed preset)
local function cycleRow(parent, label, cfgKey, options, order, onChange)
    if CFG[cfgKey] == nil then CFG[cfgKey] = options[1] end
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.55, 0, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(92, 22), Position = UDim2.new(1, -92, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local vLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = tostring(CFG[cfgKey]),
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▶",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)
    local idx = 1
    for i, v in ipairs(options) do if v == CFG[cfgKey] then idx = i; break end end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            idx = (idx % #options) + 1
            CFG[cfgKey] = options[idx]
            vLabel.Text = tostring(CFG[cfgKey])
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, vLabel
end

--========================================================================
-- POPULATE: MAIN (Auto Collect)
--========================================================================
local oM_a, oM_b = 0, 0
local function nMa() oM_a = oM_a + 1; return oM_a end
local function nMb() oM_b = oM_b + 1; return oM_b end

sectionHeader(scrolls["Main_alpha"], "●", "Auto Collect", nMa())
toggleRow    (scrolls["Main_alpha"], "Auto Collect",         "AutoCollect", nMa())
dropdownRow  (scrolls["Main_alpha"], "Collect Types",        "CollectTypes", STRUCTURE_NAMES, nMa(), true)
cycleRow     (scrolls["Main_alpha"], "Delay",                "CollectDelay", DELAY_PRESETS, nMa())

sectionHeader(scrolls["Main_alpha"], "▣", "Manual", nMa())
actionBtn(scrolls["Main_alpha"], "Collect All Now", C.bg3, nMa(), function()
    local prev = CFG.AutoCollect
    CFG.AutoCollect = true
    pcall(doCollectOnce)
    CFG.AutoCollect = prev
end)
actionBtn(scrolls["Main_alpha"], "Claim All Rewards", C.green, nMa(), doClaimRewards)
actionBtn(scrolls["Main_alpha"], "Skip Tutorial", C.bg3, nMa(), doSkipTutorial)

sectionHeader(scrolls["Main_alpha"], "✦", "Notes", nMa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Auto Collect iterates every\nbuilt structure on your plot\nand fires Collect(instance).\n\nEmpty Types = all structures.\nSelect types to limit.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nMa(),
}, scrolls["Main_alpha"])

sectionHeader(scrolls["Main_beta"], "●", "Status", nMb())
U.infoMode = infoRow(scrolls["Main_beta"], "Mode",     "Idle", C.pink,  nMb())
U.infoRuntime = infoRow(scrolls["Main_beta"], "Runtime",  "0m",   C.text2, nMb())
U.infoStructs = infoRow(scrolls["Main_beta"], "Structures On Plot", "—", C.text, nMb())

sectionHeader(scrolls["Main_beta"], "◉", "Session Totals", nMb())
U.infoCollects = infoRow(scrolls["Main_beta"], "Collects",  "0", C.pink, nMb())
U.infoPurch = infoRow(scrolls["Main_beta"], "Purchases", "0", C.pink, nMb())
U.infoCrates = infoRow(scrolls["Main_beta"], "Crates",    "0", C.pink, nMb())
U.infoRewards = infoRow(scrolls["Main_beta"], "Rewards",   "0", C.purple, nMb())

sectionHeader(scrolls["Main_beta"], "✦", "Remote Health", nMb())
infoRow(scrolls["Main_beta"], "Collect",          R.Collect          and "OK" or "MISSING", R.Collect          and C.green or C.red, nMb())
infoRow(scrolls["Main_beta"], "PurchaseStructure",R.PurchaseStructure and "OK" or "MISSING", R.PurchaseStructure and C.green or C.red, nMb())
infoRow(scrolls["Main_beta"], "PlaceStructure",   R.PlaceStructure   and "OK" or "MISSING", R.PlaceStructure   and C.green or C.red, nMb())
infoRow(scrolls["Main_beta"], "OpenLootCrate",    R.OpenLootCrate    and "OK" or "MISSING", R.OpenLootCrate    and C.green or C.red, nMb())
infoRow(scrolls["Main_beta"], "ToggleTenOpen",    R.ToggleTenOpen    and "OK" or "MISSING", R.ToggleTenOpen    and C.green or C.red, nMb())

--========================================================================
-- POPULATE: VENDOR
--========================================================================
local oV_a, oV_b = 0, 0
local function nVa() oV_a = oV_a + 1; return oV_a end
local function nVb() oV_b = oV_b + 1; return oV_b end

sectionHeader(scrolls["Vendor_alpha"], "●", "Auto Purchase", nVa())
toggleRow    (scrolls["Vendor_alpha"], "Auto Purchase",          "AutoPurchase",       nVa())
dropdownRow  (scrolls["Vendor_alpha"], "Structures",             "PurchaseStructures", STRUCTURE_NAMES, nVa(), true)
toggleRow    (scrolls["Vendor_alpha"], "Auto Place After Buy",   "AutoPlaceAfterBuy",  nVa())
cycleRow     (scrolls["Vendor_alpha"], "Delay",                  "PurchaseDelay",      DELAY_PRESETS, nVa())

sectionHeader(scrolls["Vendor_alpha"], "▣", "Manual", nVa())
actionBtn(scrolls["Vendor_alpha"], "Purchase Once Now", C.bg3, nVa(), function()
    local prev = CFG.AutoPurchase
    CFG.AutoPurchase = true
    pcall(doPurchaseOnce)
    CFG.AutoPurchase = prev
end)
actionBtn(scrolls["Vendor_alpha"], "Rebirth (confirm)", C.red, nVa(), doRebirth)

sectionHeader(scrolls["Vendor_alpha"], "✦", "Notes", nVa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 130), BackgroundTransparency = 1,
    Text = "Auto Purchase fires\nPurchaseStructure(name) for each\nselected structure every cycle.\n\nServer rejects silently when\nyou're out of currency — safe.\n\nAuto Place tries placing on a\ngrid around your baseplate.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nVa(),
}, scrolls["Vendor_alpha"])

sectionHeader(scrolls["Vendor_beta"], "●", "Vendor", nVb())
infoRow(scrolls["Vendor_beta"], "Structure Count", tostring(#STRUCTURE_NAMES), C.text, nVb())
U.infoSelected = infoRow(scrolls["Vendor_beta"], "Selected", "0", C.pink, nVb())

sectionHeader(scrolls["Vendor_beta"], "◉", "Known Structures", nVb())
for i, name in ipairs(STRUCTURE_NAMES) do
    if i > 25 then break end
    infoRow(scrolls["Vendor_beta"], name, "—", C.text3, nVb())
end

--========================================================================
-- POPULATE: CRATES
--========================================================================
local oC_a, oC_b = 0, 0
local function nCa() oC_a = oC_a + 1; return oC_a end
local function nCb() oC_b = oC_b + 1; return oC_b end

sectionHeader(scrolls["Crates_alpha"], "●", "Auto Open Crates", nCa())
toggleRow    (scrolls["Crates_alpha"], "Auto Open Crates", "AutoOpenCrates", nCa())
dropdownRow  (scrolls["Crates_alpha"], "Crate Types",      "CrateTypes", CRATE_NAMES, nCa(), true)
toggleRow    (scrolls["Crates_alpha"], "Use 10x Toggle",   "UseTenOpen",  nCa())
cycleRow     (scrolls["Crates_alpha"], "Delay",            "CrateDelay",  DELAY_PRESETS, nCa())

sectionHeader(scrolls["Crates_alpha"], "▣", "Manual", nCa())
actionBtn(scrolls["Crates_alpha"], "Open Once Now", C.bg3, nCa(), function()
    local prev = CFG.AutoOpenCrates
    CFG.AutoOpenCrates = true
    pcall(doOpenCratesOnce)
    CFG.AutoOpenCrates = prev
end)
for _, crateName in ipairs(CRATE_NAMES) do
    actionBtn(scrolls["Crates_alpha"], "Open " .. crateName, C.bg3, nCa(), function()
        if R.OpenLootCrate then pcall(function() R.OpenLootCrate:FireServer(crateName) end); S.crates = S.crates + 1 end
    end)
end

sectionHeader(scrolls["Crates_alpha"], "✦", "Notes", nCa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Auto Open fires OpenLootCrate\nfor each selected crate type.\n\n10x Toggle fires ToggleTenOpen\nbefore — may or may not bulk\nopen (experimental).",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nCa(),
}, scrolls["Crates_alpha"])

sectionHeader(scrolls["Crates_beta"], "●", "Session", nCb())
U.infoCratesTotal = infoRow(scrolls["Crates_beta"], "Crates Opened",   "0", C.pink,   nCb())
U.infoCratesRate = infoRow(scrolls["Crates_beta"], "Rate /min",       "—", C.text2,  nCb())

sectionHeader(scrolls["Crates_beta"], "◉", "Types Detected", nCb())
infoRow(scrolls["Crates_beta"], "Types Count", tostring(#CRATE_NAMES), C.text, nCb())
for _, cn in ipairs(CRATE_NAMES) do
    infoRow(scrolls["Crates_beta"], cn, "—", C.text3, nCb())
end

--========================================================================
-- POPULATE: EXPLOITS (master-gated)
--========================================================================
local oE_a, oE_b = 0, 0
local function nEa() oE_a = oE_a + 1; return oE_a end
local function nEb() oE_b = oE_b + 1; return oE_b end

create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1,
    Text = "⚠ Experimental server probes.\nMay kick or ban. Enable master\ngate below to arm.",
    Font = F_SANS_BOLD, TextSize = 11, TextColor3 = C.red,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nEa(),
}, scrolls["Exploits_alpha"])

sectionHeader(scrolls["Exploits_alpha"], "⚠", "Master Gate", nEa())
toggleRow    (scrolls["Exploits_alpha"], "ARM — I accept risk",   "ExploitMaster",           nEa())

sectionHeader(scrolls["Exploits_alpha"], "●", "Probes", nEa())
toggleRow    (scrolls["Exploits_alpha"], "Admin Command Probe",   "ExploitAdminProbe",       nEa())
toggleRow    (scrolls["Exploits_alpha"], "Collector Override",    "ExploitCollectorOverride",nEa())
toggleRow    (scrolls["Exploits_alpha"], "Unit Cap Boost",        "ExploitUnitCapBoost",     nEa())
toggleRow    (scrolls["Exploits_alpha"], "Modifier Injection",    "ExploitModifierInjection",nEa())
toggleRow    (scrolls["Exploits_alpha"], "Reward Spam",           "ExploitRewardSpam",       nEa())
toggleRow    (scrolls["Exploits_alpha"], "Free Rebirth",          "ExploitFreeRebirth",      nEa())
toggleRow    (scrolls["Exploits_alpha"], "Free Reroll Traits",    "ExploitFreeReroll",       nEa())
toggleRow    (scrolls["Exploits_alpha"], "Place Without Purchase","ExploitPlaceFree",        nEa())
toggleRow    (scrolls["Exploits_alpha"], "Dismantle Dupe Test",   "ExploitDismantleDupe",    nEa())

sectionHeader(scrolls["Exploits_alpha"], "▣", "One-Shot Manual", nEa())
actionBtn(scrolls["Exploits_alpha"], "Fire /help (admin)", C.bg3, nEa(), function()
    if R.RunCommand then pcall(function() R.RunCommand:FireServer("/help") end); logExp("manual", "/help") end
end)
actionBtn(scrolls["Exploits_alpha"], "Fire Rebirth once", C.bg3, nEa(), function()
    if R.Rebirth then pcall(function() R.Rebirth:FireServer() end); logExp("manual", "Rebirth") end
end)
actionBtn(scrolls["Exploits_alpha"], "Fire RerollTraits once", C.bg3, nEa(), function()
    if R.RerollTraits then pcall(function() R.RerollTraits:FireServer() end); logExp("manual", "RerollTraits") end
end)

sectionHeader(scrolls["Exploits_beta"], "●", "Probe Status", nEb())
U.infoExpAttempts = infoRow(scrolls["Exploits_beta"], "Attempts", "0", C.pink, nEb())
U.infoExpHits = infoRow(scrolls["Exploits_beta"], "Hits",     "0", C.green, nEb())

sectionHeader(scrolls["Exploits_beta"], "◉", "Remote Presence", nEb())
infoRow(scrolls["Exploits_beta"], "RunCommand",         R.RunCommand          and "Present" or "Missing", R.RunCommand          and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "UpdateCollectors",   R.UpdateCollectors    and "Present" or "Missing", R.UpdateCollectors    and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "UpdateUnitCap",      R.UpdateUnitCap       and "Present" or "Missing", R.UpdateUnitCap       and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "UpdateModifiers",    R.UpdateModifiers     and "Present" or "Missing", R.UpdateModifiers     and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "RerollTraits",       R.RerollTraits        and "Present" or "Missing", R.RerollTraits        and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "Rebirth",            R.Rebirth             and "Present" or "Missing", R.Rebirth             and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "DismantleRebirth",   R.DismantleRebirth    and "Present" or "Missing", R.DismantleRebirth    and C.green or C.red, nEb())
infoRow(scrolls["Exploits_beta"], "PlaceStructure",     R.PlaceStructure      and "Present" or "Missing", R.PlaceStructure      and C.green or C.red, nEb())

sectionHeader(scrolls["Exploits_beta"], "✦", "Probe Log", nEb())
U.expLogLabel = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 260),
    BackgroundTransparency = 1,
    Text = "(no probes fired yet)",
    Font = F_MONO, TextSize = 10, TextColor3 = C.text3,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nEb(),
}, scrolls["Exploits_beta"])

--========================================================================
-- POPULATE: MISC
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Misc_alpha"], "●", "Safety", nUa())
toggleRow    (scrolls["Misc_alpha"], "Anti-AFK",     "AutoAntiAFK",  nUa())
toggleRow    (scrolls["Misc_alpha"], "Auto Rewards", "AutoRewards",  nUa())

sectionHeader(scrolls["Misc_alpha"], "◉", "Player", nUa())
toggleRow    (scrolls["Misc_alpha"], "Walk Speed",   "AutoSpeed",    nUa())
cycleRow     (scrolls["Misc_alpha"], "Speed Value",  "SpeedValue",   {16, 24, 28, 40, 60, 80, 120}, nUa())
toggleRow    (scrolls["Misc_alpha"], "Inf Jump",     "AutoInfJump",  nUa())

sectionHeader(scrolls["Misc_alpha"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Anti-AFK sends Space every 120s.\nAuto Rewards claims Daily +\nPlaytime + Group every 60s.\n\nWalk Speed writes Humanoid.\nMay trigger AC — test first.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUa(),
}, scrolls["Misc_alpha"])

sectionHeader(scrolls["Misc_beta"], "●", "Manual Actions", nUb())
actionBtn(scrolls["Misc_beta"], "Claim Daily",    C.bg3, nUb(), function() if R.ClaimDaily    then pcall(function() R.ClaimDaily:FireServer() end) end end)
actionBtn(scrolls["Misc_beta"], "Claim Playtime", C.bg3, nUb(), function() if R.ClaimPlaytime then pcall(function() R.ClaimPlaytime:FireServer() end) end end)
actionBtn(scrolls["Misc_beta"], "Claim Group",    C.bg3, nUb(), function() if R.ClaimGroup    then pcall(function() R.ClaimGroup:FireServer() end) end end)
actionBtn(scrolls["Misc_beta"], "Skip Tutorial",  C.bg3, nUb(), doSkipTutorial)

sectionHeader(scrolls["Misc_beta"], "◉", "Stats", nUb())
U.infoHealth = infoRow(scrolls["Misc_beta"], "Health", "—", C.text, nUb())
U.infoSpeed = infoRow(scrolls["Misc_beta"], "Speed",  "16", C.text, nUb())

--========================================================================
-- POPULATE: SETTINGS
--========================================================================
local oS_a, oS_b = 0, 0
local function nSa() oS_a = oS_a + 1; return oS_a end
local function nSb() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSa())
toggleRow    (scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSa())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSa(), saveCFG)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), loadSavedCFG)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" and k ~= "AutoSave" then CFG[k] = false end
        if type(v) == "table" then
            for k2 in pairs(CFG[k]) do CFG[k][k2] = nil end
        end
    end
    CFG.CollectDelay  = "0.5s"
    CFG.PurchaseDelay = "1.0s"
    CFG.CrateDelay    = "0.5s"
    CFG.SpeedValue    = 28
    CFG.AutoAntiAFK   = true
    CFG.AutoRewards   = true
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn(scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn(scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.15)
    getgenv().__AURORAHUB_LEVIATHAN_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "[LEVIATHAN] Military Base", C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),      C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion), C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",             C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5.0",                      C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "Named RE (Replica)",        C.text3, nSb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSb())
U.cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 220),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSb(),
}, scrolls["Settings_beta"])

--========================================================================
-- POPULATE: LIVE GAME
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end
sectionHeader(liveScroll, "◉", "Session", nL())
U.liveRuntime = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
U.liveStatus = infoRow(liveScroll, "Status",  "Idle", C.pink,  nL())

sectionHeader(liveScroll, "●", "Player", nL())
U.liveHealth = infoRow(liveScroll, "Health", "—", C.text,  nL())
U.liveSpeed = infoRow(liveScroll, "Speed",  "16", C.text, nL())

sectionHeader(liveScroll, "▣", "Farm", nL())
U.liveCollects = infoRow(liveScroll, "Collects",  "0", C.pink,  nL())
U.livePurch = infoRow(liveScroll, "Purchases", "0", C.pink,  nL())
U.liveCrates = infoRow(liveScroll, "Crates",    "0", C.pink,  nL())

sectionHeader(liveScroll, "◆", "Plot", nL())
U.liveStructs = infoRow(liveScroll, "Structures","—", C.text,  nL())

sectionHeader(liveScroll, "✦", "Exploits", nL())
U.liveExpA = infoRow(liveScroll, "Attempts", "0", C.red, nL())
U.liveExpH = infoRow(liveScroll, "Hits",     "0", C.green, nL())

--========================================================================
-- PILL
--========================================================================
local pillGui = create("ScreenGui", {
    Name = "AuroraPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true,
})
local _pillOk = false
if _HAS.gethui then _pillOk = pcall(function() pillGui.Parent = gethui() end) end
if not _pillOk then _pillOk = pcall(function() pillGui.Parent = game:GetService("CoreGui") end) end
if not _pillOk then pcall(function() pillGui.Parent = Player:WaitForChild("PlayerGui") end) end

local pill = create("Frame", {
    Name = "Pill", Size = UDim2.fromOffset(152, 36),
    Position = UDim2.new(1, -172, 0, 22),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.15,
    BorderSizePixel = 0, Active = true,
}, pillGui)
corner(pill, 18); stroke(pill, C.border2, 1, 0)

local pillDotGlow = create("Frame", {
    Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.78,
    BorderSizePixel = 0, ZIndex = 1,
}, pill)
corner(pillDotGlow, 9)
local pillDotGlowInner = create("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.55,
    BorderSizePixel = 0, ZIndex = 2,
}, pill)
corner(pillDotGlowInner, 6)
local pillDot = create("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3,
}, pill)
corner(pillDot, 4)
task.spawn(function()
    local outerTween = TweenService:Create(
        pillDotGlow,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.55, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(7, 7) }
    )
    local innerTween = TweenService:Create(
        pillDotGlowInner,
        TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
        { BackgroundTransparency = 0.35 }
    )
    outerTween:Play(); innerTween:Play()
end)
create("TextLabel", {
    Size = UDim2.fromOffset(50, 36), Position = UDim2.fromOffset(28, 0),
    BackgroundTransparency = 1, Text = "Aurora",
    Font = F_SANS_BOLD, TextSize = 12, TextColor3 = C.pink,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pill)
create("TextLabel", {
    Size = UDim2.fromOffset(10, 36), Position = UDim2.fromOffset(80, 0),
    BackgroundTransparency = 1, Text = "·",
    Font = F_SANS_BOLD, TextSize = 14, TextColor3 = C.text3,
}, pill)
U.pillActive = create("TextLabel", {
    Size = UDim2.fromOffset(56, 36), Position = UDim2.fromOffset(92, 0),
    BackgroundTransparency = 1, Text = "0 active",
    Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
    TextXAlignment = Enum.TextXAlignment.Left,
}, pill)

pill.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = not CFG.PanelOpen
        main.Visible = CFG.PanelOpen
    end
end)

--========================================================================
-- DRAG
--========================================================================
local topDragStrip = create("Frame", {
    Name = "TopDragStrip",
    Size = UDim2.fromOffset(TOTAL_W - SIDEBAR_W, 48),
    Position = UDim2.fromOffset(SIDEBAR_W, 0),
    BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 3,
}, content)

local _drag = { active = false, start = nil, startPos = nil }
local function attachDrag(handle)
    handle.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _drag.active   = true
            _drag.start    = inp.Position
            _drag.startPos = main.Position
            closeOpenPopup()
        end
    end)
end
attachDrag(wordmarkRow)
attachDrag(topDragStrip)

UIS.InputChanged:Connect(function(inp)
    if not alive() then return end
    if _drag.active and (inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch) then
        local d = inp.Position - _drag.start
        main.Position = UDim2.new(
            _drag.startPos.X.Scale, _drag.startPos.X.Offset + d.X,
            _drag.startPos.Y.Scale, _drag.startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        _drag.active = false
    end
end)

UIS.InputBegan:Connect(function(inp, processed)
    if not alive() then return end
    if _skipNextOutside then _skipNextOutside = false; return end
    if _openPopup and (inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch) then
        local popup = _openPopup.frame
        local p0, ps = popup.AbsolutePosition, popup.AbsoluteSize
        local cx, cy = inp.Position.X, inp.Position.Y
        local inside = cx >= p0.X and cx <= p0.X + ps.X
                   and cy >= p0.Y and cy <= p0.Y + ps.Y
        if not inside then closeOpenPopup() end
    end
end)

--========================================================================
-- CLOSE + MINIMIZE
--========================================================================
local minBtn = create("Frame", {
    Name = "Minimize", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 62, 13),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
}, content)
corner(minBtn, 11); stroke(minBtn, C.border2, 1, 0)
local minLine = create("Frame", {
    Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = C.text2, BorderSizePixel = 0, ZIndex = 6,
}, minBtn)
corner(minLine, 1)
minBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.pink
        minLine.BackgroundColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        CFG.PanelOpen = false
        main.Visible = false
        closeOpenPopup()
    end
end)
minBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        minBtn.BackgroundColor3 = C.bg3
        minLine.BackgroundColor3 = C.text2
    end
end)

local closeBtn = create("Frame", {
    Name = "Close", Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 32, 13),
    BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
}, content)
corner(closeBtn, 11); stroke(closeBtn, C.border2, 1, 0)
local closeX = create("TextLabel", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    Text = "×", Font = F_SANS_BOLD, TextSize = 16,
    TextColor3 = C.text2, ZIndex = 6,
}, closeBtn)
closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.red
        closeX.TextColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        getgenv().__AURORAHUB_LEVIATHAN_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
    end
end)
closeBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.bg3
        closeX.TextColor3 = C.text2
    end
end)

--========================================================================
-- STATUS UPDATE
--========================================================================
local _crateHist = {} -- {time, count}
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            local hpTxt, spdTxt = "—", "16"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt  = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spdTxt = tostring(math.floor(hum.WalkSpeed))
                end
            end

            local elapsed = tick() - _sessionStart
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local active = {}
            if CFG.AutoCollect     then table.insert(active, "Coll") end
            if CFG.AutoPurchase    then table.insert(active, "Purch") end
            if CFG.AutoOpenCrates  then table.insert(active, "Crate") end
            if CFG.AutoRewards     then table.insert(active, "Rwd") end
            if CFG.AutoSpeed       then table.insert(active, "Spd") end
            if CFG.AutoInfJump     then table.insert(active, "Jmp") end
            if CFG.ExploitMaster and CFG.ExploitAdminProbe        then table.insert(active, "ExA") end
            if CFG.ExploitMaster and CFG.ExploitCollectorOverride then table.insert(active, "ExC") end
            if CFG.ExploitMaster and CFG.ExploitUnitCapBoost      then table.insert(active, "ExU") end
            if CFG.ExploitMaster and CFG.ExploitModifierInjection then table.insert(active, "ExM") end
            if CFG.ExploitMaster and CFG.ExploitRewardSpam        then table.insert(active, "ExR") end
            if CFG.ExploitMaster and CFG.ExploitFreeRebirth       then table.insert(active, "ExB") end
            if CFG.ExploitMaster and CFG.ExploitFreeReroll        then table.insert(active, "ExT") end
            if CFG.ExploitMaster and CFG.ExploitPlaceFree         then table.insert(active, "ExP") end
            if CFG.ExploitMaster and CFG.ExploitDismantleDupe     then table.insert(active, "ExD") end

            local mode = #active > 0 and table.concat(active, " + ") or "Idle"
            if #mode > 30 then mode = (#active) .. " active" end

            -- Update plot struct count
            local folder = getMyStructuresFolder()
            if folder then S.currentPlotStructures = #folder:GetChildren() end

            -- Selected purchase count
            local sel = 0
            for _, on in pairs(CFG.PurchaseStructures) do if on then sel = sel + 1 end end

            -- Crate rate
            table.insert(_crateHist, { t = tick(), c = S.crates })
            while #_crateHist > 0 and (tick() - _crateHist[1].t) > 60 do table.remove(_crateHist, 1) end
            local rate = 0
            if #_crateHist >= 2 then
                local first = _crateHist[1]
                rate = math.max(0, S.crates - first.c)
            end

            -- Main tab
            U.infoMode.Text     = mode
            U.infoRuntime.Text  = rtime
            U.infoStructs.Text  = tostring(S.currentPlotStructures)
            U.infoCollects.Text = fmt(S.collects)
            U.infoPurch.Text    = tostring(S.purchases)
            U.infoCrates.Text   = tostring(S.crates)
            U.infoRewards.Text  = tostring(S.rewards)

            -- Vendor
            U.infoSelected.Text = tostring(sel)

            -- Crates
            U.infoCratesTotal.Text = tostring(S.crates)
            U.infoCratesRate.Text  = rate .. "/min"

            -- Exploits
            U.infoExpAttempts.Text = tostring(S.exploitAttempts)
            U.infoExpHits.Text     = tostring(S.exploitHits)

            if #_expLog > 0 then
                local out = {}
                for i = 1, math.min(18, #_expLog) do table.insert(out, _expLog[i]) end
                U.expLogLabel.Text = table.concat(out, "\n")
            end

            -- Misc
            U.infoHealth.Text = hpTxt
            U.infoSpeed.Text  = spdTxt

            -- Live
            U.liveRuntime.Text  = rtime
            U.liveStatus.Text   = mode
            U.liveHealth.Text   = hpTxt
            U.liveSpeed.Text    = spdTxt
            U.liveCollects.Text = fmt(S.collects)
            U.livePurch.Text    = tostring(S.purchases)
            U.liveCrates.Text   = tostring(S.crates)
            U.liveStructs.Text  = tostring(S.currentPlotStructures)
            U.liveExpA.Text     = tostring(S.exploitAttempts)
            U.liveExpH.Text     = tostring(S.exploitHits)

            -- Active list + pill
            local sortedActive = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    table.insert(sortedActive, "· " .. k)
                end
            end
            table.sort(sortedActive)
            U.cfgActiveLabel.Text = #sortedActive > 0 and table.concat(sortedActive, "\n") or "None"
            U.pillActive.Text = #sortedActive .. " active"
        end)
    end
end)

--========================================================================
-- INIT
--========================================================================
switchTab(CFG.ActiveTab or "Main")
print("[Aurora v5] Leviathan Military Base loaded · " .. #STRUCTURE_NAMES .. " structures · " .. #CRATE_NAMES .. " crate types")

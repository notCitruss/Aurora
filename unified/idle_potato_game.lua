--// Aurora v5 — Idle Potato Game
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 122079988266644
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// 146 remotes — auto-click, auto-buy, auto-sell, auto-prestige, boost spam — PRESERVED VERBATIM

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
if getgenv().__AURORA_POTATO_CFG2 then
    for k, v in pairs(getgenv().__AURORA_POTATO_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_POTATO_CFG2[k] = false end
    end
end
-- Also clear legacy v4 key (never populated, but safe)
if getgenv().__AURORA_POTATO_CFG then
    for k, v in pairs(getgenv().__AURORA_POTATO_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_POTATO_CFG[k] = false end
    end
end
task.wait(0.15)

getgenv().__AURORA_POTATO_SESSION = tick()
local _mySession = getgenv().__AURORA_POTATO_SESSION
local function alive() return getgenv().__AURORA_POTATO_SESSION == _mySession end

---------- REMOTES (preserved verbatim from v4) ----------
-- Type-safe remote lookup: returns the child only if it's the expected class
local function safeRE(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteEvent")) and obj or nil
end
local function safeRF(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteFunction")) and obj or nil
end
local R = RS:WaitForChild("Remotes", 15)
if not R then warn("[Aurora] Remotes folder missing"); return end


---------- COMPAT (cross-executor support) ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    firepp    = fireproximityprompt ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
    vim       = pcall(function() return game:GetService("VirtualInputManager") end),
}
local function _promptAlive(p)
    local ok, r = pcall(function() return p and p.Parent and p.Enabled end)
    return ok and r
end
-- Cross-executor prompt firing: fireproximityprompt on Wave/Potassium/Delta,
-- InputHoldBegin + VIM E-key hold as fallback for Xeno and others that lack the helper.
local function safeFirePrompt(prompt)
    if not _promptAlive(prompt) then return end
    local holdTime = prompt.HoldDuration or 0
    pcall(function() if _HAS.firepp then fireproximityprompt(prompt) end end)
    task.wait(0.1)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local oh = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(math.max(0.15, holdTime + 0.2))
        prompt:InputHoldEnd()
        prompt.HoldDuration = oh
    end)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(math.max(0.2, holdTime + 0.2))
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().__AURORA_POTATO_CFG2 then
    getgenv().__AURORA_POTATO_CFG2 = {
        -- v4 keys preserved exactly
        AutoClick            = false,
        AutoSell             = false,
        AutoBuyUpgrades      = false,
        AutoBuyGenerators    = false,
        AutoPrestige         = false,
        AutoAscend           = false,
        BoostSpam            = false,
        AntiAFK              = false,
        AutoDig              = false,
        AutoFusePotato       = false,
        AutoPrestigeUpgrade  = false,
        AscendBlessing       = "Any",
        SmartBuyGenerator    = false,
        AutoBuyShop          = false,
        AutoUsePotions       = false,
        AutoOpenMysteryBox   = false,
        -- v4 dynamic keys (added at runtime in v4; hoisted to initial CFG here)
        CPS                  = 10,
        AutoSave             = false,
        -- v5 UI state (only additions)
        ActiveTab            = "Farm",
        PanelOpen            = true,
    }
else
    local c = getgenv().__AURORA_POTATO_CFG2
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    if c.CPS == nil then c.CPS = 10 end
    if c.AutoSave == nil then c.AutoSave = false end
    if c.AscendBlessing == nil then c.AscendBlessing = "Any" end
end
local CFG = getgenv().__AURORA_POTATO_CFG2

---------- TOGGLE SAVE/LOAD (preserved v4 filename) ----------
local _cfgFileName = "aurora_cfg_idle_potato_game.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_idle_potato_game"] end
    if saved and type(saved) == "table" then
        for k, v in saved do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        -- String config keys
        if saved.AscendBlessing and type(saved.AscendBlessing) == "string" then
            CFG.AscendBlessing = saved.AscendBlessing
        end
    end
end

local function saveCFG()
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_idle_potato_game"] = CFG
end

loadSavedCFG()

---------- STATE ----------
local S = {clicks = 0, sells = 0, upgrades = 0, generators = 0, prestiges = 0, digs = 0, fuses = 0, mysteryBoxes = 0, shopBuys = 0, potionsUsed = 0}
local _sessionStart = tick()

---------- UPGRADE/GENERATOR LISTS (preserved verbatim from v4) ----------
local CLICK_UPGRADES = {
    "stronger_hands", "padded_gloves", "steel_trowel", "golden_trowel", "farmers_instinct",
    "advanced_techniques", "grandfathers_wisdom", "lunar_planting", "dimensional_reach",
    "infinite_energy", "omnipotato_blessing", "transcendent_harvest", "galactic_harvest",
    "universal_potato_power", "infinite_potato_mastery", "omniversal_click", "singularity_tap",
    "finger_of_god", "magical_foam_finger", "mind_click", "omnifinger", "galaxy_tap",
    "big_bang_click", "infinity_finger_poke", "the_final_click", "golden_touch",
    "lucky_fertilizer", "midas_touch", "gilded_instinct", "golden_enlightenment",
    "arcane_sparks", "runic_soil", "enchanted_peeler", "archmages_blessing", "arcane_awakening",
    "supernova_sprout", "meteorite_soil", "nebula_duststorm", "zero_g_cultivation",
    "astral_projection", "collectors_guidebook", "premium_fertilizer", "prize_winning_seeds",
}

local GENERATORS = {
    "potato_seedling", "backyard_patch", "potato_garden", "potato_farm", "greenhouse",
    "agricultural_lab", "processing_plant", "mystic_garden", "wizard_tower", "enchanted_grove",
    "arcane_sprout", "cloning_facility", "golden_garden", "golden_grove", "golden_mine",
    "midas_facility", "golden_citadel", "crown_of_midas", "solar_gold_forge", "golden_nexus",
    "eternal_gold_source", "golden_infinite_universe", "divine_gold_refinery",
    "eye_magic_totem", "eye_growth_incubator", "eye_witch_cauldron", "eye_sacred_altar",
    "eye_heavens_gate", "starlight_flashlight", "stellar_magnifying_glass",
    "galactic_treasure_map", "dark_matter_metal_detector", "sonic_spud_echolocator",
    "findmypotato", "celestial_potato_compass", "cosmic_bioscanner", "cosmic_scooper",
    "cosmic_spellforge", "starch_cosmic_ray", "starch_cosmic_mill", "starch_nebula",
    "starch_star_refinery", "starch_star_masher", "starch_asteroid_drill",
    "comet_of_gods", "potato_whale_comet", "supernova_sprout",
    "galactic_potato_system", "dimensional_mirror", "dimensional_rift_farm",
    "temporal_harvester", "transmutation_core", "omnipotato", "double_omnipotato",
    "infinite_omnipotato", "the_spudularity", "potato_nexus", "quantum_potato_generator",
    "astral_potato_vacuum", "potato_galaxy", "potato_infinite_universe",
    "potato_gods_sprout", "potato_gods_garden", "potato_gods_greenhouse",
    "potato_gods_potato_realm", "potato_gods_potato_paradise",
    "the_final_spud", "superfactory_number_67",
}

local PRESTIGE_UPGRADES = {
    "seed_money", "click_percent_bonus", "generator_percent_bonus", "overnight_growth",
    "double_harvest", "golden_irrigation", "bulk_discounts", "collectors_luck",
    "starter_seedlings", "golden_generators", "prestige_mastery", "selective_breeding",
    "critical_harvest", "legendary_fortune", "mythic_fortune",
}

local BLESSINGS = {"Any", "golden", "abundance", "thrifty", "collector", "prestige"}

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CORE FUNCTIONS (preserved verbatim from v4) ----------

-- Auto-Click: adjustable CPS via slider
local CPS = CFG.CPS or 10 -- default 10, range 1-2500

local function doClickBurst()
    -- Calculate clicks per burst at 0.1s interval
    local clicksPerBurst = math.max(1, math.floor(CPS / 10))
    local workers = math.min(5, math.ceil(clicksPerBurst / 50))
    local perWorker = math.ceil(clicksPerBurst / workers)

    if workers <= 1 then
        for _ = 1, clicksPerBurst do
            pcall(function() R.PerformClick:FireServer() end)
            S.clicks += 1
        end
    else
        for _ = 1, workers do
            task.spawn(function()
                for _ = 1, perWorker do
                    pcall(function() R.PerformClick:FireServer() end)
                    S.clicks += 1
                end
            end)
        end
    end
end

-- Auto-Sell: sell all potatoes + golden potatoes
local function doSell()
    pcall(function() R.SellAllPotatoes:FireServer() end)
    pcall(function() R.SellAllGoldenPotatoes:FireServer() end)
    S.sells += 1
end

-- Auto-Buy Click Upgrades
local function doBuyUpgrades()
    for _, name in CLICK_UPGRADES do
        pcall(function() R.PurchaseClickUpgrade:FireServer(name) end)
    end
    S.upgrades += 1
end

-- Auto-Buy Generators
local function doBuyGenerators()
    for _, name in GENERATORS do
        pcall(function() R.PurchaseGenerator:FireServer(name) end)
    end
    S.generators += 1
end

-- Auto-Prestige: check if we can get prestige points first
local function doPrestige()
    local canPrestige = false
    pcall(function()
        local info = R.GetPotentialPrestigePoints:InvokeServer()
        if info and type(info) == "number" and info > 0 then canPrestige = true end
        if info and type(info) == "table" and info.Points and info.Points > 0 then canPrestige = true end
    end)
    if not canPrestige then return end

    pcall(function() R.PerformPrestige:FireServer() end)
    task.wait(1)
    for _, name in PRESTIGE_UPGRADES do
        pcall(function() R.PurchasePrestigeUpgrade:FireServer(name) end)
    end
    S.prestiges += 1
end

-- Auto-Ascend
local function doAscend()
    pcall(function() R.PerformAscension:FireServer() end)
end

-- Boost Spam
local function doBoosts()
    pcall(function() R.ActivateFreeBoost:FireServer() end)
    pcall(function() R.ActivateFreeGlobalBoost:FireServer() end)
    pcall(function() R.ClaimLoginStreak:FireServer() end)
    pcall(function() R.ClaimOfflineBoostBonus:FireServer() end)
end

-- Auto Dig
local function doDig()
    pcall(function() R.DigStartRound:FireServer() end)
    task.wait(0.3)
    for i = 1, 25 do
        pcall(function() R.DigSquare:FireServer(i) end)
        task.wait(0.05)
    end
    S.digs += 1
end

-- Auto Fuse Potato
local function doFuse()
    pcall(function() R.FusePotatoes:FireServer() end)
    S.fuses += 1
end

-- Auto Prestige Upgrade (buy prestige upgrades without prestiging)
local function doBuyPrestigeUpgrades()
    for _, name in PRESTIGE_UPGRADES do
        pcall(function() R.PurchasePrestigeUpgrade:FireServer(name) end)
    end
end

-- Auto Ascend with blessing choice
local function doAscendWithBlessing()
    local canAscend = false
    pcall(function()
        local info = R.GetAscensionInfo:InvokeServer()
        if info and type(info) == "table" and info.CanAscend then canAscend = true end
        if info == true then canAscend = true end
    end)
    if not canAscend then return end

    local blessing = CFG.AscendBlessing
    if blessing == "Any" then
        pcall(function() R.PerformAscension:FireServer() end)
    else
        pcall(function() R.PerformAscension:FireServer(blessing) end)
    end
end

-- Smart Buy Generator: delete worst, buy best affordable
local function doSmartBuyGenerator()
    -- Delete the cheapest (first in list = worst)
    pcall(function() R.DeleteGenerator:FireServer(GENERATORS[1]) end)
    task.wait(0.3)
    -- Buy most expensive affordable (iterate from end to start)
    for i = #GENERATORS, 1, -1 do
        local ok, result = pcall(function() R.PurchaseGenerator:FireServer(GENERATORS[i]) end)
        if ok then break end
    end
    S.generators += 1
end

-- Auto Buy Shop (except rock)
local function doBuyShop()
    local rotation = nil
    pcall(function()
        local data = R.GetShopRotation:InvokeServer()
        if data and type(data) == "table" then rotation = data.Rotation or data end
    end)
    if not rotation or type(rotation) ~= "table" then return end
    for _, item in rotation do
        local itemId = (type(item) == "table" and (item.ItemId or item.Id or item.Name)) or item
        if itemId and tostring(itemId) ~= "rock" then
            pcall(function() R.PurchaseShopPotato:FireServer(itemId) end)
            S.shopBuys += 1
            task.wait(0.2)
        end
    end
end

-- Auto Use Potions
local function doUsePotions()
    local playerData = nil
    pcall(function()
        playerData = R.GetPlayerData:InvokeServer()
    end)
    if not playerData or type(playerData) ~= "table" then return end
    local inv = playerData.ItemInventory or playerData.Inventory or playerData.Potions
    if not inv or type(inv) ~= "table" then return end
    for potionId, count in inv do
        if type(count) == "number" and count > 0 then
            pcall(function() R.UsePotion:FireServer(potionId) end)
            S.potionsUsed += 1
            task.wait(0.2)
        end
    end
end

-- Auto Open Mystery Box
local function doOpenMysteryBox()
    -- Try bulk open first, then single
    local ok1 = pcall(function() R.OpenMultipleMysteryBoxes:FireServer(10) end)
    if not ok1 then
        pcall(function() R.OpenMysteryBox:FireServer() end)
    end
    S.mysteryBoxes += 1
end

---------- LOOPS (preserved verbatim from v4) ----------

-- Auto-Click: fires bursts every 0.1s based on CPS slider
task.spawn(function()
    while alive() do
        if CFG.AutoClick then pcall(doClickBurst) end
        task.wait(0.1)
        if not alive() then break end
    end
end)

-- Auto-Sell: every 10s (batches more potatoes per sell)
task.spawn(function()
    while alive() do
        if CFG.AutoSell then pcall(doSell) end
        task.wait(jitter(10, 3.0))
        if not alive() then break end
    end
end)

-- Auto-Buy Upgrades: every 2s
task.spawn(function()
    while alive() do
        if CFG.AutoBuyUpgrades then pcall(doBuyUpgrades) end
        task.wait(jitter(2, 0.6))
        if not alive() then break end
    end
end)

-- Auto-Buy Generators: every 2s
task.spawn(function()
    while alive() do
        if CFG.AutoBuyGenerators then pcall(doBuyGenerators) end
        task.wait(jitter(2, 0.6))
        if not alive() then break end
    end
end)

-- Auto-Prestige: every 10s
task.spawn(function()
    while alive() do
        if CFG.AutoPrestige then pcall(doPrestige) end
        task.wait(jitter(10, 3.0))
        if not alive() then break end
    end
end)

-- Auto-Ascend: replaced by blessing-aware loop below

-- Boost Spam: every 15s
task.spawn(function()
    while alive() do
        if CFG.BoostSpam then pcall(doBoosts) end
        task.wait(jitter(15, 4.5))
        if not alive() then break end
    end
end)

-- Anti-AFK
task.spawn(function()
    while alive() do
        if CFG.AntiAFK then
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

-- Auto Dig: every 2s
task.spawn(function()
    while alive() do
        if CFG.AutoDig then pcall(doDig) end
        task.wait(jitter(2, 0.6))
        if not alive() then break end
    end
end)

-- Auto Fuse Potato: every 15s
task.spawn(function()
    while alive() do
        if CFG.AutoFusePotato then pcall(doFuse) end
        task.wait(jitter(15, 4.5))
        if not alive() then break end
    end
end)

-- Auto Prestige Upgrade: every 5s
task.spawn(function()
    while alive() do
        if CFG.AutoPrestigeUpgrade then pcall(doBuyPrestigeUpgrades) end
        task.wait(jitter(5, 1.5))
        if not alive() then break end
    end
end)

-- Auto Ascend with blessing: every 30s
task.spawn(function()
    while alive() do
        if CFG.AutoAscend then pcall(doAscendWithBlessing) end
        task.wait(jitter(30, 9.0))
        if not alive() then break end
    end
end)

-- Smart Buy Generator: every 5s
task.spawn(function()
    while alive() do
        if CFG.SmartBuyGenerator then pcall(doSmartBuyGenerator) end
        task.wait(jitter(5, 1.5))
        if not alive() then break end
    end
end)

-- Auto Buy Shop: every 30s
task.spawn(function()
    while alive() do
        if CFG.AutoBuyShop then pcall(doBuyShop) end
        task.wait(jitter(30, 9.0))
        if not alive() then break end
    end
end)

-- Auto Use Potions: every 30s
task.spawn(function()
    while alive() do
        if CFG.AutoUsePotions then pcall(doUsePotions) end
        task.wait(jitter(30, 9.0))
        if not alive() then break end
    end
end)

-- Auto Open Mystery Box: every 10s
task.spawn(function()
    while alive() do
        if CFG.AutoOpenMysteryBox then pcall(doOpenMysteryBox) end
        task.wait(jitter(10, 3.0))
        if not alive() then break end
    end
end)

-- Claim rewards on load
task.spawn(function()
    task.wait(2)
    pcall(function() R.ClaimLoginStreak:FireServer() end)
    pcall(function() R.ClaimOfflineBoostBonus:FireServer() end)
    pcall(function() R.ActivateFreeBoost:FireServer() end)
    pcall(function() R.RefreshSocialBonuses:FireServer() end)
end)

-- ========================================================================
-- ========================================================================
-- V5 3-COLUMN UI (Sidebar + Panel Alpha + Panel Beta + Live Game + Pill)
-- ========================================================================
-- ========================================================================

--========================================================================
-- PALETTE
--========================================================================
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

--========================================================================
-- UI HELPERS
--========================================================================
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

--========================================================================
-- LAYOUT CONSTANTS
--========================================================================
local TOTAL_W   = 1080
local TOTAL_H   = 620
local SIDEBAR_W = 168
local PA_W      = 350
local PB_W      = 350
local LG_W      = TOTAL_W - SIDEBAR_W - PA_W - PB_W  -- 212

--========================================================================
-- SCREENGUI + PARENT (Xeno-safe: each parent in own pcall)
--========================================================================
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

--========================================================================
-- MAIN PANEL
--========================================================================
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

-- Centered brand watermark (bleeds through transparent panels/scrolls)
local watermark = create("TextLabel", {
    Name = "Watermark",
    Size = UDim2.fromOffset(800, 120),
    Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2),
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    Text = "Aurorahub.net",
    Font = F_SANS_BOLD,
    TextSize = 72,
    TextColor3 = C.pink,
    TextTransparency = 0.82,
    TextStrokeTransparency = 1,
    TextXAlignment = Enum.TextXAlignment.Center,
    TextYAlignment = Enum.TextYAlignment.Center,
    ZIndex = 1,
}, main)
watermark.RichText = true
watermark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

local content = create("Frame", {
    Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2,
}, main)

--========================================================================
-- SIDEBAR
--========================================================================
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
    TextColor3 = C.text, Text = "Aurorahub.net",
}, wordmarkRow)
wordmark.RichText = true
wordmark.Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>'

create("Frame", {
    Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, 54),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, sidebar)

--========================================================================
-- TABS
--========================================================================
local TABS = {
    { name = "Farm",     icon = "●" },
    { name = "Shop",     icon = "▣" },
    { name = "Progress", icon = "◆" },
    { name = "Utility",  icon = "≡" },
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
    bgGrad.Rotation = 0
    bgGrad.Parent = row

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

-- Forward-declare switchTab / popup helpers
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

-- Settings tab (pinned at bottom)
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

--========================================================================
-- PANEL FACTORY
--========================================================================
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

local TAB_NAMES = { "Farm", "Shop", "Progress", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm     = C.pink,
    Shop     = C.purple,
    Progress = C.pink,
    Utility  = C.purple,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "FARMING",    beta = "FARM STATUS"  },
    Shop     = { alpha = "UPGRADES",   beta = "SHOP STATUS"  },
    Progress = { alpha = "PROGRESS",   beta = "ASCENSION"    },
    Utility  = { alpha = "UTILITY",    beta = "MANUAL"       },
    Settings = { alpha = "CONFIG",     beta = "ABOUT"        },
}

local scrolls = {}
for _, tn in ipairs(TAB_NAMES) do
    local acc = TAB_ACCENT[tn]
    local t   = PANEL_TITLES[tn]
    scrolls[tn .. "_alpha"] = makePanel(tn, "alpha", SIDEBAR_W,        PA_W, acc, t.alpha)
    scrolls[tn .. "_beta"]  = makePanel(tn, "beta",  SIDEBAR_W + PA_W, PB_W, acc, t.beta)
end

-- Persistent Live Game panel
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

--========================================================================
-- TAB SWITCHER
--========================================================================
switchTab = function(tabName)
    if not panels[tabName] then tabName = "Farm" end
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

--========================================================================
-- COMPONENT BUILDERS
--========================================================================
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
        BackgroundTransparency = 1, Text = tostring(initialVal or "---"),
        Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text2,
        TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    return val
end

-- CPS slider: log-scale 1-2500 (preserves v4 exponential behavior)
local function cpsSliderRow(parent, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.fromOffset(0, 2),
        BackgroundTransparency = 1, Text = "CPS",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local valLabel = create("TextLabel", {
        Size = UDim2.new(0.5, 0, 0, 20), Position = UDim2.new(0.5, 0, 0, 2),
        BackgroundTransparency = 1, Text = tostring(CPS),
        Font = F_MONO, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local trackFrame = create("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, 30),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true,
    }, row)
    corner(trackFrame, 3)
    stroke(trackFrame, C.border2, 1, 0)
    local initFrac = math.log(math.max(1, CPS)) / math.log(2500)
    local fill = create("Frame", {
        Size = UDim2.new(initFrac, 0, 1, 0), BackgroundColor3 = C.pink, BorderSizePixel = 0,
    }, trackFrame)
    corner(fill, 3)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(initFrac, -7, 0.5, -7),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
    }, trackFrame)
    corner(knob, 7)
    local sliding = false
    local function updateSlider(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        if absSize <= 0 then return end
        local frac = math.clamp((inputX - absPos) / absSize, 0, 1)
        local expVal = 1 * (2500 / 1) ^ frac
        local val = math.clamp(math.floor(expVal), 1, 2500)
        CPS = val
        CFG.CPS = val
        fill.Size = UDim2.new(frac, 0, 1, 0)
        knob.Position = UDim2.new(frac, -7, 0.5, -7)
        valLabel.Text = tostring(val)
        if CFG.AutoSave then saveCFG() end
    end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = true; updateSlider(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if sliding and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)
    return row
end

-- Blessing cycler (preserves CFG.AscendBlessing semantics)
local function blessingCycleRow(parent, order, onChange)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = "Blessing",
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local pill = create("Frame", {
        Size = UDim2.fromOffset(180, 22), Position = UDim2.new(1, -180, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)
    local bLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = CFG.AscendBlessing or "Any",
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▶",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)
    local _idx = 1
    for i, bn in ipairs(BLESSINGS) do if bn == CFG.AscendBlessing then _idx = i; break end end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _idx = (_idx % #BLESSINGS) + 1
            CFG.AscendBlessing = BLESSINGS[_idx]
            bLabel.Text = CFG.AscendBlessing
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange() end
        end
    end)
    return row, bLabel
end

--========================================================================
-- POPULATE: FARM
--========================================================================
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Farming", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto-Click",            "AutoClick",          nFa())
cpsSliderRow (scrolls["Farm_alpha"], nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto-Sell All",         "AutoSell",           nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Dig",              "AutoDig",            nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Fuse Potato",      "AutoFusePotato",     nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Open Mystery Box", "AutoOpenMysteryBox", nFa())

sectionHeader(scrolls["Farm_alpha"], "▣", "Manual", nFa())
actionBtn(scrolls["Farm_alpha"], "Sell All Potatoes", C.bg3, nFa(), doSell)
actionBtn(scrolls["Farm_alpha"], "Fuse Potatoes",     C.bg3, nFa(), doFuse)
actionBtn(scrolls["Farm_alpha"], "Open Mystery Box",  C.bg3, nFa(), doOpenMysteryBox)

sectionHeader(scrolls["Farm_alpha"], "✦", "Notes", nFa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "CPS slider is log-scale 1-2500.\nHigh CPS splits into up to 5\nworker threads per 0.1s burst.\n\nAuto Dig runs all 25 squares\neach round.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFa(),
}, scrolls["Farm_alpha"])

sectionHeader(scrolls["Farm_beta"], "●", "Status", nFb())
local _infoMode       = infoRow(scrolls["Farm_beta"], "Mode",        "Idle", C.pink,  nFb())
local _infoRuntime    = infoRow(scrolls["Farm_beta"], "Runtime",     "0m",   C.text2, nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Session Totals", nFb())
local _infoClicks     = infoRow(scrolls["Farm_beta"], "Clicks",       "0",   C.pink,  nFb())
local _infoSells      = infoRow(scrolls["Farm_beta"], "Sell Cycles",  "0",   C.pink,  nFb())
local _infoDigs       = infoRow(scrolls["Farm_beta"], "Dig Rounds",   "0",   C.pink,  nFb())
local _infoFuses      = infoRow(scrolls["Farm_beta"], "Fuse Cycles",  "0",   C.pink,  nFb())
local _infoMystBox    = infoRow(scrolls["Farm_beta"], "Mystery Boxes","0",   C.pink,  nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "CPS", nFb())
local _infoCPS        = infoRow(scrolls["Farm_beta"], "Clicks/sec",   tostring(CPS), C.text, nFb())

--========================================================================
-- POPULATE: SHOP
--========================================================================
local oSh_a, oSh_b = 0, 0
local function nShA() oSh_a = oSh_a + 1; return oSh_a end
local function nShB() oSh_b = oSh_b + 1; return oSh_b end

sectionHeader(scrolls["Shop_alpha"], "●", "Upgrades & Shop", nShA())
toggleRow    (scrolls["Shop_alpha"], "Auto-Buy Click Upgrades", "AutoBuyUpgrades",    nShA())
toggleRow    (scrolls["Shop_alpha"], "Auto-Buy Generators",     "AutoBuyGenerators",  nShA())
toggleRow    (scrolls["Shop_alpha"], "Smart Buy Generator",     "SmartBuyGenerator",  nShA())
toggleRow    (scrolls["Shop_alpha"], "Auto Buy Shop",           "AutoBuyShop",        nShA())

sectionHeader(scrolls["Shop_alpha"], "▣", "Manual", nShA())
actionBtn(scrolls["Shop_alpha"], "Buy All Click Upgrades", C.bg3, nShA(), doBuyUpgrades)
actionBtn(scrolls["Shop_alpha"], "Buy All Generators",     C.bg3, nShA(), doBuyGenerators)
actionBtn(scrolls["Shop_alpha"], "Smart Buy Now",          C.bg3, nShA(), doSmartBuyGenerator)
actionBtn(scrolls["Shop_alpha"], "Buy Shop Items",         C.bg3, nShA(), doBuyShop)

sectionHeader(scrolls["Shop_alpha"], "✦", "Notes", nShA())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Auto-Buy iterates the full\nupgrade/generator list every 2s.\n\nSmart Buy deletes the cheapest\ngenerator, then buys the most\nexpensive affordable one.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nShA(),
}, scrolls["Shop_alpha"])

sectionHeader(scrolls["Shop_beta"], "●", "Shop Status", nShB())
local _infoUpgrades   = infoRow(scrolls["Shop_beta"], "Upgrade Cycles",   "0", C.pink, nShB())
local _infoGens       = infoRow(scrolls["Shop_beta"], "Generator Cycles", "0", C.pink, nShB())
local _infoShopBuys   = infoRow(scrolls["Shop_beta"], "Shop Buys",        "0", C.pink, nShB())

sectionHeader(scrolls["Shop_beta"], "◉", "Counts", nShB())
infoRow(scrolls["Shop_beta"], "Click Upgrades", tostring(#CLICK_UPGRADES),  C.text2, nShB())
infoRow(scrolls["Shop_beta"], "Generators",     tostring(#GENERATORS),      C.text2, nShB())
infoRow(scrolls["Shop_beta"], "Prestige Ups",   tostring(#PRESTIGE_UPGRADES), C.text2, nShB())

sectionHeader(scrolls["Shop_beta"], "✦", "Tips", nShB())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Shop rotation skips 'rock'\n(trap item).\n\nSmart Buy is safer long-term —\nit frees the bottom slot and\nbuys the biggest jump.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nShB(),
}, scrolls["Shop_beta"])

--========================================================================
-- POPULATE: PROGRESS
--========================================================================
local oP_a, oP_b = 0, 0
local function nPa() oP_a = oP_a + 1; return oP_a end
local function nPb() oP_b = oP_b + 1; return oP_b end

sectionHeader(scrolls["Progress_alpha"], "●", "Prestige", nPa())
toggleRow    (scrolls["Progress_alpha"], "Auto-Prestige",        "AutoPrestige",        nPa())
toggleRow    (scrolls["Progress_alpha"], "Auto Prestige Upgrade","AutoPrestigeUpgrade", nPa())

sectionHeader(scrolls["Progress_alpha"], "◆", "Ascension", nPa())
toggleRow    (scrolls["Progress_alpha"], "Auto-Ascend",          "AutoAscend",          nPa())
local _blessRow, _blessLabel = blessingCycleRow(scrolls["Progress_alpha"], nPa(), nil)

sectionHeader(scrolls["Progress_alpha"], "▣", "Boosts", nPa())
toggleRow    (scrolls["Progress_alpha"], "Boost Spam",           "BoostSpam",           nPa())

sectionHeader(scrolls["Progress_alpha"], "⚙", "Manual", nPa())
actionBtn(scrolls["Progress_alpha"], "Prestige Now",         C.bg3,   nPa(), doPrestige)
actionBtn(scrolls["Progress_alpha"], "Ascend Now",           C.green, nPa(), doAscendWithBlessing)
actionBtn(scrolls["Progress_alpha"], "Claim All Rewards",    C.green, nPa(), doBoosts)

sectionHeader(scrolls["Progress_beta"], "●", "Session", nPb())
local _infoPrest      = infoRow(scrolls["Progress_beta"], "Prestiges",  "0", C.pink, nPb())
local _infoBlessing   = infoRow(scrolls["Progress_beta"], "Blessing",   CFG.AscendBlessing or "Any", C.pink, nPb())

sectionHeader(scrolls["Progress_beta"], "◉", "Available Blessings", nPb())
for _, bn in ipairs(BLESSINGS) do
    infoRow(scrolls["Progress_beta"], bn, bn == CFG.AscendBlessing and "Selected" or "---", bn == CFG.AscendBlessing and C.pink or C.text2, nPb())
end

sectionHeader(scrolls["Progress_beta"], "✦", "Tips", nPb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Auto-Prestige checks\nGetPotentialPrestigePoints first.\n\nAuto-Ascend uses the selected\nblessing. 'Any' fires without\nspecifying a blessing.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nPb(),
}, scrolls["Progress_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK",         "AntiAFK",       nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Use Potions", "AutoUsePotions", nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Player Stats", nUa())
local _infoHealth = infoRow(scrolls["Utility_alpha"], "Health", "---", C.text, nUa())
local _infoSpeed  = infoRow(scrolls["Utility_alpha"], "Speed",  "16",  C.text, nUa())

sectionHeader(scrolls["Utility_alpha"], "✦", "Notes", nUa())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Anti-AFK sends a Space keypress\nevery 120s via\nVirtualInputManager.\n\nAuto Use Potions iterates the\nplayer inventory every 30s.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUa(),
}, scrolls["Utility_alpha"])

sectionHeader(scrolls["Utility_beta"], "●", "Manual Actions", nUb())
actionBtn(scrolls["Utility_beta"], "Claim Login Streak",     C.bg3, nUb(), function() pcall(function() R.ClaimLoginStreak:FireServer() end) end)
actionBtn(scrolls["Utility_beta"], "Claim Offline Bonus",    C.bg3, nUb(), function() pcall(function() R.ClaimOfflineBoostBonus:FireServer() end) end)
actionBtn(scrolls["Utility_beta"], "Activate Free Boost",    C.bg3, nUb(), function() pcall(function() R.ActivateFreeBoost:FireServer() end) end)
actionBtn(scrolls["Utility_beta"], "Activate Global Boost",  C.bg3, nUb(), function() pcall(function() R.ActivateFreeGlobalBoost:FireServer() end) end)
actionBtn(scrolls["Utility_beta"], "Refresh Social Bonuses", C.bg3, nUb(), function() pcall(function() R.RefreshSocialBonuses:FireServer() end) end)

sectionHeader(scrolls["Utility_beta"], "◉", "Counters", nUb())
local _infoPotions = infoRow(scrolls["Utility_beta"], "Potions Used", "0", C.pink, nUb())

sectionHeader(scrolls["Utility_beta"], "✦", "Tips", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1,
    Text = "Claim buttons fire the named\nremote once per click.\n\nSafe for overnight farming\nwhen combined with Anti-AFK.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

--========================================================================
-- POPULATE: SETTINGS
--========================================================================
local oS_a, oS_b = 0, 0
local function nSa() oS_a = oS_a + 1; return oS_a end
local function nSb() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSa())
toggleRow    (scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSa())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSa(), function() saveCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), function()
    loadSavedCFG()
    if _blessLabel then _blessLabel.Text = CFG.AscendBlessing or "Any" end
end)
actionBtn    (scrolls["Settings_alpha"], "Reset Config",    C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.AscendBlessing = "Any"
    CFG.CPS = 10
    CPS = 10
    CFG.AutoSave = true
    saveCFG()
    if _blessLabel then _blessLabel.Text = CFG.AscendBlessing end
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_POTATO_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Idle Potato Game",           C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),       C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),  C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",        C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                         C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                 C.text3, nSb())
infoRow(scrolls["Settings_beta"], "Network", "Standard Remotes",           C.text3, nSb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSb())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 200),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSb(),
}, scrolls["Settings_beta"])

--========================================================================
-- POPULATE: LIVE GAME (persistent)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
local _liveStatus  = infoRow(liveScroll, "Status",  "Idle", C.pink,  nL())

sectionHeader(liveScroll, "●", "Player", nL())
local _liveHealth  = infoRow(liveScroll, "Health", "---", C.text,  nL())
local _liveSpeed   = infoRow(liveScroll, "Speed",  "16",  C.text,  nL())

sectionHeader(liveScroll, "▣", "Farm", nL())
local _liveClicks  = infoRow(liveScroll, "Clicks",  "0", C.pink,  nL())
local _liveSells   = infoRow(liveScroll, "Sells",   "0", C.pink,  nL())
local _liveCPS     = infoRow(liveScroll, "CPS",     tostring(CPS), C.text, nL())

sectionHeader(liveScroll, "◆", "Progress", nL())
local _livePrest   = infoRow(liveScroll, "Prestiges", "0", C.pink, nL())
local _liveDigs    = infoRow(liveScroll, "Digs",      "0", C.pink, nL())
local _liveFuses   = infoRow(liveScroll, "Fuses",     "0", C.pink, nL())
local _liveMyst    = infoRow(liveScroll, "Mystery",   "0", C.pink, nL())

sectionHeader(liveScroll, "✦", "Shop", nL())
local _liveUpg     = infoRow(liveScroll, "Upg",   "0", C.text2, nL())
local _liveGens    = infoRow(liveScroll, "Gens",  "0", C.text2, nL())
local _liveShop    = infoRow(liveScroll, "Shop",  "0", C.text2, nL())

--========================================================================
-- FLOATING PILL
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

-- Outer glow halo (behind the dot)
local pillDotGlow = create("Frame", {
    Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.78,
    BorderSizePixel = 0, ZIndex = 1,
}, pill)
corner(pillDotGlow, 9)

-- Inner glow ring (middle layer)
local pillDotGlowInner = create("Frame", {
    Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.55,
    BorderSizePixel = 0, ZIndex = 2,
}, pill)
corner(pillDotGlowInner, 6)

-- Solid dot on top
local pillDot = create("Frame", {
    Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
    BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3,
}, pill)
corner(pillDot, 4)

-- Breathing pulse
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
    outerTween:Play()
    innerTween:Play()
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
local _pillActive = create("TextLabel", {
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
-- DRAG (unified — wordmark row + full-width top strip)
--========================================================================
local topDragStrip = create("Frame", {
    Name = "TopDragStrip",
    Size = UDim2.fromOffset(TOTAL_W - SIDEBAR_W, 48),
    Position = UDim2.fromOffset(SIDEBAR_W, 0),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 3,
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

-- Global outside-click handler for popups
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
-- CLOSE + MINIMIZE BUTTONS (top-right)
--========================================================================
local minBtn = create("Frame", {
    Name = "Minimize",
    Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 62, 13),
    BackgroundColor3 = C.bg3,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
}, content)
corner(minBtn, 11)
stroke(minBtn, C.border2, 1, 0)

local minLine = create("Frame", {
    Size = UDim2.fromOffset(10, 2),
    Position = UDim2.new(0.5, -5, 0.5, -1),
    BackgroundColor3 = C.text2,
    BorderSizePixel = 0,
    ZIndex = 6,
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
    Name = "Close",
    Size = UDim2.fromOffset(22, 22),
    Position = UDim2.fromOffset(TOTAL_W - 32, 13),
    BackgroundColor3 = C.bg3,
    BorderSizePixel = 0,
    Active = true,
    ZIndex = 5,
}, content)
corner(closeBtn, 11)
stroke(closeBtn, C.border2, 1, 0)

local closeX = create("TextLabel", {
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    Text = "×",
    Font = F_SANS_BOLD,
    TextSize = 16,
    TextColor3 = C.text2,
    ZIndex = 6,
}, closeBtn)

closeBtn.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.red
        closeX.TextColor3 = C.white
    elseif inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
        getgenv().__AURORA_POTATO_SESSION = 0
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
-- STATUS UPDATE LOOP
--========================================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            -- Player stats
            local hpTxt, spdTxt = "---", "16"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hpTxt = string.format("%.0f/%.0f", hum.Health, hum.MaxHealth)
                    spdTxt = tostring(math.floor(hum.WalkSpeed))
                end
            end

            -- Runtime
            local elapsed = tick() - _sessionStart
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Status mode (shows primary active loop)
            local active = {}
            if CFG.AutoClick then table.insert(active, "Click") end
            if CFG.AutoSell then table.insert(active, "Sell") end
            if CFG.AutoBuyUpgrades then table.insert(active, "Upg") end
            if CFG.AutoBuyGenerators then table.insert(active, "Gen") end
            if CFG.AutoPrestige then table.insert(active, "Prest") end
            if CFG.AutoAscend then table.insert(active, "Asc") end
            if CFG.BoostSpam then table.insert(active, "Boost") end
            if CFG.AutoDig then table.insert(active, "Dig") end
            if CFG.AutoFusePotato then table.insert(active, "Fuse") end
            if CFG.AutoPrestigeUpgrade then table.insert(active, "PUpg") end
            if CFG.SmartBuyGenerator then table.insert(active, "SmGen") end
            if CFG.AutoBuyShop then table.insert(active, "Shop") end
            if CFG.AutoUsePotions then table.insert(active, "Pot") end
            if CFG.AutoOpenMysteryBox then table.insert(active, "MBox") end

            local mode = #active > 0 and table.concat(active, " + ") or "Idle"
            if #mode > 28 then mode = (#active) .. " active" end

            -- Farm tab
            _infoMode.Text       = mode
            _infoRuntime.Text    = rtime
            _infoClicks.Text     = fmt(S.clicks)
            _infoSells.Text      = tostring(S.sells)
            _infoDigs.Text       = tostring(S.digs)
            _infoFuses.Text      = tostring(S.fuses)
            _infoMystBox.Text    = tostring(S.mysteryBoxes)
            _infoCPS.Text        = tostring(CPS)

            -- Shop tab
            _infoUpgrades.Text   = tostring(S.upgrades)
            _infoGens.Text       = tostring(S.generators)
            _infoShopBuys.Text   = tostring(S.shopBuys)

            -- Progress tab
            _infoPrest.Text      = tostring(S.prestiges)
            _infoBlessing.Text   = CFG.AscendBlessing or "Any"

            -- Utility tab
            _infoHealth.Text     = hpTxt
            _infoSpeed.Text      = spdTxt
            _infoPotions.Text    = tostring(S.potionsUsed)

            -- Live Game
            _liveRuntime.Text    = rtime
            _liveStatus.Text     = mode
            _liveHealth.Text     = hpTxt
            _liveSpeed.Text      = spdTxt
            _liveClicks.Text     = fmt(S.clicks)
            _liveSells.Text      = tostring(S.sells)
            _liveCPS.Text        = tostring(CPS)
            _livePrest.Text      = tostring(S.prestiges)
            _liveDigs.Text       = tostring(S.digs)
            _liveFuses.Text      = tostring(S.fuses)
            _liveMyst.Text       = tostring(S.mysteryBoxes)
            _liveUpg.Text        = tostring(S.upgrades)
            _liveGens.Text       = tostring(S.generators)
            _liveShop.Text       = tostring(S.shopBuys)

            -- Active features list + pill counter
            local sortedActive = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    table.insert(sortedActive, "· " .. k)
                end
            end
            table.sort(sortedActive)
            _cfgActiveLabel.Text = #sortedActive > 0 and table.concat(sortedActive, "\n") or "None"
            _pillActive.Text = #sortedActive .. " active"
        end)
    end
end)

--========================================================================
-- INIT
--========================================================================
switchTab(CFG.ActiveTab or "Farm")

print("[Aurora v5] Idle Potato Game loaded")

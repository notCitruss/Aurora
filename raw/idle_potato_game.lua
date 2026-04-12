--// Aurora v3 — Idle Potato Game
--// Made by notCitruss | Dark Glass Theme
--// PlaceId: 122079988266644
--// 146 remotes — auto-click, auto-buy, auto-sell, auto-prestige, boost spam

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Player = Players.LocalPlayer

-- Cleanup
for _, n in {"Aurora", "TestAurora"} do
    pcall(function() local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end)
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild(n); if old then old:Destroy() end end)
    pcall(function() if gethui then local old = gethui():FindFirstChild(n); if old then old:Destroy() end end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_POTATO_CFG then
    for k, v in pairs(getgenv().__AURORA_POTATO_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_POTATO_CFG[k] = false end
    end
end
getgenv().__AURORA_POTATO_SESSION = tick()
local _mySession = getgenv().__AURORA_POTATO_SESSION
local function alive() return getgenv().__AURORA_POTATO_SESSION == _mySession end

---------- REMOTES ----------
local R = RS:FindFirstChild("Remotes")


---------- COMPAT (cross-executor support) ----------
local _HAS = {
    gethui    = typeof(gethui) == "function",
    writefile = writefile ~= nil,
    firepp    = fireproximityprompt ~= nil,
    hookfn    = hookfunction ~= nil,
    getgc     = getgc ~= nil,
    vim       = pcall(function() return game:GetService("VirtualInputManager") end),
}
local function safeFirePrompt(prompt)
    if _HAS.firepp then
        fireproximityprompt(prompt)
    else
        local od, oh = prompt.MaxActivationDistance, prompt.HoldDuration
        prompt.MaxActivationDistance = 9999; prompt.HoldDuration = 0
        prompt:InputHoldBegin(); task.wait(0.05); prompt:InputHoldEnd()
        prompt.MaxActivationDistance = od; prompt.HoldDuration = oh
    end
end
---------- CONFIG ----------
local CFG = {
    AutoClick = false,
    AutoSell = false,
    AutoBuyUpgrades = false,
    AutoBuyGenerators = false,
    AutoPrestige = false,
    AutoAscend = false,
    BoostSpam = false,
    AntiAFK = false,
    AutoDig = false,
    AutoFusePotato = false,
    AutoPrestigeUpgrade = false,
    AscendBlessing = "Any",
    SmartBuyGenerator = false,
    AutoBuyShop = false,
    AutoUsePotions = false,
    AutoOpenMysteryBox = false,
}

---------- TOGGLE SAVE/LOAD ----------
local _cfgFileName = "aurora_cfg_idle_potato_game.json"
local HttpService = game:GetService("HttpService")

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
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end)
    getgenv()["AuroraCFG_idle_potato_game"] = CFG
end

loadSavedCFG()

local function G() return CFG end

---------- STATE ----------
local S = {clicks = 0, sells = 0, upgrades = 0, generators = 0, prestiges = 0, digs = 0, fuses = 0, mysteryBoxes = 0, shopBuys = 0, potionsUsed = 0}

---------- UPGRADE/GENERATOR LISTS ----------
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

---------- CORE FUNCTIONS ----------

-- Auto-Click: adjustable CPS via slider
local CPS = 10 -- default 10, range 1-2500

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

---------- LOOPS ----------

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
        if G().AutoDig then pcall(doDig) end
        task.wait(jitter(2, 0.6))
        if not alive() then break end
    end
end)

-- Auto Fuse Potato: every 15s
task.spawn(function()
    while alive() do
        if G().AutoFusePotato then pcall(doFuse) end
        task.wait(jitter(15, 4.5))
        if not alive() then break end
    end
end)

-- Auto Prestige Upgrade: every 5s
task.spawn(function()
    while alive() do
        if G().AutoPrestigeUpgrade then pcall(doBuyPrestigeUpgrades) end
        task.wait(jitter(5, 1.5))
        if not alive() then break end
    end
end)

-- Auto Ascend with blessing: every 30s
task.spawn(function()
    while alive() do
        if G().AutoAscend then pcall(doAscendWithBlessing) end
        task.wait(jitter(30, 9.0))
        if not alive() then break end
    end
end)

-- Smart Buy Generator: every 5s
task.spawn(function()
    while alive() do
        if G().SmartBuyGenerator then pcall(doSmartBuyGenerator) end
        task.wait(jitter(5, 1.5))
        if not alive() then break end
    end
end)

-- Auto Buy Shop: every 30s
task.spawn(function()
    while alive() do
        if G().AutoBuyShop then pcall(doBuyShop) end
        task.wait(jitter(30, 9.0))
        if not alive() then break end
    end
end)

-- Auto Use Potions: every 30s
task.spawn(function()
    while alive() do
        if G().AutoUsePotions then pcall(doUsePotions) end
        task.wait(jitter(30, 9.0))
        if not alive() then break end
    end
end)

-- Auto Open Mystery Box: every 10s
task.spawn(function()
    while alive() do
        if G().AutoOpenMysteryBox then pcall(doOpenMysteryBox) end
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

-- ============================================================
-- V2 SIDEBAR UI
-- ============================================================

local C = {
    bg       = Color3.fromRGB(20, 20, 20),
    sidebar  = Color3.fromRGB(25, 25, 25),
    panel    = Color3.fromRGB(30, 30, 30),
    card     = Color3.fromRGB(35, 35, 35),
    accent   = Color3.fromRGB(252, 110, 142),
    accentDim = Color3.fromRGB(180, 80, 110),
    text     = Color3.fromRGB(255, 255, 255),
    dim      = Color3.fromRGB(150, 150, 150),
    green    = Color3.fromRGB(0, 200, 100),
    red      = Color3.fromRGB(255, 80, 80),
    trackOff = Color3.fromRGB(60, 60, 60),
    knobOff  = Color3.fromRGB(90, 90, 90),
    stroke   = Color3.fromRGB(80, 80, 80),
    sliderBg = Color3.fromRGB(45, 45, 45),
}

---------- UI HELPERS ----------
local function create(class, props, parent)
    local inst = Instance.new(class)
    for k, v in props do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function corner(p, r) return create("UICorner", { CornerRadius = UDim.new(0, r) }, p) end
local function stroke(p, col, th, tr)
    return create("UIStroke", { Color = col, Thickness = th or 1, Transparency = tr or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p)
end
local function lbl(parent, props)
    local d = { BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, BorderSizePixel = 0, Active = false }
    for k, v in d do if props[k] == nil then props[k] = v end end
    return create("TextLabel", props, parent)
end
local function connectClick(frame, cb)
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then cb() end
    end)
end

---------- SCREEN GUI ----------
local gui = create("ScreenGui", {
    Name = "Aurora", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, IgnoreGuiInset = true,
})
local _isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
local parentOk = false
if _isMobile then
    parentOk = pcall(function() gui.Parent = Player.PlayerGui end)
end
if not parentOk then
    parentOk = pcall(function()
        gui.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
end
if not parentOk then pcall(function() gui.Parent = Player.PlayerGui end) end

---------- MOBILE DETECTION + SCALING ----------
local _viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _isMobile = UIS.TouchEnabled and (_viewport.X < 1200)
local _scale = _isMobile and math.clamp(_viewport.X / 700, 0.55, 0.85) or 1

---------- LAYOUT ----------
local SIDEBAR_W  = 110
local TOTAL_W    = 660
local TOTAL_H    = 455
local TOP_H      = 40
local GAP        = 6
local CONTENT_X  = SIDEBAR_W + GAP
local CONTENT_Y  = TOP_H + 4
local CONTENT_H  = TOTAL_H - CONTENT_Y - 6
local AVAIL_W    = TOTAL_W - CONTENT_X - 6
local LEFT_PW    = math.floor(AVAIL_W * 0.58)
local RIGHT_PW   = AVAIL_W - LEFT_PW - GAP

---------- MAIN ----------
local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = _isMobile and UDim2.new(0.5, -TOTAL_W * _scale / 2, 0, 40) or UDim2.fromOffset(16, 60),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, gui)
corner(main, 12)
stroke(main, C.stroke, 1, 0.2)
if _scale ~= 1 then create("UIScale", { Scale = _scale }, main) end

---------- TOP BAR ----------
local topBar = create("Frame", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, TOP_H), Position = UDim2.fromOffset(0, 0),
    BackgroundColor3 = C.sidebar, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 5,
}, main)
corner(topBar, 12)
create("Frame", {
    Name = "TopDivider", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = C.stroke, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5,
}, topBar)

create("ImageLabel", {
    Name = "Logo", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 6),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181", ScaleType = Enum.ScaleType.Fit, ZIndex = 6,
}, topBar)

lbl(topBar, {
    Name = "Title", Size = UDim2.new(0, 80, 1, 0), Position = UDim2.fromOffset(44, 0),
    Text = "Aurora", TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = C.accent, ZIndex = 6,
})

local gameName = "Idle Potato Game"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
lbl(topBar, {
    Name = "Game", Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(1, -310, 0, 0),
    Text = gameName, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
})

-- Minimize
local minBtn = create("Frame", {
    Name = "Min", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(minBtn, { Size = UDim2.new(1,0,1,0), Text = "\xE2\x80\x93", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })

-- Close
local closeBtn = create("Frame", {
    Name = "Close", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(closeBtn, { Size = UDim2.new(1,0,1,0), Text = "x", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })

-- Drag handle
local dragHandle = create("Frame", {
    Name = "DragHandle", Size = UDim2.new(1, -80, 1, 0),
    BackgroundTransparency = 1, Active = true, ZIndex = 5,
}, topBar)
do
    local dragging, dragStart, startPos = false, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; dragStart = input.Position; startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
end

---------- MINIMIZE FLOWER ----------
local flower = create("Frame", {
    Name = "Flower", Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(16, 60),
    BackgroundColor3 = C.accent, BackgroundTransparency = 0.3,
    BorderSizePixel = 0, Visible = false, Active = true,
}, gui)
corner(flower, 22)
stroke(flower, C.accent, 2, 0.2)
create("ImageLabel", {
    Size = UDim2.new(0.7, 0, 0.7, 0), Position = UDim2.new(0.15, 0, 0.15, 0),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit,
}, flower)

connectClick(flower, function()
    flower.Visible = false
    main.Position = flower.Position
end)

connectClick(minBtn, function()
    flower.Position = main.Position
    main.Position = UDim2.fromOffset(-9999, -9999)
    flower.Visible = true
end)
connectClick(closeBtn, function() gui:Destroy() end)


---------- SIDEBAR ----------
local sidebar = create("Frame", {
    Name = "Sidebar", Size = UDim2.new(0, SIDEBAR_W, 1, -TOP_H),
    Position = UDim2.fromOffset(0, TOP_H), BackgroundColor3 = C.sidebar, BackgroundTransparency = 0, BorderSizePixel = 0,
    ClipsDescendants = true,
}, main)
corner(sidebar, 12)

create("Frame", {
    Name = "Divider", Size = UDim2.new(0, 1, 1, -8), Position = UDim2.new(1, 0, 0, 4),
    BackgroundColor3 = C.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
}, sidebar)

local TAB_DEFS = {
    { name = "Farm",    color = Color3.fromRGB(255, 200, 0) },
    { name = "Utility", color = Color3.fromRGB(180, 130, 255) },
}
local CONFIG_TAB = { name = "Config", color = Color3.fromRGB(130, 130, 155) }

local tabBtns = {}
local leftContainers = {}
local rightContainers = {}

local tabList = create("Frame", {
    Name = "TabList", Size = UDim2.new(1, -8, 0, #TAB_DEFS * 40 + 4),
    Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1, BorderSizePixel = 0,
}, sidebar)
create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, tabList)

local function makeTabBtn(def, idx, parent)
    local btn = create("Frame", {
        Name = "Tab_" .. def.name, Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.card, BackgroundTransparency = 0.5, BorderSizePixel = 0, Active = true, LayoutOrder = idx,
    }, parent)
    corner(btn, 8)

    local indicator = create("Frame", {
        Name = "Indicator", Size = UDim2.new(0, 3, 0, 22), Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = def.color or C.accent, BackgroundTransparency = 1, BorderSizePixel = 0,
    }, btn)
    corner(indicator, 2)

    lbl(btn, {
        Name = "Label", Size = UDim2.new(1, 0, 1, 0), Position = UDim2.fromOffset(0, 0),
        Text = def.name, TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    return btn, indicator
end

local allTabs = {}
for i, def in ipairs(TAB_DEFS) do
    local btn, ind = makeTabBtn(def, i, tabList)
    allTabs[i] = { btn = btn, indicator = ind, name = def.name }
end

local configBtn, configInd = makeTabBtn(CONFIG_TAB, 99, nil)
configBtn.Parent = sidebar
configBtn.Position = UDim2.new(0, 4, 1, -44)
configBtn.Size = UDim2.new(1, -8, 0, 36)
allTabs[#TAB_DEFS + 1] = { btn = configBtn, indicator = configInd, name = "Config" }

---------- CONTENT PANELS ----------
local function makePanel(name, xPos, width)
    local p = create("ScrollingFrame", {
        Name = name, Size = UDim2.new(0, width, 0, CONTENT_H),
        Position = UDim2.fromOffset(xPos, CONTENT_Y),
        BackgroundColor3 = C.panel, BackgroundTransparency = 0.10, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
        TopImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        MidImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    }, main)
    corner(p, 10)
    stroke(p, C.stroke, 1, 0.4)
    create("UIPadding", { PaddingTop = UDim.new(0,8), PaddingLeft = UDim.new(0,10), PaddingRight = UDim.new(0,10), PaddingBottom = UDim.new(0,10) }, p)
    local layout = create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, p)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
    end)
    return p
end

local TOTAL_TABS = #TAB_DEFS + 1
for i = 1, TOTAL_TABS do
    local tabName = (i <= #TAB_DEFS) and TAB_DEFS[i].name or "Config"
    local lp = makePanel("L_" .. tabName, CONTENT_X, LEFT_PW)
    local rp = makePanel("R_" .. tabName, CONTENT_X + LEFT_PW + GAP, RIGHT_PW)
    lp.Visible = (i == 1)
    rp.Visible = (i == 1)
    leftContainers[i] = lp
    rightContainers[i] = rp
end

---------- SWITCH TAB ----------
local activeTabIdx = 1

local function switchTab(idx)
    activeTabIdx = idx
    for i, t in ipairs(allTabs) do
        local active = (i == idx)
        t.btn.BackgroundTransparency = active and 0.15 or 0.5
        t.indicator.BackgroundTransparency = active and 0 or 1
        local lblInst = t.btn:FindFirstChild("Label")
        if lblInst then lblInst.TextColor3 = active and C.text or C.dim end
    end
    for i = 1, TOTAL_TABS do
        leftContainers[i].Visible = (i == idx)
        rightContainers[i].Visible = (i == idx)
    end
end

for i, t in ipairs(allTabs) do
    local ci = i
    connectClick(t.btn, function() switchTab(ci) end)
end

---------- COMPONENT BUILDERS ----------
local _order = {}
local _curLeft, _curRight = nil, nil

local function setPanel(leftP, rightP)
    _curLeft = leftP; _curRight = rightP
    _order[leftP] = 0; _order[rightP] = 0
end

local function nextOrder(panel)
    _order[panel] = (_order[panel] or 0) + 1
    return _order[panel]
end

local function sectionHeader(title, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    create("Frame", { Size = UDim2.new(1,0,0,2), BackgroundTransparency = 1, LayoutOrder = o }, panel)
    o = nextOrder(panel)
    local row = create("Frame", { Size = UDim2.new(1,0,0,24), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0 }, panel)
    create("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, row)
    corner(row:FindFirstChild("Frame"), 2)
    lbl(row, { Size = UDim2.new(1,-12,1,0), Position = UDim2.fromOffset(12, 0), Text = string.upper(title), TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = C.accent })
end

local function toggleRow(name, cfgKey, panel, callback)
    panel = panel or _curLeft
    if CFG[cfgKey] == nil then CFG[cfgKey] = false end
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "T_" .. name, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)

    lbl(row, { Size = UDim2.new(1,-60,1,0), Position = UDim2.fromOffset(10,0), Text = name, TextSize = 13, Font = Enum.Font.Gotham })

    local track = create("Frame", {
        Name = "Track", Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1,-48, 0.5,-10),
        BackgroundColor3 = CFG[cfgKey] and C.accent or C.trackOff, BorderSizePixel = 0,
    }, row)
    corner(track, 10)

    local knob = create("Frame", {
        Name = "Knob", Size = UDim2.fromOffset(16, 16),
        Position = CFG[cfgKey] and UDim2.new(1,-18, 0.5,-8) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = CFG[cfgKey] and Color3.new(1,1,1) or C.knobOff, BorderSizePixel = 0,
    }, track)
    corner(knob, 8)

    local function updateVisual()
        local on = CFG[cfgKey]
        TweenService:Create(track, TweenInfo.new(0.15), { BackgroundColor3 = on and C.accent or C.trackOff }):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.new(1,-18, 0.5,-8) or UDim2.fromOffset(2, 2),
            BackgroundColor3 = on and Color3.new(1,1,1) or C.knobOff,
        }):Play()
    end

    connectClick(row, function()
        CFG[cfgKey] = not CFG[cfgKey]
        updateVisual()
        if CFG.AutoSave then saveCFG() end
        if callback then callback(CFG[cfgKey]) end
    end)

    return row, updateVisual
end

local function sliderRow(name, cfgKey, min, max, step, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "S_" .. name, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)

    lbl(row, { Size = UDim2.new(0.5,0,0,20), Position = UDim2.fromOffset(10,2), Text = name, TextSize = 12, Font = Enum.Font.Gotham })

    local valLabel = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5,-20,0,20), Position = UDim2.new(0.5,10,0,2),
        Text = tostring(CFG[cfgKey]), TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    })

    local trackFrame = create("Frame", {
        Name = "SlTrack", Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 30),
        BackgroundColor3 = C.sliderBg, BorderSizePixel = 0, Active = true,
    }, row)
    corner(trackFrame, 3)

    local pct = math.clamp((CFG[cfgKey] - min) / (max - min), 0, 1)
    local fill = create("Frame", {
        Name = "Fill", Size = UDim2.new(pct, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0,
    }, trackFrame)
    corner(fill, 3)

    local knobSize = 14
    local sKnob = create("Frame", {
        Name = "Knob", Size = UDim2.fromOffset(knobSize, knobSize),
        Position = UDim2.new(pct, -knobSize/2, 0.5, -knobSize/2),
        BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 3,
    }, trackFrame)
    corner(sKnob, knobSize/2)

    local sliding = false
    local function updateSlider(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        local raw = math.clamp((inputX - absPos) / absSize, 0, 1)
        local val = min + raw * (max - min)
        val = math.floor(val / step + 0.5) * step
        val = math.clamp(val, min, max)
        if step >= 1 then val = math.floor(val) end
        CFG[cfgKey] = val
        local newPct = math.clamp((val - min) / (max - min), 0, 1)
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        sKnob.Position = UDim2.new(newPct, -knobSize/2, 0.5, -knobSize/2)
        valLabel.Text = (step < 1) and string.format("%.1f", val) or tostring(val)
        if CFG.AutoSave then saveCFG() end
    end

    trackFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true; updateSlider(input.Position.X)
        end
    end)
    sKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = true
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            updateSlider(input.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            sliding = false
        end
    end)

    return row
end

local function infoRow(name, initialValue, panel)
    panel = panel or _curRight
    local o = nextOrder(panel)
    local row = create("Frame", {
        Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0,
    }, panel)
    lbl(row, { Size = UDim2.new(0.5,0,1,0), Position = UDim2.fromOffset(4,0), Text = name, TextSize = 10, Font = Enum.Font.GothamSemibold, TextColor3 = C.dim })
    local val = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5,-4,1,0), Position = UDim2.new(0.5,0,0,0),
        Text = initialValue or "---", TextSize = 10, Font = Enum.Font.GothamBold,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
    })
    return val
end

local function actionButton(name, color, panel, callback)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local btn = create("Frame", {
        Name = "A_" .. name, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color or C.accent,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(btn, 8)
    local btnLabel = lbl(btn, {
        Size = UDim2.new(1,0,1,0), Text = name, TextSize = 11, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.text,
    })
    connectClick(btn, function()
        if callback then callback() end
        local orig = btnLabel.Text
        btnLabel.Text = name .. " ..."
        btnLabel.TextColor3 = C.green
        task.delay(1.5, function() btnLabel.Text = orig; btnLabel.TextColor3 = C.text end)
    end)
    return btn
end

---------- TAB 1: FARM ----------
setPanel(leftContainers[1], rightContainers[1])

sectionHeader("Farming", _curLeft)
toggleRow("Auto-Click", "AutoClick", _curLeft)
-- CPS slider (uses CPS variable, not CFG key directly)
do
    if not CFG.CPS then CFG.CPS = CPS end
    CPS = CFG.CPS
    local o = nextOrder(_curLeft)
    local row = create("Frame", {
        Name = "S_CPS", Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, _curLeft)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(0.5,0,0,20), Position = UDim2.fromOffset(10,2), Text = "CPS", TextSize = 12, Font = Enum.Font.Gotham })
    local valLabel = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5,-20,0,20), Position = UDim2.new(0.5,10,0,2),
        Text = tostring(CPS), TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    })
    local trackFrame = create("Frame", {
        Name = "SlTrack", Size = UDim2.new(1, -20, 0, 6), Position = UDim2.fromOffset(10, 30),
        BackgroundColor3 = C.sliderBg, BorderSizePixel = 0, Active = true,
    }, row)
    corner(trackFrame, 3)
    local pct = math.clamp((CPS - 1) / (2500 - 1), 0, 1)
    local fill = create("Frame", { Name = "Fill", Size = UDim2.new(pct, 0, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, trackFrame)
    corner(fill, 3)
    local knobSize = 14
    local sKnob = create("Frame", { Name = "Knob", Size = UDim2.fromOffset(knobSize, knobSize), Position = UDim2.new(pct, -knobSize/2, 0.5, -knobSize/2), BackgroundColor3 = Color3.new(1,1,1), BorderSizePixel = 0, ZIndex = 3 }, trackFrame)
    corner(sKnob, knobSize/2)
    local sliding = false
    local function updateSlider(inputX)
        local absPos = trackFrame.AbsolutePosition.X
        local absSize = trackFrame.AbsoluteSize.X
        local frac = math.clamp((inputX - absPos) / absSize, 0, 1)
        local expVal = 1 * (2500 / 1) ^ frac
        local val = math.clamp(math.floor(expVal), 1, 2500)
        CPS = val
        local newPct = frac
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        sKnob.Position = UDim2.new(newPct, -knobSize/2, 0.5, -knobSize/2)
        valLabel.Text = tostring(val)
    end
    trackFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = true; updateSlider(input.Position.X) end
    end)
    sKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = true end
    end)
    UIS.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then updateSlider(input.Position.X) end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)
end
toggleRow("Auto-Sell All", "AutoSell", _curLeft)
toggleRow("Auto Dig", "AutoDig", _curLeft)
toggleRow("Auto Fuse Potato", "AutoFusePotato", _curLeft)
toggleRow("Auto Open Mystery Box", "AutoOpenMysteryBox", _curLeft)

sectionHeader("Upgrades & Shop", _curLeft)
toggleRow("Auto-Buy Click Upgrades", "AutoBuyUpgrades", _curLeft)
toggleRow("Auto-Buy Generators", "AutoBuyGenerators", _curLeft)
toggleRow("Smart Buy Generator", "SmartBuyGenerator", _curLeft)
toggleRow("Auto Buy Shop", "AutoBuyShop", _curLeft)

sectionHeader("Progression", _curLeft)
toggleRow("Auto-Prestige", "AutoPrestige", _curLeft)
toggleRow("Auto Prestige Upgrade", "AutoPrestigeUpgrade", _curLeft)
toggleRow("Auto-Ascend", "AutoAscend", _curLeft)
toggleRow("Boost Spam", "BoostSpam", _curLeft)

-- Right: Session Stats
sectionHeader("Session", _curRight)
local clicksV = infoRow("Clicks Sent", "0", _curRight)
local sellsV = infoRow("Sell Cycles", "0", _curRight)
local upgradesV = infoRow("Upgrade Cycles", "0", _curRight)
local gensV = infoRow("Generator Cycles", "0", _curRight)
local prestV = infoRow("Prestiges", "0", _curRight)
local digsV = infoRow("Dig Rounds", "0", _curRight)
local fusesV = infoRow("Fuse Cycles", "0", _curRight)
local mystBoxV = infoRow("Mystery Boxes", "0", _curRight)
local shopBuysV = infoRow("Shop Buys", "0", _curRight)
local potionsV = infoRow("Potions Used", "0", _curRight)

sectionHeader("Status", _curRight)
local _infoStatus = infoRow("Mode", "Idle", _curRight)

---------- TAB 2: UTILITY ----------
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Safety", _curLeft)
toggleRow("Anti-AFK", "AntiAFK", _curLeft)
toggleRow("Auto Use Potions", "AutoUsePotions", _curLeft)

sectionHeader("Ascension", _curLeft)
-- Ascend Blessing cycling selector
do
    local o = nextOrder(_curLeft)
    local row = create("Frame", {
        Name = "Cyc_AscendBlessing", Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, _curLeft)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(10, 0), Text = "Blessing", TextSize = 13, Font = Enum.Font.Gotham })
    local valLbl = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5, -20, 1, 0), Position = UDim2.new(0.5, 10, 0, 0),
        Text = CFG.AscendBlessing or "Any", TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    })
    connectClick(row, function()
        local cur = CFG.AscendBlessing or "Any"
        local idx = 1
        for i, v in BLESSINGS do
            if v == cur then idx = i; break end
        end
        idx = (idx % #BLESSINGS) + 1
        CFG.AscendBlessing = BLESSINGS[idx]
        valLbl.Text = BLESSINGS[idx]
        if CFG.AutoSave then saveCFG() end
    end)
end

sectionHeader("Actions", _curLeft)
actionButton("Sell All Potatoes", C.accent, _curLeft, doSell)
actionButton("Prestige Now", C.accent, _curLeft, doPrestige)
actionButton("Ascend Now", C.green, _curLeft, doAscendWithBlessing)
actionButton("Claim All Rewards", C.green, _curLeft, doBoosts)
actionButton("Fuse Potatoes", C.accent, _curLeft, doFuse)
actionButton("Open Mystery Box", C.accent, _curLeft, doOpenMysteryBox)
actionButton("Buy Shop Items", C.accent, _curLeft, doBuyShop)

sectionHeader("Info", _curRight)
infoRow("Game", gameName, _curRight)
infoRow("PlaceId", tostring(game.PlaceId), _curRight)
infoRow("Blessing", CFG.AscendBlessing or "Any", _curRight)

---------- TAB 3: CONFIG ----------
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Config Management", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)

actionButton("Save Config", C.green, _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function() loadSavedCFG() end)
actionButton("Reset All", C.red, _curLeft, function()
    for k, v in CFG do
        if type(v) == "boolean" then CFG[k] = false end
    end
    CFG.AscendBlessing = "Any"
    CFG.AutoSave = true
    saveCFG()
end)

sectionHeader("Config Info", _curRight)
infoRow("File", _cfgFileName, _curRight)

sectionHeader("Active Features", _curRight)
local _cfgActiveList = lbl(rightContainers[3], {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 120),
    Text = "None", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    LayoutOrder = nextOrder(rightContainers[3]),
})

---------- STATUS UPDATE LOOP ----------
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.5))
        if not alive() then break end
        pcall(function()
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

            _infoStatus.Text = #active > 0 and table.concat(active, " + ") or "Idle"

            clicksV.Text = tostring(S.clicks)
            sellsV.Text = tostring(S.sells)
            upgradesV.Text = tostring(S.upgrades)
            gensV.Text = tostring(S.generators)
            prestV.Text = tostring(S.prestiges)
            digsV.Text = tostring(S.digs)
            fusesV.Text = tostring(S.fuses)
            mystBoxV.Text = tostring(S.mysteryBoxes)
            shopBuysV.Text = tostring(S.shopBuys)
            potionsV.Text = tostring(S.potionsUsed)

            -- Config active list
            local activeList = {}
            for k, v in CFG do
                if type(v) == "boolean" and v and k ~= "AutoSave" then table.insert(activeList, k) end
            end
            _cfgActiveList.Text = #activeList > 0 and table.concat(activeList, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #activeList * 14 + 10))
        end)
    end
end)

-- Init first tab
switchTab(1)

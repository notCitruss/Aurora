--// Aurora v5 — Bee Garden
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 81535567274521
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// HONEYPOT WARNING: DO NOT fire HackerEvent, GodHandler, AdminEvent, AdminShopHandler
--// Xeno compat: all fireproximityprompt calls go through safeFirePrompt() which
--// fires the native API AND falls back to InputHoldBegin/End since Xeno's firepp silently fails.

--========================================================================
-- SERVICES
--========================================================================
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local RS           = game:GetService("ReplicatedStorage")
local Player       = Players.LocalPlayer

--========================================================================
-- CLEANUP (old + new gui names)
--========================================================================
for _, n in ipairs({"Aurora", "AuroraHubUI", "AuroraHubPill"}) do
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function()
        if typeof(gethui) == "function" then
            local o = gethui():FindFirstChild(n); if o then o:Destroy() end
        end
    end)
end

--========================================================================
-- SESSION KILL + alive()  (PRESERVED __AURORA_BG_ prefix)
--========================================================================
if getgenv().__AURORA_BG_CFG then
    for k, v in pairs(getgenv().__AURORA_BG_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_BG_CFG[k] = false end
    end
end
if getgenv().__AURORA_BG_CFG2 then
    for k, v in pairs(getgenv().__AURORA_BG_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_BG_CFG2[k] = false end
    end
end
getgenv().__AURORA_BG_SESSION = tick()
local _mySession = getgenv().__AURORA_BG_SESSION
local function alive() return getgenv().__AURORA_BG_SESSION == _mySession end

--========================================================================
-- REMOTES
--========================================================================
local Events = RS:WaitForChild("Events", 15)
if not Events then warn("[Aurora] Events folder not found"); return end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

-- Cross-executor prompt firing: native fireproximityprompt on Wave/Potassium/Delta/Fluxus,
-- InputHoldBegin/End fallback for Xeno (where fireproximityprompt exists but silently fails).
local _HAS_FIREPP = typeof(fireproximityprompt) == "function"
local function safeFirePrompt(prompt)
    if not (prompt and prompt.Parent) then return end
    if _HAS_FIREPP then
        safeFirePrompt(prompt)
    end
    -- Always run the InputHoldBegin fallback too (fire both) — safe on all executors.
    pcall(function()
        local oh = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(0.1)
        prompt:InputHoldEnd()
        if prompt and prompt.Parent then prompt.HoldDuration = oh end
    end)
end

--========================================================================
-- WORKSPACE DESCENDANTS CACHE
--========================================================================
local _wsDescCache = {}
local _wsDescLastRefresh = 0
local _WS_DESC_TTL = 4
local function getWsDescendants()
    local now = tick()
    if now - _wsDescLastRefresh >= _WS_DESC_TTL then
        _wsDescCache = workspace:GetDescendants()
        _wsDescLastRefresh = now
    end
    return _wsDescCache
end

--========================================================================
-- CONFIG (getgenv shared — survives re-execute)
--========================================================================
if not getgenv().__AURORA_BG_CFG2 then
    getgenv().__AURORA_BG_CFG2 = {
        -- Farm tab
        AutoBuyConveyorEgg  = false,
        AutoSkipEggs        = false,
        AutoCollectCoins    = false,
        -- Bees tab
        AutoBuyBee          = false,
        AutoEquipBest       = false,
        AutoFuse            = false,
        SelectedBee         = "Any",
        -- Auto tab
        AutoSell            = false,
        AutoDaily           = false,
        AutoArcade          = false,
        AutoLuckyBlock      = false,
        AutoChest           = false,
        AutoDelivery        = false,
        AutoPlaytime        = false,
        AutoFollow          = false,
        AutoAchievements    = false,
        AutoClaimAll        = false,
        AutoEventShop       = false,
        -- Events tab
        AutoCollectOrbs     = false,
        AutoCollectTickets  = false,
        AutoEventSignup     = false,
        EasterESP           = false,
        AutoEasterEggs      = false,
        AutoMeteorons       = false,
        AutoGhostBees       = false,
        -- Utility tab
        SpeedBoost          = false,
        SpeedValue          = 50,
        AntiAFK             = false,
        AutoSwatter         = false,
        -- NEW (2026-04-21 audit): new claim loops + AC-safer TPs
        AutoSpecialEvent    = false,
        AutoFountain        = false,
        AutoPotion          = false,
        AutoBooth           = false,
        SlowTpMode          = false,
        -- Config tab
        AutoSave            = false,
        -- v5 UI state
        ActiveTab           = "Farm",
        PanelOpen           = true,
    }
end
local CFG = getgenv().__AURORA_BG_CFG2
local function G() return getgenv().__AURORA_BG_CFG2 end

--========================================================================
-- SELECTION MAPS (preserved verbatim from v4)
--========================================================================
local BEE_SHOP_NAMES = {
    "Daisy Bee", "Lobelia Bee", "Cornflower Bee", "Spider Lilly Bee",
    "Dandelion Bee", "Unicorn Bee", "Nuzwat Bee", "Orchid Bee",
    "Rose Bee", "Snowdrifter Bee", "Glowberry Bee", "Frostbit Bee",
    "Twilight Bee", "Fairy Queentessa Bee",
}
local SelBees = { ["All"] = true }

local EGG_NAMES = {
    "Basic Egg", "Uncommon Egg", "Rare Egg", "Epic Egg", "More Epic Egg",
    "Legendary Egg", "Secret Egg", "Mystery Egg", "VIP Egg", "Inspector Egg",
    "Radiant Egg", "Solar Egg", "Permafrost Egg", "Void Egg", "Meteor Egg",
    "Arcade Egg", "Fairy Egg", "Duality Egg", "Brainrot Egg", "Blizzard Egg",
    "Alien Egg", "Easter Egg", "Playtime Egg", "Christmas Egg", "Snowy Egg",
    "Prism Egg", "Crystal Egg", "Toxic Egg", "Blaze Egg",
}
local SelEggs = { ["All"] = true }

--========================================================================
-- ZONE NAMES (preserved verbatim from v4)
--========================================================================
local ZONE_NAMES = {
    "Spawn", "Meadow", "Forest", "Desert", "Arctic",
    "Volcano", "Ocean", "Swamp", "Jungle", "Space",
}

--========================================================================
-- SAVE / LOAD (preserved _cfgFileName verbatim)
--========================================================================
local _cfgFileName = "aurora_cfg_bee_garden.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._SelBees then for k in pairs(SelBees) do SelBees[k] = nil end; for k, v in pairs(saved._SelBees) do SelBees[k] = v end end
        if saved._SelEggs then for k in pairs(SelEggs) do SelEggs[k] = nil end; for k, v in pairs(saved._SelEggs) do SelEggs[k] = v end end
    end
end

local function saveCFG()
    local d = {}; for k, v in pairs(CFG) do d[k] = v end
    d._SelBees = SelBees; d._SelEggs = SelEggs
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(d)) end)
end

loadSavedCFG()

--========================================================================
-- BEE DATA (preserved verbatim)
--========================================================================
local BEE_LIST = {"Any"}
local BEE_DATA = {}
do
    local ok, Bees = pcall(function() return require(RS.Modules.Gameplay.Shared_Bees) end)
    if ok and Bees and Bees.List then
        local sorted = {}
        for k, v in pairs(Bees.List) do
            if typeof(v) == "table" and not v.BeeShopExcluded and not v.Exclusive and v.Price then
                table.insert(sorted, { id = k, name = v.AssetName or k, price = tonumber(v.Price) or 0, rarity = v.Rarity or "?" })
            end
        end
        table.sort(sorted, function(a, b) return a.price < b.price end)
        for _, b in ipairs(sorted) do
            table.insert(BEE_LIST, b.id)
            BEE_DATA[b.id] = b
        end
    end
end

--========================================================================
-- HELPERS
--========================================================================
local function formatNum(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e12 then return string.format("%.2fT", n / 1e12)
    elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function getCoins()
    local data = Player:FindFirstChild("Data")
    return data and data:FindFirstChild("Coins") and data.Coins.Value or 0
end

-- Find player's plot by nearest ConveyorModel proximity
local _cachedPlot = nil
local function getMyPlot()
    if _cachedPlot and _cachedPlot.Parent then return _cachedPlot end
    local char = Player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local plots = workspace:FindFirstChild("Core") and workspace.Core:FindFirstChild("Scriptable") and
        workspace.Core.Scriptable:FindFirstChild("Plots")
    if not plots then return nil end
    local best, bestDist = nil, math.huge
    for _, plot in ipairs(plots:GetChildren()) do
        local conv = plot:FindFirstChild("ConveyorModel")
        if conv then
            for _, p in ipairs(conv:GetDescendants()) do
                if p:IsA("BasePart") then
                    local dist = (hrp.Position - p.Position).Magnitude
                    if dist < bestDist then bestDist = dist; best = plot end
                    break
                end
            end
        end
    end
    _cachedPlot = best
    return best
end

--========================================================================
-- SESSION STATS
--========================================================================
local S = {
    session      = tick(),
    eggsBought   = 0,
    coinsCollect = 0,
    status       = "Idle",
    beeCount     = 0,
}

--========================================================================
-- SHOP STOCK (from server events)
--========================================================================
local _shopStock = {}
pcall(function()
    Events.BeeShopHandler.OnClientEvent:Connect(function(action, data)
        if action == "Restocked" and typeof(data) == "table" then _shopStock = data end
    end)
end)

--========================================================================
-- CORE GAME FUNCTIONS (preserved verbatim)
--========================================================================

-- AC-safer teleport: when SlowTpMode is on, breaks long jumps into intermediate steps
-- so character velocity stays realistic. Default OFF — normal snap CFrame is already safe.
local function safeTP(targetPos)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    if not G().SlowTpMode then
        hrp.CFrame = CFrame.new(targetPos)
        return
    end
    local STEP = 45 -- studs per hop
    local from = hrp.Position
    local delta = targetPos - from
    local dist = delta.Magnitude
    if dist <= STEP then
        hrp.CFrame = CFrame.new(targetPos)
        return
    end
    local steps = math.min(10, math.ceil(dist / STEP))
    for i = 1, steps do
        local t = i / steps
        hrp.CFrame = CFrame.new(from:Lerp(targetPos, t))
        task.wait(0.05 + math.random() * 0.04)
    end
end

-- Buy conveyor egg: find eggs on player's plot, TP close, fireproximityprompt
local function buyConveyorEggsOnce()
    pcall(function()
        local char = Player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local plot = getMyPlot()
        if not plot then return end
        local eggsFolder = plot:FindFirstChild("Eggs")
        if not eggsFolder then return end
        for _, egg in ipairs(eggsFolder:GetChildren()) do
            if not egg:IsA("Model") then continue end
            -- Check egg name against filter
            local eggName = ""
            for _, d in ipairs(egg:GetDescendants()) do
                if d:IsA("TextLabel") and d.Name == "AssetName" then eggName = d.Text; break end
            end
            if not SelEggs["All"] and not SelEggs[eggName] then continue end
            -- Find ProximityPrompt
            local prompt = nil
            for _, d in ipairs(egg:GetDescendants()) do
                if d:IsA("ProximityPrompt") then prompt = d; break end
            end
            if not prompt then continue end
            -- TP close to egg (safeTP respects SlowTpMode)
            local eggRoot = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
            if not eggRoot then continue end
            safeTP(eggRoot.Position + Vector3.new(0, 3, 3))
            task.wait(0.05)
            safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
            S.eggsBought += 1
            task.wait(0.3 + math.random() * 0.2)
        end
        -- Also check MissedEggs
        local missed = plot:FindFirstChild("MissedEggs")
        if missed then
            for _, egg in ipairs(missed:GetChildren()) do
                if not egg:IsA("Model") then continue end
                local prompt = nil
                for _, d in ipairs(egg:GetDescendants()) do
                    if d:IsA("ProximityPrompt") then prompt = d; break end
                end
                if not prompt then continue end
                local eggRoot = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
                if not eggRoot then continue end
                safeTP(eggRoot.Position + Vector3.new(0, 3, 3))
                task.wait(0.05)
                safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
                S.eggsBought += 1
                task.wait(0.3 + math.random() * 0.2)
            end
        end
    end)
end

-- Skip all eggs on conveyor
local function skipAllEggsOnce()
    pcall(function()
        local plot = getMyPlot()
        if not plot then return end
        local skipPart = plot:FindFirstChild("SkipAllEggs")
        if not skipPart then return end
        local prompt = nil
        for _, d in ipairs(skipPart:GetDescendants()) do
            if d:IsA("ProximityPrompt") then prompt = d; break end
        end
        if prompt then
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local partPos = skipPart:IsA("BasePart") and skipPart.Position or (skipPart.PrimaryPart and skipPart.PrimaryPart.Position)
                if partPos then hrp.CFrame = CFrame.new(partPos + Vector3.new(0, 3, 3)) end
                task.wait(0.05)
            end
            safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
        end
    end)
end

-- Collect coins: touch CoinCollector on your plot + fire remote backup
local function collectCoinsOnce()
    pcall(function()
        local plot = getMyPlot()
        if plot then
            local collector = plot:FindFirstChild("CoinCollector")
            if collector and collector:IsA("BasePart") then
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    pcall(function() firetouchinterest(hrp, collector, 0); task.wait(0.05); firetouchinterest(hrp, collector, 1) end)
                    S.coinsCollect += 1
                end
            end
        end
        pcall(function() Events.ClaimCoins:FireServer() end) -- SAFE: tested 2026-04-15
    end)
end

-- Buy bee from shop (fires UI button connections)
local function buyBeeOnce()
    pcall(function()
        local mainGui = Player.PlayerGui:FindFirstChild("Main")
        if not mainGui then return end
        local beeShop = mainGui:FindFirstChild("BeeShop", true)
        if not beeShop then return end
        local list = beeShop:FindFirstChild("List")
        if not list then return end

        for _, slot in ipairs(list:GetChildren()) do
            if not slot.Name:find("StockItem") then continue end
            local stockLabel, nameLabel = nil, nil
            for _, d in ipairs(slot:GetDescendants()) do
                if d:IsA("TextLabel") and d.Name == "Stock" then stockLabel = d end
                if d:IsA("TextLabel") and d.Name == "ItemName" then nameLabel = d end
            end
            local stock = stockLabel and tonumber(stockLabel.Text:match("%d+")) or 0
            local beeName = nameLabel and nameLabel.Text or ""
            if stock <= 0 then continue end
            if not SelBees[beeName] and not SelBees["All"] then continue end
            local purchaseBtn = slot:FindFirstChild("MainFrame") and slot.MainFrame:FindFirstChild("Purchase")
            if purchaseBtn then
                if not getconnections then continue end
                for _, conn in ipairs(getconnections(purchaseBtn.Activated)) do
                    conn:Fire()
                end
                task.wait(0.5 + math.random() * 0.3)
            end
        end
    end)
end

-- Equip best bees
local function equipBestOnce()
    pcall(function() Events.BeeHandler:InvokeServer("EquipBest") end) -- SAFE: tested 2026-04-15
end

-- Fuse bees
local function fuseOnce()
    pcall(function() Events.FusingHandler:FireServer("AutoFuse") end) -- SAFE: tested 2026-04-15
    task.wait(0.1 + math.random() * 0.1)
    pcall(function() Events.FusingHandler:FireServer("Fuse") end) -- SAFE: tested 2026-04-15
end

-- Sell all
local function sellAllOnce()
    pcall(function() Events.SellAll:InvokeServer() end) -- SAFE: tested 2026-04-15
end

-- Daily spin
local function spinDailyOnce()
    pcall(function() Events.DailySpin:FireServer("spin", "daily") end) -- SAFE: tested 2026-04-15
end

-- Arcade roll
local function arcadeOnce()
    pcall(function() Events.ArcadeMachineRoll:FireServer() end) -- SAFE: tested 2026-04-15
end

-- Lucky block
local function luckyBlockOnce()
    pcall(function() Events.LuckyBlockHandler:FireServer("Claim") end) -- SAFE: tested 2026-04-15
    task.wait(0.1)
    pcall(function() Events.LuckyBlockHandler:FireServer("Open") end) -- SAFE: tested 2026-04-15
end

-- Open chest (TP to each chest in world)
local function chestOnce()
    pcall(function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local chestParts = {}
        for _, v in ipairs(getWsDescendants()) do
            if v:IsA("ProximityPrompt") and (v.Parent.Name:lower():find("chest") or v.ActionText == "Open") then
                table.insert(chestParts, v)
            end
        end
        for _, prompt in ipairs(chestParts) do
            if hrp then
                local part = prompt.Parent
                local pos = part:IsA("BasePart") and part.Position or (part.PrimaryPart and part.PrimaryPart.Position)
                if pos then safeTP(pos + Vector3.new(0, 3, 3)); task.wait(0.1) end
            end
            safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
            task.wait(0.3 + math.random() * 0.2)
        end
        pcall(function() Events.Chest:FireServer("Open") end) -- SAFE: tested 2026-04-15
        pcall(function() Events.Chest:FireServer("Claim") end) -- SAFE: tested 2026-04-15
    end)
end

-- Delivery
local function deliveryOnce()
    pcall(function() Events.DeliveryHandler:FireServer("ClaimAll") end) -- SAFE: tested 2026-04-15
    task.wait(0.1)
    pcall(function() Events.DeliveryHandler:FireServer("Claim") end) -- SAFE: tested 2026-04-15
    task.wait(0.1)
    pcall(function() Events.DeliveryPickup:FireServer() end) -- SAFE: tested 2026-04-15
end

-- Playtime rewards
local function playtimeOnce()
    pcall(function() Events.PlaytimeRewardsHandler:FireServer("Claim") end) -- SAFE: tested 2026-04-15
    task.wait(0.1)
    pcall(function() Events.PlaytimeRewardsHandler:FireServer("ClaimAll") end) -- SAFE: tested 2026-04-15
end

-- Follow rewards
local function followOnce()
    pcall(function() Events.FollowRewardsHandler:FireServer("Claim") end) -- SAFE: tested 2026-04-15
end

-- Achievements
local function achievementsOnce()
    pcall(function() Events.Achievements:FireServer("ClaimAll") end) -- SAFE: tested 2026-04-15
    task.wait(0.1)
    pcall(function() Events.Achievements:FireServer("Claim") end) -- SAFE: tested 2026-04-15
end

-- Swatter
local function swatterOnce()
    pcall(function() Events.Swatter:FireServer("Swing") end) -- SAFE: tested 2026-04-15
end

-- Combined rewards claim (playtime + follow + achievements)
local function claimAllRewardsOnce()
    playtimeOnce()
    task.wait(0.2)
    followOnce()
    task.wait(0.2)
    achievementsOnce()
end

-- Event shop claim
local function eventShopOnce()
    pcall(function() Events.EventShop:FireServer("Claim") end) -- SAFE: tested 2026-04-15
end

-- NEW: Special Event claim (quest rewards from current event)
local function specialEventOnce()
    pcall(function() Events.SpecialEvent:FireServer("Claim") end) -- SAFE: tested 2026-04-21
    task.wait(0.15)
    pcall(function() Events.SpecialEvent:FireServer("ClaimQuest") end) -- SAFE: tested 2026-04-21
end

-- NEW: Fountain invoke (fountain buff)
local function fountainOnce()
    pcall(function() Events.Fountain:InvokeServer() end) -- SAFE: tested 2026-04-21
end

-- NEW: Potion claim / use
local function potionOnce()
    pcall(function() Events.PotionHandler:FireServer() end) -- SAFE: tested 2026-04-21
    task.wait(0.15)
    pcall(function() Events.PotionHandler:FireServer("Claim") end) -- SAFE: tested 2026-04-21
end

-- NEW: Booth claim cycle (11 booths: Bamboo/VIP/Kitty/Bee/Bonsai/etc)
local function boothOnce()
    pcall(function() Events.BoothHandler:FireServer() end) -- SAFE: tested 2026-04-21
    task.wait(0.15)
    pcall(function() Events.BoothHandler:FireServer("Claim") end) -- SAFE: tested 2026-04-21
end

-- NEW: Redeem code helper (called by a button — pass a code string)
local function redeemCodeOnce(code)
    if not code or code == "" then return end
    pcall(function() Events.RedeemCode:FireServer(tostring(code)) end)
end

-- Zone teleport (10s minimum anti-detection delay — bumped from 5s 2026-04-21)
local _lastTP = 0
local function teleportToZone(zoneName)
    local now = tick()
    if now - _lastTP < 10 then return end -- 10s minimum between zone TPs
    _lastTP = now
    pcall(function() Events.TeleportRequest:FireServer(zoneName) end) -- SAFE: tested 2026-04-15
end

--========================================================================
-- HONEYPOT FILTER (preserved)
--========================================================================
local function isHoneypot(obj)
    local pp = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
    if not pp then return true end
    local pos = pp.Position
    if pos.Y < -5 then return true end
    if pos.Y > 500 then return true end
    if math.abs(pos.X) < 1 and math.abs(pos.Z) < 1 then return true end
    if pp.Transparency >= 1 then return true end
    if pp.Size.Magnitude < 0.1 then return true end
    return false
end

--========================================================================
-- MAIN AUTO LOOPS (preserved verbatim from v4)
--========================================================================

-- Auto Buy Conveyor Egg loop (2s)
task.spawn(function()
    while alive() do
        task.wait(2 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoBuyConveyorEgg then continue end
        buyConveyorEggsOnce()
    end
end)

-- Auto Skip Eggs loop
task.spawn(function()
    while alive() do
        task.wait(2 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoSkipEggs then continue end
        skipAllEggsOnce()
    end
end)

-- Auto Collect Coins loop (3s)
task.spawn(function()
    while alive() do
        task.wait(3 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoCollectCoins then continue end
        collectCoinsOnce()
    end
end)

-- Auto Buy Bee loop
task.spawn(function()
    while alive() do
        task.wait(1.5 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoBuyBee then continue end
        buyBeeOnce()
    end
end)

-- Auto Equip Best Bees loop (8s)
task.spawn(function()
    while alive() do
        task.wait(8 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoEquipBest then continue end
        equipBestOnce()
    end
end)

-- Auto Fuse loop (15s)
task.spawn(function()
    while alive() do
        task.wait(15 + math.random() * 0.5)
        if not alive() then break end
        if not G().AutoFuse then continue end
        fuseOnce()
    end
end)

-- Auto Sell loop (4s)
task.spawn(function()
    while alive() do
        task.wait(4 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoSell then continue end
        sellAllOnce()
    end
end)

-- Auto Daily loop
task.spawn(function()
    while alive() do
        task.wait(60 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoDaily then continue end
        spinDailyOnce()
    end
end)

-- Auto Arcade loop (6-10s)
task.spawn(function()
    while alive() do
        task.wait(jitter(6, 4))
        if not alive() then break end
        if not G().AutoArcade then continue end
        arcadeOnce()
    end
end)

-- Auto Lucky Block loop (20s)
task.spawn(function()
    while alive() do
        task.wait(20 + math.random() * 1)
        if not alive() then break end
        if not G().AutoLuckyBlock then continue end
        luckyBlockOnce()
    end
end)

-- Auto Chest loop (20s)
task.spawn(function()
    while alive() do
        task.wait(20 + math.random() * 1)
        if not alive() then break end
        if not G().AutoChest then continue end
        chestOnce()
    end
end)

-- Auto Delivery loop (30s)
task.spawn(function()
    while alive() do
        task.wait(30 + math.random() * 1)
        if not alive() then break end
        if not G().AutoDelivery then continue end
        deliveryOnce()
    end
end)

-- Auto Playtime loop
task.spawn(function()
    while alive() do
        task.wait(15 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoPlaytime then continue end
        playtimeOnce()
    end
end)

-- Auto Follow loop
task.spawn(function()
    while alive() do
        task.wait(30 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoFollow then continue end
        followOnce()
    end
end)

-- Auto Achievements loop
task.spawn(function()
    while alive() do
        task.wait(15 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoAchievements then continue end
        achievementsOnce()
    end
end)

-- Auto Claim All Rewards loop (60s)
task.spawn(function()
    while alive() do
        task.wait(60 + math.random() * 2)
        if not alive() then break end
        if not G().AutoClaimAll then continue end
        claimAllRewardsOnce()
    end
end)

-- Auto Event Shop loop (60s)
task.spawn(function()
    while alive() do
        task.wait(60 + math.random() * 2)
        if not alive() then break end
        if not G().AutoEventShop then continue end
        eventShopOnce()
    end
end)

-- NEW: Auto Special Event loop (45s — claim quest rewards)
task.spawn(function()
    while alive() do
        task.wait(45 + math.random() * 3)
        if not alive() then break end
        if not G().AutoSpecialEvent then continue end
        specialEventOnce()
    end
end)

-- NEW: Auto Fountain loop (90s — fountain buff)
task.spawn(function()
    while alive() do
        task.wait(90 + math.random() * 4)
        if not alive() then break end
        if not G().AutoFountain then continue end
        fountainOnce()
    end
end)

-- NEW: Auto Potion loop (120s)
task.spawn(function()
    while alive() do
        task.wait(120 + math.random() * 5)
        if not alive() then break end
        if not G().AutoPotion then continue end
        potionOnce()
    end
end)

-- NEW: Auto Booth loop (60s)
task.spawn(function()
    while alive() do
        task.wait(60 + math.random() * 3)
        if not alive() then break end
        if not G().AutoBooth then continue end
        boothOnce()
    end
end)

-- Auto Swatter loop
task.spawn(function()
    while alive() do
        task.wait(0.6 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoSwatter then continue end
        swatterOnce()
    end
end)

-- Speed Boost loop
task.spawn(function()
    while alive() do
        task.wait(jitter(0.5, 0.5))
        if not alive() then break end
        pcall(function()
            local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            if G().SpeedBoost then hum.WalkSpeed = G().SpeedValue
            elseif hum.WalkSpeed == G().SpeedValue then hum.WalkSpeed = 16 end
        end)
    end
end)

-- Auto Collect Arcade Orbs (TP to each orb)
task.spawn(function()
    while alive() do
        task.wait(0.5 + math.random() * 0.3)
        if not alive() then break end
        if not G().AutoCollectOrbs then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local eventsFolder = workspace:FindFirstChild("Events")
            if not eventsFolder then return end
            for _, folder in pairs({eventsFolder:FindFirstChild("ArcadeSpheres"), eventsFolder:FindFirstChild("Arcade")}) do
                if not folder then continue end
                for _, orb in ipairs(folder:GetChildren()) do
                    if not G().AutoCollectOrbs then break end
                    if orb.Name:find("ArcadeOrb") and orb:IsA("Model") then
                        local pp = orb.PrimaryPart or orb:FindFirstChildWhichIsA("BasePart")
                        if pp and pp.Parent then
                            hrp.CFrame = CFrame.new(pp.Position)
                            task.wait(0.05)
                        end
                    end
                end
            end
        end)
    end
end)

-- Auto Collect Arcade Tickets (TP + fire ProximityPrompt)
task.spawn(function()
    while alive() do
        task.wait(2 + math.random() * 0.5)
        if not alive() then break end
        if not G().AutoCollectTickets then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local eventsFolder = workspace:FindFirstChild("Events")
            if not eventsFolder then return end
            for _, folder in ipairs(eventsFolder:GetChildren()) do
                if not folder.Name:find("ArcadeTicket") then continue end
                for _, ticket in ipairs(folder:GetChildren()) do
                    if not G().AutoCollectTickets then break end
                    local prompt = ticket:FindFirstChildOfClass("ProximityPrompt", true)
                    local pp = ticket.PrimaryPart or ticket:FindFirstChildWhichIsA("BasePart")
                    if prompt and pp and pp.Parent then
                        hrp.CFrame = CFrame.new(pp.Position)
                        task.wait(0.1)
                        safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
                        task.wait(1.2 + math.random() * 0.3)
                    end
                end
            end
            local arcade = eventsFolder:FindFirstChild("Arcade")
            if arcade then
                for _, item in ipairs(arcade:GetChildren()) do
                    if item.Name:find("ArcadeTicket") then
                        local prompt = item:FindFirstChildOfClass("ProximityPrompt", true)
                        local pp = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                        if prompt and pp and pp.Parent then
                            hrp.CFrame = CFrame.new(pp.Position)
                            task.wait(0.1)
                            safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
                            task.wait(1.2 + math.random() * 0.3)
                        end
                    end
                end
            end
        end)
    end
end)

-- Auto Event Signup
task.spawn(function()
    while alive() do
        task.wait(30 + math.random() * 5)
        if not alive() then break end
        if not G().AutoEventSignup then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local core = workspace:FindFirstChild("Core")
            local scriptable = core and core:FindFirstChild("Scriptable")
            local touchParts = scriptable and scriptable:FindFirstChild("TouchParts")
            if touchParts then
                local signup = touchParts:FindFirstChild("EventSignup")
                if signup then
                    hrp.CFrame = CFrame.new(signup.Position)
                    task.wait(jitter(0.5, 0.5))
                end
            end
            pcall(function() Events.EventHandler:FireServer("Join") end) -- SAFE: tested 2026-04-15
        end)
    end
end)

-- Easter Egg ESP
local _easterESPFolder = Instance.new("Folder"); _easterESPFolder.Name = "AuroraEasterESP"
pcall(function() _easterESPFolder.Parent = gethui() end)
local _easterBBs = setmetatable({}, {__mode = "k"})

task.spawn(function()
    while alive() do
        task.wait(jitter(0.5, 0.5))
        if not alive() then break end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, egg in ipairs(workspace:GetChildren()) do
                if not egg.Name:find("EasterEgg_") then continue end
                local pp = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if not pp then continue end
                if G().EasterESP then
                    local data = _easterBBs[egg]
                    if not data or not data.bb or not data.bb.Parent then
                        local bb = Instance.new("BillboardGui"); bb.Adornee = pp
                        bb.Size = UDim2.fromOffset(120, 30); bb.StudsOffset = Vector3.new(0, 4, 0)
                        bb.AlwaysOnTop = true; bb.Parent = _easterESPFolder
                        local l = Instance.new("TextLabel"); l.Size = UDim2.new(1,0,1,0)
                        l.BackgroundTransparency = 1; l.Font = Enum.Font.GothamBold; l.TextSize = 12
                        l.TextColor3 = Color3.fromRGB(255, 200, 50); l.TextStrokeTransparency = 0.3
                        l.TextStrokeColor3 = Color3.new(0,0,0); l.Parent = bb
                        data = {bb = bb, label = l}; _easterBBs[egg] = data
                    end
                    local dist = math.floor((hrp.Position - pp.Position).Magnitude)
                    data.label.Text = egg.Name:gsub("EasterEgg_", "Egg #") .. " [" .. dist .. "m]"
                else
                    local data = _easterBBs[egg]
                    if data and data.bb then data.bb.Enabled = false end
                end
            end
        end)
    end
end)

-- Auto Easter Eggs (honeypot-safe)
task.spawn(function()
    while alive() do
        task.wait(jitter(5, 2))
        if not alive() then break end
        if not G().AutoEasterEggs then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, egg in ipairs(workspace:GetChildren()) do
                if not G().AutoEasterEggs then break end
                if not egg.Name:find("EasterEgg_") then continue end
                if isHoneypot(egg) then continue end
                local pp = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if not pp then continue end
                safeTP(pp.Position + Vector3.new(0, 3, 0))
                task.wait(2 + math.random() * 1.5)
                local prompt = nil
                for _, d in ipairs(egg:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then prompt = d; break end
                end
                if prompt then
                    safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
                else
                    pcall(function()
                        firetouchinterest(hrp, pp, 0); task.wait(0.15); firetouchinterest(hrp, pp, 1)
                    end)
                end
                task.wait(8 + math.random() * 5)
            end
        end)
    end
end)

-- Auto Meteorons (honeypot-safe)
task.spawn(function()
    while alive() do
        task.wait(jitter(4, 2))
        if not alive() then break end
        if not G().AutoMeteorons then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, obj in ipairs(workspace:GetChildren()) do
                if not G().AutoMeteorons then break end
                if obj.Name ~= "MeteoronPickup" then continue end
                if isHoneypot(obj) then continue end
                local prompt = nil
                for _, d in ipairs(obj:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Collect" then
                        prompt = d; break
                    end
                end
                if not prompt then continue end
                local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if not pp then continue end
                safeTP(pp.Position + Vector3.new(0, 2, 0))
                task.wait(2 + math.random() * 1.5)
                safeFirePrompt(prompt) -- Xeno-safe (fires native + InputHoldBegin fallback)
                task.wait(8 + math.random() * 5)
            end
        end)
    end
end)

-- Auto Ghost Bees (honeypot-safe, swatter slap)
task.spawn(function()
    while alive() do
        task.wait(jitter(3, 1))
        if not alive() then break end
        if not G().AutoGhostBees then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, obj in ipairs(workspace:GetChildren()) do
                if not G().AutoGhostBees then break end
                if not obj:IsA("Model") then continue end
                local name = obj.Name
                if not (name:find("Ghost") and not name:find("Explosion")) then continue end
                if name:find("Honeypot") then continue end
                local main = obj:FindFirstChild("Main") or obj:FindFirstChild("HumanoidRootPart")
                if not main then continue end
                if isHoneypot(obj) then continue end
                pcall(function() hrp.CFrame = CFrame.new(main.Position) end)
                task.wait(0.1)
                pcall(function() Events.Swatter:FireServer() end) -- SAFE: tested 2026-04-15
                task.wait(0.15)
                pcall(function() Events.Swatter:FireServer() end) -- SAFE: tested 2026-04-15
                task.wait(jitter(6, 4))
            end
        end)
    end
end)

-- Event info listener
local _eventName = "---"
local _eventTime = "---"
pcall(function()
    Events.EventUIEvent.OnClientEvent:Connect(function(action, data)
        if action == "CountdownUpdate" and type(data) == "table" then
            _eventName = data.eventName or "---"
            local t = data.timeRemaining or 0
            _eventTime = t > 60 and string.format("%dm %ds", math.floor(t/60), t%60) or (t .. "s")
        end
    end)
end)

-- Anti-AFK loop
task.spawn(function()
    while alive() do
        task.wait(jitter(30, 9.0))
        if not alive() then break end
        if not G().AntiAFK then continue end
        pcall(function()
            local vu = game:GetService("VirtualUser")
            vu:CaptureController()
            vu:ClickButton2(Vector2.new())
        end)
    end
end)

-- Status updater
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.5))
        if not alive() then break end
        pcall(function()
            local activeCount = 0
            for k, v in pairs(CFG) do if type(v) == "boolean" and v then activeCount += 1 end end
            if activeCount > 0 then S.status = "Active (" .. activeCount .. " features)"
            else S.status = "Idle" end
            local data = Player:FindFirstChild("Data")
            S.beeCount = data and data:FindFirstChild("BeeCount") and data.BeeCount.Value or 0
        end)
    end
end)

-- ========================================================================
-- ========================================================================
-- 3-COLUMN UI (Sidebar + Panel Alpha + Panel Beta + Live Game + Pill)
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
-- SCREENGUI + PARENT
--========================================================================
local screenGui = create("ScreenGui", {
    Name = "AuroraHubUI", DisplayOrder = 9999, ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
local _pOk = false
if typeof(gethui) == "function" then _pOk = pcall(function() screenGui.Parent = gethui() end) end
if not _pOk then _pOk = pcall(function() screenGui.Parent = game:GetService("CoreGui") end) end
if not _pOk then screenGui.Parent = Player:WaitForChild("PlayerGui") end

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

-- Centered brand watermark — all panel bgs transparent so it bleeds through
local watermark = create("TextLabel", {
    Name = "Watermark",
    Size = UDim2.fromOffset(700, 120),
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
-- SIDEBAR (transparent so main rounded bg shows through corners)
--========================================================================
local sidebar = create("Frame", {
    Name = "Sidebar", Size = UDim2.fromOffset(SIDEBAR_W, TOTAL_H),
    BackgroundColor3 = C.bg2, BackgroundTransparency = 1,
    BorderSizePixel = 0, ClipsDescendants = true,
}, content)

-- Sidebar right border (in content layer so no clipping issue)
create("Frame", {
    Size = UDim2.fromOffset(1, TOTAL_H), Position = UDim2.fromOffset(SIDEBAR_W - 1, 0),
    BackgroundColor3 = C.border, BorderSizePixel = 0,
}, content)

-- Wordmark row (drag handle)
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
    BackgroundTransparency = 1, Font = F_SANS_BOLD, TextSize = 13,
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
    { name = "Bees",     icon = "◆" },
    { name = "Auto",     icon = "≡" },
    { name = "Events",   icon = "✦" },
    { name = "Utility",  icon = "◉" },
    { name = "Zones",    icon = "□" },
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

-- Forward-declare switchTab so tab rows can call it
local switchTab = function(_) end

-- Forward-declare dropdown popup helpers (defined later)
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

-- Build tab pairs + persistent Live Game
local TAB_NAMES = { "Farm", "Bees", "Auto", "Events", "Utility", "Zones", "Settings" }
local TAB_ACCENT = {
    Farm     = C.pink,
    Bees     = C.purple,
    Auto     = C.pink,
    Events   = C.pink,
    Utility  = C.pink,
    Zones    = C.pink,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "CONVEYOR",  beta = "COINS"    },
    Bees     = { alpha = "SHOP",      beta = "MANAGE"   },
    Auto     = { alpha = "ECONOMY",   beta = "REWARDS"  },
    Events   = { alpha = "EVENTS",    beta = "ARCADE"   },
    Utility  = { alpha = "MOVEMENT",  beta = "SAFETY"   },
    Zones    = { alpha = "TELEPORT",  beta = "INFO"     },
    Settings = { alpha = "CONFIG",    beta = "ABOUT"    },
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
    -- Fallback for stale CFG from previous builds
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

local function sliderRow(parent, label, cfgKey, minV, maxV, step, order)
    if CFG[cfgKey] == nil then CFG[cfgKey] = minV end
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 18), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local fmtVal = function(v) return (step < 1) and string.format("%.2f", v) or tostring(math.floor(v)) end
    local valLabel = create("TextLabel", {
        Size = UDim2.new(0.3, 0, 0, 18), Position = UDim2.new(0.7, 0, 0, 0),
        BackgroundTransparency = 1, Text = fmtVal(CFG[cfgKey]),
        Font = F_MONO, TextSize = 11, TextColor3 = C.pink,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row)
    local track = create("Frame", {
        Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0, 28),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(track, 2); stroke(track, C.border, 1, 0)
    local startPct = math.clamp((CFG[cfgKey] - minV) / math.max(1e-6, (maxV - minV)), 0, 1)
    local fill = create("Frame", {
        Size = UDim2.new(startPct, 0, 1, 0), BackgroundColor3 = C.white, BorderSizePixel = 0,
    }, track)
    corner(fill, 2); grad(fill, C.pink, C.purple, 0)
    local knob = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(startPct, -7, 0.5, -7),
        BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
    }, track)
    corner(knob, 7); stroke(knob, C.pink, 2, 0)
    local dragging = false
    local function update(x)
        local p0 = track.AbsolutePosition.X
        local w  = track.AbsoluteSize.X
        local rel = math.clamp((x - p0) / math.max(1, w), 0, 1)
        local raw = minV + (maxV - minV) * rel
        local snapped = math.floor(raw / step + 0.5) * step
        snapped = math.clamp(snapped, minV, maxV)
        if step >= 1 then snapped = math.floor(snapped) end
        CFG[cfgKey] = snapped
        local newPct = math.clamp((snapped - minV) / math.max(1e-6, (maxV - minV)), 0, 1)
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        knob.Position = UDim2.new(newPct, -7, 0.5, -7)
        valLabel.Text = fmtVal(snapped)
    end
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(inp.Position.X)
        end
    end)
    UIS.InputChanged:Connect(function(inp)
        if not alive() then return end
        if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            update(inp.Position.X)
        end
    end)
    UIS.InputEnded:Connect(function(inp)
        if not alive() then return end
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            if dragging and CFG.AutoSave then saveCFG() end
            dragging = false
        end
    end)
    return row
end

-- =========================================================================
-- DROPDOWN (proper popup, supports single or multi select via CFG)
-- =========================================================================
closeOpenPopup = function()
    if _openPopup and _openPopup.frame then
        _openPopup.frame.Visible = false
        if _openPopup.onClose then _openPopup.onClose() end
    end
    _openPopup = nil
end

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
            if count == 0 then return "None" end
            if count == 1 then return tostring(firstKey) end
            return count .. " selected"
        else
            return tostring(CFG[cfgKey] or "—")
        end
    end

    local valLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = displayText(),
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)

    local arrow = create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▼",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)

    local POPUP_W  = 140
    local OPT_H    = 26
    local POPUP_H  = math.min(220, #options * (OPT_H + 2) + 8)

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
            onClose = function() arrow.Text = "▼" end,
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

    return row
end

-- =========================================================================
-- DROPDOWN VARIANT: operates on EXTERNAL set map (for SelBees / SelEggs)
-- Preserves v4's multi-select-with-shared-state semantics.
-- =========================================================================
local function dropdownMapRow(parent, label, options, setMap, order)
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
        if setMap["All"] then return "All" end
        local count, firstKey = 0, nil
        for _, nm in ipairs(options) do
            if setMap[nm] then count = count + 1; if not firstKey then firstKey = nm end end
        end
        if count == 0 then return "None" end
        if count == 1 then return tostring(firstKey) end
        return count .. " selected"
    end

    local valLabel = create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(8, 0),
        BackgroundTransparency = 1, Text = displayText(),
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, pill)

    local arrow = create("TextLabel", {
        Size = UDim2.fromOffset(18, 22), Position = UDim2.new(1, -18, 0, 0),
        BackgroundTransparency = 1, Text = "▼",
        Font = F_SANS, TextSize = 8, TextColor3 = C.pink,
    }, pill)

    local POPUP_W  = 180
    local OPT_H    = 26
    local popOptions = {"All"}
    for _, nm in ipairs(options) do table.insert(popOptions, nm) end
    local POPUP_H  = math.min(240, #popOptions * (OPT_H + 2) + 8)

    local popup = create("Frame", {
        Name = "DDMapPopup_" .. label,
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
    local function isSelected(opt) return setMap[opt] == true end

    for i, opt in ipairs(popOptions) do
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
        corner(check, 2)
        stroke(check, C.border2, 1, 0)
        local fill = create("Frame", {
            Size = UDim2.fromScale(1, 1),
            BackgroundColor3 = C.pink, BorderSizePixel = 0,
            Visible = false, ZIndex = 54,
        }, check)
        corner(fill, 2)

        create("TextLabel", {
            Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(26, 0),
            BackgroundTransparency = 1, Text = tostring(opt),
            Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 53,
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
                if setMap[o.opt] then setMap[o.opt] = nil
                else setMap[o.opt] = true end
                paintOpts()
                valLabel.Text = displayText()
                if CFG.AutoSave then saveCFG() end
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
            onClose = function() arrow.Text = "▼" end,
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

    return row
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

--========================================================================
-- POPULATE: FARM (Conveyor eggs + Coins)
--========================================================================
local oF_a, oF_b = 0, 0
local function nFa() oF_a = oF_a + 1; return oF_a end
local function nFb() oF_b = oF_b + 1; return oF_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Conveyor Eggs",           nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Buy Conveyor Egg", "AutoBuyConveyorEgg", nFa())
toggleRow    (scrolls["Farm_alpha"], "Auto Skip Eggs",        "AutoSkipEggs",       nFa())

sectionHeader(scrolls["Farm_alpha"], "◉", "Egg Filter",              nFa())
dropdownMapRow(scrolls["Farm_alpha"], "Buy Eggs", EGG_NAMES, SelEggs, nFa())

sectionHeader(scrolls["Farm_alpha"], "▣", "Manual", nFa())
actionBtn(scrolls["Farm_alpha"], "Buy Eggs Now",   C.bg3, nFa(), function() buyConveyorEggsOnce() end)
actionBtn(scrolls["Farm_alpha"], "Skip All Eggs",  C.bg3, nFa(), function() skipAllEggsOnce() end)

sectionHeader(scrolls["Farm_beta"], "●", "Coins", nFb())
toggleRow    (scrolls["Farm_beta"], "Auto Collect Coins", "AutoCollectCoins", nFb())
actionBtn    (scrolls["Farm_beta"], "Collect Coins Now",  C.bg3, nFb(), function() collectCoinsOnce() end)

sectionHeader(scrolls["Farm_beta"], "✦", "Notes", nFb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Conveyor eggs auto-detected on your plot.\nFilter narrows buy targets by egg name.\nCoin collection also sweeps missed eggs.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFb(),
}, scrolls["Farm_beta"])

--========================================================================
-- POPULATE: BEES
--========================================================================
local oB_a, oB_b = 0, 0
local function nBa() oB_a = oB_a + 1; return oB_a end
local function nBb() oB_b = oB_b + 1; return oB_b end

sectionHeader(scrolls["Bees_alpha"], "●", "Shop", nBa())
toggleRow    (scrolls["Bees_alpha"], "Auto Buy Bee", "AutoBuyBee", nBa())
dropdownMapRow(scrolls["Bees_alpha"], "Buy Bees", BEE_SHOP_NAMES, SelBees, nBa())

sectionHeader(scrolls["Bees_alpha"], "◉", "Management", nBa())
toggleRow    (scrolls["Bees_alpha"], "Auto Equip Best", "AutoEquipBest", nBa())
toggleRow    (scrolls["Bees_alpha"], "Auto Fuse Bees",  "AutoFuse",      nBa())

sectionHeader(scrolls["Bees_alpha"], "▣", "Manual", nBa())
actionBtn(scrolls["Bees_alpha"], "Buy Bee Now",     C.bg3, nBa(), function() buyBeeOnce() end)
actionBtn(scrolls["Bees_alpha"], "Equip Best Now",  C.bg3, nBa(), function() equipBestOnce() end)
actionBtn(scrolls["Bees_alpha"], "Fuse Now",        C.bg3, nBa(), function() fuseOnce() end)

sectionHeader(scrolls["Bees_beta"], "●", "Bee Status", nBb())
local _bBeeCount   = infoRow(scrolls["Bees_beta"], "Bee Count",      "—",    C.pink,  nBb())
local _bBeeStatus  = infoRow(scrolls["Bees_beta"], "Status",         "Idle", C.text2, nBb())
local _bEggsBought = infoRow(scrolls["Bees_beta"], "Eggs Bought",    "0",    C.text2, nBb())

sectionHeader(scrolls["Bees_beta"], "✦", "Notes", nBb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Shop buy fires UI connections; no shop remote.\nEquip Best uses server RF for validation.\nFusing runs Auto + Fuse back-to-back.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nBb(),
}, scrolls["Bees_beta"])

--========================================================================
-- POPULATE: AUTO (Economy + Rewards)
--========================================================================
local oA_a, oA_b = 0, 0
local function nAa() oA_a = oA_a + 1; return oA_a end
local function nAb() oA_b = oA_b + 1; return oA_b end

sectionHeader(scrolls["Auto_alpha"], "●", "Economy", nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Sell All",     "AutoSell",      nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Daily Spin",   "AutoDaily",     nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Arcade Roll",  "AutoArcade",    nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Event Shop",   "AutoEventShop", nAa())

sectionHeader(scrolls["Auto_alpha"], "◉", "World", nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Lucky Block",  "AutoLuckyBlock", nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Open Chests",  "AutoChest",      nAa())
toggleRow    (scrolls["Auto_alpha"], "Auto Deliveries",   "AutoDelivery",   nAa())

sectionHeader(scrolls["Auto_alpha"], "▣", "Manual", nAa())
actionBtn(scrolls["Auto_alpha"], "Sell All Now",      C.bg3, nAa(), function() sellAllOnce() end)
actionBtn(scrolls["Auto_alpha"], "Spin Daily Now",    C.bg3, nAa(), function() spinDailyOnce() end)

sectionHeader(scrolls["Auto_beta"], "●", "Rewards", nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Claim All",        "AutoClaimAll",     nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Playtime Rewards", "AutoPlaytime",     nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Follow Rewards",   "AutoFollow",       nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Achievements",     "AutoAchievements", nAb())

sectionHeader(scrolls["Auto_beta"], "✦", "Buffs & Quests", nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Special Event",    "AutoSpecialEvent", nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Fountain",         "AutoFountain",     nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Potion",           "AutoPotion",       nAb())
toggleRow    (scrolls["Auto_beta"], "Auto Booth",            "AutoBooth",        nAb())

sectionHeader(scrolls["Auto_beta"], "▣", "Manual", nAb())
actionBtn(scrolls["Auto_beta"], "Claim Delivery",      C.bg3, nAb(), function() deliveryOnce() end)
actionBtn(scrolls["Auto_beta"], "Claim All Rewards",   C.bg3, nAb(), function() claimAllRewardsOnce() end)
actionBtn(scrolls["Auto_beta"], "Claim Event Shop",    C.bg3, nAb(), function() eventShopOnce() end)
actionBtn(scrolls["Auto_beta"], "Claim Special Event", C.bg3, nAb(), function() specialEventOnce() end)
actionBtn(scrolls["Auto_beta"], "Use Fountain",        C.bg3, nAb(), function() fountainOnce() end)

--========================================================================
-- POPULATE: EVENTS (Easter + Arcade)
--========================================================================
local oE_a, oE_b = 0, 0
local function nEa() oE_a = oE_a + 1; return oE_a end
local function nEb() oE_b = oE_b + 1; return oE_b end

sectionHeader(scrolls["Events_alpha"], "●", "Easter Event", nEa())
toggleRow    (scrolls["Events_alpha"], "Easter Egg ESP",    "EasterESP",     nEa())
toggleRow    (scrolls["Events_alpha"], "Auto Easter Eggs",  "AutoEasterEggs", nEa())
toggleRow    (scrolls["Events_alpha"], "Auto Meteorons",    "AutoMeteorons", nEa())
toggleRow    (scrolls["Events_alpha"], "Auto Ghost Bees",   "AutoGhostBees", nEa())

sectionHeader(scrolls["Events_alpha"], "▣", "Manual", nEa())
actionBtn(scrolls["Events_alpha"], "TP Nearest Egg", C.green, nEa(), function()
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local best, bestDist = nil, math.huge
        for _, egg in ipairs(workspace:GetChildren()) do
            if egg.Name:find("EasterEgg_") then
                local pp = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if pp then
                    local d = (hrp.Position - pp.Position).Magnitude
                    if d < bestDist then bestDist = d; best = pp end
                end
            end
        end
        if best then hrp.CFrame = CFrame.new(best.Position + Vector3.new(0, 3, 0)) end
    end)
end)

sectionHeader(scrolls["Events_beta"], "●", "Arcade Event", nEb())
toggleRow    (scrolls["Events_beta"], "Auto Collect Orbs",    "AutoCollectOrbs",    nEb())
toggleRow    (scrolls["Events_beta"], "Auto Collect Tickets", "AutoCollectTickets", nEb())
toggleRow    (scrolls["Events_beta"], "Auto Event Signup",    "AutoEventSignup",    nEb())

sectionHeader(scrolls["Events_beta"], "▣", "Pac-Man TP", nEb())
actionBtn(scrolls["Events_beta"], "TP Pacman 1", C.bg3, nEb(), function()
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(11.8, 11.1, 79) end
    end)
end)
actionBtn(scrolls["Events_beta"], "TP Pacman 2", C.bg3, nEb(), function()
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = CFrame.new(106.8, 11, -35.7) end
    end)
end)
actionBtn(scrolls["Events_beta"], "TP to Event Signup", C.bg3, nEb(), function()
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local tp = workspace.Core.Scriptable.TouchParts:FindFirstChild("Event")
        if tp then hrp.CFrame = CFrame.new(tp.Position + Vector3.new(0, 3, 0)) end
    end)
end)

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Movement", nUa())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost",  "SpeedBoost", nUa())
sliderRow    (scrolls["Utility_alpha"], "Walk Speed",   "SpeedValue", 16, 200, 1, nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK",     "AntiAFK",    nUa())
toggleRow    (scrolls["Utility_alpha"], "Auto Swatter", "AutoSwatter", nUa())
toggleRow    (scrolls["Utility_alpha"], "Slow TP Mode", "SlowTpMode", nUa())

sectionHeader(scrolls["Utility_alpha"], "▣", "Manual", nUa())
actionBtn(scrolls["Utility_alpha"], "Sell All",         C.bg3, nUa(), function() sellAllOnce() end)
actionBtn(scrolls["Utility_alpha"], "Equip Best Bees",  C.bg3, nUa(), function() equipBestOnce() end)

sectionHeader(scrolls["Utility_beta"], "●", "Safety Note", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "HONEYPOT WARNING\nThe following remotes are NEVER fired:\n- HackerEvent\n- GodHandler\n- AdminEvent\n- AdminShopHandler\nFiring these bans the account on sight.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.red,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

sectionHeader(scrolls["Utility_beta"], "✦", "Features", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Anti-AFK keeps you connected indefinitely.\nAuto Swatter spams swing for zombies/ghosts.\nSpeed Boost applies 16-200 WalkSpeed.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

--========================================================================
-- POPULATE: ZONES
--========================================================================
local oZ_a, oZ_b = 0, 0
local function nZa() oZ_a = oZ_a + 1; return oZ_a end
local function nZb() oZ_b = oZ_b + 1; return oZ_b end

sectionHeader(scrolls["Zones_alpha"], "●", "Zone Teleport", nZa())
for _, zoneName in ipairs(ZONE_NAMES) do
    actionBtn(scrolls["Zones_alpha"], "TP: " .. zoneName, C.bg3, nZa(), function()
        teleportToZone(zoneName)
    end)
end

sectionHeader(scrolls["Zones_beta"], "●", "Zone Info", nZb())
infoRow(scrolls["Zones_beta"], "Min TP Delay", "10s",               C.text2, nZb())
infoRow(scrolls["Zones_beta"], "Method",       "TeleportRequest",   C.text2, nZb())
local _zLastTP = infoRow(scrolls["Zones_beta"], "Last TP", "—", C.pink, nZb())

sectionHeader(scrolls["Zones_beta"], "✦", "Notes", nZb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Zone TPs throttled to 10s between calls.\nServer validates destination — invalid\nzones return you to spawn.\nEnable Slow TP Mode in Utility for\nextra anti-detection on CFrame hops.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nZb(),
}, scrolls["Zones_beta"])

--========================================================================
-- POPULATE: SETTINGS (Config + About)
--========================================================================
local oS_a, oS_b = 0, 0
local function nSa() oS_a = oS_a + 1; return oS_a end
local function nSb() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSa())
toggleRow    (scrolls["Settings_alpha"], "Auto-Save", "AutoSave", nSa())
actionBtn    (scrolls["Settings_alpha"], "Save Config Now", C.green, nSa(), function() saveCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSa(), function() loadSavedCFG() end)
actionBtn    (scrolls["Settings_alpha"], "Reset All",       C.red,   nSa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.SpeedValue  = 50
    CFG.SelectedBee = "Any"
    CFG.AutoSave    = true
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSa())
actionBtn(scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn(scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_BG_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Bee Garden",              C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),    C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion), C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",           C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                      C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,              C.text3, nSb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSb())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 220),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSb(),
}, scrolls["Settings_beta"])

--========================================================================
-- POPULATE: LIVE GAME (persistent right column)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
local _liveMode    = infoRow(liveScroll, "Mode",    "Idle", C.pink,  nL())

sectionHeader(liveScroll, "●", "Wallet", nL())
local _liveCoins   = infoRow(liveScroll, "Coins",        "—", C.text,  nL())
local _liveGScore  = infoRow(liveScroll, "Garden Score", "—", C.text2, nL())

sectionHeader(liveScroll, "◆", "Bees", nL())
local _liveBeeCount    = infoRow(liveScroll, "Bee Count",   "—", C.pink,  nL())
local _liveEggsBought  = infoRow(liveScroll, "Eggs Bought", "0", C.text2, nL())

sectionHeader(liveScroll, "⚔", "Player", nL())
local _liveHealth = infoRow(liveScroll, "Health",     "—", C.text,  nL())
local _liveSpeed  = infoRow(liveScroll, "Walk Speed", "—", C.text2, nL())

sectionHeader(liveScroll, "✦", "Event", nL())
local _liveEvtName = infoRow(liveScroll, "Event",      "—", C.text2, nL())
local _liveEvtTime = infoRow(liveScroll, "Time Left",  "—", C.text2, nL())
local _liveEvtEggs = infoRow(liveScroll, "Eggs Left",  "—", C.text2, nL())
local _liveCoinsCollect = infoRow(liveScroll, "Collects", "0", C.text2, nL())

--========================================================================
-- FLOATING PILL
--========================================================================
local pillGui = create("ScreenGui", {
    Name = "AuroraHubPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true,
})
local _pillOk = false
if typeof(gethui) == "function" then _pillOk = pcall(function() pillGui.Parent = gethui() end) end
if not _pillOk then _pillOk = pcall(function() pillGui.Parent = game:GetService("CoreGui") end) end
if not _pillOk then pillGui.Parent = Player:WaitForChild("PlayerGui") end

local pill = create("Frame", {
    Name = "Pill", Size = UDim2.fromOffset(152, 36),
    Position = UDim2.new(1, -172, 0, 22),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0.15,
    BorderSizePixel = 0, Active = true,
}, pillGui)
corner(pill, 18); stroke(pill, C.border2, 1, 0)

-- Outer glow halo
local pillDotGlow = create("Frame", {
    Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
    BackgroundColor3 = C.green, BackgroundTransparency = 0.78,
    BorderSizePixel = 0, ZIndex = 1,
}, pill)
corner(pillDotGlow, 9)

-- Inner glow ring
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

-- Global outside-click handler for dropdowns
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

-- Close — destroys UI + kills session
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
        getgenv().__AURORA_BG_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
        pcall(function() if _easterESPFolder then _easterESPFolder:Destroy() end end)
    end
end)
closeBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.bg3
        closeX.TextColor3 = C.text2
    end
end)

--========================================================================
-- STATUS UPDATE LOOP (wired to v5 labels)
--========================================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            -- Session
            local elapsed = tick() - S.session
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Wallet / score
            local coins = getCoins()
            local data  = Player:FindFirstChild("Data")
            local gs    = data and data:FindFirstChild("GardenScore") and data.GardenScore.Value or 0
            local bees  = data and data:FindFirstChild("BeeCount") and data.BeeCount.Value or 0

            -- Bees tab stats
            _bBeeCount.Text   = tostring(bees)
            _bEggsBought.Text = tostring(S.eggsBought)
            local beeActive = {}
            if G().AutoBuyBee    then table.insert(beeActive, "Buying")    end
            if G().AutoEquipBest then table.insert(beeActive, "Equipping") end
            if G().AutoFuse      then table.insert(beeActive, "Fusing")    end
            _bBeeStatus.Text = #beeActive > 0 and table.concat(beeActive, "+") or "Idle"

            -- Zones tab
            if _lastTP > 0 then
                local ago = math.floor(tick() - _lastTP)
                _zLastTP.Text = ago .. "s ago"
            end

            -- Live Game column
            _liveRuntime.Text      = rtime
            _liveCoins.Text        = formatNum(coins)
            _liveGScore.Text       = formatNum(gs)
            _liveBeeCount.Text     = tostring(bees)
            _liveEggsBought.Text   = tostring(S.eggsBought)
            _liveCoinsCollect.Text = tostring(S.coinsCollect)

            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    _liveHealth.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    _liveSpeed.Text  = tostring(math.floor(hum.WalkSpeed))
                end
            end

            _liveEvtName.Text = _eventName
            _liveEvtTime.Text = _eventTime
            pcall(function()
                local ec = 0
                for _, e in ipairs(workspace:GetChildren()) do if e.Name:find("EasterEgg_") then ec += 1 end end
                _liveEvtEggs.Text = ec .. " remaining"
            end)

            -- Active mode
            local mode = "Idle"
            if G().AutoBuyConveyorEgg or G().AutoSkipEggs or G().AutoCollectCoins then
                mode = "Farming"
            elseif G().AutoBuyBee or G().AutoEquipBest or G().AutoFuse then
                mode = "Bees"
            elseif G().AutoSell or G().AutoDaily or G().AutoArcade or G().AutoLuckyBlock or G().AutoChest
                or G().AutoDelivery or G().AutoPlaytime or G().AutoFollow or G().AutoAchievements
                or G().AutoClaimAll or G().AutoEventShop then
                mode = "Auto"
            elseif G().AutoCollectOrbs or G().AutoCollectTickets or G().AutoEventSignup
                or G().AutoEasterEggs or G().AutoMeteorons or G().AutoGhostBees then
                mode = "Event"
            end
            _liveMode.Text = mode

            -- Active features list + pill counter
            local active = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    table.insert(active, "· " .. k)
                end
            end
            table.sort(active)
            _cfgActiveLabel.Text = #active > 0 and table.concat(active, "\n") or "None"
            _pillActive.Text = #active .. " active"
        end)
    end
end)

--========================================================================
-- INIT
--========================================================================
switchTab(CFG.ActiveTab or "Farm")
print("[Aurora v5] Bee Garden loaded — AuroraHub Edition")

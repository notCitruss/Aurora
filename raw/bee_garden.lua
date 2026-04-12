--// Aurora -- Bee Garden
--// Sidebar + Dual Panel Layout
--// PlaceId: 81535567274521

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Cleanup previous instance
for _, n in {"Aurora"} do
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
end

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_BG_CFG then
    for k, v in getgenv().__AURORA_BG_CFG do
        if type(v) == "boolean" then getgenv().__AURORA_BG_CFG[k] = false end
    end
end
getgenv().__AURORA_BG_SESSION = tick()
local _mySession = getgenv().__AURORA_BG_SESSION
local function alive() return getgenv().__AURORA_BG_SESSION == _mySession end

---------- SERVICES & REMOTES ----------
local RS = game:GetService("ReplicatedStorage")
local Events = RS:WaitForChild("Events", 15)
if not Events then warn("[Aurora] Events folder not found"); return end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- WORKSPACE DESCENDANTS CACHE ----------
local _wsDescCache = {}
local _wsDescLastRefresh = 0
local _WS_DESC_TTL = 4  -- refresh every 4 seconds
local function getWsDescendants()
    local now = tick()
    if now - _wsDescLastRefresh >= _WS_DESC_TTL then
        _wsDescCache = workspace:GetDescendants()
        _wsDescLastRefresh = now
    end
    return _wsDescCache
end

---------- CONFIG ----------
local CFG = {
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
    -- Config tab
    AutoSave            = false,
}

---------- SELECTION MAPS ----------
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

---------- SAVE / LOAD ----------
local _cfgFileName = "aurora_cfg_bee_garden.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_bee_garden"] end
    if saved and type(saved) == "table" then
        for k, v in saved do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._SelBees then for k in SelBees do SelBees[k] = nil end; for k, v in saved._SelBees do SelBees[k] = v end end
        if saved._SelEggs then for k in SelEggs do SelEggs[k] = nil end; for k, v in saved._SelEggs do SelEggs[k] = v end end
    end
end

local function saveCFG()
    local d = {}; for k, v in CFG do d[k] = v end
    d._SelBees = SelBees; d._SelEggs = SelEggs
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(d)) end)
    getgenv()["AuroraCFG_bee_garden"] = d
end

loadSavedCFG()

local function G() return CFG end

---------- BEE DATA ----------
local BEE_LIST = {"Any"}
local BEE_DATA = {}
do
    local ok, Bees = pcall(function() return require(RS.Modules.Gameplay.Shared_Bees) end)
    if ok and Bees and Bees.List then
        local sorted = {}
        for k, v in Bees.List do
            if typeof(v) == "table" and not v.BeeShopExcluded and not v.Exclusive and v.Price then
                table.insert(sorted, { id = k, name = v.AssetName or k, price = tonumber(v.Price) or 0, rarity = v.Rarity or "?" })
            end
        end
        table.sort(sorted, function(a, b) return a.price < b.price end)
        for _, b in sorted do
            table.insert(BEE_LIST, b.id)
            BEE_DATA[b.id] = b
        end
    end
end

---------- HELPERS ----------
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

local function getBeeDisplay(id)
    if id == "Any" then return "Any (auto)" end
    local d = BEE_DATA[id]
    return d and string.format("%s (%s)", d.name, formatNum(d.price)) or id
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
    for _, plot in plots:GetChildren() do
        local conv = plot:FindFirstChild("ConveyorModel")
        if conv then
            for _, p in conv:GetDescendants() do
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
---------- SESSION STATS ----------
local S = {
    session      = tick(),
    eggsBought   = 0,
    coinsCollect = 0,
    status       = "Idle",
    beeCount     = 0,
}

---------- SHOP STOCK (from server events) ----------
local _shopStock = {}
pcall(function()
    Events.BeeShopHandler.OnClientEvent:Connect(function(action, data)
        if action == "Restocked" and typeof(data) == "table" then _shopStock = data end
    end)
end)

-- ============================================================
-- CORE GAME FUNCTIONS
-- ============================================================

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
        for _, egg in eggsFolder:GetChildren() do
            if not egg:IsA("Model") then continue end
            -- Check egg name against filter
            local eggName = ""
            for _, d in egg:GetDescendants() do
                if d:IsA("TextLabel") and d.Name == "AssetName" then eggName = d.Text; break end
            end
            if not SelEggs["All"] and not SelEggs[eggName] then continue end
            -- Find ProximityPrompt
            local prompt = nil
            for _, d in egg:GetDescendants() do
                if d:IsA("ProximityPrompt") then prompt = d; break end
            end
            if not prompt then continue end
            -- TP close to egg
            local eggRoot = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
            if not eggRoot then continue end
            hrp.CFrame = CFrame.new(eggRoot.Position + Vector3.new(0, 3, 3))
            task.wait(0.05)
            pcall(function() safeFirePrompt(prompt) end)
            S.eggsBought += 1
            task.wait(0.3 + math.random() * 0.2)
        end
        -- Also check MissedEggs
        local missed = plot:FindFirstChild("MissedEggs")
        if missed then
            for _, egg in missed:GetChildren() do
                if not egg:IsA("Model") then continue end
                local prompt = nil
                for _, d in egg:GetDescendants() do
                    if d:IsA("ProximityPrompt") then prompt = d; break end
                end
                if not prompt then continue end
                local eggRoot = egg.PrimaryPart or egg:FindFirstChildOfClass("BasePart")
                if not eggRoot then continue end
                hrp.CFrame = CFrame.new(eggRoot.Position + Vector3.new(0, 3, 3))
                task.wait(0.05)
                pcall(function() safeFirePrompt(prompt) end)
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
        for _, d in skipPart:GetDescendants() do
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
            pcall(function() safeFirePrompt(prompt) end)
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
        pcall(function() Events.ClaimCoins:FireServer() end)
    end)
end

-- Buy bee from shop (fires UI button connections — the only method that works)
local function buyBeeOnce()
    pcall(function()
        local mainGui = Player.PlayerGui:FindFirstChild("Main")
        if not mainGui then return end
        local beeShop = mainGui:FindFirstChild("BeeShop", true)
        if not beeShop then return end
        local list = beeShop:FindFirstChild("List")
        if not list then return end

        for _, slot in list:GetChildren() do
            if not slot.Name:find("StockItem") then continue end
            -- Check stock
            local stockLabel, nameLabel = nil, nil
            for _, d in slot:GetDescendants() do
                if d:IsA("TextLabel") and d.Name == "Stock" then stockLabel = d end
                if d:IsA("TextLabel") and d.Name == "ItemName" then nameLabel = d end
            end
            local stock = stockLabel and tonumber(stockLabel.Text:match("%d+")) or 0
            local beeName = nameLabel and nameLabel.Text or ""
            if stock <= 0 then continue end

            -- Check if this bee matches selection (SelBees filter)
            if not SelBees[beeName] and not SelBees["All"] then continue end

            -- Find and fire the Purchase button
            local purchaseBtn = slot:FindFirstChild("MainFrame") and slot.MainFrame:FindFirstChild("Purchase")
            if purchaseBtn then
                for _, conn in getconnections(purchaseBtn.Activated) do
                    conn:Fire()
                end
                task.wait(0.5 + math.random() * 0.3)
            end
        end
    end)
end

-- Equip best bees
local function equipBestOnce()
    pcall(function() Events.BeeHandler:InvokeServer("EquipBest") end)
end

-- Fuse bees
local function fuseOnce()
    pcall(function() Events.FusingHandler:FireServer("AutoFuse") end)
    task.wait(0.1 + math.random() * 0.1)
    pcall(function() Events.FusingHandler:FireServer("Fuse") end)
end

-- Sell all
local function sellAllOnce()
    pcall(function() Events.SellAll:InvokeServer() end)
end

-- Daily spin
local function spinDailyOnce()
    pcall(function() Events.DailySpin:FireServer("spin", "daily") end)
end

-- Arcade roll
local function arcadeOnce()
    pcall(function() Events.ArcadeMachineRoll:FireServer() end)
end

-- Lucky block
local function luckyBlockOnce()
    pcall(function() Events.LuckyBlockHandler:FireServer("Claim") end)
    task.wait(0.1)
    pcall(function() Events.LuckyBlockHandler:FireServer("Open") end)
end

-- Open chest (TP to each chest in world)
local function chestOnce()
    pcall(function()
        local char = Player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local chestParts = {}
        -- Scan workspace for chests (cached)
        for _, v in getWsDescendants() do
            if v:IsA("ProximityPrompt") and (v.Parent.Name:lower():find("chest") or v.ActionText == "Open") then
                table.insert(chestParts, v)
            end
        end
        for _, prompt in chestParts do
            if hrp then
                local part = prompt.Parent
                local pos = part:IsA("BasePart") and part.Position or (part.PrimaryPart and part.PrimaryPart.Position)
                if pos then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 3)); task.wait(0.1) end
            end
            pcall(function() safeFirePrompt(prompt) end)
            task.wait(0.3 + math.random() * 0.2)
        end
        -- Remote backup
        pcall(function() Events.Chest:FireServer("Open") end)
        pcall(function() Events.Chest:FireServer("Claim") end)
    end)
end

-- Delivery
local function deliveryOnce()
    pcall(function() Events.DeliveryHandler:FireServer("ClaimAll") end)
    task.wait(0.1)
    pcall(function() Events.DeliveryHandler:FireServer("Claim") end)
    task.wait(0.1)
    pcall(function() Events.DeliveryPickup:FireServer() end)
end

-- Playtime rewards
local function playtimeOnce()
    pcall(function() Events.PlaytimeRewardsHandler:FireServer("Claim") end)
    task.wait(0.1)
    pcall(function() Events.PlaytimeRewardsHandler:FireServer("ClaimAll") end)
end

-- Follow rewards
local function followOnce()
    pcall(function() Events.FollowRewardsHandler:FireServer("Claim") end)
end

-- Achievements
local function achievementsOnce()
    pcall(function() Events.Achievements:FireServer("ClaimAll") end)
    task.wait(0.1)
    pcall(function() Events.Achievements:FireServer("Claim") end)
end

-- Swatter
local function swatterOnce()
    pcall(function() Events.Swatter:FireServer("Swing") end)
end

-- ============================================================
-- MAIN AUTO LOOPS
-- ============================================================

-- Auto Buy Conveyor Egg loop
task.spawn(function()
    while alive() do
        task.wait(0.5 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoBuyConveyorEgg then continue end
        buyConveyorEggsOnce()
    end
end)

-- Auto Skip Eggs loop
task.spawn(function()
    while alive() do
        task.wait(2 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoSkipEggs then continue end
        skipAllEggsOnce()
    end
end)

-- Auto Collect Coins loop
task.spawn(function()
    while alive() do
        task.wait(3 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoCollectCoins then continue end
        collectCoinsOnce()
    end
end)

-- Auto Buy Bee loop
task.spawn(function()
    while alive() do
        task.wait(1.5 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoBuyBee then continue end
        buyBeeOnce()
    end
end)

-- Auto Equip Best Bees loop
task.spawn(function()
    while alive() do
        task.wait(10 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoEquipBest then continue end
        equipBestOnce()
    end
end)

-- Auto Fuse loop
task.spawn(function()
    while alive() do
        task.wait(5 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoFuse then continue end
        fuseOnce()
    end
end)

-- Auto Sell loop
task.spawn(function()
    while alive() do
        task.wait(5 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoSell then continue end
        sellAllOnce()
    end
end)

-- Auto Daily loop
task.spawn(function()
    while alive() do
        task.wait(60 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoDaily then continue end
        spinDailyOnce()
    end
end)

-- Auto Arcade loop (6-10s to avoid anti-cheat ban)
task.spawn(function()
    while alive() do
        task.wait(jitter(6, 4))
        if not alive() then break end
        if not G().AutoArcade then continue end
        arcadeOnce()
    end
end)

-- Auto Lucky Block loop
task.spawn(function()
    while alive() do
        task.wait(3 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoLuckyBlock then continue end
        luckyBlockOnce()
    end
end)

-- Auto Chest loop
task.spawn(function()
    while alive() do
        task.wait(8 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoChest then continue end
        chestOnce()
    end
end)

-- Auto Delivery loop
task.spawn(function()
    while alive() do
        task.wait(10 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoDelivery then continue end
        deliveryOnce()
    end
end)

-- Auto Playtime loop
task.spawn(function()
    while alive() do
        task.wait(15 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoPlaytime then continue end
        playtimeOnce()
    end
end)

-- Auto Follow loop
task.spawn(function()
    while alive() do
        task.wait(30 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoFollow then continue end
        followOnce()
    end
end)

-- Auto Achievements loop
task.spawn(function()
    while alive() do
        task.wait(15 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoAchievements then continue end
        achievementsOnce()
    end
end)

-- Auto Swatter loop
task.spawn(function()
    while alive() do
        task.wait(0.6 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoSwatter then continue end
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
            if CFG.SpeedBoost then hum.WalkSpeed = CFG.SpeedValue
            elseif hum.WalkSpeed == CFG.SpeedValue then hum.WalkSpeed = 16 end
        end)
    end
end)

-- Auto Collect Arcade Orbs (TP to each orb, touch to collect)
task.spawn(function()
    while alive() do
        task.wait(0.5 + math.random() * 0.3)
        if not alive() then break end
        if not CFG.AutoCollectOrbs then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            -- Collect from ArcadeSpheres and Arcade folders
            local eventsFolder = workspace:FindFirstChild("Events")
            if not eventsFolder then return end
            for _, folder in {eventsFolder:FindFirstChild("ArcadeSpheres"), eventsFolder:FindFirstChild("Arcade")} do
                if not folder then continue end
                for _, orb in folder:GetChildren() do
                    if not CFG.AutoCollectOrbs then break end
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
        if not CFG.AutoCollectTickets then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local eventsFolder = workspace:FindFirstChild("Events")
            if not eventsFolder then return end
            for _, folder in eventsFolder:GetChildren() do
                if not folder.Name:find("ArcadeTicket") then continue end
                for _, ticket in folder:GetChildren() do
                    if not CFG.AutoCollectTickets then break end
                    local prompt = ticket:FindFirstChildOfClass("ProximityPrompt", true)
                    local pp = ticket.PrimaryPart or ticket:FindFirstChildWhichIsA("BasePart")
                    if prompt and pp and pp.Parent then
                        hrp.CFrame = CFrame.new(pp.Position)
                        task.wait(0.1)
                        pcall(function() safeFirePrompt(prompt) end)
                        task.wait(1.2 + math.random() * 0.3)
                    end
                end
            end
            -- Also check Arcade folder for tickets
            local arcade = eventsFolder:FindFirstChild("Arcade")
            if arcade then
                for _, item in arcade:GetChildren() do
                    if item.Name:find("ArcadeTicket") then
                        local prompt = item:FindFirstChildOfClass("ProximityPrompt", true)
                        local pp = item.PrimaryPart or item:FindFirstChildWhichIsA("BasePart")
                        if prompt and pp and pp.Parent then
                            hrp.CFrame = CFrame.new(pp.Position)
                            task.wait(0.1)
                            pcall(function() safeFirePrompt(prompt) end)
                            task.wait(1.2 + math.random() * 0.3)
                        end
                    end
                end
            end
        end)
    end
end)

-- Auto Event Signup (touch the signup part)
task.spawn(function()
    while alive() do
        task.wait(30 + math.random() * 5)
        if not alive() then break end
        if not CFG.AutoEventSignup then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            -- TP to event signup touch part
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
            pcall(function() Events.EventHandler:FireServer("Join") end)
        end)
    end
end)

-- Easter Egg ESP (BillboardGui on each egg showing name + distance)
local _easterESPFolder = Instance.new("Folder"); _easterESPFolder.Name = "AuroraEasterESP"
pcall(function() _easterESPFolder.Parent = game:GetService("CoreGui") end)
local _easterBBs = setmetatable({}, {__mode = "k"})

task.spawn(function()
    while alive() do
        task.wait(jitter(0.5, 0.5))
        if not alive() then break end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, egg in workspace:GetChildren() do
                if not egg.Name:find("EasterEgg_") then continue end
                local pp = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if not pp then continue end

                if CFG.EasterESP then
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

-- ============================================================
-- HONEYPOT FILTER (shared by all event auto-collectors)
-- ============================================================
local function isHoneypot(obj)
    local pp = obj:IsA("BasePart") and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))
    if not pp then return true end -- no part = suspicious
    local pos = pp.Position
    if pos.Y < -5 then return true end              -- underground
    if pos.Y > 500 then return true end             -- extreme height
    if math.abs(pos.X) < 1 and math.abs(pos.Z) < 1 then return true end  -- origin bait
    if pp.Transparency >= 1 then return true end    -- invisible = trap
    if pp.Size.Magnitude < 0.1 then return true end -- too small = fake
    return false
end

-- ============================================================
-- AUTO EASTER EGGS (instant TP, honeypot-safe)
-- ============================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(5, 2))
        if not alive() then break end
        if not G().AutoEasterEggs then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            for _, egg in workspace:GetChildren() do
                if not G().AutoEasterEggs then break end
                if not egg.Name:find("EasterEgg_") then continue end
                if isHoneypot(egg) then continue end

                local pp = egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart")
                if not pp then continue end

                -- TP above egg
                hrp.CFrame = CFrame.new(pp.Position + Vector3.new(0, 3, 0))
                task.wait(2 + math.random() * 1.5) -- wait after TP

                -- Collect: prompt or touch
                local prompt = nil
                for _, d in egg:GetDescendants() do
                    if d:IsA("ProximityPrompt") and d.Enabled then prompt = d; break end
                end
                if prompt then
                    safeFirePrompt(prompt)
                else
                    pcall(function()
                        if firetouchinterest then
                            firetouchinterest(hrp, pp, 0); task.wait(0.15); firetouchinterest(hrp, pp, 1)
                        end
                    end)
                end
                task.wait(8 + math.random() * 5) -- 8-13s between eggs
            end
        end)
    end
end)

-- ============================================================
-- AUTO METEORONS (instant TP, honeypot-safe)
-- Valid: Y > -5, has PickUpPrompt with action="Collect"
-- Invalid: underground (no prompt), origin, invisible
-- ============================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(4, 2))
        if not alive() then break end
        if not G().AutoMeteorons then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            for _, obj in workspace:GetChildren() do
                if not G().AutoMeteorons then break end
                if obj.Name ~= "MeteoronPickup" then continue end
                if isHoneypot(obj) then continue end

                -- MUST have a valid prompt (underground ones don't)
                local prompt = nil
                for _, d in obj:GetDescendants() do
                    if d:IsA("ProximityPrompt") and d.Enabled and d.ActionText == "Collect" then
                        prompt = d; break
                    end
                end
                if not prompt then continue end

                local pp = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                if not pp then continue end

                -- TP to meteoron
                hrp.CFrame = CFrame.new(pp.Position + Vector3.new(0, 2, 0))
                task.wait(2 + math.random() * 1.5) -- wait after TP

                -- Collect (hold 1s)
                safeFirePrompt(prompt)
                task.wait(8 + math.random() * 5) -- 8-13s between meteorons
            end
        end)
    end
end)

-- ============================================================
-- AUTO GHOST BEES (instant TP, swatter slap, honeypot-safe)
-- Ghost Event: Ghosts spawn as Models at workspace root (NormalGhost_X, SlowGhost_X, FastGhost_X)
-- Catch: TP onto ghost + Swatter:FireServer() (no args, server checks proximity)
-- Skip: _Honeypot suffix = anti-cheat trap
-- ============================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(3, 1))
        if not alive() then break end
        if not G().AutoGhostBees then continue end
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            -- Scan workspace root for ghost models
            for _, obj in workspace:GetChildren() do
                if not G().AutoGhostBees then break end
                if not obj:IsA("Model") then continue end
                local name = obj.Name
                -- Match: NormalGhost_X, SlowGhost_X, FastGhost_X
                if not (name:find("Ghost") and not name:find("Explosion")) then continue end
                -- Skip honeypots
                if name:find("Honeypot") then continue end

                local main = obj:FindFirstChild("Main") or obj:FindFirstChild("HumanoidRootPart")
                if not main then continue end
                if isHoneypot(obj) then continue end

                -- TP onto ghost
                pcall(function()
                    hrp.CFrame = CFrame.new(main.Position)
                end)
                task.wait(0.1)

                -- Fire swatter (no args — server checks proximity)
                pcall(function() Events.Swatter:FireServer() end)
                task.wait(0.15)
                -- Double tap for fast ghosts
                pcall(function() Events.Swatter:FireServer() end)

                task.wait(jitter(6, 4)) -- 6-10s between ghosts (anti-cheat safe)
            end
        end)
    end
end)

-- Event info listener (updates Events tab)
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
        if not CFG.AntiAFK then continue end
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
            for k, v in CFG do if type(v) == "boolean" and v then activeCount += 1 end end
            if activeCount > 0 then S.status = "Active (" .. activeCount .. " features)"
            else S.status = "Idle" end
            local data = Player:FindFirstChild("Data")
            S.beeCount = data and data:FindFirstChild("BeeCount") and data.BeeCount.Value or 0
        end)
    end
end)

-- ============================================================
-- SIDEBAR UI
-- ============================================================

---------- PALETTE ----------
local C = {
    bg         = Color3.fromRGB(18, 20, 28),
    sidebar    = Color3.fromRGB(22, 24, 34),
    panel      = Color3.fromRGB(28, 30, 42),
    card       = Color3.fromRGB(35, 37, 50),
    accent   = Color3.fromRGB(252, 110, 142),
    accentDim = Color3.fromRGB(180, 80, 110),
    text       = Color3.fromRGB(235, 235, 245),
    dim        = Color3.fromRGB(130, 130, 155),
    green      = Color3.fromRGB(80, 200, 120),
    red        = Color3.fromRGB(220, 60, 60),
    trackOff   = Color3.fromRGB(15, 15, 25),
    knobOff    = Color3.fromRGB(100, 100, 120),
    stroke     = Color3.fromRGB(50, 52, 68),
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
    local d = {
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text,
        TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center, BorderSizePixel = 0, Active = false,
    }
    for k, v in d do if props[k] == nil then props[k] = v end end
    return create("TextLabel", props, parent)
end
local function connectClick(frame, cb)
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then cb() end
    end)
end

---------- SCREEN GUI ----------
local gui = create("ScreenGui", {
    Name = "Aurora", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, IgnoreGuiInset = true,
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
if not parentOk then
    pcall(function() gui.Parent = Player.PlayerGui end)
end

---------- MOBILE DETECTION + SCALING ----------
local _viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _isMobile = UIS.TouchEnabled and (_viewport.X < 1200)
local _scale    = _isMobile and math.clamp(_viewport.X / 700, 0.55, 0.85) or 1

---------- LAYOUT CONSTANTS ----------
local SIDEBAR_W = 110
local TOTAL_W   = 660
local TOTAL_H   = 455
local TOP_H     = 40
local GAP       = 6
local CONTENT_X = SIDEBAR_W + GAP
local CONTENT_Y = TOP_H + 4
local CONTENT_H = TOTAL_H - CONTENT_Y - 6
local AVAIL_W   = TOTAL_W - CONTENT_X - 6
local LEFT_PW   = math.floor(AVAIL_W * 0.58)
local RIGHT_PW  = AVAIL_W - LEFT_PW - GAP

---------- MAIN FRAME ----------
local main = create("Frame", {
    Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = _isMobile and UDim2.new(0.5, -TOTAL_W * _scale / 2, 0, 40) or UDim2.fromOffset(16, 60),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0,
    BorderSizePixel = 0, Active = true, ClipsDescendants = true,
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

local gameName = "Bee Garden"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
lbl(topBar, {
    Name = "Game", Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(1, -320, 0, 0),
    Text = gameName, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
})

-- Minimize button
local minBtn = create("Frame", {
    Name = "Min", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(minBtn, { Size = UDim2.new(1,0,1,0), Text = "\xE2\x80\x93", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })

-- Close button
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
    Position = UDim2.fromOffset(0, TOP_H), BackgroundColor3 = C.sidebar,
    BackgroundTransparency = 0, BorderSizePixel = 0, ClipsDescendants = true,
}, main)
corner(sidebar, 12)
create("Frame", {
    Name = "Divider", Size = UDim2.new(0, 1, 1, -8), Position = UDim2.new(1, 0, 0, 4),
    BackgroundColor3 = C.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
}, sidebar)

local TAB_DEFS = {
    { name = "Farm",    color = Color3.fromRGB(80, 200, 120) },
    { name = "Bees",    color = Color3.fromRGB(252, 200, 80) },
    { name = "Auto",    color = Color3.fromRGB(100, 180, 255) },
    { name = "Events",  color = Color3.fromRGB(255, 100, 100) },
    { name = "Utility", color = Color3.fromRGB(180, 130, 255) },
}
local CONFIG_TAB = { name = "Config", color = Color3.fromRGB(130, 130, 155) }

local tabBtns       = {}
local leftContainers  = {}
local rightContainers = {}

local tabList = create("Frame", {
    Name = "TabList", Size = UDim2.new(1, -8, 0, #TAB_DEFS * 40 + 4),
    Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1, BorderSizePixel = 0,
}, sidebar)
create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4) }, tabList)

local allTabs = {}

local function makeTabBtn(def, idx, parent)
    local btn = create("Frame", {
        Name = "Tab_" .. def.name, Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.card, BackgroundTransparency = 0.5,
        BorderSizePixel = 0, Active = true, LayoutOrder = idx,
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

for i, def in ipairs(TAB_DEFS) do
    local btn, ind = makeTabBtn(def, i, tabList)
    allTabs[i] = { btn = btn, indicator = ind, name = def.name }
end

-- Config tab pinned at bottom of sidebar
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
    local tname = (i <= #TAB_DEFS) and TAB_DEFS[i].name or "Config"
    local lp = makePanel("L_" .. tname, CONTENT_X, LEFT_PW)
    local rp = makePanel("R_" .. tname, CONTENT_X + LEFT_PW + GAP, RIGHT_PW)
    lp.Visible = (i == 1)
    rp.Visible = (i == 1)
    leftContainers[i]  = lp
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
        leftContainers[i].Visible  = (i == idx)
        rightContainers[i].Visible = (i == idx)
    end
end

for i, t in ipairs(allTabs) do
    local ci = i
    connectClick(t.btn, function() switchTab(ci) end)
end

---------- COMPONENT BUILDERS ----------
local _order   = {}
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
    local dot = create("Frame", { Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.accent, BorderSizePixel = 0 }, row)
    corner(dot, 2)
    lbl(row, { Size = UDim2.new(1,-12,1,0), Position = UDim2.fromOffset(12, 0), Text = string.upper(title), TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = C.accent })
end

local function toggleRow(name, cfgKey, panel, callback)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "T_" .. cfgKey, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(1,-60,1,0), Position = UDim2.fromOffset(10,0), Text = name, TextSize = 12, Font = Enum.Font.Gotham })
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

local function infoRow(name, initialValue, panel)
    panel = panel or _curRight
    local o = nextOrder(panel)
    local row = create("Frame", {
        Size = UDim2.new(1,0,0,22), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0,
    }, panel)
    lbl(row, { Size = UDim2.new(0.52,0,1,0), Position = UDim2.fromOffset(4,0), Text = name, TextSize = 10, Font = Enum.Font.GothamSemibold, TextColor3 = C.dim })
    local val = lbl(row, {
        Name = "Val", Size = UDim2.new(0.48,-4,1,0), Position = UDim2.new(0.52,0,0,0),
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
    local btnLbl = lbl(btn, {
        Size = UDim2.new(1,0,1,0), Text = name, TextSize = 11, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.text,
    })
    connectClick(btn, function()
        if callback then task.spawn(function() pcall(callback) end) end
        local orig = btnLbl.Text
        btnLbl.Text = name .. " ..."
        btnLbl.TextColor3 = C.green
        task.delay(1.5, function() btnLbl.Text = orig; btnLbl.TextColor3 = C.text end)
    end)
    return btn
end

-- Cycling selector (click to cycle through a list)
local function cycleRow(label, list, cfgKey, displayFn, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "C_" .. cfgKey, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    stroke(row, C.accent, 1, 0.7)
    local idx = 1
    for i, v in ipairs(list) do if v == CFG[cfgKey] then idx = i; break end end
    local rowLbl = lbl(row, {
        Name = "Label", Size = UDim2.new(1,-10,1,0), Position = UDim2.fromOffset(10,0),
        Text = label .. ": " .. (displayFn and displayFn(CFG[cfgKey]) or tostring(CFG[cfgKey])),
        TextSize = 11, Font = Enum.Font.GothamSemibold, TextColor3 = C.text,
    })
    -- Arrow hint
    lbl(row, {
        Size = UDim2.fromOffset(16,34), Position = UDim2.new(1,-20,0,0),
        Text = ">", TextSize = 11, Font = Enum.Font.GothamBold, TextColor3 = C.dim,
        TextXAlignment = Enum.TextXAlignment.Center,
    })
    connectClick(row, function()
        idx = (idx % #list) + 1
        CFG[cfgKey] = list[idx]
        rowLbl.Text = label .. ": " .. (displayFn and displayFn(CFG[cfgKey]) or tostring(CFG[cfgKey]))
        if CFG.AutoSave then saveCFG() end
    end)
    return row
end

local function multiSelectDD(title, items, selMap, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local expanded = false
    local ITEM_H = 26
    local MAX_VIS = 5
    local totalH = #items * ITEM_H
    local scrollH = math.min(totalH, MAX_VIS * ITEM_H)
    local wrapper = create("Frame", {
        Name = "DD_" .. title, Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = o, ClipsDescendants = false,
    }, panel)
    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.card, BorderSizePixel = 0, Active = true,
    }, wrapper)
    corner(header, 8); stroke(header, C.accent, 1, 0.6)
    local function getCountText()
        local count = 0
        for _, nm in items do if selMap[nm] then count += 1 end end
        if selMap["All"] then return title .. ": All" end
        if count == 0 then return title .. ": None" end
        if count <= 2 then
            local names = {}
            for _, nm in items do if selMap[nm] and nm ~= "All" then table.insert(names, nm) end end
            return title .. ": " .. table.concat(names, ", ")
        end
        return title .. ": " .. count .. "/" .. #items
    end
    local hdrLbl = lbl(header, {
        Size = UDim2.new(0.78, 0, 1, 0), Position = UDim2.fromOffset(10, 0),
        Text = getCountText(), TextSize = 10, Font = Enum.Font.GothamSemibold,
    })
    lbl(header, {
        Size = UDim2.new(0.18, 0, 1, 0), Position = UDim2.new(0.78, 0, 0, 0),
        Text = "\xE2\x96\xBC", TextSize = 10, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Center,
    })
    local listFrame = create("ScrollingFrame", {
        Name = "List", Size = UDim2.new(1, 0, 0, scrollH),
        Position = UDim2.fromOffset(0, 30), BackgroundColor3 = C.bg, BackgroundTransparency = 0.05,
        BorderSizePixel = 0, Visible = false, ClipsDescendants = true,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent,
        CanvasSize = UDim2.fromOffset(0, totalH), ScrollingDirection = Enum.ScrollingDirection.Y,
        ZIndex = 10,
    }, wrapper)
    corner(listFrame, 6)
    for i, nm in ipairs(items) do
        local optRow = create("Frame", {
            Size = UDim2.new(1, 0, 0, ITEM_H), Position = UDim2.fromOffset(0, (i-1) * ITEM_H),
            BackgroundColor3 = C.card, BackgroundTransparency = 0.3, BorderSizePixel = 0, Active = true, ZIndex = 11,
        }, listFrame)
        corner(optRow, 4)
        local ind = lbl(optRow, {
            Size = UDim2.new(0, 20, 1, 0), Position = UDim2.fromOffset(8, 0),
            Text = selMap[nm] and "+" or "o", TextSize = 10, Font = Enum.Font.GothamBold,
            TextColor3 = selMap[nm] and C.accent or C.dim, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 12,
        })
        local ol = lbl(optRow, {
            Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(28, 0),
            Text = nm, TextSize = 10, Font = Enum.Font.GothamSemibold,
            TextColor3 = selMap[nm] and C.accent or C.dim, ZIndex = 12,
        })
        connectClick(optRow, function()
            selMap[nm] = not selMap[nm]
            ind.Text = selMap[nm] and "+" or "o"
            ind.TextColor3 = selMap[nm] and C.accent or C.dim
            ol.TextColor3 = selMap[nm] and C.accent or C.dim
            hdrLbl.Text = getCountText()
            if CFG.AutoSave then saveCFG() end
        end)
    end
    connectClick(header, function()
        expanded = not expanded
        listFrame.Visible = expanded
        wrapper.Size = expanded and UDim2.new(1, 0, 0, 30 + scrollH) or UDim2.new(1, 0, 0, 28)
    end)
end

-- ============================================================
-- TAB 1: FARM
-- ============================================================
setPanel(leftContainers[1], rightContainers[1])

sectionHeader("Conveyor Eggs", _curLeft)
toggleRow("Auto Buy Conveyor Egg", "AutoBuyConveyorEgg", _curLeft)
toggleRow("Auto Skip Eggs", "AutoSkipEggs", _curLeft)

sectionHeader("Egg Filter", _curLeft)
multiSelectDD("Buy Eggs", (function() local t = {"All"}; for _, v in EGG_NAMES do table.insert(t, v) end; return t end)(), SelEggs, _curLeft)

sectionHeader("Coins", _curLeft)
toggleRow("Auto Collect Coins", "AutoCollectCoins", _curLeft)

sectionHeader("Quick Actions", _curLeft)
actionButton("Buy Eggs Now", C.card, _curLeft, function() buyConveyorEggsOnce() end)
actionButton("Skip All Eggs", C.card, _curLeft, function() skipAllEggsOnce() end)
actionButton("Collect Coins", C.card, _curLeft, function() collectCoinsOnce() end)

-- Right: Farm status
sectionHeader("Farm Status", _curRight)
local _rFarmStatus = infoRow("Status", "Idle", _curRight)
local _rEggsBought = infoRow("Eggs Bought", "0", _curRight)
local _rCoins      = infoRow("Coins Collected", "0", _curRight)

sectionHeader("Wallet", _curRight)
local _rCoinsWallet = infoRow("Coins", "---", _curRight)
local _rGardenScore = infoRow("Garden Score", "---", _curRight)

sectionHeader("Session", _curRight)
local _rRuntime = infoRow("Runtime", "0m", _curRight)

-- ============================================================
-- TAB 2: BEES
-- ============================================================
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Shop", _curLeft)
toggleRow("Auto Buy Bee", "AutoBuyBee", _curLeft)
multiSelectDD("Buy Bees", (function() local t = {"All"}; for _, v in BEE_SHOP_NAMES do table.insert(t, v) end; return t end)(), SelBees, _curLeft)

sectionHeader("Management", _curLeft)
toggleRow("Auto Equip Best", "AutoEquipBest", _curLeft)
toggleRow("Auto Fuse Bees", "AutoFuse", _curLeft)

sectionHeader("Quick Actions", _curLeft)
actionButton("Buy Bee Now", C.card, _curLeft, function() buyBeeOnce() end)
actionButton("Equip Best Now", C.card, _curLeft, function() equipBestOnce() end)
actionButton("Fuse Now", C.card, _curLeft, function() fuseOnce() end)

-- Right: Bee info
sectionHeader("Bee Info", _curRight)
local _rBeeCount    = infoRow("Bee Count", "---", _curRight)
local _rBeeStatus   = infoRow("Status", "Idle", _curRight)

-- ============================================================
-- TAB 3: AUTO
-- ============================================================
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Economy", _curLeft)
toggleRow("Auto Sell All", "AutoSell", _curLeft)
toggleRow("Auto Daily Spin", "AutoDaily", _curLeft)
toggleRow("Auto Arcade Roll", "AutoArcade", _curLeft)

sectionHeader("World", _curLeft)
toggleRow("Auto Lucky Block", "AutoLuckyBlock", _curLeft)
toggleRow("Auto Open Chests", "AutoChest", _curLeft)
toggleRow("Auto Deliveries", "AutoDelivery", _curLeft)

sectionHeader("Rewards", _curLeft)
toggleRow("Auto Playtime Rewards", "AutoPlaytime", _curLeft)
toggleRow("Auto Follow Rewards", "AutoFollow", _curLeft)
toggleRow("Auto Achievements", "AutoAchievements", _curLeft)

-- Right: Session stats
sectionHeader("Session Stats", _curRight)
local _rAutoRuntime  = infoRow("Runtime", "0m", _curRight)
local _rAutoCoins    = infoRow("Coins", "---", _curRight)
local _rAutoStatus   = infoRow("Status", "Idle", _curRight)

sectionHeader("Quick Actions", _curRight)
actionButton("Sell All Now", C.card, _curRight, function() sellAllOnce() end)
actionButton("Spin Daily Now", C.card, _curRight, function() spinDailyOnce() end)
actionButton("Claim Delivery", C.card, _curRight, function() deliveryOnce() end)
actionButton("Claim Playtime", C.card, _curRight, function() playtimeOnce() end)
actionButton("Claim Achievements", C.card, _curRight, function() achievementsOnce() end)

-- ============================================================
-- TAB 4: EVENTS
-- ============================================================
setPanel(leftContainers[4], rightContainers[4])

sectionHeader("Easter Event", _curLeft)
toggleRow("Easter Egg ESP", "EasterESP", _curLeft)
toggleRow("Auto Collect Eggs", "AutoEasterEggs", _curLeft)
toggleRow("Auto Meteorons", "AutoMeteorons", _curLeft)
toggleRow("Auto Ghost Bees", "AutoGhostBees", _curLeft)

actionButton("TP Nearest Egg", C.green, _curLeft, function()
    pcall(function()
        local hrp = Player.Character.HumanoidRootPart
        local best, bestDist = nil, math.huge
        for _, egg in workspace:GetChildren() do
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

sectionHeader("Arcade Event", _curLeft)
toggleRow("Auto Collect Orbs", "AutoCollectOrbs", _curLeft)
toggleRow("Auto Collect Tickets", "AutoCollectTickets", _curLeft)
toggleRow("Auto Event Signup", "AutoEventSignup", _curLeft)

actionButton("TP to Event", C.accent, _curLeft, function()
    pcall(function()
        local tp = workspace.Core.Scriptable.TouchParts:FindFirstChild("Event")
        if tp then Player.Character.HumanoidRootPart.CFrame = CFrame.new(tp.Position + Vector3.new(0, 3, 0)) end
    end)
end)

sectionHeader("Event Info", _curRight)
local _evtName = infoRow("Event", "---", _curRight)
local _evtTime = infoRow("Time Left", "---", _curRight)
local _evtStatus = infoRow("Status", "---", _curRight)
local _evtEggs = infoRow("Easter Eggs", "---", _curRight)

sectionHeader("Pac-Man", _curRight)
actionButton("TP Pacman 1", C.card, _curRight, function()
    pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(11.8, 11.1, 79) end)
end)
actionButton("TP Pacman 2", C.card, _curRight, function()
    pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(106.8, 11, -35.7) end)
end)

-- ============================================================
-- TAB 5: UTILITY
-- ============================================================
setPanel(leftContainers[5], rightContainers[5])

sectionHeader("Movement", _curLeft)
toggleRow("Speed Boost", "SpeedBoost", _curLeft)

-- Speed slider (manual with +/- buttons for simplicity)
do
    local o = nextOrder(_curLeft)
    local srow = create("Frame", {
        Name = "SpeedRow", Size = UDim2.new(1,0,0,34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, _curLeft)
    corner(srow, 8)
    lbl(srow, { Size = UDim2.new(0.55,0,1,0), Position = UDim2.fromOffset(10,0), Text = "Walk Speed", TextSize = 12, Font = Enum.Font.Gotham })
    local speedValLbl = lbl(srow, {
        Name = "SpeedVal", Size = UDim2.new(0.2,0,1,0), Position = UDim2.new(0.55,0,0,0),
        Text = tostring(CFG.SpeedValue), TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Center,
    })
    local minusBtn = create("Frame", {
        Name = "Minus", Size = UDim2.fromOffset(22,22), Position = UDim2.new(0.75,0,0.5,-11),
        BackgroundColor3 = C.card, BorderSizePixel = 0, Active = true,
    }, srow)
    corner(minusBtn, 4)
    stroke(minusBtn, C.stroke, 1, 0.3)
    lbl(minusBtn, { Size = UDim2.new(1,0,1,0), Text = "-", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
    local plusBtn = create("Frame", {
        Name = "Plus", Size = UDim2.fromOffset(22,22), Position = UDim2.new(0.75,26,0.5,-11),
        BackgroundColor3 = C.card, BorderSizePixel = 0, Active = true,
    }, srow)
    corner(plusBtn, 4)
    stroke(plusBtn, C.stroke, 1, 0.3)
    lbl(plusBtn, { Size = UDim2.new(1,0,1,0), Text = "+", TextSize = 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center })
    connectClick(minusBtn, function()
        CFG.SpeedValue = math.max(16, CFG.SpeedValue - 5)
        speedValLbl.Text = tostring(CFG.SpeedValue)
        if CFG.AutoSave then saveCFG() end
    end)
    connectClick(plusBtn, function()
        CFG.SpeedValue = math.min(200, CFG.SpeedValue + 5)
        speedValLbl.Text = tostring(CFG.SpeedValue)
        if CFG.AutoSave then saveCFG() end
    end)
end

sectionHeader("Safety", _curLeft)
toggleRow("Anti-AFK", "AntiAFK", _curLeft)
toggleRow("Auto Swatter", "AutoSwatter", _curLeft)

sectionHeader("Quick Actions", _curLeft)
actionButton("Sell All", C.card, _curLeft, function() sellAllOnce() end)
actionButton("Equip Best Bees", C.card, _curLeft, function() equipBestOnce() end)

-- Right: Player stats
sectionHeader("Player Stats", _curRight)
local _rUtilCoins  = infoRow("Coins", "---", _curRight)
local _rUtilScore  = infoRow("Garden Score", "---", _curRight)
local _rUtilHealth = infoRow("Health", "---", _curRight)
local _rUtilSpeed  = infoRow("Walk Speed", "16", _curRight)

-- ============================================================
-- TAB 6: CONFIG
-- ============================================================
setPanel(leftContainers[6], rightContainers[6])

sectionHeader("Config Management", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)

actionButton("Save Config", C.green, _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function()
    loadSavedCFG()
end)
actionButton("Reset All", C.red, _curLeft, function()
    for k, v in CFG do
        if type(v) == "boolean" then CFG[k] = false end
    end
    CFG.SpeedValue = 50
    CFG.SelectedBee = "Any"
    saveCFG()
end)

-- Right: active feature list
sectionHeader("Config File", _curRight)
infoRow("File", _cfgFileName, _curRight)

sectionHeader("Active Features", _curRight)
local _cfgActiveList = lbl(rightContainers[5], {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 120),
    Text = "None", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    LayoutOrder = nextOrder(rightContainers[5]),
})

-- ============================================================
-- STATUS UPDATE LOOP
-- ============================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.5))
        if not alive() then break end
        pcall(function()
            local elapsed = tick() - S.session
            local mins  = math.floor(elapsed / 60)
            local hrs   = math.floor(mins / 60)
            local rtime = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local coins = getCoins()
            local data  = Player:FindFirstChild("Data")
            local gs    = data and data:FindFirstChild("GardenScore") and data.GardenScore.Value or 0
            local bees  = data and data:FindFirstChild("BeeCount") and data.BeeCount.Value or 0

            -- Tab 1: Farm
            _rFarmStatus.Text  = S.status
            _rEggsBought.Text  = tostring(S.eggsBought)
            _rCoins.Text       = tostring(S.coinsCollect)
            _rCoinsWallet.Text = formatNum(coins)
            _rGardenScore.Text = formatNum(gs)
            _rRuntime.Text     = rtime

            -- Tab 2: Bees
            _rBeeCount.Text   = tostring(bees)
            local beeActive = {}
            if CFG.AutoBuyBee then table.insert(beeActive, "Buying") end
            if CFG.AutoEquipBest then table.insert(beeActive, "Equipping") end
            if CFG.AutoFuse then table.insert(beeActive, "Fusing") end
            _rBeeStatus.Text = #beeActive > 0 and table.concat(beeActive, "+") or "Idle"

            -- Tab 3: Auto
            _rAutoRuntime.Text = rtime
            _rAutoCoins.Text   = formatNum(coins)
            _rAutoStatus.Text  = S.status

            -- Tab 4: Events
            _evtName.Text = _eventName
            _evtTime.Text = _eventTime
            pcall(function()
                local ec = 0
                for _, e in workspace:GetChildren() do if e.Name:find("EasterEgg_") then ec += 1 end end
                _evtEggs.Text = ec .. " remaining"
            end)
            pcall(function()
                local eventsFolder = workspace:FindFirstChild("Events")
                local orbCount = 0
                if eventsFolder then
                    local spheres = eventsFolder:FindFirstChild("ArcadeSpheres")
                    if spheres then orbCount = #spheres:GetChildren() end
                end
                _evtStatus.Text = CFG.AutoCollectOrbs and ("Collecting (" .. orbCount .. " orbs)") or "Idle"
            end)

            -- Tab 5: Utility
            _rUtilCoins.Text  = formatNum(coins)
            _rUtilScore.Text  = formatNum(gs)
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then
                    _rUtilHealth.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth)
                    _rUtilSpeed.Text  = tostring(math.floor(hum.WalkSpeed))
                end
            end

            -- Tab 6: Config active features
            local active = {}
            for k, v in CFG do
                if type(v) == "boolean" and v and k ~= "AutoSave" then
                    table.insert(active, k)
                end
            end
            table.sort(active)
            _cfgActiveList.Text = #active > 0 and table.concat(active, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #active * 14 + 10))
        end)
    end
end)

-- Init first tab
switchTab(1)

print("[Aurora] Bee Garden loaded")

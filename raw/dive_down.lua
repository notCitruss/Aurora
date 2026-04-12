--// Aurora v3 -- Dive Down
--// Made by notCitruss | Sidebar UI
--// PlaceId: 131756752872026
--// Dual networking: Packet system (binary) + Network remotes (workspace.Network)
--// BuyItem:Fire("Treat"/"Tool", itemName) for shop purchases
--// FeedFish:FireServer(fishId, treatName) for feeding

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local Player = Players.LocalPlayer

for _, n in {"Aurora"} do
    pcall(function() if gethui then local old = gethui():FindFirstChild(n); if old then old:Destroy() end end end)
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild(n); if old then old:Destroy() end end)
    pcall(function() local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end)
end
task.wait(0.1)

---------- NETWORKING ----------
local NET = workspace:FindFirstChild("Network")
local Packet = require(RS.Packets.Packet)
local PKT = {
    SellInventory      = Packet("SellInventory"),
    SellItem           = Packet("SellItem"),
    ClaimOfflineReward = Packet("ClaimOfflineReward"),
    BuyItem            = Packet("BuyItem"),
}

local function fireNet(name, arg1, arg2)
    pcall(function()
        local r = NET:FindFirstChild(name .. "-RemoteEvent")
        if r then
            if arg2 then r:FireServer(arg1, arg2)
            elseif arg1 then r:FireServer(arg1)
            else r:FireServer() end
        end
    end)
end

local function invokeNet(name, arg1)
    local res
    pcall(function()
        local r = NET:FindFirstChild(name .. "-RemoteFunction")
        if r then
            if arg1 then res = r:InvokeServer(arg1)
            else res = r:InvokeServer() end
        end
    end)
    return res
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
---------- CONFIG ----------
local CFG = {
    AutoFarm        = false,
    FarmAutoSell    = false,
    AutoSell        = false,
    AutoEquipBest   = false,
    AutoBuyTreats   = false,
    AutoBuyTools    = false,
    AutoFeedFish    = false,
    AutoRebirth     = false,
    AutoClaim       = false,
    ProtectMutations = true,
    StealFish       = false,
    SpeedBoost      = false,
    AntiAFK         = false,
    AutoSave        = false,
}

---------- RARITY FILTER ----------
local RARITIES = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Divine"}
local SelRarities = {}
for _, r in ipairs(RARITIES) do SelRarities[r] = true end

---------- SELL RARITY FILTER ----------
local SelSellRarities = {Common = true, Rare = true}

---------- MUTATION FILTER ----------
local MUTATIONS = {"Normal", "Silver", "Gold", "Rainbow", "Frozen", "Shocked", "Magma", "Chocolate", "Dry", "Infected", "Evil"}
local SelMutations = {Normal = false, Silver = true, Gold = true, Rainbow = true, Frozen = true, Shocked = true, Magma = true, Chocolate = true, Dry = true, Infected = true, Evil = true}

---------- OCEAN ZONES ----------
local OCEAN_ZONES = {
    {name = "SunlightZone",   label = "Sunlight Zone",    pos = Vector3.new(-1929, 2485, -1414)},
    {name = "CoralReef",      label = "Coral Reef",       pos = Vector3.new(-1935, 2409, -1419)},
    {name = "TwilightZone",   label = "Twilight Zone",    pos = Vector3.new(-1935, 2219, -1419)},
    {name = "DeepOcean",      label = "Deep Ocean",       pos = Vector3.new(-1935, 1829, -1419)},
    {name = "TheDeepDark",    label = "The Deep Dark",    pos = Vector3.new(-1935, 1102, -1419)},
    {name = "TheTrenches",    label = "The Trenches",     pos = Vector3.new(-1929, 324, -1420)},
    {name = "Atlantis",       label = "Atlantis",         pos = Vector3.new(-1916, -16, -1419)},
    {name = "AquaForest",     label = "Aqua Forest",      pos = Vector3.new(-1928, -301, -1419)},
    {name = "ShellReef",      label = "Shell Reef",       pos = Vector3.new(-1928, -651, -1419)},
    {name = "KrakenWorld",    label = "Kraken World",     pos = Vector3.new(-1928, -1103, -1419)},
    {name = "MegalodonsLair", label = "Megalodon's Lair", pos = Vector3.new(-1928, -1577, -1419)},
    {name = "IceArea",        label = "Ice Area",          pos = Vector3.new(-1928, -1957, -1419)},
}

local ZONE_NAMES = {}
local ZONE_NAME_TO_LABEL = {}
local ZONE_LABEL_TO_DATA = {}
for _, z in ipairs(OCEAN_ZONES) do
    table.insert(ZONE_NAMES, z.label)
    ZONE_NAME_TO_LABEL[z.name] = z.label
    ZONE_LABEL_TO_DATA[z.label] = z
end

local SelZones = {}
for _, z in ipairs(OCEAN_ZONES) do SelZones[z.label] = true end

---------- SELECTIONS ----------
local SelTreats = {Worm = true, Bee = true, Cockroach = true, Snail = true}
local SelTools  = {HarpoonGun = true, TNT = true}
local FEED_SLOTS = {"1st", "2nd", "3rd", "4th", "5th"}
local SelFeedSlots = {["1st"]=true, ["2nd"]=true, ["3rd"]=true, ["4th"]=true, ["5th"]=true}

---------- SAVE/LOAD ----------
local _cfgFileName = "aurora_cfg_dive_down.json"
local HttpService  = game:GetService("HttpService")

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_dive_down"] end
    if saved and type(saved) == "table" then
        for k, v in saved do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._SelTreats      then for k,_ in SelTreats      do SelTreats[k]      = nil end; for k,v in saved._SelTreats      do SelTreats[k]      = v end end
        if saved._SelTools       then for k,_ in SelTools        do SelTools[k]       = nil end; for k,v in saved._SelTools       do SelTools[k]       = v end end
        if saved._SelFeedSlots and next(saved._SelFeedSlots) then for k,_ in SelFeedSlots do SelFeedSlots[k] = nil end; for k,v in saved._SelFeedSlots do SelFeedSlots[k] = v end end
        if saved._SelRarities    then for k,_ in SelRarities     do SelRarities[k]    = nil end; for k,v in saved._SelRarities    do SelRarities[k]    = v end end
        if saved._SelSellRarities then for k,_ in SelSellRarities do SelSellRarities[k] = nil end; for k,v in saved._SelSellRarities do SelSellRarities[k] = v end end
        if saved._SelZones       then for k,_ in SelZones        do SelZones[k]       = nil end; for k,v in saved._SelZones       do SelZones[k]       = v end end
        if saved._SelMutations   then for k,_ in SelMutations    do SelMutations[k]   = nil end; for k,v in saved._SelMutations   do SelMutations[k]   = v end end
    end
end

local function saveCFG()
    local toSave = {}
    for k, v in CFG do toSave[k] = v end
    toSave._SelTreats      = SelTreats
    toSave._SelTools       = SelTools
    toSave._SelFeedSlots   = SelFeedSlots
    toSave._SelRarities    = SelRarities
    toSave._SelSellRarities = SelSellRarities
    toSave._SelZones       = SelZones
    toSave._SelMutations   = SelMutations
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(toSave)) end)
    getgenv()["AuroraCFG_dive_down"] = toSave
end

loadSavedCFG()

local TREAT_LIST = {"Worm","Beetle","Ladybug","Bee","Cockroach","Spider","Frog","Grasshopper","Butterfly","Mouse","Dragonfly","Snail"}
local TOOL_LIST  = {"HarpoonGun","LegendaryRadar","EpicRadar","MythicalRadar","TNT","MutationRemover","LifeJacket"}

---------- STATE ----------
local _cash = 0
local _reb  = 0
local S = {sells = 0, equips = 0, reb = 0, steals = 0, treats = 0, tools = 0, feeds = 0, session = tick()}

pcall(function()
    local ls = Player:WaitForChild("leaderstats", 5)
    if ls then
        local c = ls:FindFirstChild("Cash")
        if c then _cash = c.Value; c.Changed:Connect(function(v) _cash = v end) end
        local r = ls:FindFirstChild("Rebirth")
        if r then _reb = r.Value; r.Changed:Connect(function(v) _reb = v end) end
    end
end)

local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return string.format("%.0f", n) end
end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CORE FUNCTIONS ----------

-- Fish name -> rarity (scanned from game TextLabels, NOT CPS-based)
local FISH_RARITY = {
    ["Bass"] = "Rare", ["Bettafish"] = "Epic", ["Blobfish"] = "Common",
    ["Blue Tang"] = "Common", ["Bull"] = "Common", ["Butterflyfish"] = "Rare",
    ["Catfish"] = "Common", ["Cloudfish"] = "Common", ["Clownfish"] = "Common",
    ["Crabfish"] = "Common", ["Eel"] = "Legendary", ["Goldfish"] = "Common",
    ["GreatWhite"] = "Common", ["Gulper Eel"] = "Common", ["Kelpy"] = "Common",
    ["Koi"] = "Epic", ["Lionfish"] = "Rare", ["Mahi-Mahi"] = "Common",
    ["Mako"] = "Common", ["Piranha"] = "Rare", ["Pufferfish"] = "Epic",
    ["Rockfish"] = "Common", ["Salmon"] = "Rare", ["Seahorse"] = "Epic",
    ["Seal"] = "Legendary", ["Skelfin"] = "Common", ["Slickhead"] = "Common",
    ["Spinyfish"] = "Common", ["Sunfish"] = "Common", ["Swordfish"] = "Epic",
    ["Thresher"] = "Common", ["Tuna"] = "Common", ["Turtle"] = "Legendary",
    ["Whale"] = "Common", ["Whalefish"] = "Common",
}

local function getFishRarity(fishName)
    return FISH_RARITY[fishName] or "Common"
end

local function doSell()
    pcall(function() PKT.SellInventory:Fire() end)
    S.sells += 1
end

local function doFilteredSell()
    -- SellInventory is all-or-nothing (SellItem packet doesn't work from executor)
    -- Protection: equip best fish before selling — equipped fish is NOT sold
    pcall(function() invokeNet("RequestEquipBestFish") end)
    task.wait(0.3)
    pcall(function() PKT.SellInventory:Fire() end)
    S.sells += 1
    return true
end

local function doSmartSell()
    return doFilteredSell()
end

local function doEquipBest()
    invokeNet("RequestEquipBestFish")
    S.equips += 1
end

local _suppressNotifs = false

pcall(function()
    local notif1   = NET:FindFirstChild("ShowNotification-RemoteEvent")
    local notif2   = NET:FindFirstChild("ShowNotfication-RemoteEvent")
    local popupEvt = RS:FindFirstChild("Modules") and RS.Modules:FindFirstChild("PopUp") and RS.Modules.PopUp:FindFirstChild("PopUpEvent")

    for _, remote in {notif1, notif2} do
        if remote then
            remote.OnClientEvent:Connect(function(msg)
                if _suppressNotifs and type(msg) == "string" then
                    local low = msg:lower()
                    if low:find("stock") or low:find("afford") or low:find("enough") or low:find("sold out") then
                        pcall(function()
                            local notifGui = Player.PlayerGui:FindFirstChild("NotificationUI")
                            if notifGui then
                                for _, child in notifGui:GetDescendants() do
                                    if child:IsA("TextLabel") and child.Text:lower():find("stock") then
                                        child.Parent.Visible = false
                                    end
                                end
                            end
                        end)
                    end
                end
            end)
        end
    end

    if popupEvt then
        popupEvt.Event:Connect(function(data)
            if _suppressNotifs and type(data) == "table" and type(data.text) == "string" then
                local low = data.text:lower()
                if low:find("stock") or low:find("afford") then return end
            end
        end)
    end
end)

local function getUIStock()
    local stock = {Treat = {}, Tool = {}}
    pcall(function()
        local shops = Player.PlayerGui.PersistentUI.Shops
        for _, shopFrame in shops:GetChildren() do
            local st = shopFrame.Name
            if stock[st] then
                for _, d in shopFrame:GetDescendants() do
                    local itemId = d:GetAttribute("ItemId")
                    local count  = d:GetAttribute("Stock")
                    if itemId and count ~= nil then stock[st][itemId] = count end
                end
            end
        end
    end)
    return stock
end

local function doBuyTreats()
    if not CFG.AutoBuyTreats then return end
    local stock = getUIStock()
    for name, sel in SelTreats do
        if not CFG.AutoBuyTreats then break end
        if sel and (stock.Treat[name] or 0) > 0 then
            pcall(function() PKT.BuyItem:Fire("Treat", name) end)
            S.treats += 1
            task.wait(1.5)
        end
    end
end

local function doBuyTools()
    if not CFG.AutoBuyTools then return end
    local stock = getUIStock()
    for name, sel in SelTools do
        if not CFG.AutoBuyTools then break end
        if sel and (stock.Tool[name] or 0) > 0 then
            pcall(function() PKT.BuyItem:Fire("Tool", name) end)
            S.tools += 1
            task.wait(1.5)
        end
    end
end

local function doFeedFish()
    if not CFG.AutoFeedFish then return end
    pcall(function()
        local sv = NET:FindFirstChild("Get Save-RemoteFunction"):InvokeServer()
        if sv and sv.AquariumFish and sv.OwnedTreats then
            local sorted = {}
            for fId, fData in sv.AquariumFish do
                local cps = typeof(fData) == "table" and (fData.CashPerSec or fData.Earnings or 0) or 0
                table.insert(sorted, {id = fId, cps = cps})
            end
            table.sort(sorted, function(a, b) return a.cps > b.cps end)
            local slotNames = {"1st", "2nd", "3rd", "4th", "5th"}
            for i = 1, math.min(5, #sorted) do
                if not CFG.AutoFeedFish then break end
                if not SelFeedSlots[slotNames[i]] then continue end
                local fish = sorted[i]
                for tName, count in sv.OwnedTreats do
                    if count > 0 then
                        fireNet("FeedFish", fish.id, tName)
                        S.feeds += 1
                        task.wait(0.15)
                        break
                    end
                end
            end
        end
    end)
end

local function doRebirth()
    fireNet("skipRebirth")
    task.wait(0.5)
    fireNet("RebirthRequest")
    S.reb += 1
end

local function doClaim()
    fireNet("ClaimDailyReward")
    fireNet("ClaimFreeCrates")
    pcall(function() PKT.ClaimOfflineReward:Fire() end)
    fireNet("ClaimTreatPack")
end

local function doSteal()
    if not CFG.StealFish then return end
    for _, p in Players:GetPlayers() do
        if not CFG.StealFish then break end
        if p ~= Player then
            fireNet("RequestStealFish", p)
            S.steals += 1
        end
    end
end

---------- LOOPS ----------
task.spawn(function() while true do if CFG.AutoSell      then pcall(doFilteredSell) end; task.wait(jitter(5, 1.5))  end end)
task.spawn(function() while true do if CFG.AutoEquipBest then pcall(doEquipBest)   end; task.wait(jitter(10, 3.0)) end end)
task.spawn(function() while true do if CFG.AutoBuyTreats then pcall(doBuyTreats)   end; task.wait(jitter(10, 3.0)) end end)
task.spawn(function() while true do if CFG.AutoBuyTools  then pcall(doBuyTools)    end; task.wait(jitter(10, 3.0)) end end)
task.spawn(function() while true do if CFG.AutoFeedFish  then pcall(doFeedFish)    end; task.wait(jitter(5, 1.5)) end end)
task.spawn(function() while true do if CFG.AutoRebirth   then pcall(doRebirth)     end; task.wait(jitter(15, 4.5)) end end)
task.spawn(function() while true do if CFG.AutoClaim     then pcall(doClaim)       end; task.wait(jitter(30, 9.0)) end end)
task.spawn(function() while true do if CFG.StealFish     then pcall(doSteal)       end; task.wait(jitter(10, 3.0)) end end)

local _sOn = false
task.spawn(function()
    while true do
        pcall(function()
            local h = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
            if not h then return end
            if CFG.SpeedBoost then
                if h.WalkSpeed < 100 then h.WalkSpeed = 100 end
                _sOn = true
            elseif _sOn then
                h.WalkSpeed = 16; _sOn = false
            end
        end)
        task.wait(jitter(0.5, 0.5))
    end
end)

---------- AUTO-FARM DIVE LOOP ----------
local _farmStatus = nil
local _farmCaught = 0
local _farmSells  = 0

local function getOxygenPct()
    local pct = 1
    pcall(function()
        local txt = Player.PlayerGui.PersistentUI.OxygenBar.OxygenBar.Amount.Text
        local num = tonumber(txt:match("(%d+)%%"))
        if num then pct = num / 100 end
    end)
    if pct == 1 then
        pcall(function()
            for _, d in Player.PlayerGui.PersistentUI.OxygenBar:GetDescendants() do
                if d:IsA("TextLabel") and d.Text:find("Oxygen") then
                    local num = tonumber(d.Text:match("(%d+)%%"))
                    if num then pct = num / 100; break end
                end
            end
        end)
    end
    return pct
end

local function getHRP()
    local c = Player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function reliableTP(target)
    for attempt = 1, 5 do
        local hrp = getHRP()
        if not hrp then
            task.wait(2)
            hrp = getHRP()
            if not hrp then return false end
        end
        pcall(function() hrp.Velocity = Vector3.zero end)
        pcall(function() hrp.CFrame = target end)
        task.wait(0.15)
        pcall(function() hrp.Velocity = Vector3.zero end)
        task.wait(0.2)
        hrp = getHRP()
        if hrp and (hrp.Position - target.Position).Magnitude < 50 then
            return true
        end
    end
    return false
end

-- Cache player plot (refreshes if nil or destroyed)
local _myPlot = nil
local function getMyPlot()
    if _myPlot and _myPlot.Parent then return _myPlot end
    -- Try GetPlayerPlot remote first (most reliable — returns actual plot instance)
    pcall(function()
        local plot = NET:FindFirstChild("GetPlayerPlot-RemoteFunction"):InvokeServer()
        if typeof(plot) == "Instance" then _myPlot = plot end
    end)
    -- Fallback: search by player name
    if not _myPlot then
        pcall(function()
            _myPlot = workspace.Game.Plots:FindFirstChild(Player.Name)
        end)
    end
    return _myPlot
end

local function tpToSurface()
    local plotSpawn = CFrame.new(-1813, 2530, -1421)
    pcall(function()
        local myPlot = getMyPlot()
        if myPlot and myPlot:FindFirstChild("SpawnLocation") then
            plotSpawn = myPlot.SpawnLocation.CFrame + Vector3.new(0, 5, 0)
        elseif myPlot then
            plotSpawn = myPlot:GetPivot() + Vector3.new(0, 5, 0)
        end
    end)
    return reliableTP(plotSpawn)
end

local function tpToZone(zone)
    if zone.pos then
        return reliableTP(CFrame.new(zone.pos))
    end
    return false
end

local function getRarity(fish)
    local rarity = "Common"
    pcall(function()
        for _, d in fish:GetDescendants() do
            if d:IsA("TextLabel") and d.Name == "Rarity" and d.Text ~= "" then
                rarity = d.Text; break
            end
        end
    end)
    return rarity
end

local function catchFishInZone(zoneName)
    local fishes = game.Workspace.Game:FindFirstChild("Fishes")
    if not fishes then return 0 end
    local hrp = getHRP()
    if not hrp then return 0 end

    local caught = 0

    local candidates = {}
    for _, f in fishes:GetChildren() do
        local fishZone = f:GetAttribute("Zone")
        if fishZone ~= zoneName then continue end

        local rootPart = f:FindFirstChild("RootPart")
        local prompt   = rootPart and rootPart:FindFirstChild("ProximityPrompt")
        if not prompt then continue end

        local isNormal     = f:GetAttribute("Normal")
        local mutationType = nil
        for _, mt in {"Silver","Gold","Rainbow","Frozen","Shocked","Magma","Chocolate","Dry","Infected","Evil"} do
            if f:GetAttribute(mt) then mutationType = mt; break end
        end
        local rarity       = getRarity(f)
        local shouldCatch  = false

        -- Must pass rarity filter AND mutation filter
        if not SelRarities[rarity] then shouldCatch = false
        elseif mutationType then shouldCatch = SelMutations[mutationType]
        else shouldCatch = SelMutations["Normal"]
        end

        if shouldCatch then
            local cps = f:GetAttribute("CashPerSec") or 0
            local tag = mutationType and (mutationType .. " " .. rarity) or rarity
            table.insert(candidates, {
                fish     = f,
                root     = rootPart,
                prompt   = prompt,
                cps      = cps,
                rarity   = rarity,
                mutation = mutationType,
                tag      = tag,
                name     = f:GetAttribute("Name") or f.Name,
            })
        end
    end

    table.sort(candidates, function(a, b) return a.cps > b.cps end)

    for _, c in ipairs(candidates) do
        if not CFG.AutoFarm then break end
        if getOxygenPct() <= 0.10 then break end

        local used  = Player:GetAttribute("BackpackUsed")  or 0
        local space = Player:GetAttribute("BackpackSpace") or 25
        if used >= space then
            if CFG.FarmAutoSell then
                local sold = doFilteredSell()
                if sold then _farmSells += 1 end
                task.wait(0.3)
                used = Player:GetAttribute("BackpackUsed") or 0
                if used >= space then break end
            else
                break
            end
        end

        if not c.fish.Parent or not c.root.Parent then continue end

        -- CFrame teleport directly to fish (fixes underwater MoveTo pathfinding failure)
        pcall(function()
            hrp = getHRP()
            if not hrp then return end

            hrp.CFrame = CFrame.new(c.root.Position + Vector3.new(0, 0, 3))
            task.wait(0.3)

            if c.root.Parent and c.prompt.Parent then
                safeFirePrompt(c.prompt)
            end
        end)

        caught      += 1
        _farmCaught += 1
        _farmStatus  = c.name .. " [" .. c.tag .. "] " .. c.cps .. "$/s"
        task.wait(0.3)
    end

    return caught
end

local WATER_SURFACE_Y = 2524

task.spawn(function()
    while true do
        if CFG.AutoFarm then
            local hrp = getHRP()
            if not hrp then task.wait(jitter(0.5, 0.5)); continue end

            if getOxygenPct() <= 0.10 then
                _farmStatus = "Low O2 - Surfacing..."
                tpToSurface()
                task.wait(jitter(1, 0.5))
                local t0 = tick()
                while getOxygenPct() < 0.90 and CFG.AutoFarm and (tick() - t0) < 30 do
                    _farmStatus = string.format("Recovering O2... %.0f%%", getOxygenPct() * 100)
                    pcall(function() local h = getHRP(); if h and h.Position.Y < 2520 then tpToSurface() end end)
                    task.wait(jitter(0.5, 0.5))
                end
                if not CFG.AutoFarm then continue end
            end

            local used  = Player:GetAttribute("BackpackUsed")  or 0
            local space = Player:GetAttribute("BackpackSpace") or 25
            if used >= space then
                if CFG.FarmAutoSell then
                    local sold = doFilteredSell()
                    if sold then _farmSells += 1 end
                    task.wait(0.3)
                    used = Player:GetAttribute("BackpackUsed") or 0
                end
                -- Still full? Surface and wait (either FarmAutoSell off, or filter blocked sell)
                if (Player:GetAttribute("BackpackUsed") or 0) >= (Player:GetAttribute("BackpackSpace") or 25) then
                    _farmStatus = "Backpack full - Surfacing..."
                    tpToSurface()
                    while (Player:GetAttribute("BackpackUsed") or 0) >= (Player:GetAttribute("BackpackSpace") or 25) and CFG.AutoFarm do
                        _farmStatus = string.format("Full %d/%d - sell/equip to continue", Player:GetAttribute("BackpackUsed") or 0, Player:GetAttribute("BackpackSpace") or 25)
                        task.wait(jitter(1, 0.5))
                    end
                    if not CFG.AutoFarm then continue end
                end
            end

            local activeZones = {}
            for _, z in ipairs(OCEAN_ZONES) do
                if SelZones[z.label] then table.insert(activeZones, z) end
            end
            if #activeZones == 0 then
                _farmStatus = "No zones selected"
                task.wait(1)
                continue
            end
            local zone = activeZones[math.random(#activeZones)]

            if not CFG.AutoFarm then _farmStatus = nil; continue end
            _farmStatus = "Diving to " .. zone.label .. "..."
            tpToZone(zone)
            task.wait(0.8)
            if not CFG.AutoFarm then _farmStatus = nil; continue end

            local caught = catchFishInZone(zone.name)
            if caught > 0 then
                _farmStatus = "Caught " .. caught .. " | Total: " .. _farmCaught
            else
                _farmStatus = "No fish in " .. zone.label .. " - rotating..."
                task.wait(0.5)
            end
        else
            _farmStatus = nil
            task.wait(0.5)
        end
    end
end)

task.spawn(function()
    while true do
        if CFG.AntiAFK then
            pcall(function()
                game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
                task.wait(0.1)
                game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
            end)
        end
        task.wait(120)
    end
end)

task.spawn(function() task.wait(3); pcall(doClaim) end)

pcall(function()
    game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function() end)
    game:GetService("MarketplaceService").PromptPurchaseFinished:Connect(function() end)
    game:GetService("GuiService"):SetPurchasePromptIsShown(false)
end)

task.spawn(function()
    while true do
        if CFG.AutoBuyTreats or CFG.AutoBuyTools then
            pcall(function() game:GetService("GuiService"):CloseInspectMenu() end)
            pcall(function()
                local cg = game:GetService("CoreGui")
                for _, gui in cg:GetChildren() do
                    if gui.Name == "PurchasePromptApp" or gui.Name == "PurchasePrompt" then
                        for _, d in gui:GetDescendants() do
                            if d:IsA("TextButton") and (d.Text == "Cancel" or d.Text == "X" or d.Text:find("Close")) then
                                d.Activated:Fire()
                            end
                        end
                    end
                end
            end)
        end
        task.wait(0.5)
    end
end)

-- ============================================================
-- SIDEBAR UI (Sailor Piece layout adapted for Dive Down)
-- ============================================================

---------- PALETTE ----------
local C = {
    bg      = Color3.fromRGB(18, 20, 28),
    sidebar = Color3.fromRGB(22, 24, 34),
    panel   = Color3.fromRGB(28, 30, 42),
    card    = Color3.fromRGB(35, 37, 50),
    accent   = Color3.fromRGB(252, 110, 142),
    text    = Color3.fromRGB(235, 235, 245),
    dim     = Color3.fromRGB(130, 130, 155),
    green   = Color3.fromRGB(80, 200, 120),
    red     = Color3.fromRGB(220, 60, 60),
    trackOff = Color3.fromRGB(15, 15, 25),
    knobOff  = Color3.fromRGB(100, 100, 120),
    stroke   = Color3.fromRGB(50, 52, 68),
}

---------- HELPERS ----------
local function create(class, props, parent)
    local inst = Instance.new(class)
    for k, v in props do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function corner(p, r) return create("UICorner", {CornerRadius = UDim.new(0, r)}, p) end
local function stroke(p, col, th, tr)
    return create("UIStroke", {Color = col, Thickness = th or 1, Transparency = tr or 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, p)
end
local function lbl(parent, props)
    local d = {BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextColor3 = C.text, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center, BorderSizePixel = 0, Active = false}
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
local parentOk = false
-- Try gethui first (works on all platforms, invisible to anti-cheat)
if not parentOk and typeof(gethui) == "function" then
    parentOk = pcall(function() gui.Parent = gethui() end)
end
-- Fallback: CoreGui
if not parentOk then
    parentOk = pcall(function() gui.Parent = game:GetService("CoreGui") end)
end
-- Last resort: PlayerGui
if not parentOk then
    pcall(function() gui.Parent = Player.PlayerGui end)
end

---------- MOBILE DETECTION ----------
local _viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _isMobile = UIS.TouchEnabled and (_viewport.X < 1200)
local _scale    = _isMobile and math.clamp(_viewport.X / 700, 0.55, 0.85) or 1

---------- LAYOUT ----------
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
    BackgroundColor3 = C.bg, BackgroundTransparency = 0, BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, gui)
corner(main, 12)
stroke(main, C.stroke, 1, 0.2)
if _scale ~= 1 then create("UIScale", {Scale = _scale}, main) end

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
local gameName = "Dive Down"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
lbl(topBar, {
    Name = "Game", Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(1, -310, 0, 0),
    Text = gameName, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
})

local minBtn = create("Frame", {
    Name = "Min", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(minBtn, {Size = UDim2.new(1,0,1,0), Text = "\xE2\x80\x93", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7})

local closeBtn = create("Frame", {
    Name = "Close", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(closeBtn, {Size = UDim2.new(1,0,1,0), Text = "x", TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7})

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
    Position = UDim2.fromOffset(0, TOP_H), BackgroundColor3 = C.sidebar, BackgroundTransparency = 0,
    BorderSizePixel = 0, ClipsDescendants = true,
}, main)
corner(sidebar, 12)
create("Frame", {
    Name = "Divider", Size = UDim2.new(0, 1, 1, -8), Position = UDim2.new(1, 0, 0, 4),
    BackgroundColor3 = C.stroke, BackgroundTransparency = 0.4, BorderSizePixel = 0,
}, sidebar)

local TAB_DEFS = {
    {name = "Farm",    color = Color3.fromRGB(80, 200, 120)},
    {name = "Shop",    color = Color3.fromRGB(255, 200, 80)},
    {name = "Filters", color = Color3.fromRGB(100, 180, 255)},
    {name = "Utility", color = Color3.fromRGB(180, 130, 255)},
}
local CONFIG_TAB = {name = "Config", color = Color3.fromRGB(130, 130, 155)}

local tabBtns        = {}
local leftContainers = {}
local rightContainers = {}

local tabList = create("Frame", {
    Name = "TabList", Size = UDim2.new(1, -8, 0, #TAB_DEFS * 40 + 4),
    Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1, BorderSizePixel = 0,
}, sidebar)
create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, tabList)

local allTabs = {}

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

for i, def in ipairs(TAB_DEFS) do
    local btn, ind = makeTabBtn(def, i, tabList)
    allTabs[i] = {btn = btn, indicator = ind, name = def.name}
end

local configBtn, configInd = makeTabBtn(CONFIG_TAB, 99, nil)
configBtn.Parent   = sidebar
configBtn.Position = UDim2.new(0, 4, 1, -44)
configBtn.Size     = UDim2.new(1, -8, 0, 36)
allTabs[#TAB_DEFS + 1] = {btn = configBtn, indicator = configInd, name = "Config"}

---------- CONTENT PANELS ----------
local function makePanel(name, xPos, width)
    local p = create("ScrollingFrame", {
        Name = name, Size = UDim2.new(0, width, 0, CONTENT_H),
        Position = UDim2.fromOffset(xPos, CONTENT_Y),
        BackgroundColor3 = C.panel, BackgroundTransparency = 0.10, BorderSizePixel = 0,
        ScrollBarThickness = 3, ScrollBarImageColor3 = C.accent, ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0), ScrollingDirection = Enum.ScrollingDirection.Y,
        TopImage    = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        MidImage    = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    }, main)
    corner(p, 10)
    stroke(p, C.stroke, 1, 0.4)
    create("UIPadding", {PaddingTop = UDim.new(0, 8), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10)}, p)
    local layout = create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4)}, p)
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
local _order    = {}
local _curLeft  = nil
local _curRight = nil

local function setPanel(lp, rp)
    _curLeft = lp; _curRight = rp
    _order[lp] = 0; _order[rp] = 0
end

local function nextOrder(panel)
    _order[panel] = (_order[panel] or 0) + 1
    return _order[panel]
end

local function sectionHeader(title, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    create("Frame", {Size = UDim2.new(1, 0, 0, 2), BackgroundTransparency = 1, LayoutOrder = o}, panel)
    o = nextOrder(panel)
    local row = create("Frame", {Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0}, panel)
    local dot = create("Frame", {Size = UDim2.fromOffset(4, 4), Position = UDim2.fromOffset(0, 10), BackgroundColor3 = C.accent, BorderSizePixel = 0}, row)
    corner(dot, 2)
    lbl(row, {Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(12, 0), Text = string.upper(title), TextSize = 11, Font = Enum.Font.GothamBlack, TextColor3 = C.accent})
end

local function toggleRow(name, cfgKey, panel, callback)
    panel = panel or _curLeft
    local o   = nextOrder(panel)
    local row = create("Frame", {
        Name = "T_" .. name, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    lbl(row, {Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(10, 0), Text = name, TextSize = 13, Font = Enum.Font.Gotham})

    local track = create("Frame", {
        Name = "Track", Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -48, 0.5, -10),
        BackgroundColor3 = CFG[cfgKey] and C.accent or C.trackOff, BorderSizePixel = 0,
    }, row)
    corner(track, 10)
    local knob = create("Frame", {
        Name = "Knob", Size = UDim2.fromOffset(16, 16),
        Position = CFG[cfgKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.fromOffset(2, 2),
        BackgroundColor3 = CFG[cfgKey] and Color3.new(1, 1, 1) or C.knobOff, BorderSizePixel = 0,
    }, track)
    corner(knob, 8)

    local function updateVisual()
        local on = CFG[cfgKey]
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3 = on and C.accent or C.trackOff}):Play()
        TweenService:Create(knob,  TweenInfo.new(0.15), {
            Position         = on and UDim2.new(1, -18, 0.5, -8) or UDim2.fromOffset(2, 2),
            BackgroundColor3 = on and Color3.new(1, 1, 1) or C.knobOff,
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

local function actionButton(name, color, panel, callback)
    panel = panel or _curLeft
    local o   = nextOrder(panel)
    local btn = create("Frame", {
        Name = "A_" .. name, Size = UDim2.new(1, 0, 0, 32), BackgroundColor3 = color or C.accent,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(btn, 8)
    local btnLabel = lbl(btn, {
        Size = UDim2.new(1, 0, 1, 0), Text = name, TextSize = 11, Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.text,
    })
    connectClick(btn, function()
        if callback then callback() end
        local orig = btnLabel.Text
        btnLabel.Text      = name .. " ..."
        btnLabel.TextColor3 = C.green
        task.delay(1.5, function() btnLabel.Text = orig; btnLabel.TextColor3 = C.text end)
    end)
    return btn
end

local function infoRow(name, initialValue, panel)
    panel = panel or _curRight
    local o   = nextOrder(panel)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = o, BorderSizePixel = 0,
    }, panel)
    lbl(row, {Size = UDim2.new(0.5, 0, 1, 0), Position = UDim2.fromOffset(4, 0), Text = name, TextSize = 10, Font = Enum.Font.GothamSemibold, TextColor3 = C.dim})
    local val = lbl(row, {
        Name = "Val", Size = UDim2.new(0.5, -4, 1, 0), Position = UDim2.new(0.5, 0, 0, 0),
        Text = initialValue or "---", TextSize = 10, Font = Enum.Font.GothamBold,
        TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Right,
    })
    return val
end

-- Multi-select dropdown
local function multiSelectDD(title, items, selMap, panel)
    panel = panel or _curLeft
    local o        = nextOrder(panel)
    local expanded = false
    local ITEM_H   = 26
    local MAX_VIS  = 5
    local totalH   = #items * ITEM_H
    local scrollH  = math.min(totalH, MAX_VIS * ITEM_H)

    local wrapper = create("Frame", {
        Name = "DD_" .. title, Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = o, ClipsDescendants = false,
    }, panel)

    local header = create("Frame", {
        Size = UDim2.new(1, 0, 0, 28), BackgroundColor3 = C.card, BorderSizePixel = 0, Active = true,
    }, wrapper)
    corner(header, 8)
    stroke(header, C.accent, 1, 0.6)

    local function getCountText()
        local count = 0
        for _, nm in items do if selMap[nm] then count += 1 end end
        if count == 0 then return title .. ": None" end
        if count <= 2 then
            local names = {}
            for _, nm in items do if selMap[nm] then table.insert(names, nm) end end
            return title .. ": " .. table.concat(names, ", ")
        end
        return title .. ": " .. count .. "/" .. #items
    end

    local hdrLbl = lbl(header, {
        Size = UDim2.new(0.78, 0, 1, 0), Position = UDim2.fromOffset(10, 0),
        Text = getCountText(), TextSize = 10, Font = Enum.Font.GothamSemibold,
    })
    local arrow = lbl(header, {
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
    }, wrapper)
    corner(listFrame, 6)

    for i, nm in ipairs(items) do
        local optRow = create("Frame", {
            Size = UDim2.new(1, 0, 0, ITEM_H), Position = UDim2.fromOffset(0, (i-1) * ITEM_H),
            BackgroundColor3 = C.card, BackgroundTransparency = 0.3, BorderSizePixel = 0, Active = true,
        }, listFrame)
        corner(optRow, 4)
        local ind = lbl(optRow, {
            Size = UDim2.new(0, 20, 1, 0), Position = UDim2.fromOffset(8, 0),
            Text = selMap[nm] and "+" or "o", TextSize = 10, Font = Enum.Font.GothamBold,
            TextColor3 = selMap[nm] and C.accent or C.dim, TextXAlignment = Enum.TextXAlignment.Center,
        })
        local ol = lbl(optRow, {
            Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(28, 0),
            Text = nm, TextSize = 10, Font = Enum.Font.GothamSemibold,
            TextColor3 = selMap[nm] and C.accent or C.dim,
        })
        connectClick(optRow, function()
            selMap[nm]      = not selMap[nm]
            ind.Text        = selMap[nm] and "+" or "o"
            ind.TextColor3  = selMap[nm] and C.accent or C.dim
            ol.TextColor3   = selMap[nm] and C.accent or C.dim
            hdrLbl.Text     = getCountText()
            if CFG.AutoSave then saveCFG() end
        end)
    end

    connectClick(header, function()
        expanded         = not expanded
        arrow.Text       = expanded and "\xE2\x96\xB2" or "\xE2\x96\xBC"
        listFrame.Visible = expanded
        wrapper.Size     = expanded and UDim2.new(1, 0, 0, 30 + scrollH) or UDim2.new(1, 0, 0, 28)
    end)
end

-- ============================================================
-- TAB 1: FARM
-- ============================================================
setPanel(leftContainers[1], rightContainers[1])

sectionHeader("Auto Farm", _curLeft)
toggleRow("Auto Farm", "AutoFarm", _curLeft)
toggleRow("Farm Auto Sell", "FarmAutoSell", _curLeft)

actionButton("TP to Surface", C.green, _curLeft, function() tpToSurface() end)
actionButton("TP to Ice Area", C.blue or C.accent, _curLeft, function()
    pcall(function()
        local hrp = getHRP()
        if not hrp then return end
        -- Force TP with velocity reset to prevent rubber-banding
        for _ = 1, 5 do
            pcall(function()
                hrp.Velocity = Vector3.zero
                hrp.CFrame = CFrame.new(-1928, -1957, -1419)
            end)
            task.wait(0.15)
            hrp = getHRP()
            if hrp and hrp.Position.Y < -1900 then break end
        end
    end)
end)
actionButton("Sell Inventory", C.accent, _curLeft, function() doFilteredSell() end)
actionButton("Equip Best Fish", C.accent, _curLeft, function() doEquipBest() end)
actionButton("Catch All (Filter)", C.green, _curLeft, function()
    pcall(function()
        local fishes = workspace.Game:FindFirstChild("Fishes")
        if not fishes then return end
        local hrp = getHRP()
        if not hrp then return end
        local caught = 0
        for _, f in fishes:GetChildren() do
            local rootPart = f:FindFirstChild("RootPart")
            local prompt = rootPart and rootPart:FindFirstChild("ProximityPrompt")
            if not prompt then continue end
            local isNormal = f:GetAttribute("Normal")
            local mutationType = nil
            for _, mt in {"Silver","Gold","Rainbow","Frozen","Shocked","Magma","Chocolate","Dry","Infected","Evil"} do
                if f:GetAttribute(mt) then mutationType = mt; break end
            end
            local rarity = getRarity(f)
            local shouldCatch = false
            if not SelRarities[rarity] then shouldCatch = false
            elseif mutationType then shouldCatch = SelMutations[mutationType]
            else shouldCatch = SelMutations["Normal"]
            end
            if not shouldCatch then continue end
            pcall(function()
                hrp.CFrame = rootPart.CFrame * CFrame.new(0, 0, -3)
                task.wait(0.15)
                safeFirePrompt(prompt)
                caught += 1
            end)
            task.wait(jitter(0.3, 0.2))
        end
        _farmStatus = "Caught " .. caught .. " fish (all zones)"
        tpToSurface()
    end)
end)

-- Right: Farm Status
sectionHeader("Farm Status", _curRight)
local _infoFarmStatus = infoRow("Status",   "Off",  _curRight)
local _infoZone       = infoRow("Zone",     "---",  _curRight)
local _infoFish       = infoRow("Target",   "---",  _curRight)

sectionHeader("Vitals", _curRight)
local _infoO2         = infoRow("O2",       "100%", _curRight)
local _infoBP         = infoRow("Backpack", "0/25", _curRight)

sectionHeader("Session", _curRight)
local _infoCaught     = infoRow("Caught",   "0",    _curRight)
local _infoSells      = infoRow("Farm Sells","0",   _curRight)
local _infoRuntime    = infoRow("Runtime",  "0m",   _curRight)

-- ============================================================
-- TAB 2: SHOP
-- ============================================================
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Buy", _curLeft)
toggleRow("Auto Buy Treats", "AutoBuyTreats", _curLeft)
toggleRow("Auto Buy Tools",  "AutoBuyTools",  _curLeft)
toggleRow("Auto Feed Fish",  "AutoFeedFish",  _curLeft)
multiSelectDD("Feed Slots", FEED_SLOTS, SelFeedSlots, _curLeft)

sectionHeader("Actions", _curRight)
toggleRow("Auto Sell",       "AutoSell",      _curRight)
toggleRow("Auto Equip Best", "AutoEquipBest", _curRight)

sectionHeader("Stats", _curRight)
local _shopTreats = infoRow("Treats Bought", "0", _curRight)
local _shopTools  = infoRow("Tools Bought",  "0", _curRight)
local _shopFeeds  = infoRow("Fish Fed",      "0", _curRight)
local _shopSells  = infoRow("Sells",         "0", _curRight)
local _shopEquips = infoRow("Equips",        "0", _curRight)

-- ============================================================
-- TAB 3: FILTERS
-- ============================================================
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Farm Zones", _curLeft)
multiSelectDD("Ocean Zones", ZONE_NAMES, SelZones, _curLeft)

sectionHeader("Catch Filter", _curLeft)
multiSelectDD("Catch Rarities", RARITIES, SelRarities, _curLeft)
multiSelectDD("Mutations", MUTATIONS, SelMutations, _curLeft)

sectionHeader("Sell Filter", _curRight)
multiSelectDD("Sell Rarities", RARITIES, SelSellRarities, _curRight)
toggleRow("Protect Mutations", "ProtectMutations", _curRight)

sectionHeader("Shop Selections", _curRight)
multiSelectDD("Buy Treats", TREAT_LIST, SelTreats, _curRight)
multiSelectDD("Buy Tools", TOOL_LIST, SelTools, _curRight)

-- ============================================================
-- TAB 4: UTILITY
-- ============================================================
setPanel(leftContainers[4], rightContainers[4])

sectionHeader("Toggles", _curLeft)
toggleRow("Auto Rebirth", "AutoRebirth", _curLeft)
toggleRow("Auto Claim",   "AutoClaim",   _curLeft)
toggleRow("Steal Fish",   "StealFish",   _curLeft)
toggleRow("Speed Boost",  "SpeedBoost",  _curLeft)
toggleRow("Anti-AFK",     "AntiAFK",     _curLeft)

sectionHeader("Actions", _curLeft)
actionButton("Rebirth",       C.accent, _curLeft, function() doRebirth() end)
actionButton("Claim Rewards", C.green,  _curLeft, function() doClaim()   end)
actionButton("TP Kraken",     C.accent, _curLeft, function()
    pcall(function() Player.Character.HumanoidRootPart.CFrame = CFrame.new(-1928, -1103, -1419) end)
end)
actionButton("TP Aquarium", C.green, _curLeft, function() tpToSurface() end)

-- Right: Player stats
sectionHeader("Player Stats", _curRight)
local _uCash   = infoRow("Cash",      "$0",  _curRight)
local _uReb    = infoRow("Rebirths",  "0",   _curRight)
local _uO2     = infoRow("O2",        "100%",_curRight)
local _uBP     = infoRow("Backpack",  "0/25",_curRight)

sectionHeader("Session", _curRight)
local _uSteals = infoRow("Fish Stolen","0",  _curRight)
local _uRebS   = infoRow("Rebirths",   "0",  _curRight)

-- ============================================================
-- TAB 5: CONFIG
-- ============================================================
setPanel(leftContainers[5], rightContainers[5])

sectionHeader("Config", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)

actionButton("Save Config", C.green,  _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function() loadSavedCFG() end)
actionButton("Reset All",   C.red,    _curLeft, function()
    for k, v in CFG do
        if type(v) == "boolean" then CFG[k] = false end
    end
    CFG.AutoSave = false
    saveCFG()
end)

sectionHeader("Config Info", _curRight)
infoRow("File", _cfgFileName, _curRight)

sectionHeader("Active Features", _curRight)
local _cfgActiveList = lbl(rightContainers[5], {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 120),
    Text = "None", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    LayoutOrder = nextOrder(rightContainers[5]),
})

---------- STATUS UPDATE LOOP ----------
task.spawn(function()
    while task.wait(jitter(1, 0.5)) do
        pcall(function()
            local used  = Player:GetAttribute("BackpackUsed")  or 0
            local space = Player:GetAttribute("BackpackSpace") or 25
            local o2pct = string.format("%.0f%%", getOxygenPct() * 100)
            local bpStr = used .. "/" .. space

            -- Tab 1: Farm
            _infoFarmStatus.Text = _farmStatus or (CFG.AutoFarm and "Active" or "Off")
            _infoO2.Text         = o2pct
            _infoBP.Text         = bpStr
            _infoCaught.Text     = tostring(_farmCaught)
            _infoSells.Text      = tostring(_farmSells)

            -- Parse current zone from farm status
            if _farmStatus and CFG.AutoFarm then
                local zone = _farmStatus:match("Diving to (.-)%.%.%.") or _farmStatus:match("No fish in (.-)%s*%-") or "---"
                _infoZone.Text = zone
                local fish = _farmStatus:match("^(.-)%s+%[") or "---"
                _infoFish.Text = fish
            else
                _infoZone.Text = "---"
                _infoFish.Text = "---"
            end

            local elapsed = tick() - S.session
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            _infoRuntime.Text = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Tab 2: Shop
            _shopTreats.Text = tostring(S.treats)
            _shopTools.Text  = tostring(S.tools)
            _shopFeeds.Text  = tostring(S.feeds)
            _shopSells.Text  = tostring(S.sells)
            _shopEquips.Text = tostring(S.equips)

            -- Tab 4: Utility
            _uCash.Text   = "$" .. fmt(_cash)
            _uReb.Text    = tostring(_reb)
            _uO2.Text     = o2pct
            _uBP.Text     = bpStr
            _uSteals.Text = tostring(S.steals)
            _uRebS.Text   = tostring(S.reb)

            -- Tab 5: Config active list
            local active = {}
            for k, v in CFG do
                if type(v) == "boolean" and v and k ~= "AutoSave" then table.insert(active, k) end
            end
            _cfgActiveList.Text = #active > 0 and table.concat(active, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #active * 14 + 10))
        end)
    end
end)

-- Init first tab
switchTab(1)

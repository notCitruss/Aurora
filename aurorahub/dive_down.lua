--// Aurora v5 — Dive Down
--// AuroraHub Edition (Wave / Potassium)
--// PlaceId: 131756752872026
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill
--// Dual networking: Packet system (binary) + Network remotes (workspace.Network) — PRESERVED VERBATIM

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Cleanup old UI
for _, n in ipairs({"Aurora", "AuroraHubPill"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- NETWORKING (preserved verbatim) ----------
local NET = workspace:FindFirstChild("Network")
local Packet = require(RS.Packets.Packet)
local PKT = {
    SellInventory      = Packet("SellInventory"),
    SellItem           = Packet("SellItem"),
    ClaimOfflineReward = Packet("ClaimOfflineReward"),
    BuyItem            = Packet("BuyItem"),
    SpinWheel          = Packet("SpinWheel"),
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

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_DIVEDOWN_CFG then
    for k, v in pairs(getgenv().__AURORA_DIVEDOWN_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_DIVEDOWN_CFG[k] = false end
    end
end
pcall(function() if getgenv().__AURORA_DIVEDOWN_SPEED then getgenv().__AURORA_DIVEDOWN_SPEED:Disconnect() end end)
task.wait(0.15)

getgenv().__AURORA_DIVEDOWN_SESSION = tick()
local _mySession = getgenv().__AURORA_DIVEDOWN_SESSION
local function alive() return getgenv().__AURORA_DIVEDOWN_SESSION == _mySession end

---------- CONFIG ----------
if not getgenv().__AURORA_DIVEDOWN_CFG then
    getgenv().__AURORA_DIVEDOWN_CFG = {
        AutoFarm         = false,
        FarmAutoSell     = false,
        AutoSell         = false,
        AutoEquipBest    = false,
        AutoBuyTreats    = false,
        AutoBuyTools     = false,
        AutoFeedFish     = false,
        AutoRebirth      = false,
        AutoClaim        = false,
        AutoSpinWheel    = false,
        AutoClaimQuests  = false,
        ProtectMutations = true,
        StealFish        = false,
        SpeedBoost       = false,
        AntiAFK          = false,
        AutoSave         = false,
        -- v5 UI state
        ActiveTab        = "Farm",
        PanelOpen        = true,
        DiveZone         = "Sunlight Zone",
    }
else
    local c = getgenv().__AURORA_DIVEDOWN_CFG
    if c.ActiveTab == nil then c.ActiveTab = "Farm" end
    if c.PanelOpen == nil then c.PanelOpen = true end
    if c.DiveZone == nil then c.DiveZone = "Sunlight Zone" end
end
local CFG = getgenv().__AURORA_DIVEDOWN_CFG

---------- RARITY FILTER ----------
local RARITIES = {"Common", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Divine", "Limited", "Group Reward"}
local SelRarities = {}
for _, r in ipairs(RARITIES) do SelRarities[r] = true end

---------- SELL RARITY FILTER ----------
local SelSellRarities = {Common = true, Rare = true, Limited = false, ["Group Reward"] = false}

---------- MUTATION FILTER ----------
local MUTATIONS = {"Normal", "Silver", "Gold", "Rainbow", "Frozen", "Shocked", "Magma", "Chocolate", "Dry", "Infected", "Evil", "YinYang", "Hacker", "Taco", "Galaxy"}
local SelMutations = {Normal = false, Silver = true, Gold = true, Rainbow = true, Frozen = true, Shocked = true, Magma = true, Chocolate = true, Dry = true, Infected = true, Evil = true, YinYang = true, Hacker = true, Taco = true, Galaxy = true}

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
    {name = "IceArea",        label = "Ice Area",         pos = Vector3.new(-1928, -1957, -1419)},
    {name = "JellyfishFields", label = "Jellyfish Fields", pos = Vector3.new(-1926, -2344, -1422)},
    {name = "SteampunkZone",   label = "Steampunk Zone",   pos = Vector3.new(-1926, -2887, -1422)},
    {name = "DeadWaters",      label = "Dead Waters",      pos = Vector3.new(-1926, -3365, -1422)},
    {name = "Prehistoric",     label = "Prehistoric",      pos = Vector3.new(-1926, -3779, -1422)},
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

---------- SAVE/LOAD (preserved verbatim filename) ----------
local _cfgFileName = "aurora_cfg_dive_down.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._SelTreats       then for k,_ in pairs(SelTreats)       do SelTreats[k]       = nil end; for k,v in pairs(saved._SelTreats)       do SelTreats[k]       = v end end
        if saved._SelTools        then for k,_ in pairs(SelTools)         do SelTools[k]        = nil end; for k,v in pairs(saved._SelTools)        do SelTools[k]        = v end end
        if saved._SelFeedSlots and next(saved._SelFeedSlots) then for k,_ in pairs(SelFeedSlots) do SelFeedSlots[k] = nil end; for k,v in pairs(saved._SelFeedSlots) do SelFeedSlots[k] = v end end
        if saved._SelRarities     then for k,_ in pairs(SelRarities)      do SelRarities[k]     = nil end; for k,v in pairs(saved._SelRarities)     do SelRarities[k]     = v end end
        if saved._SelSellRarities then for k,_ in pairs(SelSellRarities)  do SelSellRarities[k] = nil end; for k,v in pairs(saved._SelSellRarities) do SelSellRarities[k] = v end end
        if saved._SelZones        then for k,_ in pairs(SelZones)         do SelZones[k]        = nil end; for k,v in pairs(saved._SelZones)        do SelZones[k]        = v end end
        if saved._SelMutations    then for k,_ in pairs(SelMutations)     do SelMutations[k]    = nil end; for k,v in pairs(saved._SelMutations)    do SelMutations[k]    = v end end
        -- Migration: Wet was phantom (game never had it); Galaxy/Taco/Hacker added
        SelMutations.Wet = nil
        if SelMutations.Galaxy == nil then SelMutations.Galaxy = true end
        if SelMutations.Taco   == nil then SelMutations.Taco   = true end
        if SelMutations.Hacker == nil then SelMutations.Hacker = true end
        -- Back-compat: convert v4's _selectedZoneIdx int -> CFG.DiveZone label
        if saved._selectedZoneIdx and type(saved._selectedZoneIdx) == "number" and OCEAN_ZONES[saved._selectedZoneIdx] then
            CFG.DiveZone = OCEAN_ZONES[saved._selectedZoneIdx].label
        end
    end
end

local function saveCFG()
    local toSave = {}
    for k, v in pairs(CFG) do toSave[k] = v end
    toSave._SelTreats       = SelTreats
    toSave._SelTools        = SelTools
    toSave._SelFeedSlots    = SelFeedSlots
    toSave._SelRarities     = SelRarities
    toSave._SelSellRarities = SelSellRarities
    toSave._SelZones        = SelZones
    toSave._SelMutations    = SelMutations
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(toSave)) end)
end

loadSavedCFG()

local TREAT_LIST = {"Worm","Beetle","Ladybug","Bee","Cockroach","Spider","Frog","Grasshopper","Butterfly","Mouse","Dragonfly","Snail","Ant","Fly","Mosquito","Mole"}
local TOOL_LIST  = {"HarpoonGun","LegendaryRadar","EpicRadar","MythicalRadar","TNT","MutationRemover","LifeJacket"}

---------- STATE ----------
local _cash = 0
local _reb  = 0
local S = {sells = 0, equips = 0, reb = 0, steals = 0, treats = 0, tools = 0, feeds = 0, spins = 0, quests = 0, session = tick()}

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

---------- CORE FUNCTIONS (preserved verbatim) ----------

-- Fish name -> rarity (sourced from ReplicatedStorage.Modules.PickupConfig.Fish, 98 fish)
local FISH_RARITY = {
    -- SunlightZone
    ["Goldfish"] = "Common", ["Butterflyfish"] = "Rare", ["Piranha"] = "Rare",
    ["Pufferfish"] = "Epic", ["Koi"] = "Epic", ["Stingray"] = "Legendary",
    -- CoralReef
    ["Clownfish"] = "Common", ["Blue Tang"] = "Common", ["Lionfish"] = "Rare",
    ["Seahorse"] = "Epic", ["Bettafish"] = "Epic", ["Turtle"] = "Legendary", ["Shark"] = "Legendary",
    -- TwilightZone
    ["Bass"] = "Rare", ["Salmon"] = "Rare", ["Catfish"] = "Common",
    ["Swordfish"] = "Epic", ["Eel"] = "Legendary", ["Seal"] = "Legendary",
    ["Jellyfish"] = "Mythical", ["Dolphin"] = "Divine",
    -- DeepOcean
    ["Mahi-Mahi"] = "Rare", ["Parrotfish"] = "Common", ["Sunfish"] = "Rare",
    ["Tuna"] = "Epic", ["Squid"] = "Legendary", ["Hammerhead"] = "Mythical", ["Narwhal"] = "Mythical",
    -- TheDeepDark
    ["Shrimp"] = "Common", ["Rockfish"] = "Rare", ["Slickhead"] = "Epic",
    ["Gulper Eel"] = "Legendary", ["Blobfish"] = "Epic", ["Anglerfish"] = "Mythical", ["Whale"] = "Secret",
    -- TheTrenches
    ["Telescopefish"] = "Common", ["Spinyfish"] = "Rare", ["Fangtooth"] = "Rare",
    ["Macropinna"] = "Epic", ["Lizardfish"] = "Epic", ["Hatchetfish"] = "Legendary",
    ["Snailfish"] = "Legendary", ["Whalefish"] = "Mythical",
    -- Atlantis
    ["Cloudfish"] = "Epic", ["Polkafish"] = "Rare", ["Crabfish"] = "Common",
    ["Pebblefish"] = "Legendary", ["Rubyfish"] = "Mythical", ["Peeber"] = "Secret", ["Mermaid"] = "Divine",
    -- AquaForest
    ["Kelpy"] = "Common", ["Fernback"] = "Rare", ["Muncher"] = "Rare",
    ["Paddleleaf"] = "Epic", ["Shroomster"] = "Legendary", ["Weerfish"] = "Mythical", ["Grooty"] = "Secret",
    -- ShellReef
    ["Nautilus"] = "Common", ["Shellfin"] = "Common", ["Whorlwig"] = "Rare",
    ["Snailshell"] = "Epic", ["Twistopus"] = "Legendary", ["Yapclam"] = "Mythical", ["Unishell"] = "Divine",
    -- KrakenWorld
    ["Skelfin"] = "Common", ["Bitey"] = "Rare", ["Riftjaw"] = "Epic",
    ["Globby"] = "Legendary", ["Slimer"] = "Legendary", ["Licklid"] = "Mythical", ["Shoober"] = "Secret",
    -- MegalodonsLair
    ["Bull Shark"] = "Epic", ["Tiger Shark"] = "Epic", ["Whale Shark"] = "Epic",
    ["Thresher Shark"] = "Mythical", ["Great White Shark"] = "Mythical",
    -- IceArea
    ["Penguin"] = "Epic", ["Otter"] = "Epic", ["Walrus"] = "Legendary",
    ["Beluga Whale"] = "Legendary", ["Orca"] = "Mythical", ["Blue Whale"] = "Secret", ["Polar Bear"] = "Secret",
    -- JellyfishFields
    ["Moon Jellyfish"] = "Common", ["Whitespotted Jellyfish"] = "Common", ["Cauliflower Jellyfish"] = "Rare",
    ["Box Jellyfish"] = "Epic", ["Black Sea Nettle"] = "Legendary", ["Crystal Jellyfish"] = "Mythical", ["Immortal Jellyfish"] = "Secret",
    -- SteampunkZone
    ["CogFish"] = "Common", ["ElectricSeaHorse"] = "Common", ["Lampjaw"] = "Rare",
    ["MetalBrass"] = "Epic", ["MotorEel"] = "Legendary", ["SteamPike"] = "Mythical", ["SteamWhale"] = "Secret",
    -- DeadWaters
    ["ChainBass"] = "Common", ["GraveBite"] = "Common", ["GraveFin"] = "Rare",
    ["RotFish"] = "Epic", ["PhantomFin"] = "Legendary", ["SkullSpine"] = "Mythical", ["Reaper"] = "Divine",
    -- Prehistoric
    ["Ichthyosaurus"] = "Common", ["Rollipolli"] = "Common", ["Mosasaur"] = "Epic",
    ["Stonesmasher"] = "Legendary", ["TongueFin"] = "Mythical", ["Plesiosaur"] = "Divine", ["Trexfish"] = "Secret",
    -- Kraken specials
    ["Bobble Kraken"] = "Mythical", ["Puddle Kraken"] = "Mythical",
    ["Sentinel Kraken"] = "Secret", ["Tangle Kraken"] = "Secret", ["Crown Kraken"] = "Divine",
    -- Limited / event fish
    ["Pinata Fish"] = "Limited", ["Partyhat Fish"] = "Limited", ["Partybottle Fish"] = "Limited",
    ["Cake Fish"] = "Limited", ["Gift Fish"] = "Limited", ["Heart Fish"] = "Limited",
    ["Spinister"] = "Limited", ["UsernameFish"] = "Limited", ["UsernameMermaid"] = "Limited",
    -- Group Reward
    ["Jandelfish"] = "Group Reward",
}

local function getFishRarity(fishName)
    return FISH_RARITY[fishName] or "Common"
end

local function doSell()
    pcall(function() PKT.SellInventory:Fire() end)
    S.sells += 1
end

local function doFilteredSell()
    -- SellInventory is all-or-nothing server-side (SellItem / ToggleFavoriteEvent silently
    -- fail from executor context — verified via MCP live test). Client-side protection via
    -- Parent=nil / Parent=Character / RequestEquipBestFish all FAIL: server validates inventory
    -- and sells every owned fish regardless of Parent. Therefore we GATE the sell — only fire
    -- SellInventory when every fish in backpack+character passes the SelSellRarities filter
    -- (and mutation filter if ProtectMutations on).
    local canSell = true
    pcall(function()
        local pools = {Player.Backpack}
        local char = Player.Character
        if char then table.insert(pools, char) end
        local mutList = {"Silver","Gold","Rainbow","Frozen","Shocked","Magma","Chocolate","Dry","Infected","Evil","YinYang","Hacker","Taco","Galaxy"}
        for _, pool in ipairs(pools) do
            if not pool then continue end
            for _, t in ipairs(pool:GetChildren()) do
                if t:IsA("Tool") and t:GetAttribute("Category") == "Fish" then
                    local fishName = t:GetAttribute("Name") or t.Name
                    local rarity = getFishRarity(fishName)
                    if not SelSellRarities[rarity] then canSell = false; return end
                    if CFG.ProtectMutations then
                        for _, mut in ipairs(mutList) do
                            if t:GetAttribute(mut) then canSell = false; return end
                        end
                    end
                end
            end
        end
    end)
    if not canSell then return false end
    pcall(function() PKT.SellInventory:Fire() end)
    S.sells += 1
    return true
end

local function doEquipBest()
    invokeNet("RequestEquipBestFish")
    S.equips += 1
end

local _suppressNotifs = false

pcall(function()
    local notif1   = NET:FindFirstChild("ShowNotification-RemoteEvent")
    local notif2   = NET:FindFirstChild("ShowNotfication-RemoteEvent")

    for _, remote in pairs({notif1, notif2}) do
        if remote then
            remote.OnClientEvent:Connect(function(msg)
                if _suppressNotifs and type(msg) == "string" then
                    local low = msg:lower()
                    if low:find("stock") or low:find("afford") or low:find("enough") or low:find("sold out") then
                        pcall(function()
                            local notifGui = Player.PlayerGui:FindFirstChild("NotificationUI")
                            if notifGui then
                                for _, child in ipairs(notifGui:GetDescendants()) do
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
end)

local function getUIStock()
    local stock = {Treat = {}, Tool = {}}
    pcall(function()
        local shops = Player.PlayerGui.PersistentUI.Shops
        for _, shopFrame in ipairs(shops:GetChildren()) do
            local st = shopFrame.Name
            if stock[st] then
                for _, d in ipairs(shopFrame:GetDescendants()) do
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
    for name, sel in pairs(SelTreats) do
        if not alive() or not CFG.AutoBuyTreats then break end
        if sel and (stock.Treat[name] or 0) > 0 then
            pcall(function() PKT.BuyItem:Fire("Treat", name) end)
            S.treats += 1
            task.wait(0.8)
        end
    end
end

local function doBuyTools()
    if not CFG.AutoBuyTools then return end
    local stock = getUIStock()
    for name, sel in pairs(SelTools) do
        if not alive() or not CFG.AutoBuyTools then break end
        if sel and (stock.Tool[name] or 0) > 0 then
            pcall(function() PKT.BuyItem:Fire("Tool", name) end)
            S.tools += 1
            task.wait(0.8)
        end
    end
end

local function doFeedFish()
    if not CFG.AutoFeedFish then return end
    pcall(function()
        local remote = NET:FindFirstChild("Get Save-RemoteFunction")
        if not remote then return end
        local ok, sv = pcall(function() return remote:InvokeServer() end)
        if not ok or typeof(sv) ~= "table" then return end
        if not sv.AquariumFish or not sv.OwnedTreats then return end
        local hasTreats = false
        for _, count in pairs(sv.OwnedTreats) do if count > 0 then hasTreats = true; break end end
        if not hasTreats then return end
        local sorted = {}
        for fId, fData in pairs(sv.AquariumFish) do
            local cps = typeof(fData) == "table" and (fData.CashPerSec or fData.Earnings or 0) or 0
            table.insert(sorted, {id = fId, cps = cps})
        end
        table.sort(sorted, function(a, b) return a.cps > b.cps end)
        local slotNames = {"1st", "2nd", "3rd", "4th", "5th"}
        local anySlotSelected = false
        for _, s in ipairs(slotNames) do if SelFeedSlots[s] then anySlotSelected = true; break end end
        for i = 1, math.min(5, #sorted) do
            if not alive() or not CFG.AutoFeedFish then break end
            if anySlotSelected and not SelFeedSlots[slotNames[i]] then continue end
            local fish = sorted[i]
            for tName, count in pairs(sv.OwnedTreats) do
                if count > 0 then
                    fireNet("FeedFish", fish.id, tName)
                    S.feeds += 1
                    task.wait(0.15)
                    break
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
    invokeNet("ClaimKrakenEgg")
end

local function doSpinWheel()
    pcall(function() PKT.SpinWheel:Fire() end)
    S.spins += 1
end

local function doClaimQuests()
    pcall(function()
        local remote = NET:FindFirstChild("Get Save-RemoteFunction")
        if not remote then return end
        local ok, sv = pcall(function() return remote:InvokeServer() end)
        if not ok or typeof(sv) ~= "table" then return end
        local quests = sv.Quests or sv.ActiveQuests or sv.QuestProgress
        if not quests or typeof(quests) ~= "table" then return end
        for questId, qData in pairs(quests) do
            if not alive() or not CFG.AutoClaimQuests then break end
            local completed = false
            if typeof(qData) == "table" then
                completed = qData.Completed or qData.Complete or qData.Done or false
                if not completed and qData.Progress and qData.Goal then
                    completed = qData.Progress >= qData.Goal
                end
            elseif typeof(qData) == "boolean" then
                completed = qData
            end
            if completed then
                pcall(function()
                    local r = NET:FindFirstChild("ClaimQuest-RemoteFunction")
                    if r then r:InvokeServer(questId); S.quests += 1 end
                end)
                task.wait(0.3)
            end
        end
    end)
end

local function doSteal()
    if not CFG.StealFish then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if not alive() or not CFG.StealFish then break end
        if p ~= Player then
            fireNet("RequestStealFish", p)
            S.steals += 1
        end
    end
end

---------- LOOPS (preserved verbatim) ----------
task.spawn(function() while alive() do if CFG.AutoSell      then pcall(doFilteredSell) end; task.wait(jitter(3, 1.0));   if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoEquipBest then pcall(doEquipBest)    end; task.wait(jitter(5, 1.5));   if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoBuyTreats then pcall(doBuyTreats)    end; task.wait(jitter(6, 2.0));   if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoBuyTools  then pcall(doBuyTools)     end; task.wait(jitter(6, 2.0));   if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoFeedFish  then pcall(doFeedFish)     end; task.wait(jitter(5, 1.5));   if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoRebirth   then pcall(doRebirth)      end; task.wait(jitter(15, 4.5));  if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoClaim     then pcall(doClaim)        end; task.wait(jitter(30, 9.0));  if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.StealFish     then pcall(doSteal)        end; task.wait(jitter(10, 3.0));  if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoSpinWheel then pcall(doSpinWheel)    end; task.wait(jitter(60, 10.0)); if not alive() then break end end end)
task.spawn(function() while alive() do if CFG.AutoClaimQuests then pcall(doClaimQuests) end; task.wait(jitter(30, 5.0));  if not alive() then break end end end)

local _sOn = false
task.spawn(function()
    while alive() do
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

---------- AUTO-FARM DIVE LOOP (preserved verbatim) ----------
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
            for _, d in ipairs(Player.PlayerGui.PersistentUI.OxygenBar:GetDescendants()) do
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

local _myPlot = nil
local function getMyPlot()
    if _myPlot and _myPlot.Parent then return _myPlot end
    pcall(function()
        local plot = invokeNet("GetPlayerPlot")
        if typeof(plot) == "Instance" then _myPlot = plot end
    end)
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
    if zone and zone.pos then
        return reliableTP(CFrame.new(zone.pos))
    end
    return false
end

local function getRarity(fish)
    local rarity = "Common"
    pcall(function()
        for _, d in ipairs(fish:GetDescendants()) do
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
    for _, f in ipairs(fishes:GetChildren()) do
        local fishZone = f:GetAttribute("Zone")
        if fishZone ~= zoneName then continue end

        local rootPart = f:FindFirstChild("RootPart")
        local prompt   = rootPart and rootPart:FindFirstChild("ProximityPrompt")
        if not prompt then continue end

        local mutationType = nil
        for _, mt in ipairs({"Silver","Gold","Rainbow","Frozen","Shocked","Magma","Chocolate","Dry","Infected","Evil","YinYang","Hacker","Taco","Galaxy"}) do
            if f:GetAttribute(mt) then mutationType = mt; break end
        end
        local rarity      = getRarity(f)
        local shouldCatch = false

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
        if not alive() or not CFG.AutoFarm then break end
        if getOxygenPct() <= 0.10 then break end

        local used  = Player:GetAttribute("BackpackUsed")  or 0
        local space = Player:GetAttribute("BackpackSpace") or 25
        if used >= space then
            if CFG.FarmAutoSell then
                local sold = doFilteredSell()
                if sold then _farmSells += 1 end
                task.wait(0.2)
                used = Player:GetAttribute("BackpackUsed") or 0
                if used >= space then break end
            else
                break
            end
        end

        if not c.fish.Parent or not c.root.Parent then continue end

        pcall(function()
            hrp = getHRP()
            if not hrp then return end
            hrp.CFrame = CFrame.new(c.root.Position + Vector3.new(0, 0, 3))
            task.wait(0.25)
            if c.root.Parent and c.prompt.Parent then
                pcall(function() fireproximityprompt(c.prompt) end)
            end
        end)

        caught      += 1
        _farmCaught += 1
        _farmStatus  = c.name .. " [" .. c.tag .. "] " .. c.cps .. "$/s"
        task.wait(0.25)
    end

    return caught
end

task.spawn(function()
    while alive() do
        if CFG.AutoFarm then
            local hrp = getHRP()
            if not hrp then task.wait(jitter(0.5, 0.5)); continue end

            if getOxygenPct() <= 0.10 then
                _farmStatus = "Low O2 - Surfacing..."
                tpToSurface()
                task.wait(jitter(1, 0.5))
                local t0 = tick()
                while getOxygenPct() < 0.90 and CFG.AutoFarm and alive() and (tick() - t0) < 30 do
                    _farmStatus = string.format("Recovering O2... %.0f%%", getOxygenPct() * 100)
                    pcall(function() local h = getHRP(); if h and h.Position.Y < 2520 then tpToSurface() end end)
                    task.wait(jitter(0.5, 0.5))
                end
                if not alive() or not CFG.AutoFarm then continue end
            end

            local used  = Player:GetAttribute("BackpackUsed")  or 0
            local space = Player:GetAttribute("BackpackSpace") or 25
            if used >= space then
                if CFG.FarmAutoSell then
                    local sold = doFilteredSell()
                    if sold then _farmSells += 1 end
                    task.wait(0.2)
                end
                if (Player:GetAttribute("BackpackUsed") or 0) >= (Player:GetAttribute("BackpackSpace") or 25) then
                    _farmStatus = "Backpack full - Surfacing..."
                    tpToSurface()
                    while (Player:GetAttribute("BackpackUsed") or 0) >= (Player:GetAttribute("BackpackSpace") or 25) and CFG.AutoFarm and alive() do
                        _farmStatus = string.format("Full %d/%d - sell/equip to continue", Player:GetAttribute("BackpackUsed") or 0, Player:GetAttribute("BackpackSpace") or 25)
                        task.wait(jitter(1, 0.5))
                    end
                    if not alive() or not CFG.AutoFarm then continue end
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

            if not alive() or not CFG.AutoFarm then _farmStatus = nil; continue end
            _farmStatus = "Diving to " .. zone.label .. "..."
            tpToZone(zone)
            task.wait(0.6)
            if not alive() or not CFG.AutoFarm then _farmStatus = nil; continue end

            local caught = catchFishInZone(zone.name)
            if caught > 0 then
                _farmStatus = "Caught " .. caught .. " | Total: " .. _farmCaught
            else
                _farmStatus = "No fish in " .. zone.label .. " - rotating..."
                task.wait(0.4)
            end
        else
            _farmStatus = nil
            task.wait(0.5)
        end
    end
end)

-- Anti-AFK
task.spawn(function()
    while alive() do
        if CFG.AntiAFK then
            pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
            end)
        end
        task.wait(120)
    end
end)

-- Auto-claim on start
task.spawn(function() task.wait(3); if alive() then pcall(doClaim) end end)

-- Block purchase prompts
pcall(function()
    game:GetService("MarketplaceService").PromptProductPurchaseFinished:Connect(function() end)
    game:GetService("MarketplaceService").PromptPurchaseFinished:Connect(function() end)
    game:GetService("GuiService"):SetPurchasePromptIsShown(false)
end)

task.spawn(function()
    while alive() do
        if CFG.AutoBuyTreats or CFG.AutoBuyTools then
            pcall(function() game:GetService("GuiService"):CloseInspectMenu() end)
            pcall(function()
                local cg = game:GetService("CoreGui")
                for _, gui in ipairs(cg:GetChildren()) do
                    if gui.Name == "PurchasePromptApp" or gui.Name == "PurchasePrompt" then
                        for _, d in ipairs(gui:GetDescendants()) do
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
-- V5 UI — SIDEBAR + PANEL ALPHA + PANEL BETA + LIVE GAME
-- ============================================================

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
    Name = "Aurora", DisplayOrder = 9999, ResetOnSpawn = false,
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

-- Centered brand watermark
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
    { name = "Farm",    icon = "●" },
    { name = "Fishing", icon = "◆" },
    { name = "Shop",    icon = "≡" },
    { name = "Utility", icon = "□" },
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

-- Forward-declare dropdown popup helpers
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

local TAB_NAMES = { "Farm", "Fishing", "Shop", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm    = C.pink,
    Fishing = C.purple,
    Shop    = C.pink,
    Utility = C.pink,
    Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "DIVE FARM",      beta = "FARM STATUS" },
    Fishing  = { alpha = "CATCH FILTERS",  beta = "SELL & PROTECT" },
    Shop     = { alpha = "SHOP",           beta = "AQUARIUM" },
    Utility  = { alpha = "UTILITY",        beta = "TOOLS" },
    Settings = { alpha = "CONFIG",         beta = "ABOUT" },
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

-- =========================================================================
-- DROPDOWN (single or multi select on CFG[cfgKey])
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
        Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = create("Frame", {
        Size = UDim2.fromOffset(120, 22), Position = UDim2.new(1, -120, 0.5, -11),
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

    local POPUP_W  = 180
    local OPT_H    = 26
    local POPUP_H  = math.min(260, #options * (OPT_H + 2) + 8)

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
-- DROPDOWN VARIANT: operates on EXTERNAL set map (for SelRarities/SelMutations/SelZones/SelTreats/SelTools/SelFeedSlots/SelSellRarities)
-- Preserves v4's multi-select-with-shared-state semantics.
-- =========================================================================
local function dropdownMapRow(parent, label, options, setMap, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(1, -130, 1, 0), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local pill = create("Frame", {
        Size = UDim2.fromOffset(120, 22), Position = UDim2.new(1, -120, 0.5, -11),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(pill, 5); stroke(pill, C.border2, 1, 0)

    local function displayText()
        local count, firstKey = 0, nil
        for _, nm in ipairs(options) do
            if setMap[nm] then count = count + 1; if not firstKey then firstKey = nm end end
        end
        if count == 0 then return "None" end
        if count == #options then return "All (" .. count .. ")" end
        if count == 1 then return tostring(firstKey) end
        return count .. "/" .. #options
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

    local POPUP_W  = 190
    local OPT_H    = 26
    local POPUP_H  = math.min(260, #options * (OPT_H + 2) + 8)

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

    return row, function() valLabel.Text = displayText(); paintOpts() end
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
-- POPULATE: FARM
--========================================================================
local oFarm_a, oFarm_b = 0, 0
local function nFa() oFarm_a = oFarm_a + 1; return oFarm_a end
local function nFb() oFarm_b = oFarm_b + 1; return oFarm_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Auto Farm", nFa())
toggleRow(scrolls["Farm_alpha"], "Auto Farm",      "AutoFarm",     nFa())
toggleRow(scrolls["Farm_alpha"], "Farm Auto Sell", "FarmAutoSell", nFa())

sectionHeader(scrolls["Farm_alpha"], "◉", "Quick Dive", nFa())
dropdownRow(scrolls["Farm_alpha"], "Dive Zone", "DiveZone", ZONE_NAMES, nFa(), false)
actionBtn(scrolls["Farm_alpha"], "Dive to Zone", C.bg3, nFa(), function()
    local zone = ZONE_LABEL_TO_DATA[CFG.DiveZone or "Sunlight Zone"]
    if zone then tpToZone(zone) end
end)
actionBtn(scrolls["Farm_alpha"], "TP to Surface", C.bg3, nFa(), function() tpToSurface() end)

sectionHeader(scrolls["Farm_alpha"], "▣", "Manual Actions", nFa())
actionBtn(scrolls["Farm_alpha"], "Sell Inventory",      C.bg3, nFa(), function() doFilteredSell() end)
actionBtn(scrolls["Farm_alpha"], "Equip Best Fish",     C.bg3, nFa(), function() doEquipBest() end)
actionBtn(scrolls["Farm_alpha"], "Catch All (Filter)",  C.bg3, nFa(), function()
    task.spawn(function()
        pcall(function()
            local fishes = workspace.Game:FindFirstChild("Fishes")
            if not fishes then return end
            local hrp = getHRP()
            if not hrp then return end
            local caught = 0
            for _, f in ipairs(fishes:GetChildren()) do
                local rootPart = f:FindFirstChild("RootPart")
                local prompt = rootPart and rootPart:FindFirstChild("ProximityPrompt")
                if not prompt then continue end
                local mutationType = nil
                for _, mt in ipairs({"Silver","Gold","Rainbow","Frozen","Shocked","Magma","Chocolate","Dry","Infected","Evil","YinYang","Hacker","Taco","Galaxy"}) do
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
                    pcall(function() fireproximityprompt(prompt) end)
                    caught += 1
                end)
                task.wait(jitter(0.25, 0.15))
            end
            _farmStatus = "Caught " .. caught .. " fish (all zones)"
            tpToSurface()
        end)
    end)
end)

sectionHeader(scrolls["Farm_beta"], "●", "Status", nFb())
local _infoFarmStatus = infoRow(scrolls["Farm_beta"], "Status",   "Off",  C.text,  nFb())
local _infoZone       = infoRow(scrolls["Farm_beta"], "Zone",     "---",  C.text2, nFb())
local _infoFish       = infoRow(scrolls["Farm_beta"], "Target",   "---",  C.text2, nFb())

sectionHeader(scrolls["Farm_beta"], "◉", "Vitals", nFb())
local _infoO2         = infoRow(scrolls["Farm_beta"], "O2",       "100%", C.text,  nFb())
local _infoBP         = infoRow(scrolls["Farm_beta"], "Backpack", "0/25", C.text,  nFb())

sectionHeader(scrolls["Farm_beta"], "✦", "Session", nFb())
local _infoCaught     = infoRow(scrolls["Farm_beta"], "Fish Caught",  "0",  C.pink,  nFb())
local _infoSells      = infoRow(scrolls["Farm_beta"], "Farm Sells",   "0",  C.pink,  nFb())
local _infoRuntime    = infoRow(scrolls["Farm_beta"], "Runtime",      "0m", C.text2, nFb())

--========================================================================
-- POPULATE: FISHING (catch & sell filters)
--========================================================================
local oFi_a, oFi_b = 0, 0
local function nFia() oFi_a = oFi_a + 1; return oFi_a end
local function nFib() oFi_b = oFi_b + 1; return oFi_b end

sectionHeader(scrolls["Fishing_alpha"], "●", "Catch Filter", nFia())
dropdownMapRow(scrolls["Fishing_alpha"], "Rarities",  RARITIES,   SelRarities,  nFia())
dropdownMapRow(scrolls["Fishing_alpha"], "Mutations", MUTATIONS,  SelMutations, nFia())

sectionHeader(scrolls["Fishing_alpha"], "◉", "Farm Zones", nFia())
dropdownMapRow(scrolls["Fishing_alpha"], "Ocean Zones", ZONE_NAMES, SelZones, nFia())

sectionHeader(scrolls["Fishing_alpha"], "✦", "Notes", nFia())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "AutoFarm dives a random selected zone,\ncatches fish matching Rarity & Mutation,\nsorts by Cash/sec (highest first).\n\n'Normal' mutation = unmutated fish.\nProtect Mutations prevents selling\nmutated fish via the Sell filter.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nFia(),
}, scrolls["Fishing_alpha"])

sectionHeader(scrolls["Fishing_beta"], "●", "Sell Filter", nFib())
dropdownMapRow(scrolls["Fishing_beta"], "Sell Rarities", RARITIES, SelSellRarities, nFib())
toggleRow(scrolls["Fishing_beta"], "Protect Mutations", "ProtectMutations", nFib())

sectionHeader(scrolls["Fishing_beta"], "◉", "Auto Sell", nFib())
toggleRow(scrolls["Fishing_beta"], "Auto Sell",       "AutoSell",      nFib())
toggleRow(scrolls["Fishing_beta"], "Auto Equip Best", "AutoEquipBest", nFib())

sectionHeader(scrolls["Fishing_beta"], "▣", "Manual", nFib())
actionBtn(scrolls["Fishing_beta"], "Sell Now",         C.bg3, nFib(), function() doFilteredSell() end)
actionBtn(scrolls["Fishing_beta"], "Equip Best Now",   C.bg3, nFib(), function() doEquipBest() end)

--========================================================================
-- POPULATE: SHOP
--========================================================================
local oSh_a, oSh_b = 0, 0
local function nSa() oSh_a = oSh_a + 1; return oSh_a end
local function nSb() oSh_b = oSh_b + 1; return oSh_b end

sectionHeader(scrolls["Shop_alpha"], "●", "Auto Purchase", nSa())
toggleRow(scrolls["Shop_alpha"], "Auto Buy Treats", "AutoBuyTreats", nSa())
toggleRow(scrolls["Shop_alpha"], "Auto Buy Tools",  "AutoBuyTools",  nSa())

sectionHeader(scrolls["Shop_alpha"], "◉", "Selections", nSa())
dropdownMapRow(scrolls["Shop_alpha"], "Buy Treats", TREAT_LIST, SelTreats, nSa())
dropdownMapRow(scrolls["Shop_alpha"], "Buy Tools",  TOOL_LIST,  SelTools,  nSa())

sectionHeader(scrolls["Shop_alpha"], "▣", "Session", nSa())
local _shopTreats = infoRow(scrolls["Shop_alpha"], "Treats Bought", "0", C.pink, nSa())
local _shopTools  = infoRow(scrolls["Shop_alpha"], "Tools Bought",  "0", C.pink, nSa())

sectionHeader(scrolls["Shop_beta"], "●", "Aquarium", nSb())
toggleRow(scrolls["Shop_beta"], "Auto Feed Fish", "AutoFeedFish", nSb())

sectionHeader(scrolls["Shop_beta"], "◉", "Feed Slots", nSb())
dropdownMapRow(scrolls["Shop_beta"], "Slots", FEED_SLOTS, SelFeedSlots, nSb())

sectionHeader(scrolls["Shop_beta"], "✦", "Session", nSb())
local _shopFeeds  = infoRow(scrolls["Shop_beta"], "Fish Fed",  "0", C.pink,  nSb())
local _shopSells  = infoRow(scrolls["Shop_beta"], "Sells",     "0", C.pink,  nSb())
local _shopEquips = infoRow(scrolls["Shop_beta"], "Equips",    "0", C.pink,  nSb())

sectionHeader(scrolls["Shop_beta"], "▣", "Notes", nSb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Feed Fish selects the top N fish by\nCash/sec from the aquarium and feeds\nthe first owned treat.\n\nOnly selected Feed Slots are fed.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nSb(),
}, scrolls["Shop_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Auto Rewards", nUa())
toggleRow(scrolls["Utility_alpha"], "Auto Rebirth",      "AutoRebirth",     nUa())
toggleRow(scrolls["Utility_alpha"], "Auto Claim",        "AutoClaim",       nUa())
toggleRow(scrolls["Utility_alpha"], "Auto Spin Wheel",   "AutoSpinWheel",   nUa())
toggleRow(scrolls["Utility_alpha"], "Auto Claim Quests", "AutoClaimQuests", nUa())
toggleRow(scrolls["Utility_alpha"], "Steal Fish",        "StealFish",       nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Character", nUa())
toggleRow(scrolls["Utility_alpha"], "Speed Boost", "SpeedBoost", nUa())
toggleRow(scrolls["Utility_alpha"], "Anti AFK",    "AntiAFK",    nUa())

sectionHeader(scrolls["Utility_alpha"], "▣", "Session", nUa())
local _uSteals = infoRow(scrolls["Utility_alpha"], "Fish Stolen",  "0", C.pink, nUa())
local _uRebS   = infoRow(scrolls["Utility_alpha"], "Rebirths",     "0", C.pink, nUa())
local _uSpins  = infoRow(scrolls["Utility_alpha"], "Wheel Spins",  "0", C.pink, nUa())
local _uQuests = infoRow(scrolls["Utility_alpha"], "Quests",       "0", C.pink, nUa())

sectionHeader(scrolls["Utility_beta"], "●", "Manual Actions", nUb())
actionBtn(scrolls["Utility_beta"], "Rebirth",       C.bg3, nUb(), function() doRebirth() end)
actionBtn(scrolls["Utility_beta"], "Claim Rewards", C.bg3, nUb(), function() doClaim()   end)
actionBtn(scrolls["Utility_beta"], "Spin Wheel",    C.bg3, nUb(), function() doSpinWheel() end)

sectionHeader(scrolls["Utility_beta"], "◉", "Teleport", nUb())
actionBtn(scrolls["Utility_beta"], "TP Kraken World", C.bg3, nUb(), function()
    pcall(function() reliableTP(CFrame.new(-1928, -1103, -1419)) end)
end)
actionBtn(scrolls["Utility_beta"], "TP Megalodons Lair", C.bg3, nUb(), function()
    pcall(function() reliableTP(CFrame.new(-1928, -1577, -1419)) end)
end)
actionBtn(scrolls["Utility_beta"], "TP Aquarium/Surface", C.bg3, nUb(), function() tpToSurface() end)

sectionHeader(scrolls["Utility_beta"], "✦", "Player", nUb())
local _uCash   = infoRow(scrolls["Utility_beta"], "Cash",      "$0",   C.pink,  nUb())
local _uReb    = infoRow(scrolls["Utility_beta"], "Rebirths",  "0",    C.text,  nUb())
local _uO2     = infoRow(scrolls["Utility_beta"], "O2",        "100%", C.text2, nUb())
local _uBP     = infoRow(scrolls["Utility_beta"], "Backpack",  "0/25", C.text2, nUb())

--========================================================================
-- POPULATE: SETTINGS
--========================================================================
local oSet_a, oSet_b = 0, 0
local function nSeta() oSet_a = oSet_a + 1; return oSet_a end
local function nSetb() oSet_b = oSet_b + 1; return oSet_b end

sectionHeader(scrolls["Settings_alpha"], "●", "Config", nSeta())
toggleRow(scrolls["Settings_alpha"], "Auto Save", "AutoSave", nSeta())
actionBtn(scrolls["Settings_alpha"], "Save Config Now", C.green, nSeta(), function() saveCFG() end)
actionBtn(scrolls["Settings_alpha"], "Load Config",     C.bg3,   nSeta(), function() loadSavedCFG() end)
actionBtn(scrolls["Settings_alpha"], "Reset Config",    C.red,   nSeta(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.ProtectMutations = true
    CFG.DiveZone = "Sunlight Zone"
    CFG.AutoSave = true
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSeta())
actionBtn(scrolls["Settings_alpha"], "Reset Position", C.bg3, nSeta(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn(scrolls["Settings_alpha"], "Destroy UI", C.red, nSeta(), function()
    task.wait(0.3)
    getgenv().__AURORA_DIVEDOWN_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSetb())
infoRow(scrolls["Settings_beta"], "Game",    "Dive Down",                   C.text,  nSetb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),        C.text2, nSetb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),   C.text2, nSetb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",               C.pink,  nSetb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                          C.text2, nSetb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                  C.text3, nSetb())
infoRow(scrolls["Settings_beta"], "Network", "Packet + Workspace.Network",  C.text3, nSetb())

sectionHeader(scrolls["Settings_beta"], "◆", "Active Features", nSetb())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 200),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nSetb(),
}, scrolls["Settings_beta"])

--========================================================================
-- POPULATE: LIVE GAME (persistent)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime  = infoRow(liveScroll, "Runtime", "0m", C.text2, nL())
local _liveStatus   = infoRow(liveScroll, "Status",  "Idle", C.text, nL())

sectionHeader(liveScroll, "●", "Player", nL())
local _liveCash     = infoRow(liveScroll, "Cash",      "$0",   C.pink,  nL())
local _liveReb      = infoRow(liveScroll, "Rebirths",  "0",    C.text,  nL())

sectionHeader(liveScroll, "◆", "Dive", nL())
local _liveO2       = infoRow(liveScroll, "O2",        "100%", C.text2, nL())
local _liveBP       = infoRow(liveScroll, "Backpack",  "0/25", C.text2, nL())
local _liveZone     = infoRow(liveScroll, "Zone",      "---",  C.text2, nL())
local _liveFish     = infoRow(liveScroll, "Target",    "---",  C.text2, nL())

sectionHeader(liveScroll, "✦", "Session Totals", nL())
local _liveCaught   = infoRow(liveScroll, "Caught",    "0", C.pink, nL())
local _liveFSells   = infoRow(liveScroll, "Farm Sells","0", C.pink, nL())
local _liveSells    = infoRow(liveScroll, "Sells",     "0", C.pink, nL())
local _liveEquips   = infoRow(liveScroll, "Equips",    "0", C.pink, nL())
local _liveTreats   = infoRow(liveScroll, "Treats",    "0", C.pink, nL())
local _liveTools    = infoRow(liveScroll, "Tools",     "0", C.pink, nL())
local _liveFeeds    = infoRow(liveScroll, "Feeds",     "0", C.pink, nL())
local _liveSpins    = infoRow(liveScroll, "Spins",     "0", C.pink, nL())
local _liveQuests   = infoRow(liveScroll, "Quests",    "0", C.pink, nL())
local _liveSteals   = infoRow(liveScroll, "Steals",    "0", C.pink, nL())

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
-- CLOSE + MINIMIZE BUTTONS
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
        getgenv().__AURORA_DIVEDOWN_SESSION = 0
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
            local used  = Player:GetAttribute("BackpackUsed")  or 0
            local space = Player:GetAttribute("BackpackSpace") or 25
            local o2pct = string.format("%.0f%%", getOxygenPct() * 100)
            local bpStr = used .. "/" .. space

            local elapsed = tick() - S.session
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Parse farm status for zone/fish
            local zoneTxt, fishTxt = "---", "---"
            if _farmStatus and CFG.AutoFarm then
                zoneTxt = _farmStatus:match("Diving to (.-)%.%.%.") or _farmStatus:match("No fish in (.-)%s*%-") or "---"
                fishTxt = _farmStatus:match("^(.-)%s+%[") or "---"
            end

            -- Farm tab
            _infoFarmStatus.Text = _farmStatus or (CFG.AutoFarm and "Active" or "Off")
            _infoZone.Text       = zoneTxt
            _infoFish.Text       = fishTxt
            _infoO2.Text         = o2pct
            _infoBP.Text         = bpStr
            _infoCaught.Text     = tostring(_farmCaught)
            _infoSells.Text      = tostring(_farmSells)
            _infoRuntime.Text    = rtime

            -- Shop tab
            _shopTreats.Text = tostring(S.treats)
            _shopTools.Text  = tostring(S.tools)
            _shopFeeds.Text  = tostring(S.feeds)
            _shopSells.Text  = tostring(S.sells)
            _shopEquips.Text = tostring(S.equips)

            -- Utility tab
            _uCash.Text   = "$" .. fmt(_cash)
            _uReb.Text    = tostring(_reb)
            _uO2.Text     = o2pct
            _uBP.Text     = bpStr
            _uSteals.Text = tostring(S.steals)
            _uRebS.Text   = tostring(S.reb)
            _uSpins.Text  = tostring(S.spins)
            _uQuests.Text = tostring(S.quests)

            -- Live Game
            _liveRuntime.Text = rtime
            _liveCash.Text    = "$" .. fmt(_cash)
            _liveReb.Text     = tostring(_reb)
            _liveO2.Text      = o2pct
            _liveBP.Text      = bpStr
            _liveZone.Text    = zoneTxt
            _liveFish.Text    = fishTxt
            _liveCaught.Text  = tostring(_farmCaught)
            _liveFSells.Text  = tostring(_farmSells)
            _liveSells.Text   = tostring(S.sells)
            _liveEquips.Text  = tostring(S.equips)
            _liveTreats.Text  = tostring(S.treats)
            _liveTools.Text   = tostring(S.tools)
            _liveFeeds.Text   = tostring(S.feeds)
            _liveSpins.Text   = tostring(S.spins)
            _liveQuests.Text  = tostring(S.quests)
            _liveSteals.Text  = tostring(S.steals)

            -- Status mode
            local mode = "Idle"
            if CFG.AutoFarm then mode = "Diving"
            elseif CFG.AutoSell or CFG.AutoEquipBest then mode = "Selling"
            elseif CFG.AutoBuyTreats or CFG.AutoBuyTools or CFG.AutoFeedFish then mode = "Shopping"
            elseif CFG.AutoRebirth or CFG.AutoClaim or CFG.AutoSpinWheel or CFG.AutoClaimQuests then mode = "Rewards"
            elseif CFG.StealFish then mode = "Stealing" end
            _liveStatus.Text = mode

            -- Active features list + pill counter
            local active = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" and k ~= "ProtectMutations" then
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

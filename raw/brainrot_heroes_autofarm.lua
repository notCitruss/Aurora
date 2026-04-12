--// Aurora v4 — Brainrot Heroes Auto-Farm
--// PlaceId: 75251063577391

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

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_BH_CFG then
    for k, v in getgenv().__AURORA_BH_CFG do
        if type(v) == "boolean" then getgenv().__AURORA_BH_CFG[k] = false end
    end
end
pcall(function() if getgenv().__AURORA_BH_SPEED then getgenv().__AURORA_BH_SPEED:Disconnect() end end)

getgenv().__AURORA_BH_SESSION = tick()
local _mySession = getgenv().__AURORA_BH_SESSION
local function alive() return getgenv().__AURORA_BH_SESSION == _mySession end

---------- REMOTES ----------
local Remotes = RS:WaitForChild("Remotes", 15)
if not Remotes then warn("[Aurora] Remotes folder not found"); return end

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
local HttpService = game:GetService("HttpService")
---------- CONFIG ----------
local CFG = {
    -- Farm
    AutoCollect     = false,
    AutoBuyGear     = false,
    AutoUseGear     = false,
    -- Heroes
    AutoEquipHeroes = false,
    AutoFuseHeroes  = false,
    AutoBuyCircle   = false,
    AutoRerollTrait = false,
    TargetTrait     = "Any",
    -- Brainrots
    AutoEquipBrainrots = false,
    -- Sell
    AutoSell        = false,
    -- Utility
    AutoRebirth     = false,
    AutoLucky       = false,
    SpeedBoost      = false,
    AntiAFK         = false,
    -- Config
    AutoSave        = false,
}

local _cfgFileName = "aurora_cfg_brainrot_heroes.json"

---------- RARITY DATA & FILTER TABLES (MUST be before loadSavedCFG) ----------
local RARITY_ORDER = {"Rare","Epic","Legendary","Mythic","Godly","Secret","Celestial","Limited"}
local RARITY_DISPLAY = {Rare="Rare",Epic="Epic",Legendary="Legendary",Mythic="Mythic",Godly="Godly",Secret="Secret",Celestial="Celestial",Limited="Limited (Zeus)"}

local SELL_FILTER      = {Rare=true, Epic=true, Legendary=false, Mythic=false, Godly=false, Secret=false, Celestial=false, Limited=false}
local HERO_BUY         = {Rare=true, Epic=true, Legendary=true,  Mythic=true,  Godly=true,  Secret=false, Celestial=false, Limited=false}
local FUSE_FILTER      = {Rare=true, Epic=true, Legendary=true,  Mythic=false, Godly=false, Secret=false, Celestial=false, Limited=false}
local HERO_FAV_FILTER  = {Rare=false,Epic=false,Legendary=true,  Mythic=true,  Godly=true,  Secret=true,  Celestial=true,  Limited=true}

local GEAR_NAMES = {
    "Crown","Freeze Bomb","War Horn","War Drum","Boxing Glove","Size Potion","Radioactive Waste","Nuke Button",
    "Barbed Bat","Bat","Darkhammer","Death Axe","Emerald Sword","Fire Mace","Greatsword","Hammer",
    "Ice Hammer","Metal Bat","Moonblade","Mystic Hammer","Overseer Axe","Shadow Blade","Skull Axe",
    "Spike Mace","Spiked Bat","Celestial Lucky Block","Godly Lucky Block","Mythic Lucky Block","Secret Lucky Block",
}
local SelGears = {}
for _, g in GEAR_NAMES do SelGears[g] = true end

---------- SAVE / LOAD CONFIG ----------
local function saveCFG()
    local saveData = {
        CFG = CFG,
        _SelGears = SelGears,
        _SellFilter = SELL_FILTER,
        _HeroBuy = HERO_BUY,
        _FuseFilter = FUSE_FILTER,
        _HeroFavFilter = HERO_FAV_FILTER,
    }
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(saveData)) end)
    getgenv()["AuroraCFG_brainrot_heroes"] = saveData
end

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_brainrot_heroes"] end
    if saved and type(saved) == "table" then
        local src = saved.CFG or saved
        for k, v in src do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._SelGears then for k in SelGears do SelGears[k] = nil end; for k, v in saved._SelGears do SelGears[k] = v end end
        -- Only load filter tables if they have the right keys (skip stale/corrupt saves)
        if saved._SellFilter and saved._SellFilter.Rare ~= nil then
            for k, v in saved._SellFilter do if SELL_FILTER[k] ~= nil then SELL_FILTER[k] = v end end
        end
        if saved._HeroBuy and saved._HeroBuy.Rare ~= nil then
            for k, v in saved._HeroBuy do if HERO_BUY[k] ~= nil then HERO_BUY[k] = v end end
        end
        if saved._FuseFilter and saved._FuseFilter.Rare ~= nil then
            for k, v in saved._FuseFilter do if FUSE_FILTER[k] ~= nil then FUSE_FILTER[k] = v end end
        end
        if saved._HeroFavFilter and saved._HeroFavFilter.Rare ~= nil then
            for k, v in saved._HeroFavFilter do if HERO_FAV_FILTER[k] ~= nil then HERO_FAV_FILTER[k] = v end end
        end
    end
end

loadSavedCFG()

---------- HERO DATA ----------
local HERO_DATA = {}
pcall(function()
    local cfg = require(RS.Get.Config)
    if cfg and cfg.Hero then
        for k, v in cfg.Hero do
            if typeof(v) == "table" and v.Cost then
                HERO_DATA[k] = {Name = v.Name or k, Cost = v.Cost, Rarity = v.Rarity or "Rare", Damage = v.Damage}
            end
        end
    end
end)

---------- STATE ----------
local _cash, _rebirths = 0, 0
local _circleSpawns    = {}
local _gearTimers      = {}
local GEAR_COOLDOWN    = 60

local S = {
    session    = tick(),
    collects   = 0,
    sells      = 0,
    rebirths   = 0,
    heroes     = 0,
    lucky      = 0,
    gears      = 0,
    fuses      = 0,
    income     = 0,
    dps        = 0,
    heroCount  = 0,
    brainrotCount = 0,
    brainrotKills = 0,
    stockDisplay  = "---",
    gearInventory = 0,
}

---------- CACHED DATA (single source, refreshed every 5s) ----------
local _cachedData  = nil  -- GetPlayerData result
local _cachedStock = nil  -- GetShopStock result

---------- HELPERS ----------
local function fmt(n)
    if type(n) ~= "number" then return tostring(n) end
    if n >= 1e15 then return string.format("%.1fQ", n/1e15)
    elseif n >= 1e12 then return string.format("%.1fT", n/1e12)
    elseif n >= 1e9  then return string.format("%.1fB", n/1e9)
    elseif n >= 1e6  then return string.format("%.1fM", n/1e6)
    elseif n >= 1e3  then return string.format("%.1fK", n/1e3)
    else return tostring(math.floor(n)) end
end

local function jitter(base, range)
    return base + math.random() * range
end

---------- LISTENERS ----------
pcall(function()
    Remotes.CurrencyUpdated.OnClientEvent:Connect(function(c, a)
        if c == "Cash" then _cash = a end
    end)
end)

---------- CORE FUNCTIONS ----------
local function collectIncome()
    pcall(function()
        for slot = 1, 19 do
            pcall(function() Remotes.CollectBrainrotIncome:InvokeServer(tostring(slot)) end)
        end
        S.collects += 1
    end)
end

local function sellBulkHeroes()
    local filter = {}
    for r, on in SELL_FILTER do if on then filter[r] = true end end
    if not next(filter) then return end
    local ok = pcall(function() Remotes.SellBulk:InvokeServer("Hero", filter) end)
    if ok then S.sells += 1 end
end

local function doRebirth()
    local ok, r = pcall(function() return Remotes.AttemptRebirth:InvokeServer() end)
    if ok and r then S.rebirths += 1; _rebirths += 1 end
end

local function equipBestHeroes()
    pcall(function() Remotes.EquipBestHeroes:InvokeServer() end)
end

local function equipBestBrainrots()
    pcall(function() Remotes.EquipBestBrainrots:InvokeServer() end)
end

-- Fuse heroes by rarity filter
-- Rank 1 needs 2 copies, Rank 2 needs 3, Rank 3 needs 4
-- Returns true on success, nil on failure
local function fuseHeroes()
    local data = _cachedData
    if not data or not data.Heroes then return 0 end
    local groups = {}
    for _, hero in data.Heroes do
        if typeof(hero) == "table" and hero.HeroId and hero.Rank and hero.UniqueId then
            if hero.Favorited then continue end
            local h = HERO_DATA[hero.HeroId]
            if h and FUSE_FILTER[h.Rarity] then
                local key = hero.HeroId .. "|" .. tostring(hero.Rank)
                if not groups[key] then groups[key] = {id=hero.HeroId, rank=hero.Rank, uids={}} end
                table.insert(groups[key].uids, hero.UniqueId)
            end
        end
    end
    local fused = 0
    for _, g in groups do
        if g.rank >= 4 then continue end
        local needed = g.rank + 1  -- rank 1 = 2 copies, rank 2 = 3, rank 3 = 4
        if needed < 2 then needed = 2 end
        while #g.uids >= needed do
            local batch = {}
            for _ = 1, needed do table.insert(batch, table.remove(g.uids, 1)) end
            local ok2, result = pcall(function()
                return Remotes.AttemptFuseHero:InvokeServer({
                    ["HeroId"] = g.id,
                    ["Rank"] = g.rank,
                    ["UniqueIds"] = batch
                })
            end)
            if ok2 and result then fused += 1 else break end
            task.wait(1 + math.random())
        end
    end
    S.fuses += fused
    return fused
end

-- Buy a specific gear by name
local function buyGear(gearName)
    local ok, r = pcall(function() return Remotes.PurchaseShopGear:InvokeServer(gearName) end)
    if ok and r then S.gears += 1; return true end
    return false
end

-- Use gear from inventory: find UUID in cached data then fire UseShopGear
local function useGearFromInventory(gearName)
    local data = _cachedData
    if not data or not data.Gears then return false end
    for _, g in data.Gears do
        if typeof(g) == "table" and g.GearId == gearName and g.UniqueId then
            local ok2, r = pcall(function() return Remotes.UseShopGear:InvokeServer(g.UniqueId) end)
            if ok2 and r then return true end
        end
    end
    return false
end

-- Single cache refresh — replaces all individual GetPlayerData/GetShopStock calls
local function refreshCache()
    pcall(function()
        local ok, data = pcall(function() return Remotes.GetPlayerData:InvokeServer() end)
        if ok and typeof(data) == "table" then
            _cachedData = data
            if typeof(data.Currency) == "table" then _cash = data.Currency.Cash or _cash end
            _rebirths = data.Rebirth or _rebirths
            S.income = (typeof(data.Income) == "number") and data.Income or S.income
            S.dps = (typeof(data.DPS) == "number") and data.DPS or S.dps
            if data.Heroes then S.heroCount = #data.Heroes end
            if data.Brainrots then S.brainrotCount = #data.Brainrots end
            if data.Gears then S.gearInventory = #data.Gears end
            S.brainrotKills = data.BrainrotsKilled or S.brainrotKills
        end
    end)
    pcall(function()
        local ok, stock = pcall(function() return Remotes.GetShopStock:InvokeServer() end)
        if ok and typeof(stock) == "table" then _cachedStock = stock end
    end)
end

-- Initial data load
refreshCache()

---------- TRAIT DATA ----------
local EASTER_TRAITS = {
    ["Easter I"]=true, ["Easter II"]=true, ["Easter III"]=true,
    ["Easter IV"]=true, ["Easter V"]=true, ["Bunny Boss"]=true,
}
local ALL_TRAITS = {
    "Any",
    -- Tiered
    "Brute I", "Brute II", "Brute III",
    "Charm I", "Charm II", "Charm III",
    "Fortune I", "Fortune II", "Fortune III",
    "Swift I", "Swift II", "Swift III",
    -- Unique
    "Apex", "Beacon", "Blitz", "Cute", "Hourglass", "Overkill", "Radiant", "Zenith",
    -- Easter
    "Easter I", "Easter II", "Easter III", "Easter IV", "Easter V", "Bunny Boss",
}

---------- GAME LOOPS ----------
local function G() return CFG end


-- Auto-dismiss Robux purchase prompts (close prompt GUI)
pcall(function()
    local MPS = game:GetService("MarketplaceService")
    MPS.PromptPurchaseRequested:Connect(function()
        task.wait(0.3)
        pcall(function()
            for _, g in game:GetService("CoreGui"):GetDescendants() do
                if g:IsA("TextButton") and (g.Text == "Cancel" or g.Text == "Not Now") then
                    pcall(function() g.Activated:Fire() end)
                    pcall(function() firesignal(g.Activated) end)
                end
            end
        end)
    end)
    MPS.PromptGamePassPurchaseFinished:Connect(function() end)
    MPS.PromptProductPurchaseFinished:Connect(function() end)
end)

-- Auto Buy Circle Heroes: scan first, TP only if matching hero found
-- Debounce per-prompt to prevent double-fire causing Robux popups
local _lastBuyTime = {}
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        if not G().AutoBuyCircle then continue end
        pcall(function()
            local heroCenter = workspace:FindFirstChild("HeroCenter")
            if not heroCenter then return end
            -- Scan first: find prompts that match our filter WITHOUT teleporting
            local targets = {}
            for _, d in heroCenter:GetDescendants() do
                if not d:IsA("ProximityPrompt") then continue end
                if d.ActionText ~= "Purchase" or not d.Enabled then continue end
                local objText = d.ObjectText or ""
                if objText:find("R%$") or objText:lower():find("robux") then continue end
                local heroName = d.Parent and d.Parent.Parent and d.Parent.Parent.Name
                if not heroName then continue end
                if _lastBuyTime[heroName] and (tick() - _lastBuyTime[heroName]) < 2 then continue end
                local h = HERO_DATA[heroName]
                if h and not HERO_BUY[h.Rarity] then continue end
                if h and h.Cost and _cash < h.Cost then continue end
                table.insert(targets, {prompt = d, name = heroName})
            end
            -- Only TP if we found matching heroes
            if #targets == 0 then return end
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(-0.2, 3.3, -0.5) end
            task.wait(0.3)
            -- Buy all matched targets
            for _, t in targets do
                if not G().AutoBuyCircle or not alive() then return end
                if not t.prompt or not t.prompt.Parent then continue end
                safeFirePrompt(t.prompt)
                _lastBuyTime[t.name] = tick()
                S.heroes += 1
                task.wait(jitter(0.3, 0.2))
            end
        end)
    end
end)

-- Auto Buy Gear — loops until all selected stock is empty, then waits
task.spawn(function()
    while alive() do
        task.wait(jitter(5, 1))
        if not alive() then break end
        if not G().AutoBuyGear then continue end
        pcall(function()
            while G().AutoBuyGear and alive() do
                local ok, stock = pcall(function() return Remotes.GetShopStock:InvokeServer() end)
                if not ok or typeof(stock) ~= "table" then break end
                local bought = false
                for gearName, count in stock do
                    if not G().AutoBuyGear then return end
                    if not SelGears[gearName] then continue end
                    if count <= 0 then continue end
                    pcall(function() Remotes.PurchaseShopGear:InvokeServer(gearName) end)
                    S.gears += 1
                    bought = true
                    task.wait(2 + math.random() * 0.5)
                end
                if not bought then break end
            end
        end)
    end
end)

-- Auto Use Gear (60s cooldown per type)
task.spawn(function()
    while alive() do
        task.wait(jitter(5, 2))
        if not alive() then break end
        pcall(function()
            if not G().AutoUseGear then return end
            for _, gearName in GEAR_NAMES do
                if not G().AutoUseGear then return end
                if not SelGears[gearName] then continue end
                if _gearTimers[gearName] and (tick() - _gearTimers[gearName]) < GEAR_COOLDOWN then continue end
                local used = useGearFromInventory(gearName)
                if used then _gearTimers[gearName] = tick() end
                task.wait(jitter(0.5, 0.5))
            end
        end)
    end
end)

-- Auto Reroll Trait
task.spawn(function()
    while alive() do
        task.wait(jitter(2, 0.5))
        if not alive() then break end
        if not G().AutoRerollTrait then continue end
        pcall(function()
            local data = _cachedData
            if not data or not data.Heroes then return end
            if (data.TraitRerolls or 0) <= 0 then return end
            local target = CFG.TargetTrait
            for _, hero in data.Heroes do
                if not hero.Favorited then continue end
                local trait = hero.Trait or "none"
                if target ~= "Any" and trait == target then continue end
                if target == "Any" and trait ~= "none" then continue end
                if EASTER_TRAITS[target] then
                    pcall(function() Remotes.RollEasterTrait:InvokeServer(hero.UniqueId) end)
                else
                    pcall(function() Remotes.RollTrait:InvokeServer(hero.UniqueId) end)
                end
                task.wait(0.35)
            end
        end)
    end
end)

-- Speed Boost (disconnectable)
local _speedConn

_speedConn = RunService.Heartbeat:Connect(function()
    if not alive() then _speedConn:Disconnect(); return end
    pcall(function()
        local hum = Player.Character and Player.Character:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if G().SpeedBoost then hum.WalkSpeed = 80; hum.JumpPower = 80
        elseif hum.WalkSpeed == 80 then hum.WalkSpeed = 16; hum.JumpPower = 50 end
    end)
end)
getgenv().__AURORA_BH_SPEED = _speedConn


-- Anti-AFK
task.spawn(function()
    while alive() do
        task.wait(jitter(60, 18.0))
        if not alive() then break end
        if not G().AntiAFK then continue end
        pcall(function()
            local v = game:GetService("VirtualUser")
            v:CaptureController()
            v:ClickButton2(Vector2.new())
        end)
    end
end)

-- Single cache refresh loop (replaces all individual remote polling)
task.spawn(function()
    while alive() do
        task.wait(jitter(5, 1))
        if not alive() then break end
        refreshCache()
    end
end)

-- Auto Collect Income
task.spawn(function()
    while alive() do
        task.wait(jitter(10, 2))
        if not alive() then break end
        if not G().AutoCollect then continue end
        pcall(function() collectIncome() end)
    end
end)

-- Auto Sell Heroes (by rarity filter)
task.spawn(function()
    while alive() do
        task.wait(jitter(8, 2))
        if not alive() then break end
        if not G().AutoSell then continue end
        pcall(function() sellBulkHeroes() end)
    end
end)

-- Auto Equip Best Heroes
task.spawn(function()
    while alive() do
        task.wait(jitter(15, 3))
        if not alive() then break end
        if not G().AutoEquipHeroes then continue end
        pcall(function() equipBestHeroes() end)
    end
end)

-- Auto Equip Best Brainrots
task.spawn(function()
    while alive() do
        task.wait(jitter(15, 3))
        if not alive() then break end
        if not G().AutoEquipBrainrots then continue end
        pcall(function() equipBestBrainrots() end)
    end
end)

-- Auto Fuse Heroes (by rarity filter)
task.spawn(function()
    while alive() do
        task.wait(jitter(10, 3))
        if not alive() then break end
        if not G().AutoFuseHeroes then continue end
        pcall(function() fuseHeroes() end)
    end
end)

-- ============================================================
-- SIDEBAR + DUAL PANEL UI (Sailor Piece style)
-- ============================================================

---------- PALETTE ----------
local C = {
    bg        = Color3.fromRGB(18, 20, 28),
    sidebar   = Color3.fromRGB(22, 24, 34),
    panel     = Color3.fromRGB(28, 30, 42),
    card      = Color3.fromRGB(35, 37, 50),
    cardHover = Color3.fromRGB(42, 44, 58),
    accent   = Color3.fromRGB(252, 110, 142),
    accentDim = Color3.fromRGB(180, 80, 110),
    text      = Color3.fromRGB(235, 235, 245),
    dim       = Color3.fromRGB(130, 130, 155),
    green     = Color3.fromRGB(80, 200, 120),
    red       = Color3.fromRGB(220, 60, 60),
    trackOff  = Color3.fromRGB(15, 15, 25),
    knobOff   = Color3.fromRGB(100, 100, 120),
    sliderBg  = Color3.fromRGB(40, 42, 55),
    stroke    = Color3.fromRGB(50, 52, 68),
    blue      = Color3.fromRGB(80, 160, 255),
    purple    = Color3.fromRGB(180, 80, 255),
    orange    = Color3.fromRGB(255, 165, 0),
}

---------- UI HELPERS ----------
local function create(class, props, parent)
    local inst = Instance.new(class)
    for k, v in props do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end

local function corner(p, r)
    return create("UICorner", {CornerRadius = UDim.new(0, r)}, p)
end

local function stroke(p, col, th, tr)
    return create("UIStroke", {
        Color = col, Thickness = th or 1, Transparency = tr or 0.3,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, p)
end

local function lbl(parent, props)
    local d = {
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold,
        TextColor3 = C.text, TextSize = 12,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        BorderSizePixel = 0, Active = false,
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
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 50, IgnoreGuiInset = true,
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

---------- MOBILE SCALING ----------
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
    Name = "Main",
    Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
    Position = _isMobile and UDim2.new(0.5, -TOTAL_W * _scale / 2, 0, 40) or UDim2.fromOffset(16, 60),
    BackgroundColor3 = C.bg, BackgroundTransparency = 0,
    BorderSizePixel = 0, Active = true, ClipsDescendants = true,
}, gui)
corner(main, 12)
stroke(main, C.stroke, 1, 0.2)
if _scale ~= 1 then create("UIScale", {Scale = _scale}, main) end

---------- TOP BAR ----------
local topBar = create("Frame", {
    Name = "TopBar", Size = UDim2.new(1, 0, 0, TOP_H),
    Position = UDim2.fromOffset(0, 0), BackgroundColor3 = C.sidebar,
    BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 5,
}, main)
corner(topBar, 12)
create("Frame", {
    Name = "TopDivider", Size = UDim2.new(1, 0, 0, 1),
    Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.stroke,
    BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5,
}, topBar)

create("ImageLabel", {
    Name = "Logo", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 6),
    BackgroundTransparency = 1, Image = "rbxassetid://77299357494181",
    ScaleType = Enum.ScaleType.Fit, ZIndex = 6,
}, topBar)

lbl(topBar, {
    Name = "Title", Size = UDim2.new(0, 80, 1, 0), Position = UDim2.fromOffset(44, 0),
    Text = "Aurora", TextSize = 14, Font = Enum.Font.GothamBlack,
    TextColor3 = C.accent, ZIndex = 6,
})

local _gameName = "Brainrot Heroes"
pcall(function()
    local info = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    if info and info.Name then _gameName = info.Name end
end)
lbl(topBar, {
    Name = "Game", Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(1, -310, 0, 0),
    Text = _gameName, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6,
})

-- Minimize button
local minBtn = create("Frame", {
    Name = "Min", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(minBtn, {Size=UDim2.new(1,0,1,0), Text="\xE2\x80\x93", TextSize=22, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=7})

-- Close button
local closeBtn = create("Frame", {
    Name = "Close", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0.5, -15),
    BackgroundTransparency = 1, Active = true, ZIndex = 6,
}, topBar)
lbl(closeBtn, {Size=UDim2.new(1,0,1,0), Text="x", TextSize=16, TextXAlignment=Enum.TextXAlignment.Center, ZIndex=7})

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

---------- RECONNECT / RESPAWN PROTECTION ----------
-- Re-parent GUI if it gets destroyed (game reconnect/teleport wipes PlayerGui)
local function ensureGuiAlive()
    if not gui or not gui.Parent then
        pcall(function()
            gui = create("ScreenGui", {
                Name = "Aurora", ResetOnSpawn = false,
                ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
                DisplayOrder = 50, IgnoreGuiInset = true,
            })
            local ok = false
            if _isMobile then ok = pcall(function() gui.Parent = Player.PlayerGui end) end
            if not ok then ok = pcall(function() gui.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui") end) end
            if not ok then pcall(function() gui.Parent = Player.PlayerGui end) end
            main.Parent = gui
            flower.Parent = gui
        end)
    end
end

pcall(function()
    Player.CharacterAdded:Connect(function()
        task.wait(1)
        if alive() then ensureGuiAlive() end
    end)
end)

-- Also watch for gui being destroyed directly
pcall(function()
    gui.AncestryChanged:Connect(function(_, newParent)
        if not newParent and alive() then
            task.wait(0.5)
            ensureGuiAlive()
        end
    end)
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
    {name="Farm",      color=Color3.fromRGB(80, 200, 120)},
    {name="Heroes",    color=Color3.fromRGB(255, 180, 30)},
    {name="Brainrots", color=Color3.fromRGB(100, 180, 255)},
    {name="Shop",      color=Color3.fromRGB(255, 100, 100)},
    {name="Utility",   color=Color3.fromRGB(180, 130, 255)},
}
local CONFIG_TAB = {name="Config", color=Color3.fromRGB(130, 130, 155)}

local tabBtns        = {}
local leftContainers = {}
local rightContainers = {}

-- Tab list
local tabList = create("Frame", {
    Name = "TabList", Size = UDim2.new(1, -8, 0, #TAB_DEFS * 40 + 4),
    Position = UDim2.fromOffset(4, 8), BackgroundTransparency = 1, BorderSizePixel = 0,
}, sidebar)
create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,4)}, tabList)

local function makeTabBtn(def, idx, parent)
    local btn = create("Frame", {
        Name = "Tab_"..def.name, Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.card, BackgroundTransparency = 0.5,
        BorderSizePixel = 0, Active = true, LayoutOrder = idx,
    }, parent)
    corner(btn, 8)
    local indicator = create("Frame", {
        Name = "Indicator", Size = UDim2.new(0, 3, 0, 22),
        Position = UDim2.fromOffset(0, 7),
        BackgroundColor3 = def.color or C.accent,
        BackgroundTransparency = 1, BorderSizePixel = 0,
    }, btn)
    corner(indicator, 2)
    lbl(btn, {
        Name = "Label", Size = UDim2.new(1, 0, 1, 0),
        Text = def.name, TextSize = 13, Font = Enum.Font.GothamBold,
        TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center,
    })
    return btn, indicator
end

local allTabs = {}
for i, def in TAB_DEFS do
    local btn, ind = makeTabBtn(def, i, tabList)
    allTabs[i] = {btn=btn, indicator=ind, name=def.name}
end

-- Config tab pinned at bottom
local configBtn, configInd = makeTabBtn(CONFIG_TAB, 99, nil)
configBtn.Parent = sidebar
configBtn.Position = UDim2.new(0, 4, 1, -44)
configBtn.Size = UDim2.new(1, -8, 0, 36)
allTabs[#TAB_DEFS + 1] = {btn=configBtn, indicator=configInd, name="Config"}

---------- CONTENT PANELS ----------
local function makePanel(name, xPos, width)
    local p = create("ScrollingFrame", {
        Name = name,
        Size = UDim2.new(0, width, 0, CONTENT_H),
        Position = UDim2.fromOffset(xPos, CONTENT_Y),
        BackgroundColor3 = C.panel, BackgroundTransparency = 0.10,
        BorderSizePixel = 0, ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent, ScrollBarImageTransparency = 0.3,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
        TopImage    = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        BottomImage = "rbxasset://textures/ui/Scroll/scroll-middle.png",
        MidImage    = "rbxasset://textures/ui/Scroll/scroll-middle.png",
    }, main)
    corner(p, 10)
    stroke(p, C.stroke, 1, 0.4)
    create("UIPadding", {
        PaddingTop    = UDim.new(0,8), PaddingLeft  = UDim.new(0,10),
        PaddingRight  = UDim.new(0,10), PaddingBottom = UDim.new(0,10),
    }, p)
    local layout = create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 4),
    }, p)
    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        p.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 20)
    end)
    return p
end

local TOTAL_TABS = #TAB_DEFS + 1
for i = 1, TOTAL_TABS do
    local tabName = (i <= #TAB_DEFS) and TAB_DEFS[i].name or "Config"
    local lp = makePanel("L_"..tabName, CONTENT_X, LEFT_PW)
    local rp = makePanel("R_"..tabName, CONTENT_X + LEFT_PW + GAP, RIGHT_PW)
    lp.Visible = (i == 1)
    rp.Visible = (i == 1)
    leftContainers[i]  = lp
    rightContainers[i] = rp
end

---------- SWITCH TAB ----------
local activeTabIdx = 1

local function switchTab(idx)
    activeTabIdx = idx
    for i, t in allTabs do
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

for i, t in allTabs do
    local ci = i
    connectClick(t.btn, function() switchTab(ci) end)
end

---------- COMPONENT BUILDERS ----------
local _order   = {}
local _curLeft, _curRight = nil, nil

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
    -- spacer
    create("Frame", {Size=UDim2.new(1,0,0,2), BackgroundTransparency=1, LayoutOrder=nextOrder(panel)}, panel)
    local o = nextOrder(panel)
    local row = create("Frame", {
        Size=UDim2.new(1,0,0,24), BackgroundTransparency=1,
        LayoutOrder=o, BorderSizePixel=0,
    }, panel)
    local dot = create("Frame", {
        Size=UDim2.fromOffset(4,4), Position=UDim2.fromOffset(0,10),
        BackgroundColor3=C.accent, BorderSizePixel=0,
    }, row)
    corner(dot, 2)
    lbl(row, {
        Size=UDim2.new(1,-12,1,0), Position=UDim2.fromOffset(12,0),
        Text=string.upper(title), TextSize=11, Font=Enum.Font.GothamBlack,
        TextColor3=C.accent,
    })
end

local function toggleRow(name, cfgKey, panel, callback)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name="T_"..name, Size=UDim2.new(1,0,0,34),
        BackgroundColor3=C.card, BackgroundTransparency=0,
        BorderSizePixel=0, LayoutOrder=o, Active=true,
    }, panel)
    corner(row, 8)
    lbl(row, {Size=UDim2.new(1,-60,1,0), Position=UDim2.fromOffset(10,0), Text=name, TextSize=13, Font=Enum.Font.Gotham})

    local track = create("Frame", {
        Name="Track", Size=UDim2.fromOffset(38,20),
        Position=UDim2.new(1,-48,0.5,-10),
        BackgroundColor3 = CFG[cfgKey] and C.accent or C.trackOff,
        BorderSizePixel=0,
    }, row)
    corner(track, 10)
    local knob = create("Frame", {
        Name="Knob", Size=UDim2.fromOffset(16,16),
        Position = CFG[cfgKey] and UDim2.new(1,-18,0.5,-8) or UDim2.fromOffset(2,2),
        BackgroundColor3 = CFG[cfgKey] and Color3.new(1,1,1) or C.knobOff,
        BorderSizePixel=0,
    }, track)
    corner(knob, 8)

    local function updateVisual()
        local on = CFG[cfgKey]
        TweenService:Create(track, TweenInfo.new(0.15), {BackgroundColor3=on and C.accent or C.trackOff}):Play()
        TweenService:Create(knob, TweenInfo.new(0.15), {
            Position = on and UDim2.new(1,-18,0.5,-8) or UDim2.fromOffset(2,2),
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
        Size=UDim2.new(1,0,0,22), BackgroundTransparency=1,
        LayoutOrder=o, BorderSizePixel=0,
    }, panel)
    lbl(row, {
        Size=UDim2.new(0.5,0,1,0), Position=UDim2.fromOffset(4,0),
        Text=name, TextSize=10, Font=Enum.Font.GothamSemibold, TextColor3=C.dim,
    })
    local val = lbl(row, {
        Name="Val", Size=UDim2.new(0.5,-4,1,0), Position=UDim2.new(0.5,0,0,0),
        Text=initialValue or "---", TextSize=10, Font=Enum.Font.GothamBold,
        TextColor3=C.text, TextXAlignment=Enum.TextXAlignment.Right,
    })
    return val
end

local function actionButton(name, color, panel, callback)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local btn = create("Frame", {
        Name="A_"..name, Size=UDim2.new(1,0,0,32),
        BackgroundColor3=color or C.accent, BackgroundTransparency=0,
        BorderSizePixel=0, LayoutOrder=o, Active=true,
    }, panel)
    corner(btn, 8)
    local btnLbl = lbl(btn, {
        Size=UDim2.new(1,0,1,0), Text=name, TextSize=11,
        Font=Enum.Font.GothamBold, TextXAlignment=Enum.TextXAlignment.Center,
        TextColor3=C.text,
    })
    connectClick(btn, function()
        if callback then callback() end
        local orig = btnLbl.Text
        btnLbl.Text = name.." ..."
        btnLbl.TextColor3 = C.green
        task.delay(1.5, function() btnLbl.Text = orig; btnLbl.TextColor3 = C.text end)
    end)
    return btn
end

-- Dropdown (single select)
local function dropdownRow(name, options, cfgKey, panel, onChange)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local MAX_DD_VIS = 8
    local totalDDH = #options * 28 + 4
    local visH = math.min(totalDDH, MAX_DD_VIS * 28 + 4)
    local wrapper = create("Frame", {
        Name="DDW_"..name, Size=UDim2.new(1,0,0,34),
        BackgroundTransparency=1, BorderSizePixel=0, LayoutOrder=o, ClipsDescendants=false,
    }, panel)
    local container = create("Frame", {
        Name="DD_"..name, Size=UDim2.new(1,0,0,34),
        BackgroundColor3=C.card, BackgroundTransparency=0,
        BorderSizePixel=0, Active=true, ClipsDescendants=false,
    }, wrapper)
    corner(container, 8)

    lbl(container, {
        Size=UDim2.new(0.45,0,1,0), Position=UDim2.fromOffset(10,0),
        Text=name, TextSize=12, Font=Enum.Font.Gotham,
    })

    -- Current value display
    local valFrame = create("Frame", {
        Name="ValFrame", Size=UDim2.new(0.52,0,0,26),
        Position=UDim2.new(0.46,0,0.5,-13),
        BackgroundColor3=C.bg, BackgroundTransparency=0,
        BorderSizePixel=0, Active=true, ZIndex=2,
    }, container)
    corner(valFrame, 6)
    stroke(valFrame, C.stroke, 1, 0.3)

    local valLbl = lbl(valFrame, {
        Size=UDim2.new(1,-8,1,0), Position=UDim2.fromOffset(6,0),
        Text=CFG[cfgKey] or options[1], TextSize=11, Font=Enum.Font.GothamBold,
        TextColor3=C.accent, ZIndex=3,
    })

    -- Dropdown arrow
    lbl(valFrame, {
        Size=UDim2.new(0,16,1,0), Position=UDim2.new(1,-18,0,0),
        Text="v", TextSize=10, TextXAlignment=Enum.TextXAlignment.Center,
        TextColor3=C.dim, ZIndex=3,
    })

    -- Dropdown list (scrollable, hidden by default)
    local ddOpen = false
    local ddList = create("ScrollingFrame", {
        Name="List", Size=UDim2.new(1,0,0,visH),
        Position=UDim2.new(0,0,1,2),
        BackgroundColor3=C.card, BackgroundTransparency=0,
        BorderSizePixel=0, Visible=false, ZIndex=20, ClipsDescendants=true,
        ScrollBarThickness=3, ScrollBarImageColor3=C.accent,
        CanvasSize=UDim2.fromOffset(0, totalDDH),
        ScrollingDirection=Enum.ScrollingDirection.Y,
    }, container)
    corner(ddList, 6)
    stroke(ddList, C.stroke, 1, 0.2)
    create("UIListLayout", {SortOrder=Enum.SortOrder.LayoutOrder, Padding=UDim.new(0,2)}, ddList)
    create("UIPadding", {PaddingTop=UDim.new(0,2),PaddingLeft=UDim.new(0,4),PaddingRight=UDim.new(0,4),PaddingBottom=UDim.new(0,2)}, ddList)

    for _, opt in options do
        local item = create("Frame", {
            Size=UDim2.new(1,0,0,24),
            BackgroundColor3=C.bg, BackgroundTransparency=0,
            BorderSizePixel=0, Active=true, ZIndex=21,
        }, ddList)
        corner(item, 4)
        local itemLbl = lbl(item, {
            Size=UDim2.new(1,0,1,0), Position=UDim2.fromOffset(6,0),
            Text=opt, TextSize=11, Font=Enum.Font.Gotham,
            TextColor3=C.text, ZIndex=22,
        })
        connectClick(item, function()
            CFG[cfgKey] = opt
            valLbl.Text = opt
            ddList.Visible = false
            ddOpen = false
            wrapper.Size = UDim2.new(1, 0, 0, 34)
            if CFG.AutoSave then saveCFG() end
            if onChange then onChange(opt) end
        end)
        item.MouseEnter:Connect(function() item.BackgroundColor3 = C.cardHover end)
        item.MouseLeave:Connect(function() item.BackgroundColor3 = C.bg end)
    end

    connectClick(valFrame, function()
        ddOpen = not ddOpen
        ddList.Visible = ddOpen
        wrapper.Size = ddOpen and UDim2.new(1, 0, 0, 36 + visH) or UDim2.new(1, 0, 0, 34)
    end)

    return wrapper
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
    local function dispName(nm) return RARITY_DISPLAY and RARITY_DISPLAY[nm] or nm end
    local function getCountText()
        local count = 0
        for _, nm in items do if selMap[nm] then count += 1 end end
        if count == 0 then return title .. ": None" end
        if count <= 2 then
            local names = {}
            for _, nm in items do if selMap[nm] then table.insert(names, dispName(nm)) end end
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
        CanvasSize = UDim2.fromOffset(0, totalH), ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 10,
    }, wrapper)
    corner(listFrame, 6)
    for i, nm in items do
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
            Text = dispName(nm), TextSize = 10, Font = Enum.Font.GothamSemibold,
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

sectionHeader("Income", _curLeft)
toggleRow("Auto Collect Income", "AutoCollect", _curLeft)

sectionHeader("Gear", _curLeft)
toggleRow("Auto Buy Gear", "AutoBuyGear", _curLeft)
toggleRow("Auto Use Gear", "AutoUseGear", _curLeft)
multiSelectDD("Gear Types", GEAR_NAMES, SelGears, _curLeft)

-- Right: Farm Stats
sectionHeader("Income Stats", _curRight)
local _infoIncome   = infoRow("Income/sec", "---", _curRight)
local _infoDPS      = infoRow("DPS", "---", _curRight)
local _infoCash     = infoRow("Cash", "---", _curRight)
local _infoRebirths = infoRow("Rebirths", "0", _curRight)

sectionHeader("Session", _curRight)
local _infoCollects = infoRow("Collects", "0", _curRight)
local _infoSells    = infoRow("Sells", "0", _curRight)
local _infoRuntime  = infoRow("Runtime", "0m", _curRight)

-- ============================================================
-- TAB 2: HEROES
-- ============================================================
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Management", _curLeft)
toggleRow("Auto Equip Best Heroes", "AutoEquipHeroes", _curLeft)
toggleRow("Auto Fuse Heroes", "AutoFuseHeroes", _curLeft)
toggleRow("Auto Buy Circle Hero", "AutoBuyCircle", _curLeft)
toggleRow("Auto Reroll Trait", "AutoRerollTrait", _curLeft)
dropdownRow("Target Trait", ALL_TRAITS, "TargetTrait", _curLeft)

sectionHeader("Manual Actions", _curLeft)
actionButton("Equip Best Now", C.card, _curLeft, function()
    pcall(function() Remotes.EquipBestHeroes:InvokeServer() end)
end)
actionButton("Fuse Heroes Now", C.card, _curLeft, function()
    task.spawn(function() fuseHeroes() end)
end)

sectionHeader("Filters", _curLeft)
multiSelectDD("Buy Rarities", RARITY_ORDER, HERO_BUY, _curLeft)
multiSelectDD("Fuse Rarities", RARITY_ORDER, FUSE_FILTER, _curLeft)
multiSelectDD("Sell Rarities", RARITY_ORDER, SELL_FILTER, _curLeft)
multiSelectDD("Fav Rarities", RARITY_ORDER, HERO_FAV_FILTER, _curLeft)

-- Right: Hero Stats
sectionHeader("Hero Info", _curRight)
local _infoHeroCount   = infoRow("Hero Count", "0", _curRight)
local _infoHeroFuses   = infoRow("Fused Total", "0", _curRight)
local _infoHeroBought  = infoRow("Bought", "0", _curRight)

sectionHeader("Status", _curRight)
local _infoFuseStatus  = infoRow("Fuse Status", "Idle", _curRight)
local _infoTraitTarget = infoRow("Trait Target", CFG.TargetTrait, _curRight)
local _infoTraitRerolls = infoRow("Rerolls Left", "0", _curRight)

-- ============================================================
-- TAB 3: BRAINROTS
-- ============================================================
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Management", _curLeft)
toggleRow("Auto Equip Best Brainrots", "AutoEquipBrainrots", _curLeft)

sectionHeader("Manual Actions", _curLeft)
actionButton("Equip Best Now", C.card, _curLeft, function()
    pcall(function() Remotes.EquipBestBrainrots:InvokeServer() end)
end)
actionButton("Collect All Now", C.card, _curLeft, function()
    task.spawn(function() collectIncome() end)
end)

-- Right: Brainrot Stats
sectionHeader("Brainrot Info", _curRight)
local _infoBrainrotCount  = infoRow("Count", "0", _curRight)
local _infoBrainrotKills  = infoRow("Kills", "0", _curRight)
local _infoBrainrotIncome = infoRow("Income", "---", _curRight)

-- ============================================================
-- TAB 4: SHOP
-- ============================================================
setPanel(leftContainers[4], rightContainers[4])

sectionHeader("Quick Buy", _curLeft)
for _, gn in GEAR_NAMES do
    actionButton("Buy " .. gn, C.card, _curLeft, function()
        task.spawn(function() buyGear(gn) end)
    end)
end

sectionHeader("Quick Use", _curLeft)
for _, gn in GEAR_NAMES do
    actionButton("Use " .. gn, C.card, _curLeft, function()
        task.spawn(function() useGearFromInventory(gn) end)
    end)
end

-- Right: Shop Stats
sectionHeader("Stock", _curRight)
local _stockLabels = {}
for _, gn in GEAR_NAMES do
    _stockLabels[gn] = infoRow(gn, "---", _curRight)
end

sectionHeader("Inventory", _curRight)
local _infoGearInv    = infoRow("Gear Count", "0", _curRight)
local _infoGearBought = infoRow("Bought Session", "0", _curRight)

actionButton("Refresh Stock", C.card, _curRight, function()
    task.spawn(function() refreshCache() end)
end)

-- ============================================================
-- TAB 5: UTILITY
-- ============================================================
setPanel(leftContainers[5], rightContainers[5])

sectionHeader("Game", _curLeft)
toggleRow("Auto Rebirth", "AutoRebirth", _curLeft)
toggleRow("Auto Lucky Block", "AutoLucky", _curLeft)
toggleRow("Auto Sell", "AutoSell", _curLeft)

sectionHeader("Player", _curLeft)
toggleRow("Speed Boost", "SpeedBoost", _curLeft)
toggleRow("Anti-AFK", "AntiAFK", _curLeft)

sectionHeader("Manual", _curLeft)
actionButton("Claim Like Reward", C.card, _curLeft, function()
    pcall(function() Remotes.ClaimLikeReward:InvokeServer() end)
end)
actionButton("Claim Index Reward", C.card, _curLeft, function()
    pcall(function() Remotes.ClaimIndexReward:InvokeServer() end)
end)
actionButton("Sell Bulk Now", C.card, _curLeft, function()
    task.spawn(function() sellBulkHeroes() end)
end)

-- Right: Player Stats
sectionHeader("Player Stats", _curRight)
local _infoUtilCash     = infoRow("Cash", "---", _curRight)
local _infoUtilRebirths = infoRow("Rebirths", "0", _curRight)
local _infoUtilLucky    = infoRow("Lucky Used", "0", _curRight)
local _infoUtilRebirthS = infoRow("Rebirths (s)", "0", _curRight)
local _infoUtilSells    = infoRow("Sells (s)", "0", _curRight)

-- ============================================================
-- TAB 6: CONFIG
-- ============================================================
setPanel(leftContainers[6], rightContainers[6])

sectionHeader("Config Management", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)
actionButton("Save Config", C.green, _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function() loadSavedCFG() end)
actionButton("Reset All", C.red, _curLeft, function()
    for k, v in CFG do
        if type(v) == "boolean" then CFG[k] = false end
    end
    SelGears = {Crown = true, ["War Horn"] = true, ["War Drum"] = true}
    CFG.TargetTrait  = "Any"
    saveCFG()
end)

sectionHeader("Info", _curLeft)
infoRow("File", _cfgFileName, _curLeft)
infoRow("Version", "v4.0", _curLeft)

-- Right: Active Features
sectionHeader("Config Info", _curRight)
infoRow("Save File", _cfgFileName, _curRight)

sectionHeader("Active Features", _curRight)
local _cfgActiveList = lbl(rightContainers[6], {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 120),
    Text = "None", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    LayoutOrder = nextOrder(rightContainers[6]),
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
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Tab 1: Farm
            _infoIncome.Text   = fmt(S.income)
            _infoDPS.Text      = fmt(S.dps)
            _infoCash.Text     = fmt(_cash)
            _infoRebirths.Text = tostring(_rebirths)
            _infoCollects.Text = tostring(S.collects)
            _infoSells.Text    = tostring(S.sells)
            _infoRuntime.Text  = rtime

            -- Tab 2: Heroes
            _infoHeroCount.Text   = tostring(S.heroCount)
            _infoHeroFuses.Text   = tostring(S.fuses)
            _infoHeroBought.Text  = tostring(S.heroes)
            _infoFuseStatus.Text  = CFG.AutoFuseHeroes and "Active" or "Idle"
            _infoTraitTarget.Text = CFG.TargetTrait
            _infoTraitRerolls.Text = _cachedData and tostring(_cachedData.TraitRerolls or 0) or "0"

            -- Tab 3: Brainrots
            _infoBrainrotCount.Text  = tostring(S.brainrotCount)
            _infoBrainrotKills.Text  = tostring(S.brainrotKills)
            _infoBrainrotIncome.Text = fmt(S.income)

            -- Tab 4: Shop (from cache)
            if _cachedStock then
                for gn, label in _stockLabels do
                    label.Text = tostring(_cachedStock[gn] or 0)
                end
            end
            _infoGearInv.Text    = tostring(S.gearInventory)
            _infoGearBought.Text = tostring(S.gears)

            -- Tab 5: Utility
            _infoUtilCash.Text     = fmt(_cash)
            _infoUtilRebirths.Text = tostring(_rebirths)
            _infoUtilLucky.Text    = tostring(S.lucky)
            _infoUtilRebirthS.Text = tostring(S.rebirths)
            _infoUtilSells.Text    = tostring(S.sells)

            -- Tab 6: Config active features
            local active = {}
            for k, v in CFG do
                if type(v) == "boolean" and v and k ~= "AutoSave" then
                    table.insert(active, k)
                end
            end
            _cfgActiveList.Text = #active > 0 and table.concat(active, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #active * 14 + 10))
        end)
    end
end)

-- Init first tab
switchTab(1)

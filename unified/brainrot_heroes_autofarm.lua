--// Aurora v5 — Brainrot Heroes Auto-Farm
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 75251063577391
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local Player = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraPill"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_BH_CFG then
    for k, v in pairs(getgenv().__AURORA_BH_CFG) do
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
local function _promptAlive(p)
    local ok, r = pcall(function() return p and p.Parent and p.Enabled end)
    return ok and r
end
-- Cross-executor prompt firing: fireproximityprompt on Wave/Potassium/Delta,
-- VIM E-key hold as fallback for Xeno and others that lack the helper.
local function safeFirePrompt(prompt)
    if not _promptAlive(prompt) then return end
    local holdTime = prompt.HoldDuration or 0
    pcall(function() if _HAS.firepp then fireproximityprompt(prompt) end end)
    task.wait(0.6)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(math.max(0.3, holdTime + 0.2))
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

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
    -- v5 UI state
    ActiveTab       = "Farm",
    PanelOpen       = true,
}

local _cfgFileName = "aurora_cfg_brainrot_heroes.json"

---------- RARITY DATA & FILTER TABLES (MUST be before loadSavedCFG) ----------
local RARITY_ORDER = {"Rare","Epic","Legendary","Mythic","Godly","Secret","Celestial","Divine","Limited"}
local RARITY_DISPLAY = {Rare="Rare",Epic="Epic",Legendary="Legendary",Mythic="Mythic",Godly="Godly",Secret="Secret",Celestial="Celestial",Divine="Divine",Limited="Limited (Event)"}

local SELL_FILTER      = {Rare=true, Epic=true, Legendary=false, Mythic=false, Godly=false, Secret=false, Celestial=false, Divine=false, Limited=false}
local HERO_BUY         = {Rare=true, Epic=true, Legendary=true,  Mythic=true,  Godly=true,  Secret=false, Celestial=false, Divine=false, Limited=false}
local FUSE_FILTER      = {Rare=true, Epic=true, Legendary=true,  Mythic=false, Godly=false, Secret=false, Celestial=false, Divine=false, Limited=false}
local HERO_FAV_FILTER  = {Rare=false,Epic=false,Legendary=true,  Mythic=true,  Godly=true,  Secret=true,  Celestial=true,  Divine=true,  Limited=true}

local GEAR_NAMES = {
    "Crown","Freeze Bomb","War Horn","War Drum","Boxing Glove","Size Potion","Radioactive Waste","Nuke Button",
    "Barbed Bat","Bat","Darkhammer","Death Axe","Emerald Sword","Fire Mace","Greatsword","Hammer",
    "Ice Hammer","Metal Bat","Moonblade","Mystic Hammer","Overseer Axe","Shadow Blade","Skull Axe",
    "Spike Mace","Spiked Bat","Celestial Lucky Block","Godly Lucky Block","Mythic Lucky Block","Secret Lucky Block",
}
local SelGears = {}
for _, g in ipairs(GEAR_NAMES) do SelGears[g] = true end

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
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(saveData)) end end)
    getgenv()["AuroraCFG_brainrot_heroes"] = saveData
end

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_brainrot_heroes"] end
    if saved and type(saved) == "table" then
        local src = saved.CFG or saved
        for k, v in pairs(src) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._SelGears then for k in pairs(SelGears) do SelGears[k] = nil end; for k, v in pairs(saved._SelGears) do SelGears[k] = v end end
        if saved._SellFilter and saved._SellFilter.Rare ~= nil then
            for k, v in pairs(saved._SellFilter) do if SELL_FILTER[k] ~= nil then SELL_FILTER[k] = v end end
        end
        if saved._HeroBuy and saved._HeroBuy.Rare ~= nil then
            for k, v in pairs(saved._HeroBuy) do if HERO_BUY[k] ~= nil then HERO_BUY[k] = v end end
        end
        if saved._FuseFilter and saved._FuseFilter.Rare ~= nil then
            for k, v in pairs(saved._FuseFilter) do if FUSE_FILTER[k] ~= nil then FUSE_FILTER[k] = v end end
        end
        if saved._HeroFavFilter and saved._HeroFavFilter.Rare ~= nil then
            for k, v in pairs(saved._HeroFavFilter) do if HERO_FAV_FILTER[k] ~= nil then HERO_FAV_FILTER[k] = v end end
        end
    end
end

loadSavedCFG()

---------- HERO DATA ----------
local HERO_DATA = {}
pcall(function()
    local cfg = require(RS.Get.Config)
    if cfg and cfg.Hero then
        for k, v in pairs(cfg.Hero) do
            if typeof(v) == "table" and v.Cost then
                HERO_DATA[k] = {Name = v.Name or k, Cost = v.Cost, Rarity = v.Rarity or "Rare", Damage = v.Damage}
            end
        end
    end
end)

---------- STATE ----------
local _cash, _rebirths = 0, 0
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
local _cachedData  = nil
local _cachedStock = nil

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
    -- Single call replaces 19-slot loop; faster + fewer remote fires (AC-friendly).
    pcall(function() Remotes.CollectAllBrainrotIncome:InvokeServer() end)
    S.collects += 1
end

local function sellBulkHeroes()
    local filter = {}
    for r, on in pairs(SELL_FILTER) do if on then filter[r] = true end end
    if not next(filter) then return end
    local ok = pcall(function() Remotes.SellBulk:InvokeServer("Hero", filter) end)
    if ok then S.sells += 1 end
end

local function doRebirth()
    local ok, r = pcall(function() return Remotes.AttemptRebirth:InvokeServer() end)
    if ok and r then S.rebirths += 1; _rebirths += 1 end
end

-- EquipBestHeroes was renamed to EquipHeroLoadout in a game update.
-- Calling with no arg equips the "best" loadout server-side.
local function equipBestHeroes()
    pcall(function() Remotes.EquipHeroLoadout:InvokeServer() end)
end

local function equipBestBrainrots()
    pcall(function() Remotes.EquipBestBrainrots:InvokeServer() end)
end

local function fuseHeroes()
    local data = _cachedData
    if not data or not data.Heroes then return 0 end
    local groups = {}
    for _, hero in ipairs(data.Heroes) do
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
    for _, g in pairs(groups) do
        if g.rank >= 4 then continue end
        local needed = g.rank + 1
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

local function buyGear(gearName)
    local ok, r = pcall(function() return Remotes.PurchaseShopGear:InvokeServer(gearName) end)
    if ok and r then S.gears += 1; return true end
    return false
end

local function useGearFromInventory(gearName)
    local data = _cachedData
    if not data or not data.Gears then return false end
    for _, g in ipairs(data.Gears) do
        if typeof(g) == "table" and g.GearId == gearName and g.UniqueId then
            local ok2, r = pcall(function() return Remotes.UseShopGear:InvokeServer(g.UniqueId) end)
            if ok2 and r then return true end
        end
    end
    return false
end

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

refreshCache()

---------- TRAIT DATA ----------
local EASTER_TRAITS = {
    ["Easter I"]=true, ["Easter II"]=true, ["Easter III"]=true,
    ["Easter IV"]=true, ["Easter V"]=true, ["Bunny Boss"]=true,
}
local ALL_TRAITS = {
    "Any",
    "Brute I", "Brute II", "Brute III",
    "Charm I", "Charm II", "Charm III",
    "Fortune I", "Fortune II", "Fortune III",
    "Swift I", "Swift II", "Swift III",
    "Apex", "Beacon", "Blitz", "Cute", "Hourglass", "Overkill", "Radiant", "Zenith",
    "Reaper", "Zombie", "Zeus",
    "Easter I", "Easter II", "Easter III", "Easter IV", "Easter V", "Bunny Boss",
}

---------- GAME LOOPS ----------
local function G() return CFG end

-- Auto-dismiss ALL purchase prompts (Robux, DevProduct, GamePass)
pcall(function()
    local MPS = game:GetService("MarketplaceService")
    local _VIM = game:GetService("VirtualInputManager")
    local function dismissPrompt()
        task.wait(0.15)
        pcall(function() _VIM:SendKeyEvent(true, Enum.KeyCode.Escape, false, game) end)
        task.wait(0.05)
        pcall(function() _VIM:SendKeyEvent(false, Enum.KeyCode.Escape, false, game) end)
    end
    MPS.PromptPurchaseRequested:Connect(dismissPrompt)
    MPS.PromptProductPurchaseRequested:Connect(dismissPrompt)
    MPS.PromptGamePassPurchaseRequested:Connect(dismissPrompt)
end)

-- Auto Buy Circle Heroes: scan first, TP per hero, cross-executor safeFirePrompt
-- v5.1 AC-evasion: slower outer scan (2.5s), per-prompt cooldown (3.5s),
-- per-prompt delay (0.8s), max 5 buys per cycle.
local _lastBuyTime = {}
task.spawn(function()
    while alive() do
        task.wait(jitter(2.5, 1.0))
        if not alive() then break end
        if not G().AutoBuyCircle then continue end
        pcall(function()
            local heroCenter = workspace:FindFirstChild("HeroCenter")
            if not heroCenter then return end
            local targets = {}
            for _, d in ipairs(heroCenter:GetDescendants()) do
                if not d:IsA("ProximityPrompt") then continue end
                if d.ActionText ~= "Purchase" or not d.Enabled then continue end
                local objText = d.ObjectText or ""
                if objText:find("R%$") or objText:lower():find("robux") then continue end
                local heroName = d.Parent and d.Parent.Parent and d.Parent.Parent.Name
                if not heroName then continue end
                if _lastBuyTime[heroName] and (tick() - _lastBuyTime[heroName]) < 3.5 then continue end
                local h = HERO_DATA[heroName]
                if not h then continue end
                if not HERO_BUY[h.Rarity] then continue end
                if h and h.Cost and _cash < h.Cost then continue end
                table.insert(targets, {prompt = d, name = heroName})
                if #targets >= 5 then break end  -- cap per-cycle buys
            end
            if #targets == 0 then return end
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            for _, t in ipairs(targets) do
                if not G().AutoBuyCircle or not alive() then return end
                if not t.prompt or not t.prompt.Parent then continue end
                local promptPart = t.prompt.Parent
                if promptPart and promptPart:IsA("BasePart") then
                    hrp.CFrame = promptPart.CFrame + Vector3.new(0, 0, 3)
                elseif promptPart and promptPart.Parent and promptPart.Parent:IsA("Model") then
                    local pp = promptPart.Parent.PrimaryPart or promptPart.Parent:FindFirstChildWhichIsA("BasePart")
                    if pp then hrp.CFrame = pp.CFrame + Vector3.new(0, 0, 3) end
                else
                    hrp.CFrame = CFrame.new(-0.2, 3.3, -0.5)
                end
                task.wait(jitter(0.5, 0.2))
                safeFirePrompt(t.prompt)
                _lastBuyTime[t.name] = tick()
                S.heroes += 1
                task.wait(jitter(0.8, 0.4))
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
                for gearName, count in pairs(stock) do
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
            for _, gearName in ipairs(GEAR_NAMES) do
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
-- Uses RollTrait return value (new trait string) for instant target detection —
-- no reliance on 5s _cachedData refresh. Stops immediately when target hit.
-- Reads Currency.TraitRerolls (live counter) instead of data.TraitRerolls (lifetime).
task.spawn(function()
    while alive() do
        task.wait(jitter(2, 0.5))
        if not alive() then break end
        if not G().AutoRerollTrait then continue end
        pcall(function()
            local data = _cachedData
            if not data or not data.Heroes then return end
            local target = CFG.TargetTrait
            local isEaster = EASTER_TRAITS[target] == true
            for _, hero in ipairs(data.Heroes) do
                if not G().AutoRerollTrait or not alive() then return end
                if not hero.Favorited then continue end
                local currentTrait = hero.Trait or "none"
                -- Skip if target already matched (source-of-truth = fresh GetPlayerData before loop)
                if target ~= "Any" and currentTrait == target then continue end
                if target == "Any" and currentTrait ~= "none" then continue end
                -- Roll until target hit OR rerolls exhausted OR toggle off
                while G().AutoRerollTrait and alive() do
                    -- Live check of reroll currency (server-truth, no cache)
                    local liveRerolls
                    if isEaster then
                        -- Easter uses a different pool if it exists, fallback to TraitRerolls
                        local d = _cachedData
                        liveRerolls = d and ((d.Currency and d.Currency.EasterTraitRerolls) or d.EasterTraitRerolls or 0)
                    else
                        local d = _cachedData
                        liveRerolls = d and d.Currency and d.Currency.TraitRerolls or 0
                    end
                    if liveRerolls <= 0 then return end
                    -- Fire roll + capture new trait from return value
                    local remote = isEaster and Remotes.RollEasterTrait or Remotes.RollTrait
                    local ok, newTrait = pcall(function() return remote:InvokeServer(hero.UniqueId) end)
                    if not ok then break end
                    -- Decrement live counter locally so we don't over-roll vs cache
                    pcall(function()
                        if isEaster then
                            if _cachedData and _cachedData.Currency and _cachedData.Currency.EasterTraitRerolls then
                                _cachedData.Currency.EasterTraitRerolls -= 1
                            end
                        else
                            if _cachedData and _cachedData.Currency and _cachedData.Currency.TraitRerolls then
                                _cachedData.Currency.TraitRerolls -= 1
                            end
                        end
                    end)
                    -- Update hero trait locally from return value
                    if type(newTrait) == "string" then
                        hero.Trait = newTrait
                        -- Match check (string equality, target is exact)
                        if target == "Any" and newTrait ~= "none" then break end
                        if target ~= "Any" and newTrait == target then break end
                    elseif typeof(newTrait) == "table" and newTrait.Trait then
                        hero.Trait = newTrait.Trait
                        if target == "Any" and newTrait.Trait ~= "none" then break end
                        if target ~= "Any" and newTrait.Trait == target then break end
                    else
                        -- Unknown response — break so we don't hammer the remote
                        break
                    end
                    task.wait(0.35)
                end
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

-- Single cache refresh loop
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

-- Auto Rebirth
task.spawn(function()
    while alive() do
        task.wait(jitter(30, 10))
        if not alive() then break end
        if not G().AutoRebirth then continue end
        pcall(function() doRebirth() end)
    end
end)

-- Auto Lucky Block — opens all unused lucky blocks from inventory
-- Feature was wired to toggle but had no loop (bug); adding it now.
task.spawn(function()
    while alive() do
        task.wait(jitter(12, 3))
        if not alive() then break end
        if not G().AutoLucky then continue end
        pcall(function()
            local data = _cachedData
            if not data or not data.Gears then return end
            local used = 0
            for _, g in ipairs(data.Gears) do
                if not G().AutoLucky or not alive() then return end
                if typeof(g) ~= "table" or not g.UniqueId or not g.GearId then continue end
                if not g.GearId:lower():find("lucky") then continue end
                pcall(function() Remotes.UseLuckyBlock:InvokeServer(g.UniqueId) end)
                S.lucky += 1
                used += 1
                if used >= 10 then break end  -- cap per cycle for AC-friendliness
                task.wait(jitter(0.6, 0.3))
            end
        end)
    end
end)

-- Auto Claim Rewards (like reward, index rewards — runs every 60s)
task.spawn(function()
    while alive() do
        task.wait(jitter(60, 10))
        if not alive() then break end
        pcall(function() Remotes.ClaimLikeReward:InvokeServer() end)
        pcall(function() Remotes.ClaimIndexReward:InvokeServer() end)
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
-- SCREENGUI + PARENT (Xeno-safe: each parent in own pcall)
--========================================================================
local screenGui = create("ScreenGui", {
    Name = "Aurora", DisplayOrder = 9999, ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
local _pOk = false
if typeof(gethui) == "function" then _pOk = pcall(function() screenGui.Parent = gethui() end) end
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

-- Centered brand watermark — shown on every tab, all panel bgs are transparent so it bleeds through
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
-- SIDEBAR (with inner glows)
--========================================================================
-- Sidebar is transparent — main's rounded bg + stroke shows through at corners.
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
    { name = "Farm",      icon = "●" },
    { name = "Heroes",    icon = "◆" },
    { name = "Brainrots", icon = "◉" },
    { name = "Shop",      icon = "≡" },
    { name = "Utility",   icon = "□" },
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

-- Forward-declare dropdown popup helpers (defined later, used by switchTab / drag / minimize)
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
local panels = {}  -- panels[tabName] = { alpha = {frame, scroll}, beta = {frame, scroll} }
local liveScroll  -- persistent Live Game scroll, set below

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
local TAB_NAMES = { "Farm", "Heroes", "Brainrots", "Shop", "Utility", "Settings" }
local TAB_ACCENT = {
    Farm = C.pink, Heroes = C.purple, Brainrots = C.pink,
    Shop = C.pink, Utility = C.pink,  Settings = C.pink,
}
local PANEL_TITLES = {
    Farm      = { alpha = "FARM",       beta = "STATS"    },
    Heroes    = { alpha = "HEROES",     beta = "RARITIES" },
    Brainrots = { alpha = "BRAINROTS",  beta = "NOTES"    },
    Shop      = { alpha = "GEAR SHOP",  beta = "LUCKY"    },
    Utility   = { alpha = "UTILITY",    beta = "MANUAL"   },
    Settings  = { alpha = "CONFIG",     beta = "ABOUT"    },
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

-- =========================================================================
-- DROPDOWN (single or multi select) — proper popup, not cycle
-- _openPopup, _skipNextOutside, closeOpenPopup are forward-declared above
-- =========================================================================
closeOpenPopup = function()
    if _openPopup and _openPopup.frame then
        _openPopup.frame.Visible = false
        if _openPopup.onClose then _openPopup.onClose() end
    end
    _openPopup = nil
end

-- dropdownRow(parent, label, cfgKey, options, order, multi?)
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

    -- Popup lives at screenGui root so it escapes panel/scroll clipping
    local POPUP_W  = 160
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

-- =========================================================================
-- RARITY FILTER (checkbox grid for SELL_FILTER / HERO_BUY / FUSE_FILTER / HERO_FAV_FILTER)
-- =========================================================================
local function rarityFilterRow(parent, rarity, filterTable, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    local check = create("Frame", {
        Size = UDim2.fromOffset(14, 14), Position = UDim2.new(0, 0, 0.5, -7),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(check, 3); stroke(check, C.border2, 1, 0)
    local fill = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.pink,
        BorderSizePixel = 0, Visible = filterTable[rarity] == true,
    }, check)
    corner(fill, 2)
    create("TextLabel", {
        Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(22, 0),
        BackgroundTransparency = 1, Text = RARITY_DISPLAY[rarity] or rarity,
        Font = F_SANS_SEMI, TextSize = 11, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            filterTable[rarity] = not filterTable[rarity]
            fill.Visible = filterTable[rarity] == true
            if CFG.AutoSave then saveCFG() end
        end
    end)
    return row
end

-- Gear checkbox row (for SelGears multi-select)
local function gearCheckRow(parent, gearName, order)
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    local check = create("Frame", {
        Size = UDim2.fromOffset(12, 12), Position = UDim2.new(0, 0, 0.5, -6),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0,
    }, row)
    corner(check, 2); stroke(check, C.border2, 1, 0)
    local fill = create("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.pink,
        BorderSizePixel = 0, Visible = SelGears[gearName] == true,
    }, check)
    corner(fill, 2)
    create("TextLabel", {
        Size = UDim2.new(1, -22, 1, 0), Position = UDim2.fromOffset(20, 0),
        BackgroundTransparency = 1, Text = gearName,
        Font = F_SANS_SEMI, TextSize = 10, TextColor3 = C.text2,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }, row)
    row.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            SelGears[gearName] = not SelGears[gearName]
            fill.Visible = SelGears[gearName] == true
            if CFG.AutoSave then saveCFG() end
        end
    end)
    return row
end

--========================================================================
-- POPULATE: FARM
--========================================================================
local oFarm_a, oFarm_b = 0, 0
local function nFa() oFarm_a = oFarm_a + 1; return oFarm_a end
local function nFb() oFarm_b = oFarm_b + 1; return oFarm_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Farm", nFa())
toggleRow(scrolls["Farm_alpha"], "Auto Collect Income", "AutoCollect", nFa())
toggleRow(scrolls["Farm_alpha"], "Auto Sell Heroes",    "AutoSell",    nFa())
toggleRow(scrolls["Farm_alpha"], "Auto Rebirth",        "AutoRebirth", nFa())

sectionHeader(scrolls["Farm_alpha"], "◉", "Sell Filter", nFa())
for _, rarity in ipairs(RARITY_ORDER) do
    rarityFilterRow(scrolls["Farm_alpha"], rarity, SELL_FILTER, nFa())
end

sectionHeader(scrolls["Farm_beta"], "●", "Stats", nFb())
local _infoCash     = infoRow(scrolls["Farm_beta"], "Cash",             "---", C.text,  nFb())
local _infoRebirths = infoRow(scrolls["Farm_beta"], "Rebirths",         "0",   C.text2, nFb())
local _infoIncome   = infoRow(scrolls["Farm_beta"], "Income/sec",       "---", C.text,  nFb())
local _infoDPS      = infoRow(scrolls["Farm_beta"], "DPS",              "---", C.text2, nFb())
local _infoHeroCount= infoRow(scrolls["Farm_beta"], "Heroes Owned",     "0",   C.text2, nFb())
local _infoBRCount  = infoRow(scrolls["Farm_beta"], "Brainrots Owned",  "0",   C.text2, nFb())
local _infoBRKills  = infoRow(scrolls["Farm_beta"], "Brainrot Kills",   "0",   C.text2, nFb())
local _infoSessSells= infoRow(scrolls["Farm_beta"], "Sells (session)",  "0",   C.pink,  nFb())
local _infoSessColl = infoRow(scrolls["Farm_beta"], "Collects (session)","0",  C.pink,  nFb())

sectionHeader(scrolls["Farm_beta"], "▣", "Manual", nFb())
actionBtn(scrolls["Farm_beta"], "Force Collect", C.bg3, nFb(), function() collectIncome() end)
actionBtn(scrolls["Farm_beta"], "Force Sell",    C.bg3, nFb(), function() sellBulkHeroes() end)

--========================================================================
-- POPULATE: HEROES
--========================================================================
local oHer_a, oHer_b = 0, 0
local function nHa() oHer_a = oHer_a + 1; return oHer_a end
local function nHb() oHer_b = oHer_b + 1; return oHer_b end

sectionHeader(scrolls["Heroes_alpha"], "●", "Auto", nHa())
toggleRow(scrolls["Heroes_alpha"], "Auto Buy Circle",   "AutoBuyCircle",   nHa())
toggleRow(scrolls["Heroes_alpha"], "Auto Fuse",         "AutoFuseHeroes",  nHa())
toggleRow(scrolls["Heroes_alpha"], "Auto Equip Best",   "AutoEquipHeroes", nHa())
toggleRow(scrolls["Heroes_alpha"], "Auto Reroll Trait", "AutoRerollTrait", nHa())

sectionHeader(scrolls["Heroes_alpha"], "◉", "Reroll Target", nHa())
dropdownRow(scrolls["Heroes_alpha"], "Target Trait", "TargetTrait", ALL_TRAITS, nHa(), false)

sectionHeader(scrolls["Heroes_alpha"], "▣", "Manual", nHa())
actionBtn(scrolls["Heroes_alpha"], "Equip Best Now", C.bg3, nHa(), function() equipBestHeroes() end)
actionBtn(scrolls["Heroes_alpha"], "Fuse Heroes Now", C.bg3, nHa(), function() task.spawn(fuseHeroes) end)

sectionHeader(scrolls["Heroes_beta"], "●", "Rarity — Buy", nHb())
for _, rarity in ipairs(RARITY_ORDER) do
    rarityFilterRow(scrolls["Heroes_beta"], rarity, HERO_BUY, nHb())
end

sectionHeader(scrolls["Heroes_beta"], "◆", "Rarity — Fuse", nHb())
for _, rarity in ipairs(RARITY_ORDER) do
    rarityFilterRow(scrolls["Heroes_beta"], rarity, FUSE_FILTER, nHb())
end

sectionHeader(scrolls["Heroes_beta"], "✦", "Rarity — Favorite", nHb())
for _, rarity in ipairs(RARITY_ORDER) do
    rarityFilterRow(scrolls["Heroes_beta"], rarity, HERO_FAV_FILTER, nHb())
end

--========================================================================
-- POPULATE: BRAINROTS
--========================================================================
local oBr_a, oBr_b = 0, 0
local function nBa() oBr_a = oBr_a + 1; return oBr_a end
local function nBb() oBr_b = oBr_b + 1; return oBr_b end

sectionHeader(scrolls["Brainrots_alpha"], "●", "Auto", nBa())
toggleRow(scrolls["Brainrots_alpha"], "Auto Equip Best", "AutoEquipBrainrots", nBa())

sectionHeader(scrolls["Brainrots_alpha"], "▣", "Manual", nBa())
actionBtn(scrolls["Brainrots_alpha"], "Equip Best Now", C.bg3, nBa(), function() equipBestBrainrots() end)
actionBtn(scrolls["Brainrots_alpha"], "Collect All Now", C.bg3, nBa(), function() collectIncome() end)

sectionHeader(scrolls["Brainrots_beta"], "✦", "Notes", nBb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 140), BackgroundTransparency = 1,
    Text = "Brainrots generate passive income.\n\nAuto Equip Best cycles every ~15s and\nselects the strongest brainrots by rank.\n\nIncome collection runs from the Farm\ntab via Auto Collect Income.\n\nBrainrots kill mobs for bonus drops —\nkill count tracked in Farm > Stats.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nBb(),
}, scrolls["Brainrots_beta"])

--========================================================================
-- POPULATE: SHOP
--========================================================================
local oSh_a, oSh_b = 0, 0
local function nSa() oSh_a = oSh_a + 1; return oSh_a end
local function nSb() oSh_b = oSh_b + 1; return oSh_b end

sectionHeader(scrolls["Shop_alpha"], "●", "Gear Purchase", nSa())
toggleRow(scrolls["Shop_alpha"], "Auto Buy Gear", "AutoBuyGear", nSa())
toggleRow(scrolls["Shop_alpha"], "Auto Use Gear", "AutoUseGear", nSa())

sectionHeader(scrolls["Shop_alpha"], "≡", "Select Gears", nSa())
for _, gn in ipairs(GEAR_NAMES) do
    gearCheckRow(scrolls["Shop_alpha"], gn, nSa())
end

sectionHeader(scrolls["Shop_beta"], "●", "Lucky", nSb())
toggleRow(scrolls["Shop_beta"], "Auto Lucky Block", "AutoLucky", nSb())

sectionHeader(scrolls["Shop_beta"], "◉", "Shop Info", nSb())
local _infoGearInv    = infoRow(scrolls["Shop_beta"], "Gear Inventory", "0", C.text2, nSb())
local _infoGearBought = infoRow(scrolls["Shop_beta"], "Bought (session)", "0", C.pink, nSb())
local _infoLuckyUsed  = infoRow(scrolls["Shop_beta"], "Lucky Used",    "0",   C.text2, nSb())

sectionHeader(scrolls["Shop_beta"], "▣", "Manual", nSb())
actionBtn(scrolls["Shop_beta"], "Refresh Stock",    C.bg3, nSb(), function() refreshCache() end)
actionBtn(scrolls["Shop_beta"], "Instant Restock",  C.bg3, nSb(), function()
    pcall(function() Remotes.InstantRestock:InvokeServer() end)
end)

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "●", "Movement", nUa())
toggleRow(scrolls["Utility_alpha"], "Speed Boost", "SpeedBoost", nUa())
toggleRow(scrolls["Utility_alpha"], "Anti AFK",    "AntiAFK",    nUa())

sectionHeader(scrolls["Utility_beta"], "▣", "Manual", nUb())
actionBtn(scrolls["Utility_beta"], "Claim Like Reward",  C.bg3, nUb(), function()
    pcall(function() Remotes.ClaimLikeReward:InvokeServer() end)
end)
actionBtn(scrolls["Utility_beta"], "Claim Index Reward", C.bg3, nUb(), function()
    pcall(function() Remotes.ClaimIndexReward:InvokeServer() end)
end)
actionBtn(scrolls["Utility_beta"], "Instant Restock",    C.bg3, nUb(), function()
    pcall(function() Remotes.InstantRestock:InvokeServer() end)
end)

sectionHeader(scrolls["Utility_beta"], "✦", "Notes", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Speed Boost: WalkSpeed 80 (Heartbeat).\nAnti AFK: 60s jittered VirtualUser click.\nLike/Index rewards refresh on cooldown.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

--========================================================================
-- POPULATE: SETTINGS (pinned, handles Config + About)
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
    CFG.TargetTrait = "Any"
    CFG.AutoSave = true
    saveCFG()
end)

sectionHeader(scrolls["Settings_alpha"], "◉", "UI", nSeta())
actionBtn(scrolls["Settings_alpha"], "Reset Position", C.bg3, nSeta(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn(scrolls["Settings_alpha"], "Destroy UI", C.red, nSeta(), function()
    task.wait(0.3)
    getgenv().__AURORA_BH_SESSION = 0
    pcall(function() screenGui:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSetb())
infoRow(scrolls["Settings_beta"], "Game",    "Brainrot Heroes", C.text,  nSetb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId), C.text2, nSetb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion), C.text2, nSetb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net", C.pink,  nSetb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",              C.text2, nSetb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,      C.text3, nSetb())

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
local _infoRuntime = infoRow(liveScroll, "Runtime", "0m", C.text2, nL())

sectionHeader(liveScroll, "●", "Money", nL())
local _liveCash     = infoRow(liveScroll, "Cash",       "---", C.pink,  nL())
local _liveRebirths = infoRow(liveScroll, "Rebirths",   "0",   C.text,  nL())
local _liveIncome   = infoRow(liveScroll, "Income/sec", "---", C.text2, nL())
local _liveDPS      = infoRow(liveScroll, "DPS",        "---", C.text2, nL())

sectionHeader(liveScroll, "⚔", "Units", nL())
local _liveHeroes   = infoRow(liveScroll, "Heroes",    "0", C.text2, nL())
local _liveBR       = infoRow(liveScroll, "Brainrots", "0", C.text2, nL())
local _liveKills    = infoRow(liveScroll, "Kills",     "0", C.text2, nL())

sectionHeader(liveScroll, "✦", "Session Totals", nL())
local _liveColl     = infoRow(liveScroll, "Collects", "0", C.pink,  nL())
local _liveSells    = infoRow(liveScroll, "Sells",    "0", C.pink,  nL())
local _liveBought   = infoRow(liveScroll, "Heroes Bought", "0", C.pink, nL())
local _liveFuses    = infoRow(liveScroll, "Fuses",    "0", C.pink,  nL())
local _liveGears    = infoRow(liveScroll, "Gears Used", "0", C.pink, nL())
local _liveLucky    = infoRow(liveScroll, "Lucky Opened", "0", C.pink, nL())

sectionHeader(liveScroll, "◆", "Status", nL())
local _liveStatus   = infoRow(liveScroll, "Status", "Idle", C.text2, nL())

--========================================================================
-- FLOATING PILL
--========================================================================
local pillGui = create("ScreenGui", {
    Name = "AuroraPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true,
})
local _pillOk = false
if typeof(gethui) == "function" then _pillOk = pcall(function() pillGui.Parent = gethui() end) end
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

-- Breathing pulse (infinite sine loop, reverses)
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
-- Minimize — hides main; pill restores it (CFG.PanelOpen persists)
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
        getgenv().__AURORA_BH_SESSION = 0
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
            -- Session runtime
            local elapsed = tick() - S.session
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Farm tab stats
            _infoCash.Text      = fmt(_cash)
            _infoRebirths.Text  = tostring(_rebirths)
            _infoIncome.Text    = fmt(S.income)
            _infoDPS.Text       = fmt(S.dps)
            _infoHeroCount.Text = tostring(S.heroCount)
            _infoBRCount.Text   = tostring(S.brainrotCount)
            _infoBRKills.Text   = tostring(S.brainrotKills)
            _infoSessSells.Text = tostring(S.sells)
            _infoSessColl.Text  = tostring(S.collects)

            -- Shop tab stats
            _infoGearInv.Text    = tostring(S.gearInventory)
            _infoGearBought.Text = tostring(S.gears)
            _infoLuckyUsed.Text  = tostring(S.lucky)

            -- Live Game
            _infoRuntime.Text   = rtime
            _liveCash.Text      = fmt(_cash)
            _liveRebirths.Text  = tostring(_rebirths)
            _liveIncome.Text    = fmt(S.income)
            _liveDPS.Text       = fmt(S.dps)
            _liveHeroes.Text    = tostring(S.heroCount)
            _liveBR.Text        = tostring(S.brainrotCount)
            _liveKills.Text     = tostring(S.brainrotKills)
            _liveColl.Text      = tostring(S.collects)
            _liveSells.Text     = tostring(S.sells)
            _liveBought.Text    = tostring(S.heroes)
            _liveFuses.Text     = tostring(S.fuses)
            _liveGears.Text     = tostring(S.gears)
            _liveLucky.Text     = tostring(S.lucky)

            -- Status line
            local mode = "Idle"
            if CFG.AutoCollect or CFG.AutoBuyCircle or CFG.AutoFuseHeroes then mode = "Farming"
            elseif CFG.AutoSell or CFG.AutoRebirth then mode = "Cleanup"
            elseif CFG.AutoBuyGear or CFG.AutoUseGear then mode = "Shopping" end
            _liveStatus.Text = mode

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

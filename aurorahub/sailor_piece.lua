--// Aurora v5 -- Sailor Piece
--// AuroraHub Edition (Wave / Potassium)
--// PlaceId: 77747658251236
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill

--========================================================================
-- SERVICES
--========================================================================
local Players        = game:GetService("Players")
local TweenService   = game:GetService("TweenService")
local UIS            = game:GetService("UserInputService")
local RunService     = game:GetService("RunService")
local HttpService    = game:GetService("HttpService")
local Lighting       = game:GetService("Lighting")
local MarketplaceSvc = game:GetService("MarketplaceService")
local RS             = game:GetService("ReplicatedStorage")
local Player         = Players.LocalPlayer

--========================================================================
-- CLEANUP (old + new gui names)
--========================================================================
for _, n in ipairs({"Aurora", "AuroraTestUI", "IconPreview", "AuroraHubUI", "AuroraHubPill", "AuroraESP"}) do
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function()
        if typeof(gethui) == "function" then
            local o = gethui():FindFirstChild(n); if o then o:Destroy() end
        end
    end)
end

--========================================================================
-- SESSION KILL + alive()
--========================================================================
if getgenv().__AURORAHUB_SAILOR_CFG then
    for k, v in pairs(getgenv().__AURORAHUB_SAILOR_CFG) do
        if type(v) == "boolean" then getgenv().__AURORAHUB_SAILOR_CFG[k] = false end
    end
end
getgenv().__AURORAHUB_SAILOR_SESSION = tick()
local _mySession = getgenv().__AURORAHUB_SAILOR_SESSION
local function alive() return getgenv().__AURORAHUB_SAILOR_SESSION == _mySession end

--========================================================================
-- REMOTE RESOLVER
--========================================================================
local function getRemote(name)
    local sources = {}
    if RS:FindFirstChild("RemoteEvents") then table.insert(sources, RS.RemoteEvents) end
    if RS:FindFirstChild("CombatSystem") and RS.CombatSystem:FindFirstChild("Remotes") then
        table.insert(sources, RS.CombatSystem.Remotes)
    end
    if RS:FindFirstChild("AbilitySystem") and RS.AbilitySystem:FindFirstChild("Remotes") then
        table.insert(sources, RS.AbilitySystem.Remotes)
    end
    if RS:FindFirstChild("Remotes") then table.insert(sources, RS.Remotes) end
    table.insert(sources, RS)
    for _, src in ipairs(sources) do
        local r = src:FindFirstChild(name)
        if r then return r end
    end
    return nil
end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

--========================================================================
-- CONFIG (getgenv shared — survives re-execute)
--========================================================================
if not getgenv().__AURORAHUB_SAILOR_CFG then
    getgenv().__AURORAHUB_SAILOR_CFG = {
        -- Farm
        AutoFarm           = false,
        AutoQuest          = false,
        AutoAbility        = false,
        AutoCollectEggs    = false,
        UndergroundAbility  = false,
        UndergroundBossOnly = false,  -- NEW: Underground farm that targets bosses only
        UGTargets           = {},     -- multi-select: allowed mob names for Underground Farm (empty = all)
        UGBossTargets       = {},     -- multi-select: allowed boss names for Boss-only Underground (empty = all bosses)
        AutoBuyMerchant     = false,  -- NEW: buy all Coins/Gems items from MerchantNPC every 30s
        -- Combat / movement
        InfDash            = false,
        MultiJump          = false,
        Haki               = false,
        ObsHaki            = false,
        ConqHaki           = false,
        AutoAttack         = false,
        -- ESP / visuals
        PlayerESP          = false,
        MobESP             = false,
        SkeletonESP        = false,
        BoxESP             = false,
        Fullbright         = false,
        EasterEggESP       = false,
        BossSpawnESP       = false,
        ESPColorR          = 252,
        ESPColorG          = 110,
        ESPColorB          = 142,
        -- Utility
        Noclip             = false,
        SpeedBoost         = false,
        AntiAFK            = false,
        AutoStats          = false,
        StatTarget         = "Sword",
        AutoBoss           = false,
        -- Numeric
        FarmDepth          = -11,
        AbilityInterval    = 0.3,
        HitInterval        = 0.5,
        SpeedValue         = 50,
        -- Exploits
        ZeroCooldown       = false,
        AutoTraitReroll    = false,
        AutoPowerReroll    = false,
        AutoBossSpawn      = false,
        AutoArtifact       = false,
        -- Config behavior
        AutoSave           = false,
        -- UI state
        ActiveTab          = "Farm",
        PanelOpen          = true,
    }
end
local CFG = getgenv().__AURORAHUB_SAILOR_CFG

--========================================================================
-- SAVE / LOAD
--========================================================================
local _cfgFileName = "aurora_cfg_sailor_piece.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end

local function saveCFG()
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end)
end

loadSavedCFG()

--========================================================================
-- STATE
--========================================================================
local S = { session = tick(), kills = 0, status = "Idle", targetName = "None", targetHP = "", patched = 0 }

--========================================================================
-- HELPERS
--========================================================================
local BLACKLIST = {
    TrainingDummy = true,
    Thief1 = true, Thief2 = true, Thief3 = true, Thief4 = true, Thief5 = true,
    ThiefBoss = true,
}

-- Scan workspace.NPCs once at load to populate the dropdown options for
-- Underground Farm (all killable) and Underground Farm Boss Only (name has "Boss").
-- Shop/quest NPCs live in workspace.ServiceNPCs and are naturally excluded.
-- Baseline catalog — comprehensive known list across all 17 islands/dungeons.
-- Runtime scan (buildMobLists) UNIONS anything newly spawned on top of this.
local _ALL_MOBS_BASELINE = {
    "AcademyTeacher1","AcademyTeacher2","AcademyTeacher3","AcademyTeacher4","AcademyTeacher5",
    "Bunny1","Bunny2","Bunny3","Bunny4","Bunny5",
    "Curse1","Curse2","Curse3","Curse4","Curse5",
    "DesertBandit1","DesertBandit2","DesertBandit3","DesertBandit4","DesertBandit5",
    "FrostRogue1","FrostRogue2","FrostRogue3","FrostRogue4","FrostRogue5",
    "Hollow1","Hollow2","Hollow3","Hollow4","Hollow5",
    "Monkey1","Monkey2","Monkey3","Monkey4","Monkey5",
    "Ninja1","Ninja2","Ninja3","Ninja4","Ninja5",
    "Quincy1","Quincy2","Quincy3","Quincy4","Quincy5",
    "Slime1","Slime2","Slime3","Slime4","Slime5",
    "Sorcerer1","Sorcerer2","Sorcerer3","Sorcerer4","Sorcerer5",
    "StrongSorcerer1","StrongSorcerer2","StrongSorcerer3","StrongSorcerer4","StrongSorcerer5",
    "Swordsman1","Swordsman2","Swordsman3","Swordsman4","Swordsman5",
    "AizenBoss","AlucardBoss","BlessedMaidenBoss","DesertBoss","GojoBoss",
    "MonkeyBoss","PandaMiniBoss","SaberBoss","SnowBoss","StrongestinHistoryBoss_Normal",
    "StrongestofTodayBoss_Normal","StrongestShinobiBoss","SukunaBoss","YamatoBoss","YujiBoss",
}
local _BOSS_MOBS_BASELINE = {
    "AizenBoss","AlucardBoss","BlessedMaidenBoss","DesertBoss","GojoBoss",
    "MonkeyBoss","PandaMiniBoss","SaberBoss","SnowBoss","StrongestinHistoryBoss_Normal",
    "StrongestofTodayBoss_Normal","StrongestShinobiBoss","SukunaBoss","YamatoBoss","YujiBoss",
}

local function buildMobLists()
    local allSet, bossSet = {}, {}
    for _, n in ipairs(_ALL_MOBS_BASELINE)  do allSet[n]  = true end
    for _, n in ipairs(_BOSS_MOBS_BASELINE) do bossSet[n] = true end
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, mob in ipairs(npcsFolder:GetChildren()) do
            if not BLACKLIST[mob.Name] then
                local hum = mob:FindFirstChildOfClass("Humanoid")
                if hum and hum.MaxHealth > 1000 then
                    allSet[mob.Name] = true
                    if mob.Name:lower():find("boss") then bossSet[mob.Name] = true end
                end
            end
        end
    end
    local all, bosses = {}, {}
    for n in pairs(allSet)  do table.insert(all, n) end
    for n in pairs(bossSet) do table.insert(bosses, n) end
    table.sort(all); table.sort(bosses)
    return all, bosses
end

local _ALL_MOBS, _BOSS_MOBS = buildMobLists()

-- Find nearest mob. Optional filters:
--   allowSet  — dict of allowed mob names (empty/nil = allow all)
--   bossOnly  — true to only consider mobs whose name contains "boss"
local function getNearestMob(allowSet, bossOnly)
    local char = Player.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if not npcsFolder then return nil end
    local useAllow = allowSet and next(allowSet) ~= nil
    local best, bestDist = nil, math.huge
    for _, mob in ipairs(npcsFolder:GetChildren()) do
        if not BLACKLIST[mob.Name] then
            if not useAllow or allowSet[mob.Name] then
                if not bossOnly or mob.Name:lower():find("boss") then
                    local hum = mob:FindFirstChildOfClass("Humanoid")
                    local root = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Root") or mob.PrimaryPart
                    if hum and hum.Health > 0 and hum.MaxHealth > 1000 and root then
                        local dist = (hrp.Position - root.Position).Magnitude
                        if dist < bestDist then bestDist = dist; best = mob end
                    end
                end
            end
        end
    end
    return best
end

local function fmtHP(n)
    if n >= 1e9 then return string.format("%.1fB", n / 1e9)
    elseif n >= 1e6 then return string.format("%.1fM", n / 1e6)
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3)
    else return tostring(math.floor(n)) end
end

local function equipBestWeapon()
    pcall(function()
        local swordName = nil
        pcall(function()
            local rf = getRemote("GetEquipped")
            if rf and rf:IsA("RemoteFunction") then
                local data = rf:InvokeServer()
                if data and data.Sword then swordName = data.Sword end
            end
        end)
        local re = getRemote("EquipWeapon")
        if re and swordName then re:FireServer(swordName) end
        local char = Player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end
        if swordName then
            for _, t in ipairs(Player.Backpack:GetChildren()) do
                if t:IsA("Tool") and (t:GetAttribute("_ToolName") == swordName or t.Name == swordName) then
                    hum:EquipTool(t); return
                end
            end
        end
        local powerName = nil
        pcall(function()
            local rf = getRemote("GetEquipped")
            if rf and rf:IsA("RemoteFunction") then
                local data = rf:InvokeServer()
                if data and data.Power then powerName = data.Power end
            end
        end)
        for _, t in ipairs(Player.Backpack:GetChildren()) do
            if t:IsA("Tool") then
                local tn = t:GetAttribute("_ToolName") or t.Name
                if tn ~= "Combat" and tn ~= powerName then hum:EquipTool(t); return end
            end
        end
    end)
end

--========================================================================
-- ISLAND + CRYSTAL DATA
--========================================================================
local ISLANDS = {
    { name = "Starter Island",   portalId = "Starter",      pos = Vector3.new(108, 71, -234) },
    { name = "Sailor Island",    portalId = "Sailor",       pos = Vector3.new(221, 68, 797) },
    { name = "Jungle Island",    portalId = "Jungle",       pos = Vector3.new(-529, 44, 430) },
    { name = "Desert Island",    portalId = "Desert",       pos = Vector3.new(-919, 25, -462) },
    { name = "Snow Island",      portalId = "Snow",         pos = Vector3.new(-391, 64, -1195) },
    { name = "Slime Island",     portalId = "Slime",        pos = Vector3.new(-985, 41, 255) },
    { name = "Ninja Island",     portalId = "Ninja",        pos = Vector3.new(-1897, 82, -584) },
    { name = "Academy Island",   portalId = "Academy",      pos = Vector3.new(954, 48, 1317) },
    { name = "Hollow Island",    portalId = "HollowIsland", pos = Vector3.new(-483, 72, 936) },
    { name = "Boss Island",      portalId = "Boss",         pos = Vector3.new(812, 23, -1133) },
    { name = "Dungeon Island",   portalId = "Dungeon",      pos = Vector3.new(1374, 20, -907) },
    { name = "Shinjuku Island",  portalId = "Shinjuku",     pos = Vector3.new(300, 50, -2126) },
    { name = "Shibuya Station",  portalId = "Shibuya",      pos = Vector3.new(1615, 184, 230) },
    { name = "Lawless Island",   portalId = "Lawless",      pos = Vector3.new(60, 205, 1868) },
    { name = "Judgement Island", portalId = "Judgement",    pos = Vector3.new(-1235, 40, -1274) },
    { name = "Tower Island",     portalId = "Tower",        pos = Vector3.new(1369, 24, -1486) },
    { name = "Soul Dominion",    portalId = "SoulDominion", pos = Vector3.new(-1487, 1794, 1721) },
    { name = "Easter Island",    portalId = "Easter",       pos = Vector3.new(2045, 16, 2129) },
}

local CRYSTAL_POS = {
    { name = "Starter Crystal",   pos = Vector3.new(-87, -2, -239) },
    { name = "Jungle Crystal",    pos = Vector3.new(-447, -4, 369) },
    { name = "Slime Crystal",     pos = Vector3.new(-985, -2, 255) },
    { name = "Hollow Crystal",    pos = Vector3.new(-483, -2, 936) },
    { name = "Desert Crystal",    pos = Vector3.new(-919, 25, -462) },
    { name = "Snow Crystal",      pos = Vector3.new(-391, 64, -1195) },
    { name = "Sailor Crystal",    pos = Vector3.new(221, 68, 797) },
    { name = "Ninja Crystal",     pos = Vector3.new(-1897, 82, -584) },
    { name = "Academy Crystal",   pos = Vector3.new(954, 48, 1317) },
    { name = "Boss Crystal",      pos = Vector3.new(812, 23, -1133) },
    { name = "Dungeon Crystal",   pos = Vector3.new(1374, 20, -907) },
    { name = "Shinjuku Crystal",  pos = Vector3.new(300, 50, -2126) },
    { name = "Shibuya Crystal",   pos = Vector3.new(1615, 184, 230) },
    { name = "Lawless Crystal",   pos = Vector3.new(60, 205, 1868) },
    { name = "Judgement Crystal", pos = Vector3.new(-1235, 40, -1274) },
    { name = "Tower Crystal",     pos = Vector3.new(1369, 24, -1486) },
    { name = "Soul Dom Crystal",  pos = Vector3.new(-1487, 1794, 1721) },
    { name = "Easter Crystal",    pos = Vector3.new(2153, 11, 2285) },
}

local function tpToIsland(island)
    pcall(function()
        local re = getRemote("TeleportToPortal")
        if re then re:FireServer(island.portalId) end
    end)
    pcall(function()
        local re = getRemote("TeleportToIslandSpot")
        if re then re:FireServer(island.portalId) end
    end)
    task.delay(1, function()
        pcall(function()
            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            if not hrp then return end
            local dist = (hrp.Position - island.pos).Magnitude
            if dist > 200 then
                hrp.CFrame = CFrame.new(island.pos + Vector3.new(0, 15, 0))
            end
        end)
    end)
end

local function tpToCrystal(crystal)
    pcall(function()
        local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        hrp.CFrame = CFrame.new(crystal.pos + Vector3.new(0, 5, 0))
    end)
end

--========================================================================
-- GAME LOOPS (preserved from v4 — all CFG keys wired)
--========================================================================

-- Auto-equip on respawn
Player.CharacterAdded:Connect(function()
    task.wait(1)
    if CFG.AutoFarm or CFG.UndergroundAbility or CFG.UndergroundBossOnly then equipBestWeapon() end
end)

-- Keep weapon equipped
task.spawn(function()
    while alive() do
        task.wait(jitter(2, 0.6))
        if not alive() then break end
        if CFG.AutoFarm or CFG.UndergroundAbility or CFG.UndergroundBossOnly then
            pcall(function()
                local char = Player.Character
                if not char then return end
                local tool = char:FindFirstChildOfClass("Tool")
                local toolName = tool and (tool:GetAttribute("_ToolName") or tool.Name) or ""
                local isSword = false
                pcall(function()
                    local rf = getRemote("GetEquipped")
                    if rf and rf:IsA("RemoteFunction") then
                        local data = rf:InvokeServer()
                        if data and data.Sword and toolName == data.Sword then isSword = true end
                    end
                end)
                if not tool or (not isSword and toolName ~= "") then equipBestWeapon() end
            end)
        end
    end
end)

-- Auto Farm: TP to nearest mob + hit
task.spawn(function()
    while alive() do
        task.wait(CFG.HitInterval)
        if not alive() then break end
        if CFG.AutoFarm then
            pcall(function()
                local mob = getNearestMob()
                if not mob then S.status = "No Mobs"; return end
                local root = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Root") or mob.PrimaryPart
                if not root then return end
                local char = Player.Character
                if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                S.status = "Farming: " .. mob.Name
                S.targetName = mob.Name
                local mHum = mob:FindFirstChildOfClass("Humanoid")
                S.targetHP = mHum and (fmtHP(mHum.Health) .. "/" .. fmtHP(mHum.MaxHealth)) or "?"
                hrp.CFrame = CFrame.new(root.Position + Vector3.new(0, 0, 5))
                local re = getRemote("RequestHit")
                if re then re:FireServer() end
                if mHum and mHum.Health <= 0 then S.kills = S.kills + 1 end
            end)
        end
    end
end)

-- Auto Collect Eggs — safe staged TP + ProximityPrompt claim + per-session claimed-set
getgenv().__AURORAHUB_SAILOR_COLLECTED_EGGS = getgenv().__AURORAHUB_SAILOR_COLLECTED_EGGS or {}
local _collectedEggs = getgenv().__AURORAHUB_SAILOR_COLLECTED_EGGS
task.spawn(function()
    while alive() do
        task.wait(jitter(1.0, 0.3))
        if not alive() then break end
        if CFG.AutoCollectEggs then
            pcall(function()
                local eggFolder = workspace:FindFirstChild("EasterEggs")
                if not eggFolder then return end
                -- Gather claimable targets — top-level Models + subfolder Spot parts
                local targets = {}
                local function _findPrompt(obj)
                    for _, d in ipairs(obj:GetDescendants()) do
                        if d:IsA("ProximityPrompt") and d.Enabled then return d end
                    end
                end
                for _, egg in ipairs(eggFolder:GetChildren()) do
                    if egg:IsA("Model") and egg.Name:find("EasterEgg_") then
                        local prompt = _findPrompt(egg)
                        if prompt then
                            local ok, pivot = pcall(function() return egg:GetPivot() end)
                            if ok then table.insert(targets, { egg = egg, prompt = prompt, pos = pivot.Position }) end
                        end
                    end
                end
                for _, subName in ipairs({"TimedSpawnPoints","HiddenEggs","BossEggSpawnPoints","BossEgg2SpawnPoints"}) do
                    local sub = eggFolder:FindFirstChild(subName)
                    if sub then
                        for _, part in ipairs(sub:GetChildren()) do
                            if part:IsA("BasePart") then
                                local prompt = _findPrompt(part)
                                if prompt then table.insert(targets, { egg = part, prompt = prompt, pos = part.Position }) end
                            end
                        end
                    end
                end
                local function _claimed(tt)
                    if not tt.egg or not tt.egg.Parent then return true end
                    if not tt.prompt or not tt.prompt.Parent then return true end
                    if not tt.prompt.Enabled then return true end
                    return false
                end
                local function _getHRP()
                    local c = Player.Character
                    local h = c and c:FindFirstChild("HumanoidRootPart")
                    local hu = c and c:FindFirstChildOfClass("Humanoid")
                    if h and hu and hu.Health > 0 then return h end
                    return nil
                end
                for _, t in ipairs(targets) do
                    if not CFG.AutoCollectEggs or not alive() then break end
                    -- Per-egg pcall so one bad egg doesn't kill the sweep
                    pcall(function()
                        local eggId = (t.egg and t.egg.Parent and t.egg:GetAttribute("EggId")) or (t.egg and t.egg.Name) or "unknown"
                        if _collectedEggs[eggId] then return end
                        if _claimed(t) then return end
                        local hrp = _getHRP()
                        if not hrp then return end
                        local landPos = t.pos + Vector3.new(0, 5, 0)
                        hrp.CFrame = CFrame.new(landPos)
                        -- Position-hold via Stepped — beats server AC snap-back during claim window
                        local _holdConn
                        _holdConn = RunService.Stepped:Connect(function()
                            local h = _getHRP()
                            if h then pcall(function() h.CFrame = CFrame.new(landPos) end) end
                        end)
                        task.wait(0.4)
                        -- Up to 4 fire attempts while holding position
                        for attempt = 1, 4 do
                            if not CFG.AutoCollectEggs or not alive() or _claimed(t) then break end
                            pcall(function()
                                if typeof(fireproximityprompt) == "function" then fireproximityprompt(t.prompt) end
                            end)
                            pcall(function()
                                if t.prompt and t.prompt.Parent then
                                    local oh = t.prompt.HoldDuration
                                    t.prompt.HoldDuration = 0
                                    t.prompt:InputHoldBegin()
                                    task.wait(0.1)
                                    t.prompt:InputHoldEnd()
                                    if t.prompt and t.prompt.Parent then t.prompt.HoldDuration = oh end
                                end
                            end)
                            for _ = 1, 5 do
                                task.wait(0.1)
                                if _claimed(t) then break end
                            end
                            if _claimed(t) then break end
                        end
                        -- Release position-hold before moving to next egg
                        if _holdConn then pcall(function() _holdConn:Disconnect() end) end
                        if _claimed(t) then _collectedEggs[eggId] = true end
                    end)
                    task.wait(0.2)  -- gap between eggs (shorter since hold released)
                end
            end)
        end
    end
end)

-- Auto Buy Merchant — fetches MerchantNPC stock every 30s, buys all Coin/Gem items.
-- Uses GetMerchantStock (RF) + PurchaseMerchantItem (RF, returns {success, itemName, quantity, newStock}).
-- Currency filter: buys only "Gems" / "Money" / "Coins" items — skips anything else.
task.spawn(function()
    while alive() do
        task.wait(jitter(30, 8))
        if not alive() then break end
        if CFG.AutoBuyMerchant then
            pcall(function()
                local merchants = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
                merchants = merchants and merchants:FindFirstChild("MerchantRemotes")
                if not merchants then return end
                local getRF = merchants:FindFirstChild("GetMerchantStock")
                local buyRF = merchants:FindFirstChild("PurchaseMerchantItem")
                if not (getRF and buyRF) then return end

                local ok, data = pcall(function() return getRF:InvokeServer() end)
                if not ok or type(data) ~= "table" or type(data.stock) ~= "table" then return end
                for itemName, item in pairs(data.stock) do
                    if type(item) == "table" and (item.stock or 0) > 0 then
                        local cur = tostring(item.currency or "")
                        if cur == "Gems" or cur == "Money" or cur == "Coins" then
                            pcall(function() buyRF:InvokeServer(itemName) end)
                            task.wait(0.3)
                        end
                    end
                end
            end)
        end
    end
end)

-- Underground Ability Farm
local _ugCurrentMob, _ugTargetPos, _ugConn = nil, nil, nil

-- Helper: is any underground farm (normal or boss-only) enabled?
local function ugActive() return CFG.UndergroundAbility or CFG.UndergroundBossOnly end

task.spawn(function()
    while alive() do
        if ugActive() and not _ugConn then
            _ugConn = RunService.Stepped:Connect(function()
                if not ugActive() or not _ugTargetPos then return end
                pcall(function()
                    local char = Player.Character
                    if not char then return end
                    local hrp = char:FindFirstChild("HumanoidRootPart")
                    if not hrp then return end
                    for _, p in ipairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                    for _, c in ipairs(hrp:GetChildren()) do
                        if c:IsA("BodyMover") then c:Destroy() end
                    end
                    hrp.AssemblyLinearVelocity = Vector3.zero
                    hrp.AssemblyAngularVelocity = Vector3.zero
                    -- Safe TP: skip on dead/ragdoll, micro-jitter, Lerp on large delta
                    local _sHum = char:FindFirstChildOfClass("Humanoid")
                    if not _sHum or _sHum.Health <= 0 then return end
                    local _sState = _sHum:GetState()
                    if _sState == Enum.HumanoidStateType.Dead or _sState == Enum.HumanoidStateType.Ragdoll then return end
                    local _sJit = Vector3.new((math.random()-0.5)*0.4, (math.random()-0.5)*0.3, (math.random()-0.5)*0.4)
                    local _sTgt = _ugTargetPos + _sJit
                    if (hrp.Position - _sTgt).Magnitude > 5 then
                        hrp.CFrame = CFrame.new(hrp.Position:Lerp(_sTgt, 0.12))
                    else
                        hrp.CFrame = CFrame.new(_sTgt)
                    end
                end)
            end)
        elseif not ugActive() and _ugConn then
            _ugConn:Disconnect(); _ugConn = nil; _ugTargetPos = nil; _ugCurrentMob = nil
            S.status = "Idle"; S.targetName = "None"; S.targetHP = ""
        end
        task.wait(0.1)
    end
end)

-- Ability spam + mob targeting
task.spawn(function()
    while alive() do
        task.wait(CFG.HitInterval)
        if not alive() then break end
        if ugActive() then
            -- Boss-only takes precedence if both toggles are on
            local bossOnly  = CFG.UndergroundBossOnly
            local allowList = bossOnly and CFG.UGBossTargets or CFG.UGTargets
            local statusPrefix = bossOnly and "UG Boss" or "UG Farm"
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if not (not hum or hum.Health <= 0) then
                    pcall(function()
                        local mob = getNearestMob(allowList, bossOnly)
                        if not mob then _ugCurrentMob = nil; _ugTargetPos = nil; S.status = statusPrefix .. ": No Targets"; return end
                        local root = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Root") or mob.PrimaryPart
                        if not root then return end
                        _ugTargetPos = root.Position + Vector3.new(0, CFG.FarmDepth, 0)
                        _ugCurrentMob = mob
                        S.status = statusPrefix .. ": " .. mob.Name
                        S.targetName = mob.Name
                        local mHum = mob:FindFirstChildOfClass("Humanoid")
                        S.targetHP = mHum and (fmtHP(mHum.Health) .. "/" .. fmtHP(mHum.MaxHealth)) or "?"
                        local abilityRE = getRemote("RequestAbility")
                        local hitRE = getRemote("RequestHit")
                        if abilityRE then
                            for slot = 1, 4 do
                                pcall(function() abilityRE:FireServer(slot) end)
                                task.wait(CFG.AbilityInterval)
                            end
                        end
                        if hitRE then pcall(function() hitRE:FireServer() end) end
                        if mHum and mHum.Health <= 0 then S.kills = S.kills + 1; _ugCurrentMob = nil end
                    end)
                else
                    _ugCurrentMob = nil; _ugTargetPos = nil
                end
            end
        end
    end
end)

-- Auto Quest
task.spawn(function()
    while alive() do
        task.wait(jitter(15, 3))
        if not alive() then break end
        if CFG.AutoQuest then
            local char = Player.Character
            if char then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        pcall(function()
                            local serviceNPCs = workspace:FindFirstChild("ServiceNPCs")
                            if not serviceNPCs then return end
                            local bestNPC, bestRoot, bestPrompt, bestDist = nil, nil, nil, math.huge
                            for _, npc in ipairs(serviceNPCs:GetChildren()) do
                                if npc.Name:match("^QuestNPC%d+$") then
                                    local root = npc:FindFirstChild("HumanoidRootPart") or npc.PrimaryPart
                                    local prompt = nil
                                    for _, d in ipairs(npc:GetDescendants()) do
                                        if d:IsA("ProximityPrompt") then prompt = d; break end
                                    end
                                    if root and prompt then
                                        local d = (root.Position - hrp.Position).Magnitude
                                        if d < bestDist then bestDist = d; bestNPC = npc; bestRoot = root; bestPrompt = prompt end
                                    end
                                end
                            end
                            if bestNPC and bestRoot and bestPrompt then
                                local savedPos = hrp.CFrame
                                local wasAnchored = hrp.Anchored
                                if wasAnchored then hrp.Anchored = false end
                                hrp.CFrame = CFrame.new(bestRoot.Position + Vector3.new(0, 0, 2))
                                task.wait(0.3)
                                pcall(function() fireproximityprompt(bestPrompt) end)
                                task.wait(2)
                                hrp.CFrame = savedPos
                                if wasAnchored then task.wait(0.1); hrp.Anchored = true end
                            end
                        end)
                    end
                end
            end
        end
    end
end)

-- Auto Ability
task.spawn(function()
    local slot = 1
    while alive() do
        task.wait(CFG.AbilityInterval)
        if not alive() then break end
        if CFG.AutoAbility then
            pcall(function()
                local re = getRemote("RequestAbility")
                if re then re:FireServer(slot) end
                slot = (slot % 4) + 1
            end)
        end
    end
end)

-- Infinite Dash
task.spawn(function()
    while alive() do
        task.wait(0.05)
        if not alive() then break end
        if CFG.InfDash then
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local re = getRemote("DashRemote")
                if re then re:FireServer(hrp.CFrame.LookVector, 50, true) end
            end)
        end
    end
end)

-- Multi Jump
task.spawn(function()
    while alive() do
        task.wait(0.05)
        if not alive() then break end
        if CFG.MultiJump then
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                local re = getRemote("MultiJumpRemote")
                if re then re:FireServer(3, hrp.Position) end
            end)
        end
    end
end)

-- Haki loops
task.spawn(function() while alive() do task.wait(jitter(1, 0.5)); if not alive() then break end; if CFG.Haki then pcall(function() local re = getRemote("HakiRemote"); if re then re:FireServer() end end) end end end)
task.spawn(function() while alive() do task.wait(jitter(1, 0.5)); if not alive() then break end; if CFG.ObsHaki then pcall(function() local re = getRemote("ObservationHakiRemote"); if re then re:FireServer() end end) end end end)
task.spawn(function() while alive() do task.wait(jitter(1, 0.5)); if not alive() then break end; if CFG.ConqHaki then pcall(function() local re = getRemote("ConquerorHakiRemote"); if re then re:FireServer() end end) end end end)

-- Auto Attack (tool activate + VIM click)
task.spawn(function()
    while alive() do
        task.wait(0.3)
        if not alive() then break end
        if CFG.AutoAttack then
            pcall(function()
                local char = Player.Character
                if not char then return end
                local tool = char:FindFirstChildOfClass("Tool")
                if tool then tool:Activate() end
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendMouseButtonEvent(0, 0, 0, true, nil, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(0, 0, 0, false, nil, 0)
            end)
        end
    end
end)

-- Noclip
local _noclipConn = nil
task.spawn(function()
    while alive() do
        task.wait(0.1)
        if not alive() then break end
        if CFG.Noclip and not _noclipConn then
            _noclipConn = RunService.Stepped:Connect(function()
                if not CFG.Noclip then _noclipConn:Disconnect(); _noclipConn = nil; return end
                pcall(function()
                    local char = Player.Character
                    if char then for _, p in ipairs(char:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
                end)
            end)
        elseif not CFG.Noclip and _noclipConn then
            _noclipConn:Disconnect(); _noclipConn = nil
        end
    end
end)

-- Speed Boost
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

-- Anti-AFK
task.spawn(function()
    while alive() do
        task.wait(jitter(30, 9.0))
        if not alive() then break end
        if CFG.AntiAFK then
            pcall(function() local re = getRemote("AntiAFKHeartbeat"); if re then re:FireServer() end end)
            pcall(function()
                local VIM = game:GetService("VirtualInputManager")
                VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, nil)
                task.wait(0.1)
                VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, nil)
            end)
        end
    end
end)

-- Auto Stat Allocate
local STAT_OPTIONS = { "Sword", "Defense", "Melee", "Power" }
task.spawn(function()
    while alive() do
        task.wait(jitter(3, 1))
        if not alive() then break end
        if CFG.AutoStats then
            pcall(function()
                local ok, stats = pcall(function() return RS.RemoteEvents.GetPlayerStats:InvokeServer() end)
                if ok and stats and stats.StatPoints and stats.StatPoints > 0 then
                    local re = RS.Remotes:FindFirstChild("AllocateStats")
                    if re then re:FireServer(CFG.StatTarget, stats.StatPoints) end
                end
            end)
        end
    end
end)

-- Auto Boss Summon
task.spawn(function()
    while alive() do
        task.wait(jitter(30, 5))
        if not alive() then break end
        if CFG.AutoBoss then
            pcall(function()
                local re = RS.Remotes:FindFirstChild("RequestSummonBoss")
                if re then re:FireServer() end
            end)
        end
    end
end)

-- Fullbright
local _origLighting = nil
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.5))
        if not alive() then break end
        if CFG.Fullbright then
            if not _origLighting then
                _origLighting = {
                    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
                    FogEnd = Lighting.FogEnd, Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
                }
            end
            Lighting.Brightness = 3; Lighting.ClockTime = 12; Lighting.FogEnd = 99999
            Lighting.Ambient = Color3.fromRGB(178, 178, 178); Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
        elseif _origLighting then
            Lighting.Brightness = _origLighting.Brightness; Lighting.ClockTime = _origLighting.ClockTime
            Lighting.FogEnd = _origLighting.FogEnd; Lighting.Ambient = _origLighting.Ambient
            Lighting.OutdoorAmbient = _origLighting.OutdoorAmbient; _origLighting = nil
        end
    end
end)

-- ESP (weak-table refs)
local _espFolder = Instance.new("Folder")
_espFolder.Name = "AuroraESP"
local _espOk = false
if typeof(gethui) == "function" then _espOk = pcall(function() _espFolder.Parent = gethui() end) end
if not _espOk then _espOk = pcall(function() _espFolder.Parent = game:GetService("CoreGui") end) end
if not _espOk then _espFolder.Parent = Player:WaitForChild("PlayerGui") end

local _espBBs   = setmetatable({}, {__mode = "k"})
local _espBoxes = setmetatable({}, {__mode = "k"})
local _espHL    = setmetatable({}, {__mode = "k"})

local function ensureBB(target, adornee, studsY, sizeX, sizeY)
    local data = _espBBs[target]
    if data and data.bb and data.bb.Parent then
        data.bb.Adornee = adornee; data.bb.Enabled = true
        return data.bb, data.label
    end
    local bb = Instance.new("BillboardGui"); bb.Adornee = adornee
    bb.Size = UDim2.fromOffset(sizeX, sizeY); bb.StudsOffset = Vector3.new(0, studsY, 0)
    bb.AlwaysOnTop = true; bb.Parent = _espFolder
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1; l.TextStrokeTransparency = 0.3; l.TextStrokeColor3 = Color3.new(0, 0, 0)
    l.Font = Enum.Font.GothamBold; l.Parent = bb
    _espBBs[target] = { bb = bb, label = l }
    return bb, l
end

local function hideBB(target)
    local data = _espBBs[target]
    if data and data.bb then data.bb.Enabled = false end
end

task.spawn(function()
    while alive() do
        task.wait(jitter(0.5, 0.5))
        if not alive() then break end
        pcall(function()
            local espColor = Color3.fromRGB(CFG.ESPColorR, CFG.ESPColorG, CFG.ESPColorB)
            local myHRP = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
            local npcsFolder = workspace:FindFirstChild("NPCs")

            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= Player then
                    if CFG.PlayerESP and p.Character and myHRP then
                        local head = p.Character:FindFirstChild("Head")
                        local hum = p.Character:FindFirstChildOfClass("Humanoid")
                        if head and hum then
                            local dist = math.floor((myHRP.Position - head.Position).Magnitude)
                            local _, l = ensureBB(p, head, 3, 150, 24)
                            l.Text = p.Name .. " " .. fmtHP(hum.Health) .. " [" .. dist .. "m]"
                            l.TextColor3 = espColor; l.TextSize = 11
                        end
                    else
                        hideBB(p)
                    end
                end
            end

            if npcsFolder then
                for _, mob in ipairs(npcsFolder:GetChildren()) do
                    local oldHL = mob:FindFirstChild("AuroraHL")
                    if oldHL then oldHL:Destroy() end
                    local hum = mob:FindFirstChildOfClass("Humanoid")
                    local root = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Root") or mob.PrimaryPart
                    if CFG.MobESP and hum and hum.Health > 0 and root then
                        local _, l = ensureBB(mob, root, 3.5, 120, 20)
                        l.Text = mob.Name .. " " .. fmtHP(hum.Health)
                        l.TextColor3 = espColor; l.TextSize = 10
                    else
                        hideBB(mob)
                    end
                end
            end

            local function ensureBox(model)
                local box = _espBoxes[model]
                if box and box.Parent then box.Color3 = espColor; box.SurfaceColor3 = espColor; box.Adornee = model; return end
                box = Instance.new("SelectionBox"); box.Name = "AuroraBox"
                box.Adornee = model; box.LineThickness = 0.03
                box.SurfaceTransparency = 0.85; box.Color3 = espColor; box.SurfaceColor3 = espColor
                box.Parent = _espFolder; _espBoxes[model] = box
            end
            local function removeBox(model)
                local box = _espBoxes[model]
                if box and box.Parent then box:Destroy() end; _espBoxes[model] = nil
            end

            if not CFG.BoxESP then
                -- Clear ALL tracked boxes, including orphans (mobs that left npcsFolder)
                local keys = {}
                for k in pairs(_espBoxes) do table.insert(keys, k) end
                for _, k in ipairs(keys) do removeBox(k) end
            else
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Player and p.Character then ensureBox(p.Character) end
                end
                if npcsFolder then
                    for _, mob in ipairs(npcsFolder:GetChildren()) do
                        local hum = mob:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then ensureBox(mob) else removeBox(mob) end
                    end
                end
            end

            local function ensureSkeleton(model)
                local hl = _espHL[model]
                if hl and hl.Parent then hl.OutlineColor = espColor; return end
                hl = Instance.new("Highlight"); hl.Name = "AuroraSkel"
                hl.FillTransparency = 1; hl.FillColor = Color3.new(0, 0, 0)
                hl.OutlineColor = espColor; hl.OutlineTransparency = 0
                hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                hl.Parent = model; _espHL[model] = hl
            end
            local function removeSkeleton(model)
                local hl = _espHL[model]
                if hl then pcall(function() hl:Destroy() end); _espHL[model] = nil end
            end

            if not CFG.SkeletonESP then
                -- Clear ALL tracked highlights, including orphans (mobs that left npcsFolder)
                local keys = {}
                for k in pairs(_espHL) do table.insert(keys, k) end
                for _, k in ipairs(keys) do removeSkeleton(k) end
            else
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= Player and p.Character then ensureSkeleton(p.Character) end
                end
                if npcsFolder then
                    for _, mob in ipairs(npcsFolder:GetChildren()) do
                        local hum = mob:FindFirstChildOfClass("Humanoid")
                        if hum and hum.Health > 0 then ensureSkeleton(mob) else removeSkeleton(mob) end
                    end
                end
            end

            -- === Easter Egg ESP (all 7: 3 Hidden Models + spawn-point Parts in 4 subfolders) ===
            -- Top-level Models are currently-spawned eggs (EggCategory attr).
            -- Subfolders (TimedSpawnPoints/HiddenEggs/BossEggSpawnPoints/BossEgg2SpawnPoints)
            -- contain Parts marking where future/respawning eggs appear — show ESP for those too.
            local eggFolder = workspace:FindFirstChild("EasterEggs")
            local _eggSubMeta = {
                TimedSpawnPoints    = { label = "Timed Spawn",    color = Color3.fromRGB( 80, 220, 255) },
                HiddenEggs          = { label = "Hidden Spawn",   color = Color3.fromRGB(255, 215,   0) },
                BossEggSpawnPoints  = { label = "Boss Egg Spawn", color = Color3.fromRGB(255,  80, 180) },
                BossEgg2SpawnPoints = { label = "Boss Egg 2",     color = Color3.fromRGB(255, 130,  50) },
            }
            local function _ensureEggAnchor(parent, pos, color, size, trans)
                local a = parent:FindFirstChild("__AuroraEggAnchor")
                if not a or not a:IsA("BasePart") then
                    if a then pcall(function() a:Destroy() end) end
                    a = Instance.new("Part")
                    a.Name = "__AuroraEggAnchor"
                    a.Shape = Enum.PartType.Ball
                    a.Size = Vector3.new(size, size, size)
                    a.Material = Enum.Material.Neon
                    a.Transparency = trans
                    a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
                    a.Anchored = true; a.CastShadow = false
                    a.Parent = parent
                end
                a.CFrame = CFrame.new(pos)
                a.Color = color
                return a
            end
            if CFG.EasterEggESP and eggFolder and myHRP then
                -- Pass 1: Models (spawned eggs). Collect positions to dedup spawn points.
                local _spawnedPos = {}
                for _, egg in ipairs(eggFolder:GetChildren()) do
                    if egg:IsA("Model") and egg.Name:find("EasterEgg_") then
                        for _, c in ipairs(egg:GetChildren()) do
                            if c.Name == "AuroraEggHL" then pcall(function() c:Destroy() end) end
                        end
                        local cat = egg:GetAttribute("EggCategory") or (egg.Name:find("Timed") and "Timed" or "Hidden")
                        local eggColor = (cat == "Hidden") and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(80, 220, 255)
                        local ok, pivot = pcall(function() return egg:GetPivot() end)
                        if ok and pivot then
                            table.insert(_spawnedPos, pivot.Position)
                            local anchor = _ensureEggAnchor(egg, pivot.Position, eggColor, 4, 0.35)
                            local dist = math.floor((myHRP.Position - anchor.Position).Magnitude)
                            local _, l = ensureBB(egg, anchor, 3, 140, 24)
                            l.Text = cat .. " Egg [" .. dist .. "m]"
                            l.TextColor3 = eggColor; l.TextSize = 12
                        end
                    end
                end
                -- Pass 2: Spawn-point Parts — skip if within 5 studs of a spawned Model (no double ESP)
                for subName, meta in pairs(_eggSubMeta) do
                    local sub = eggFolder:FindFirstChild(subName)
                    if sub then
                        for _, part in ipairs(sub:GetChildren()) do
                            if part:IsA("BasePart") then
                                local dup = false
                                for _, sp in ipairs(_spawnedPos) do
                                    if (part.Position - sp).Magnitude < 5 then dup = true; break end
                                end
                                if dup then
                                    local old = part:FindFirstChild("__AuroraEggAnchor")
                                    if old then pcall(function() old:Destroy() end) end
                                    hideBB(part)
                                else
                                    local anchor = _ensureEggAnchor(part, part.Position, meta.color, 4, 0.55)
                                    local dist = math.floor((myHRP.Position - anchor.Position).Magnitude)
                                    local _, l = ensureBB(part, anchor, 3, 140, 24)
                                    l.Text = meta.label .. " [" .. dist .. "m]"
                                    l.TextColor3 = meta.color; l.TextSize = 12
                                end
                            end
                        end
                    end
                end
            elseif eggFolder then
                for _, d in ipairs(eggFolder:GetDescendants()) do
                    if d.Name == "__AuroraEggAnchor" or d.Name == "AuroraEggHL" then
                        pcall(function() d:Destroy() end)
                    end
                    if d:IsA("Model") or d:IsA("BasePart") then
                        hideBB(d)
                    end
                end
            end

            -- === Boss Spawn ESP (TimedBossSpawn_*_Container) ===
            local bossColor = Color3.fromRGB(255, 80, 80)
            if CFG.BossSpawnESP and myHRP then
                for _, inst in ipairs(workspace:GetChildren()) do
                    if inst:IsA("Model") and inst.Name:find("^TimedBossSpawn_") then
                        local bossName = inst.Name:match("^TimedBossSpawn_(.-)_Container") or inst.Name
                        local ok, pivot = pcall(function() return inst:GetPivot() end)
                        if ok and pivot then
                            local anchor = inst:FindFirstChild("__AuroraBossAnchor")
                            if not anchor or not anchor:IsA("BasePart") then
                                if anchor then pcall(function() anchor:Destroy() end) end
                                anchor = Instance.new("Part")
                                anchor.Name = "__AuroraBossAnchor"
                                anchor.Shape = Enum.PartType.Ball
                                anchor.Size = Vector3.new(5, 5, 5)
                                anchor.Material = Enum.Material.Neon
                                anchor.Transparency = 0.4
                                anchor.CanCollide = false
                                anchor.CanQuery = false
                                anchor.CanTouch = false
                                anchor.Anchored = true
                                anchor.CastShadow = false
                                anchor.Parent = inst
                            end
                            anchor.CFrame = pivot
                            anchor.Color = bossColor
                            local dist = math.floor((myHRP.Position - anchor.Position).Magnitude)
                            local _, l = ensureBB(inst, anchor, 4, 160, 26)
                            l.Text = bossName .. " Spawn [" .. dist .. "m]"
                            l.TextColor3 = bossColor; l.TextSize = 12
                        end
                    end
                end
            else
                for _, inst in ipairs(workspace:GetChildren()) do
                    if inst:IsA("Model") and inst.Name:find("^TimedBossSpawn_") then
                        hideBB(inst)
                        for _, c in ipairs(inst:GetChildren()) do
                            if c.Name == "__AuroraBossAnchor" then
                                pcall(function() c:Destroy() end)
                            end
                        end
                    end
                end
            end
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
    { name = "Combat",   icon = "◆" },
    { name = "Visuals",  icon = "◉" },
    { name = "Misc",     icon = "≡" },
    { name = "Configs",  icon = "□" },
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

-- Build 6 tab pairs + persistent Live Game
local TAB_NAMES = { "Farm", "Combat", "Visuals", "Misc", "Configs", "Settings" }
local TAB_ACCENT = {
    Farm = C.pink, Combat = C.purple, Visuals = C.pink,
    Misc = C.pink, Configs = C.pink,  Settings = C.pink,
}
local PANEL_TITLES = {
    Farm     = { alpha = "FARM",     beta = "QUESTING"  },
    Combat   = { alpha = "MOVEMENT", beta = "EXPLOITS"  },
    Visuals  = { alpha = "ESP",      beta = "COLORS"    },
    Misc     = { alpha = "PLAYER",   beta = "TELEPORTS" },
    Configs  = { alpha = "CONFIG",   beta = "INFO"      },
    Settings = { alpha = "UI",       beta = "ABOUT"     },
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
    -- Fallback for stale CFG from previous builds (e.g. "Module A" → "Farm")
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
    -- Whole row is clickable (matches toggleRow pattern) — track alone is too thin
    local row = create("Frame", {
        Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
        LayoutOrder = order, Active = true,
    }, parent)
    create("TextLabel", {
        Size = UDim2.new(0.7, 0, 0, 18), BackgroundTransparency = 1, Text = label,
        Font = F_SANS_SEMI, TextSize = 12, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)
    local fmtVal = function(v) return (step < 1) and string.format("%.1f", v) or tostring(math.floor(v)) end
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
--   options: array of strings
--   multi=false/nil → CFG[cfgKey] is a string (single-select)
--   multi=true      → CFG[cfgKey] is a {[opt]=true,...} set
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
local oA_a, oA_b = 0, 0
local function nA() oA_a = oA_a + 1; return oA_a end
local function nAB() oA_b = oA_b + 1; return oA_b end

sectionHeader(scrolls["Farm_alpha"], "●", "Farm",                       nA())
toggleRow    (scrolls["Farm_alpha"], "Underground Farm",           "UndergroundAbility",  nA())
dropdownRow  (scrolls["Farm_alpha"], "UG Targets",                 "UGTargets",       _ALL_MOBS,  nA(), true)
toggleRow    (scrolls["Farm_alpha"], "Underground Farm Boss Only", "UndergroundBossOnly", nA())
dropdownRow  (scrolls["Farm_alpha"], "UG Boss Targets",            "UGBossTargets",   _BOSS_MOBS, nA(), true)
toggleRow    (scrolls["Farm_alpha"], "Auto Farm",         "AutoFarm",           nA())
toggleRow    (scrolls["Farm_alpha"], "Auto Attack",       "AutoAttack",         nA())

sectionHeader(scrolls["Farm_alpha"], "◉", "Tuning",                     nA())
sliderRow    (scrolls["Farm_alpha"], "Farm Depth",        "FarmDepth",        -15, -8,   1,   nA())
sliderRow    (scrolls["Farm_alpha"], "Ability Interval",  "AbilityInterval",   0.1, 1.0, 0.1, nA())
sliderRow    (scrolls["Farm_alpha"], "Hit Interval",      "HitInterval",       0.3, 1.0, 0.1, nA())

sectionHeader(scrolls["Farm_beta"],  "💰", "Shop",                              nAB())
toggleRow    (scrolls["Farm_beta"],  "Auto Buy Merchant",  "AutoBuyMerchant", nAB())

sectionHeader(scrolls["Farm_beta"],  "●", "Questing",                   nAB())
toggleRow    (scrolls["Farm_beta"],  "Auto Quest",        "AutoQuest",        nAB())
toggleRow    (scrolls["Farm_beta"],  "Auto Ability",      "AutoAbility",      nAB())
toggleRow    (scrolls["Farm_beta"],  "Auto Collect Eggs", "AutoCollectEggs",  nAB())

sectionHeader(scrolls["Farm_beta"],  "✦", "Notes",                      nAB())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Underground: noclips below mob, spams abilities.\nSurface: TP + hit nearest mob.\nAttack rate capped ~2s server-side.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAB(),
}, scrolls["Farm_beta"])

--========================================================================
-- POPULATE: COMBAT
--========================================================================
local oB_a, oB_b = 0, 0
local function nB() oB_a = oB_a + 1; return oB_a end
local function nBB() oB_b = oB_b + 1; return oB_b end

sectionHeader(scrolls["Combat_alpha"], "●", "Movement",                   nB())
toggleRow    (scrolls["Combat_alpha"], "Infinite Dash", "InfDash",   nB())
toggleRow    (scrolls["Combat_alpha"], "Multi Jump",    "MultiJump", nB())

sectionHeader(scrolls["Combat_alpha"], "◉", "Haki",                       nB())
toggleRow    (scrolls["Combat_alpha"], "Armament Haki",    "Haki",     nB())
toggleRow    (scrolls["Combat_alpha"], "Observation Haki", "ObsHaki",  nB())
toggleRow    (scrolls["Combat_alpha"], "Conqueror Haki",   "ConqHaki", nB())

sectionHeader(scrolls["Combat_beta"],  "✦", "Exploits",                   nBB())
toggleRow    (scrolls["Combat_beta"],  "Zero Cooldown",     "ZeroCooldown",    nBB())
toggleRow    (scrolls["Combat_beta"],  "Auto Trait Reroll", "AutoTraitReroll", nBB())
toggleRow    (scrolls["Combat_beta"],  "Auto Power Reroll", "AutoPowerReroll", nBB())
toggleRow    (scrolls["Combat_beta"],  "Auto Boss Spawn",   "AutoBossSpawn",   nBB())
toggleRow    (scrolls["Combat_beta"],  "Auto Artifact",     "AutoArtifact",    nBB())

sectionHeader(scrolls["Combat_beta"],  "▣", "Manual",                     nBB())
actionBtn(scrolls["Combat_beta"], "Mass Upgrade Artifacts", C.bg3, nBB(), function()
    local re = getRemote("ArtifactMassUpgrade"); if re then re:FireServer() end
end)
actionBtn(scrolls["Combat_beta"], "Claim Milestones", C.bg3, nBB(), function()
    local re = getRemote("ArtifactMilestoneClaimReward")
    if re then for i = 1, 20 do pcall(function() re:FireServer(i) end) end end
end)
actionBtn(scrolls["Combat_beta"], "Request Ascend", C.bg3, nBB(), function()
    local re = getRemote("RequestAscend"); if re then re:FireServer() end
end)
actionBtn(scrolls["Combat_beta"], "Spawn Rimuru", C.bg3, nBB(), function()
    local re = getRemote("RequestSpawnRimuru"); if re then re:FireServer() end
end)
actionBtn(scrolls["Combat_beta"], "Spawn True Aizen", C.bg3, nBB(), function()
    local re = getRemote("RequestSpawnTrueAizen"); if re then re:FireServer() end
end)
actionBtn(scrolls["Combat_beta"], "Spawn Atomic", C.bg3, nBB(), function()
    local re = getRemote("RequestSpawnAtomic"); if re then re:FireServer() end
end)

--========================================================================
-- POPULATE: VISUALS = ESP
--========================================================================
local oV_a, oV_b = 0, 0
local function nV() oV_a = oV_a + 1; return oV_a end
local function nVB() oV_b = oV_b + 1; return oV_b end

sectionHeader(scrolls["Visuals_alpha"], "●", "ESP",                         nV())
toggleRow    (scrolls["Visuals_alpha"], "Player ESP",  "PlayerESP",   nV())
toggleRow    (scrolls["Visuals_alpha"], "Mob ESP",     "MobESP",      nV())
toggleRow    (scrolls["Visuals_alpha"], "Box ESP",     "BoxESP",      nV())
toggleRow    (scrolls["Visuals_alpha"], "Outline ESP", "SkeletonESP", nV())

sectionHeader(scrolls["Visuals_alpha"], "✦", "Event ESP",                   nV())
toggleRow    (scrolls["Visuals_alpha"], "Easter Egg ESP", "EasterEggESP", nV())
toggleRow    (scrolls["Visuals_alpha"], "Boss Spawn ESP", "BossSpawnESP", nV())

sectionHeader(scrolls["Visuals_alpha"], "◉", "World",                       nV())
toggleRow    (scrolls["Visuals_alpha"], "Fullbright", "Fullbright", nV())

sectionHeader(scrolls["Visuals_beta"], "▣", "ESP Color",                    nVB())
do
    local palette = create("Frame", {
        Size = UDim2.new(1, 0, 0, 76), BackgroundTransparency = 1, LayoutOrder = nVB(),
    }, scrolls["Visuals_beta"])
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.fromOffset(28, 28)
    grid.CellPadding = UDim2.fromOffset(8, 8)
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.FillDirection = Enum.FillDirection.Horizontal
    grid.Parent = palette

    local PRESETS = {
        { n = "Pink",   r = 252, g = 110, b = 142 },
        { n = "Red",    r = 255, g = 50,  b = 50 },
        { n = "Orange", r = 255, g = 165, b = 0 },
        { n = "Yellow", r = 255, g = 220, b = 50 },
        { n = "Green",  r = 80,  g = 200, b = 120 },
        { n = "Cyan",   r = 50,  g = 220, b = 255 },
        { n = "Blue",   r = 80,  g = 100, b = 255 },
        { n = "Purple", r = 180, g = 80,  b = 255 },
        { n = "White",  r = 255, g = 255, b = 255 },
    }
    local swatches = {}
    for i, p in ipairs(PRESETS) do
        local sw = create("Frame", {
            Name = "Sw_" .. p.n, Size = UDim2.fromOffset(28, 28),
            BackgroundColor3 = Color3.fromRGB(p.r, p.g, p.b),
            BorderSizePixel = 0, Active = true, LayoutOrder = i,
        }, palette)
        corner(sw, 14)
        local ring = stroke(sw, C.white, 2, 1)
        swatches[i] = { sw = sw, ring = ring, p = p }
        sw.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                CFG.ESPColorR = p.r; CFG.ESPColorG = p.g; CFG.ESPColorB = p.b
                for _, s in pairs(swatches) do s.ring.Transparency = 1 end
                ring.Transparency = 0
                if CFG.AutoSave then saveCFG() end
            end
        end)
    end
    for _, s in pairs(swatches) do
        if s.p.r == CFG.ESPColorR and s.p.g == CFG.ESPColorG and s.p.b == CFG.ESPColorB then
            s.ring.Transparency = 0; break
        end
    end
end

sectionHeader(scrolls["Visuals_beta"], "✦", "Tips",                         nVB())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 60), BackgroundTransparency = 1,
    Text = "Box = selection outline\nOutline = full model highlight\nMob HP auto-tracked (no refresh lag).",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nVB(),
}, scrolls["Visuals_beta"])

--========================================================================
-- POPULATE: MISC = UTILITY + TELEPORTS
--========================================================================
local oM_a, oM_b = 0, 0
local function nM() oM_a = oM_a + 1; return oM_a end
local function nMB() oM_b = oM_b + 1; return oM_b end

sectionHeader(scrolls["Misc_alpha"], "●", "Player",                         nM())
toggleRow    (scrolls["Misc_alpha"], "Noclip",      "Noclip",     nM())
toggleRow    (scrolls["Misc_alpha"], "Speed Boost", "SpeedBoost", nM())
sliderRow    (scrolls["Misc_alpha"], "Walk Speed",  "SpeedValue", 16, 150, 1, nM())
toggleRow    (scrolls["Misc_alpha"], "Anti-AFK",    "AntiAFK",    nM())

sectionHeader(scrolls["Misc_alpha"], "◉", "Progression",                    nM())
toggleRow    (scrolls["Misc_alpha"], "Auto Stats",       "AutoStats", nM())
dropdownRow  (scrolls["Misc_alpha"], "Stat Target",      "StatTarget", STAT_OPTIONS, nM(), false)
toggleRow    (scrolls["Misc_alpha"], "Auto Boss Summon", "AutoBoss",  nM())

sectionHeader(scrolls["Misc_beta"], "◉", "Islands",                         nMB())
for _, island in ipairs(ISLANDS) do
    actionBtn(scrolls["Misc_beta"], island.name, C.bg3, nMB(), function() tpToIsland(island) end)
end

sectionHeader(scrolls["Misc_beta"], "✦", "Crystals",                        nMB())
for _, crystal in ipairs(CRYSTAL_POS) do
    actionBtn(scrolls["Misc_beta"], crystal.name, C.bg3, nMB(), function() tpToCrystal(crystal) end)
end

--========================================================================
-- POPULATE: CONFIGS = SAVE/LOAD
--========================================================================
local oC_a, oC_b = 0, 0
local function nC() oC_a = oC_a + 1; return oC_a end
local function nCB() oC_b = oC_b + 1; return oC_b end

sectionHeader(scrolls["Configs_alpha"], "●", "Config",                      nC())
toggleRow    (scrolls["Configs_alpha"], "Auto-Save", "AutoSave", nC())
actionBtn    (scrolls["Configs_alpha"], "Save Config", C.green, nC(), function() saveCFG() end)
actionBtn    (scrolls["Configs_alpha"], "Load Config", C.bg3,   nC(), function() loadSavedCFG() end)
actionBtn    (scrolls["Configs_alpha"], "Reset All",   C.red,   nC(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    CFG.FarmDepth = -11; CFG.AbilityInterval = 0.3; CFG.HitInterval = 0.5; CFG.SpeedValue = 50
    CFG.AutoSave = true; saveCFG()
end)

sectionHeader(scrolls["Configs_beta"], "✦", "Active Features",              nCB())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 180),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nCB(),
}, scrolls["Configs_beta"])

--========================================================================
-- POPULATE: SETTINGS = UI PREFERENCES
--========================================================================
local oS_a, oS_b = 0, 0
local function nS() oS_a = oS_a + 1; return oS_a end
local function nSB() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "UI",                         nS())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nS(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nS(), function()
    task.wait(0.5)
    -- Invalidate session so all game loops stop
    getgenv().__AURORAHUB_SAILOR_SESSION = 0
    pcall(function() screenGui:Destroy() end)
    pcall(function() pillGui:Destroy() end)
    pcall(function() _espFolder:Destroy() end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About",                       nSB())
local _aboutGame   = infoRow(scrolls["Settings_beta"], "Game",    "Sailor Piece", C.text,  nSB())
local _aboutPid    = infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId), C.text2, nSB())
local _aboutPVer   = infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion), C.text2, nSB())
local _aboutHub    = infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net", C.pink,  nSB())
local _aboutBuild  = infoRow(scrolls["Settings_beta"], "Build",   "v5",            C.text2, nSB())

--========================================================================
-- POPULATE: LIVE GAME (persistent)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end
sectionHeader(liveScroll, "◉", "Session",                                   nL())
local _infoRuntime = infoRow(liveScroll, "Runtime",   "0m",  C.text2, nL())
local _infoTarget  = infoRow(liveScroll, "Target",    "None", C.text2, nL())
local _infoTargetHP= infoRow(liveScroll, "Target HP", "—",    C.text2, nL())

sectionHeader(liveScroll, "●", "Status",                                    nL())
local _infoMode    = infoRow(liveScroll, "Mode",   "Idle", C.pink,  nL())
local _infoKills   = infoRow(liveScroll, "Kills",  "0",    C.pink,  nL())
local _infoHealth  = infoRow(liveScroll, "Health", "—",    C.text2, nL())
local _infoStatus  = infoRow(liveScroll, "Status", "Idle", C.text2, nL())

sectionHeader(liveScroll, "⚔", "Equipped",                                  nL())
local _infoSword   = infoRow(liveScroll, "Sword", "—", C.text2, nL())
local _infoPower   = infoRow(liveScroll, "Power", "—", C.text2, nL())
local _infoLevel   = infoRow(liveScroll, "Level", "—", C.text2, nL())
local _infoMoney   = infoRow(liveScroll, "Money", "—", C.text2, nL())

sectionHeader(liveScroll, "✦", "Exploit",                                   nL())
local _infoPatched = infoRow(liveScroll, "Patched", "0",    C.pink,  nL())
local _infoExplStat= infoRow(liveScroll, "Status",  "Idle", C.text2, nL())

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
-- Top drag strip: covers the panel-title area (y=0..48) across all three panels.
-- Active=true catches clicks in empty areas; close button (ZIndex 5) + panel-title
-- TextLabels (Active=false) + scroll bodies (below y=48) all sit above/around it.
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
        getgenv().__AURORAHUB_SAILOR_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
        pcall(function() _espFolder:Destroy() end)
    end
end)
closeBtn.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseMovement then
        closeBtn.BackgroundColor3 = C.bg3
        closeX.TextColor3 = C.text2
    end
end)

--========================================================================
-- EXPLOIT LOOPS (preserved, wired to new label)
--========================================================================

-- Zero Cooldown
task.spawn(function()
    while alive() do
        task.wait(5)
        if not alive() then break end
        if not CFG.ZeroCooldown then continue end
        pcall(function()
            local patched = 0
            for _, obj in ipairs(getgc(true)) do
                if typeof(obj) == "table" and rawget(obj, "Cooldown") and rawget(obj, "Name") then
                    local name = tostring(rawget(obj, "Name"))
                    if name:find("Skill") or name:find("GroundSmash") or name:find("Slash") then
                        if rawget(obj, "Cooldown") > 0.5 then
                            rawset(obj, "Cooldown", 0.5)
                            patched = patched + 1
                        end
                    end
                end
            end
            S.patched = patched
        end)
    end
end)

-- Auto Trait Reroll
task.spawn(function()
    while alive() do
        task.wait(jitter(2, 0.5))
        if not alive() then break end
        if not CFG.AutoTraitReroll then continue end
        pcall(function()
            local re = getRemote("TraitAutoReroll")
            if re then re:FireServer() end
        end)
    end
end)

-- Auto Power Reroll
task.spawn(function()
    while alive() do
        task.wait(jitter(2, 0.5))
        if not alive() then break end
        if not CFG.AutoPowerReroll then continue end
        pcall(function()
            local re = getRemote("PowerToggleAutoRoll")
            if re then re:FireServer() end
        end)
    end
end)

-- Auto Boss Spawn
task.spawn(function()
    while alive() do
        task.wait(jitter(10, 3))
        if not alive() then break end
        if not CFG.AutoBossSpawn then continue end
        pcall(function()
            local r1 = getRemote("RequestAutoSpawnRimuru")
            local r2 = getRemote("RequestAutoSpawnTrueAizen")
            local r3 = getRemote("RequestAutoSpawnAtomic")
            if r1 then r1:FireServer() end
            if r2 then r2:FireServer() end
            if r3 then r3:FireServer() end
        end)
    end
end)

-- Auto Artifact Upgrade + Milestone Claim
task.spawn(function()
    while alive() do
        task.wait(jitter(15, 5))
        if not alive() then break end
        if not CFG.AutoArtifact then continue end
        pcall(function()
            local upgrade = getRemote("ArtifactMassUpgrade")
            local milestone = getRemote("ArtifactMilestoneClaimReward")
            if upgrade then upgrade:FireServer() end
            if milestone then
                for i = 1, 20 do pcall(function() milestone:FireServer(i) end) end
            end
        end)
    end
end)

--========================================================================
-- STATUS UPDATE LOOP (wired to new labels)
--========================================================================
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            -- Session
            local elapsed = tick() - S.session
            local mins = math.floor(elapsed / 60)
            local hrs  = math.floor(mins / 60)
            _infoRuntime.Text = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)
            _infoTarget.Text = S.targetName
            _infoTargetHP.Text = S.targetHP ~= "" and S.targetHP or "—"

            -- Status
            if CFG.UndergroundBossOnly then _infoMode.Text = "UG Boss"
            elseif CFG.UndergroundAbility then _infoMode.Text = "Underground"
            elseif CFG.AutoFarm then _infoMode.Text = "Surface"
            else _infoMode.Text = "Idle"; S.status = "Idle"; S.targetName = "None"; S.targetHP = "" end
            _infoKills.Text = tostring(S.kills)
            _infoStatus.Text = S.status

            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then _infoHealth.Text = fmtHP(hum.Health) .. "/" .. fmtHP(hum.MaxHealth) end
            end

            -- Equipped
            pcall(function()
                local rf = getRemote("GetEquipped")
                if rf and rf:IsA("RemoteFunction") then
                    local data = rf:InvokeServer()
                    if data then
                        _infoSword.Text = data.Sword or "—"
                        _infoPower.Text = data.Power or "—"
                    end
                end
            end)
            local ls = Player:FindFirstChild("leaderstats")
            if ls then
                local lvl   = ls:FindFirstChild("Level")
                local money = ls:FindFirstChild("Money") or ls:FindFirstChild("Gold") or ls:FindFirstChild("Beli")
                if lvl then _infoLevel.Text = tostring(lvl.Value) end
                if money then _infoMoney.Text = fmtHP(money.Value) end
            end

            -- Exploit
            _infoPatched.Text = tostring(S.patched)
            local exS = "Idle"
            if CFG.ZeroCooldown then exS = "Patching" end
            if CFG.AutoBossSpawn or CFG.AutoArtifact or CFG.AutoTraitReroll or CFG.AutoPowerReroll then
                exS = "Running"
            end
            _infoExplStat.Text = exS

            -- Active features list (Configs tab)
            local active = {}
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    table.insert(active, "· " .. k)
                end
            end
            table.sort(active)
            if #active == 0 then
                _cfgActiveLabel.Text = "None"
            else
                _cfgActiveLabel.Text = table.concat(active, "\n")
            end

            -- Pill active count
            local count = 0
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    count = count + 1
                end
            end
            _pillActive.Text = count .. " active"
        end)
    end
end)

--========================================================================
-- INIT
--========================================================================
switchTab(CFG.ActiveTab or "Farm")

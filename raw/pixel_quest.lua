--// Aurora v4 — [ALPHA] Pixel Quest!
--// Made by notCitruss | Dark Glass Theme
--// PlaceId: 80003276594057
--// 2D sprite bullet-hell RPG — GUI-rendered combat

local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local VIM; pcall(function() VIM = game:GetService("VirtualInputManager") end)
local Player = Players.LocalPlayer

for _, n in {"Aurora"} do
    pcall(function() if gethui then local old = gethui():FindFirstChild(n); if old then old:Destroy() end end end)
    pcall(function() local old = game:GetService("CoreGui"):FindFirstChild(n); if old then old:Destroy() end end)
    pcall(function() local old = Player.PlayerGui:FindFirstChild(n); if old then old:Destroy() end end)
end
task.wait(0.1)


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
---------- SESSION GUARD ----------
local _SESSION_ID = HttpService:GenerateGUID(false)

-- Poison old config to kill zombie loops
if getgenv().__AURORA_PIXEL_QUEST_CFG then
    for k, v in pairs(getgenv().__AURORA_PIXEL_QUEST_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_PIXEL_QUEST_CFG[k] = false end
    end
end

-- Disconnect old connections
pcall(function() if getgenv().__AURORA_PQ_COMBAT then getgenv().__AURORA_PQ_COMBAT:Disconnect() end end)
pcall(function() if getgenv().__AURORA_PQ_ORBIT then getgenv().__AURORA_PQ_ORBIT:Disconnect() end end)
pcall(function() if getgenv().__AURORA_PQ_ORBS then getgenv().__AURORA_PQ_ORBS:Disconnect() end end)
pcall(function() if getgenv().__AURORA_PQ_GODMODE then getgenv().__AURORA_PQ_GODMODE:Disconnect() end end)
pcall(function() if getgenv().__AURORA_PQ_DESYNC then getgenv().__AURORA_PQ_DESYNC:Disconnect() end end)

getgenv().__AURORA_PIXEL_QUEST_CFG2 = {
    -- Combat
    AutoAttack   = false,
    AimAssist    = false,
    OrbitTarget  = false,
    AutoFire     = false,
    -- Exploits (getgc patched)
    SpeedBoost   = false,
    SpeedValue   = 2,
    FastAttack   = false,
    FireRateVal  = 0.5,
    FastAbility  = false,
    AbilityVal   = 0.5,
    Noclip       = false,
    -- Projectile mods (each has own toggle)
    ModRange     = false, ProjRange    = 0.5,
    ModSpeed     = false, ProjSpeed    = 6.8,
    ModDmgMin    = false, ProjDmgMin   = 1.5,
    ModDmgMax    = false, ProjDmgMax   = 2.5,
    ModBlasts    = false, ProjBlasts   = 3,
    ModHits      = false, ProjHits     = 1,
    ModAoE       = false, ProjAoE      = 0,
    ModPen       = false, ProjPen      = 0.6,
    ModMaxHits   = false, MaxHitsVal   = 5,
    SpamHit      = false, SpamHitRate  = 5,
    AutoCollectOrbs = false,
    -- Utility
    AutoRetreat  = false,
    LowHPWarn    = false,
    AutoPotion   = false,
    MobESP       = false,
    LootESP      = false,
    AutoInteract = false,
    AntiAFK      = false,
    AutoSave     = true,
    -- NEW: Combat
    KillAura     = false,
    KillAuraRange = 300,
    NoCooldowns  = false,
    MobHunt      = false,
    BossHunt     = false,
    TargetBoss   = "Any",
    -- NEW: Movement
    DesyncSpeed  = false,
    DesyncValue  = 2,
    FollowPlayer = false,
    FollowTarget = "",
    TPMode       = false,
    AutoRift     = false,
    -- NEW: Defense
    Godmode      = false,
    AntiStaff    = false,
    PanicTP      = false,
    PanicHPPct   = 15,
    -- NEW: Loot
    AutoTPLoot   = false,
}

getgenv().__AURORA_PIXEL_QUEST_SESSION = _SESSION_ID
local function alive() return getgenv().__AURORA_PIXEL_QUEST_SESSION == _SESSION_ID end

local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CONFIG ----------
local CFG = getgenv().__AURORA_PIXEL_QUEST_CFG2
local function G() return getgenv().__AURORA_PIXEL_QUEST_CFG2 end
local RetreatPct = 30

---------- TOGGLE SAVE/LOAD ----------
local _cfgFileName = "aurora_cfg_pixel_quest.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_pixel_quest"] end
    if saved and type(saved) == "table" then
        for k, v in saved do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
        if saved._RetreatPct then RetreatPct = saved._RetreatPct end
    end
end

local function saveCFG()
    local toSave = {}
    for k, v in CFG do toSave[k] = v end
    toSave._RetreatPct = RetreatPct
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(toSave)) end)
    getgenv()["AuroraCFG_pixel_quest"] = toSave
end

loadSavedCFG()

---------- GAME REFERENCES ----------
local function getHealthText()
    local txt = ""
    pcall(function()
        txt = Player.PlayerGui.GameUI.DesktopUI.DesktopScreens.PlayerDetails.Contents.Inspect.Status.Health.HealthText.Text
    end)
    return txt
end

local function getManaText()
    local txt = ""
    pcall(function()
        txt = Player.PlayerGui.GameUI.DesktopUI.DesktopScreens.PlayerDetails.Contents.Inspect.Status.Mana.ManaText.Text
    end)
    return txt
end

local function getLevelText()
    local txt = ""
    pcall(function()
        txt = Player.PlayerGui.GameUI.DesktopUI.DesktopHUD.InGameUI.Hotbar.Contents.Container.PlayerStatus.Experience.ExperienceText.Text
    end)
    return txt
end

local function parseHP()
    local txt = getHealthText()
    local cur, max = txt:match("HP:%s*(%d+)%s*/%s*(%d+)")
    return tonumber(cur) or 0, tonumber(max) or 1
end

local function getBaseLayer()
    local bl = nil
    pcall(function()
        bl = Player.PlayerGui.RenderMain.SessionRender.WorldRender.WorldLayers.BaseLayer
    end)
    return bl
end

local function getPixelCenter(frame)
    local ap = frame.AbsolutePosition
    local as = frame.AbsoluteSize
    return ap.X + as.X / 2, ap.Y + as.Y / 2
end

local function getPlayerPixelPos()
    local bl = getBaseLayer()
    if not bl then return 0, 0 end
    for _, child in bl:GetChildren() do
        if child:IsA("Frame") and child.Name == "" and child.Visible then
            for _, sub in child:GetChildren() do
                if sub.Name == "Glow" then
                    return getPixelCenter(child)
                end
            end
        end
    end
    return 0, 0
end

-- Cached enemy list — shared between combat + ESP (refreshed every 0.2s max)
local _enemyCache = {}
local _enemyCacheTime = 0

local function findEnemiesRaw()
    local bl = getBaseLayer()
    if not bl then return {} end

    local trackerPixels = {}
    for _, child in bl:GetChildren() do
        if child.Name == "UITrackerPivot" then
            table.insert(trackerPixels, {x = child.AbsolutePosition.X, y = child.AbsolutePosition.Y})
        end
    end

    local enemies = {}
    local vpX = workspace.CurrentCamera.ViewportSize.X
    local vpY = workspace.CurrentCamera.ViewportSize.Y

    for _, child in bl:GetChildren() do
        if child:IsA("Frame") and child.Name == "" and child.Visible then
            local hasBar, hasGlow = false, false
            for _, sub in child:GetChildren() do
                if sub.Name == "UIBar" then hasBar = true end
                if sub.Name == "Glow" then hasGlow = true end
            end

            if hasBar and not hasGlow then
                local cx, cy = getPixelCenter(child)
                if cx < -200 or cx > vpX + 450 or cy < -200 or cy > vpY + 450 then continue end
                local isOtherPlayer = false
                for _, tp in trackerPixels do
                    if math.abs(tp.x - cx) < 40 and math.abs(tp.y - cy) < 40 then
                        isOtherPlayer = true; break
                    end
                end
                if not isOtherPlayer then
                    table.insert(enemies, {frame = child, px = cx, py = cy})
                end
            end
        end
    end
    return enemies
end

-- Cached wrapper — only re-scans every 0.2s, all callers share the result
local function findEnemies()
    local now = tick()
    if now - _enemyCacheTime < 0.2 then return _enemyCache end
    _enemyCache = findEnemiesRaw()
    _enemyCacheTime = now
    return _enemyCache
end

local function findNearestEnemy()
    local playerX, playerY = getPlayerPixelPos()
    local enemies = findEnemies()
    local nearest, bestDist = nil, math.huge
    for _, e in enemies do
        local d = math.sqrt((e.px - playerX)^2 + (e.py - playerY)^2)
        if d > 5 and d < bestDist then nearest = e; bestDist = d end
    end
    return nearest, bestDist
end

---------- STATE ----------
local S = {
    attacks = 0, retreats = 0, session = tick(),
    kills = 0, orbsCollected = 0, lootCollected = 0,
    bossesKilled = 0, panicTPs = 0, projHidden = 0,
}
local _retreating = false

---------- GETGC CACHED REFERENCES ----------
local _cachedMe = nil
local _cachedNet = nil
local _cachedGlobal = nil
local _cachedScene = nil
local _origSpeed, _origFireRate, _origAbilityRate = nil, nil, nil
local _origResolve = nil

local function findMyPlayer()
    if not getgc then return nil end
    if _cachedMe and typeof(_cachedMe) == "table" and rawget(_cachedMe, "hp") then
        return _cachedMe
    end
    for _, obj in getgc(true) do
        if typeof(obj) == "table" and rawget(obj, "forceClientSideSimulation")
           and rawget(obj, "hp") and rawget(obj, "fireRate") then
            _cachedMe = obj
            return obj
        end
    end
    _cachedMe = nil
    return nil
end

local function findNetwork()
    if _cachedNet and typeof(_cachedNet) == "table" and rawget(_cachedNet, "SendServerPacket") then
        return _cachedNet
    end
    if not getgc then return nil end
    for _, obj in getgc(true) do
        if typeof(obj) == "table" and rawget(obj, "SendServerPacket") and rawget(obj, "Packet") then
            _cachedNet = obj
            return obj
        end
    end
    return nil
end

local function findGlobal()
    if _cachedGlobal and typeof(_cachedGlobal) == "table" and rawget(_cachedGlobal, "UI") then
        return _cachedGlobal
    end
    if not getgc then return nil end
    for _, obj in getgc(true) do
        if typeof(obj) == "table" and rawget(obj, "UI") and rawget(obj, "Initialize") and rawget(obj, "currentSession") then
            _cachedGlobal = obj
            return obj
        end
    end
    return nil
end

local function findScene()
    if _cachedScene and typeof(_cachedScene) == "table" and rawget(_cachedScene, "_gameObjects") then
        return _cachedScene
    end
    local g = findGlobal()
    if g then
        pcall(function()
            local session = rawget(g, "currentSession")
            if session then
                _cachedScene = rawget(session, "_scene")
            end
        end)
    end
    return _cachedScene
end

-- Shared enemy cache for SpamHit + KillAura (single scan, no duplication)
local _sharedEnemyCache = {}  -- {objectID, body.position}
local _sharedEnemyLastScan = 0

-- Background getgc scanner — refreshes all cached refs + enemies every 3s
task.spawn(function()
    task.wait(2)
    while alive() do
        pcall(function()
            findMyPlayer()
            findNetwork()
            findGlobal()
            findScene()
            -- Unified enemy scan for SpamHit + KillAura (one getgc scan for both)
            local cfg = G()
            if getgc and (cfg.SpamHit or cfg.KillAura or cfg.BossHunt) then
                local fresh = {}
                local myID = _cachedMe and _cachedMe.objectID or 0
                for _, obj in getgc(true) do
                    if typeof(obj) == "table" and rawget(obj, "hostile") == true
                       and rawget(obj, "spawned") == true and rawget(obj, "hp") then
                        local eid = rawget(obj, "objectID")
                        if eid and eid ~= myID and obj.hp > 0 then
                            local ePos = nil
                            pcall(function() ePos = obj.body.position end)
                            table.insert(fresh, {id = eid, pos = ePos, hp = obj.hp, obj = obj})
                        end
                        if #fresh >= 30 then break end
                    end
                end
                _sharedEnemyCache = fresh
                _sharedEnemyLastScan = tick()
            end
        end)
        task.wait(3)
    end
end)

---------- CORE LOOPS ----------
local _cachedEnemy = nil
local _cachedPlayerX, _cachedPlayerY = 0, 0
local _smoothMouseX, _smoothMouseY = 0, 0
local _attackHeld = false
local _orbitAngle = 0
local ORBIT_RADIUS = 120

-- Single RenderStepped connection for smooth aim + orbit (no stutters)
local _combatConn
_combatConn = RunService.RenderStepped:Connect(function(dt)
    if not alive() then _combatConn:Disconnect() return end

    pcall(function()
        local cfg = G()
        local needScan = cfg.AimAssist or cfg.OrbitTarget or cfg.AutoAttack or cfg.AutoFire

        -- TP Mode: click to teleport
        if cfg.TPMode and _cachedMe then
            -- handled via InputBegan below
        end

        if not needScan then return end

        _cachedPlayerX, _cachedPlayerY = getPlayerPixelPos()
        if _cachedPlayerX == 0 and _cachedPlayerY == 0 then return end

        _cachedEnemy = findNearestEnemy()

        -- Aim Assist — lock mouse to exact visual center of enemy
        if cfg.AimAssist and _cachedEnemy and _cachedEnemy.frame and _cachedEnemy.frame.Parent then
            local f = _cachedEnemy.frame
            local ap = f.AbsolutePosition
            local as = f.AbsoluteSize
            local cx = ap.X + as.X * 0.5
            local cy = ap.Y + as.Y * 0.5 + 45
            _smoothMouseX = cx
            _smoothMouseY = cy
            VIM:SendMouseMoveEvent(_smoothMouseX, _smoothMouseY, game)
        elseif _cachedEnemy and _cachedEnemy.frame and _cachedEnemy.frame.Parent then
            local f = _cachedEnemy.frame
            _smoothMouseX = f.AbsolutePosition.X + f.AbsoluteSize.X * 0.5
            _smoothMouseY = f.AbsolutePosition.Y + f.AbsoluteSize.Y * 0.5 + 45
        end

        -- Auto Attack
        if cfg.AutoAttack then
            if not _attackHeld then
                VIM:SendMouseButtonEvent(_smoothMouseX, _smoothMouseY, 0, true, game, 0)
                _attackHeld = true
            end
            VIM:SendMouseButtonEvent(_smoothMouseX, _smoothMouseY, 0, true, game, 0)
            S.attacks += 1
        elseif _attackHeld then
            VIM:SendMouseButtonEvent(_smoothMouseX, _smoothMouseY, 0, false, game, 0)
            _attackHeld = false
        end
    end)
end)
getgenv().__AURORA_PQ_COMBAT = _combatConn

-- Smooth Orbit (separate loop for movement keys, uses RenderStepped timing)
local _orbitConn
local _heldH, _heldV = nil, nil
local function releaseAll()
    if _heldH then pcall(function() VIM:SendKeyEvent(false, _heldH, false, game) end); _heldH = nil end
    if _heldV then pcall(function() VIM:SendKeyEvent(false, _heldV, false, game) end); _heldV = nil end
end

_orbitConn = RunService.Heartbeat:Connect(function(dt)
    if not alive() then releaseAll(); _orbitConn:Disconnect() return end

    if G().OrbitTarget and _cachedEnemy and _cachedEnemy.frame and _cachedEnemy.frame.Parent then
        pcall(function()
            local ex, ey = _cachedEnemy.px, _cachedEnemy.py
            local px, py = _cachedPlayerX, _cachedPlayerY
            if px == 0 and py == 0 then return end

            -- Smooth orbit — advance angle based on dt
            _orbitAngle = _orbitAngle + dt * 2.5 -- orbit speed (radians/sec)

            local targetX = ex + math.cos(_orbitAngle) * ORBIT_RADIUS
            local targetY = ey + math.sin(_orbitAngle) * ORBIT_RADIUS
            local moveX = targetX - px
            local moveY = targetY - py

            -- Deadzone to prevent jittering
            local needH = math.abs(moveX) > 8 and (moveX > 0 and Enum.KeyCode.D or Enum.KeyCode.A) or nil
            local needV = math.abs(moveY) > 8 and (moveY > 0 and Enum.KeyCode.S or Enum.KeyCode.W) or nil

            if needH ~= _heldH then
                if _heldH then VIM:SendKeyEvent(false, _heldH, false, game) end
                if needH then VIM:SendKeyEvent(true, needH, false, game) end
                _heldH = needH
            end
            if needV ~= _heldV then
                if _heldV then VIM:SendKeyEvent(false, _heldV, false, game) end
                if needV then VIM:SendKeyEvent(true, needV, false, game) end
                _heldV = needV
            end
        end)
    else
        releaseAll()
    end
end)
getgenv().__AURORA_PQ_ORBIT = _orbitConn

-- Auto Retreat
task.spawn(function()
    while alive() do
        if G().AutoRetreat then
            local cur, max = parseHP()
            local pct = (cur / max) * 100
            if pct > 0 and pct <= RetreatPct and not _retreating then
                _retreating = true
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                    task.wait(0.1)
                    VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                end)
                S.retreats += 1
                task.wait(3)
                _retreating = false
            end
        end
        task.wait(0.3)
    end
end)

-- Auto Potion
local _lastPotion = 0
task.spawn(function()
    while alive() do
        if G().AutoPotion then
            local cur, max = parseHP()
            local pct = (cur / max) * 100
            local now = tick()
            if pct > 0 and pct < 65 and (now - _lastPotion) > 4 then
                _lastPotion = now
                pcall(function()
                    for _, code in {Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight} do
                        VIM:SendKeyEvent(true, code, false, game)
                        task.wait(0.05)
                        VIM:SendKeyEvent(false, code, false, game)
                        task.wait(0.1)
                    end
                end)
            end
        end
        task.wait(0.5)
    end
end)

-- Auto Interact
task.spawn(function()
    while alive() do
        pcall(function()
            if G().AutoInteract then
                VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.05)
                VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end
        end)
        task.wait(0.5)
    end
end)

-- Anti-AFK
task.spawn(function()
    while alive() do
        task.wait(jitter(60, 18.0))
        if G().AntiAFK then
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.new(0, 0.1, 0) end
            end)
        end
    end
end)

---------- GETGC EXPLOITS (speed, fire rate, ability rate, noclip, auto-fire, no cooldowns) ----------

task.spawn(function()
    task.wait(3) -- let game init
    while alive() do
        pcall(function()
            local me = findMyPlayer()
            if not me then return end
            local ctrl = rawget(me, "controller")
            local cfg = G()

            -- Save originals once
            if ctrl and not _origSpeed then
                _origSpeed = rawget(ctrl, "speedScalar") or 1
            end
            if not _origFireRate then _origFireRate = me.fireRate end
            if not _origAbilityRate then _origAbilityRate = me.abilityRate end

            -- Speed: DesyncSpeed handles movement. Restore original speedScalar always.
            if ctrl and _origSpeed then
                ctrl.speedScalar = _origSpeed
            end

            -- Fast Attack (lower = faster, it's a cooldown)
            if cfg.FastAttack then
                me.fireRate = cfg.FireRateVal
            elseif cfg.NoCooldowns then
                me.fireRate = 0.01
            elseif _origFireRate then
                me.fireRate = _origFireRate
            end

            -- Fast Ability
            if cfg.FastAbility then
                me.abilityRate = cfg.AbilityVal
                me.currentAbilityCooldown = cfg.AbilityVal
            elseif cfg.NoCooldowns then
                me.abilityRate = 0.01
                me.currentAbilityCooldown = 0
                pcall(function() me.itemCooldowns = {} end)
            elseif _origAbilityRate then
                me.abilityRate = _origAbilityRate
            end

            -- Auto Fire
            me.autoFireEnabled = cfg.AutoFire

            -- Noclip
            if ctrl then
                local body = rawget(ctrl, "body")
                if body then
                    if cfg.Noclip then
                        body.resolveCollisions = false
                    elseif _origResolve == nil then
                        _origResolve = true
                    else
                        body.resolveCollisions = _origResolve
                    end
                end
            end

            -- Projectile Mods (each individually toggled)
            local prim = rawget(me, "equippedPrimary")
            if prim then
                local proj = rawget(prim, "_projectileDescriptor")
                if proj and typeof(proj) == "table" then
                    if cfg.ModRange then proj._blastLifetime = cfg.ProjRange end
                    if cfg.ModSpeed then proj._blastSpeed = cfg.ProjSpeed * 100 end
                    if cfg.ModDmgMin or cfg.ModDmgMax then
                        local mn = cfg.ModDmgMin and cfg.ProjDmgMin * 10 or proj._damageRange.X
                        local mx = cfg.ModDmgMax and cfg.ProjDmgMax * 10 or proj._damageRange.Y
                        proj._damageRange = Vector2.new(mn, mx)
                    end
                    if cfg.ModBlasts then proj._blasts = math.floor(cfg.ProjBlasts) end
                    if cfg.ModHits then proj._maxHitsPerEntity = math.floor(cfg.ProjHits) end
                    if cfg.ModAoE then proj._radiusOfEffect = cfg.ProjAoE * 10 end
                    if cfg.ModPen then proj._defensePenetration = cfg.ProjPen end
                    if cfg.ModMaxHits then proj._maxHitsPerEntity = math.floor(cfg.MaxHitsVal) end
                end
            end

        end)
        task.wait(0.5)
    end
end)

-- Spam HIT — uses shared enemy cache (no getgc scan here)
task.spawn(function()
    if not getgc then return end
    task.wait(3)

    while alive() do
        local cfg = G()
        if not cfg.SpamHit then task.wait(0.5); continue end

        local net = findNetwork()
        if _cachedMe and net and #_sharedEnemyCache > 0 then
            local idx = (tick() * 10) % #_sharedEnemyCache
            local enemy = _sharedEnemyCache[math.floor(idx) + 1]
            if enemy then
                pcall(function() net:SendServerPacket(net.Packet.HIT, enemy.id, _cachedMe.objectID, 0) end)
            end
        end

        task.wait(math.max(0.1, cfg.SpamHitRate / 10))
    end
end)

---------- NEW: KILL AURA — hit ALL hostiles in range (uses shared cache) ----------
task.spawn(function()
    if not getgc then return end
    task.wait(4)

    while alive() do
        local cfg = G()
        if not cfg.KillAura then task.wait(0.5); continue end

        local me = findMyPlayer()
        local net = findNetwork()
        if not me or not net then task.wait(1); continue end

        -- Filter shared cache by range
        local myPos = nil
        pcall(function() myPos = me.controller.body.position end)
        if myPos and #_sharedEnemyCache > 0 then
            local hits = 0
            for _, enemy in _sharedEnemyCache do
                if enemy.pos then
                    local dist = math.sqrt((enemy.pos.X - myPos.X)^2 + (enemy.pos.Y - myPos.Y)^2)
                    if dist <= cfg.KillAuraRange then
                        pcall(function() net:SendServerPacket(net.Packet.HIT, enemy.id, me.objectID, 0) end)
                        hits += 1
                    end
                end
            end
            S.kills += hits
        end

        task.wait(jitter(0.3, 0.1))
    end
end)

---------- NEW: GODMODE — delete "Blast" projectiles from BaseLayer ----------
-- Enemy projectiles are ImageLabels named "Blast" added to BaseLayer.
-- Destroying them prevents client-side hit detection.
local _godmodeConn

-- Method 1: ChildAdded listener (instant, catches projectiles as they spawn)
local _godmodeChildConn
pcall(function() if getgenv().__AURORA_PQ_GODCHILD then getgenv().__AURORA_PQ_GODCHILD:Disconnect() end end)

local function setupGodmodeListener()
    local bl = getBaseLayer()
    if not bl then return end
    if _godmodeChildConn then pcall(function() _godmodeChildConn:Disconnect() end) end
    _godmodeChildConn = bl.ChildAdded:Connect(function(child)
        if not alive() then _godmodeChildConn:Disconnect() return end
        if not G().Godmode then return end
        if child.Name == "Blast" and child:IsA("ImageLabel") then
            child:Destroy()
            S.projHidden += 1
        end
    end)
    getgenv().__AURORA_PQ_GODCHILD = _godmodeChildConn
end
setupGodmodeListener()

-- Method 2: Heartbeat sweep for any Blasts that slipped through
_godmodeConn = RunService.Heartbeat:Connect(function()
    if not alive() then _godmodeConn:Disconnect() return end
    if not G().Godmode then return end
    pcall(function()
        local bl = getBaseLayer()
        if not bl then return end
        for _, child in bl:GetChildren() do
            if child.Name == "Blast" and child:IsA("ImageLabel") then
                child:Destroy()
                S.projHidden += 1
            end
        end
    end)
end)
getgenv().__AURORA_PQ_GODMODE = _godmodeConn

---------- NEW: DESYNC SPEED — position manipulation ----------
local _desyncConn
_desyncConn = RunService.Heartbeat:Connect(function(dt)
    if not alive() then _desyncConn:Disconnect() return end
    if not G().DesyncSpeed then return end

    pcall(function()
        local me = findMyPlayer()
        if not me then return end
        local ctrl = rawget(me, "controller")
        if not ctrl then return end
        local body = rawget(ctrl, "body")
        if not body or not body.position then return end

        -- Read current velocity/direction from controller
        local vel = rawget(ctrl, "velocity") or rawget(ctrl, "_velocity")
        if vel and typeof(vel) == "table" then
            local vx = vel.X or 0
            local vy = vel.Y or 0
            local mag = math.sqrt(vx * vx + vy * vy)
            if mag > 0.1 then
                local mult = G().DesyncValue - 1
                local pos = body.position
                if pos then
                    body.position = {
                        X = (pos.X or 0) + vx * dt * mult,
                        Y = (pos.Y or 0) + vy * dt * mult,
                    }
                end
            end
        end
    end)
end)
getgenv().__AURORA_PQ_DESYNC = _desyncConn

---------- NEW: PANIC TP — emergency recall at low HP ----------
task.spawn(function()
    local _lastPanic = 0
    while alive() do
        if G().PanicTP then
            local cur, max = parseHP()
            local pct = (cur / max) * 100
            local now = tick()
            if pct > 0 and pct <= G().PanicHPPct and (now - _lastPanic) > 5 then
                _lastPanic = now
                -- Try moving player body to spawn/recall
                pcall(function()
                    local me = findMyPlayer()
                    if me and me.controller and me.controller.body then
                        -- Move to origin (typical spawn)
                        me.controller.body.position = {X = 0, Y = 0}
                    end
                end)
                -- Also press R for game's recall
                pcall(function()
                    VIM:SendKeyEvent(true, Enum.KeyCode.R, false, game)
                    task.wait(0.1)
                    VIM:SendKeyEvent(false, Enum.KeyCode.R, false, game)
                end)
                S.panicTPs += 1
            end
        end
        task.wait(0.3)
    end
end)

---------- NEW: FOLLOW PLAYER ----------
task.spawn(function()
    while alive() do
        local cfg = G()
        if cfg.FollowPlayer and cfg.FollowTarget ~= "" then
            pcall(function()
                local me = findMyPlayer()
                if not me or not me.controller or not me.controller.body then return end

                local scene = findScene()
                if not scene then return end
                local players = rawget(scene, "_players")
                if not players then return end

                local myPos = me.controller.body.position
                for _, p in players do
                    if typeof(p) == "table" then
                        local name = rawget(p, "name") or rawget(p, "displayName") or ""
                        if string.lower(name) == string.lower(cfg.FollowTarget) then
                            local tPos = nil
                            pcall(function() tPos = p.controller.body.position end)
                            if tPos then
                                local dx = (tPos.X or 0) - (myPos.X or 0)
                                local dy = (tPos.Y or 0) - (myPos.Y or 0)
                                local dist = math.sqrt(dx*dx + dy*dy)
                                if dist > 30 then
                                    -- Move toward target
                                    local nx, ny = dx / dist, dy / dist
                                    me.controller.body.position = {
                                        X = (myPos.X or 0) + nx * 15,
                                        Y = (myPos.Y or 0) + ny * 15,
                                    }
                                end
                            end
                            break
                        end
                    end
                end
            end)
        end
        task.wait(0.15)
    end
end)

---------- NEW: TP MODE — click to teleport ----------
local _tpModeConn
_tpModeConn = UIS.InputBegan:Connect(function(input, gpe)
    if not alive() then _tpModeConn:Disconnect() return end
    if gpe then return end
    if not G().TPMode then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end

    pcall(function()
        local me = findMyPlayer()
        if not me or not me.controller or not me.controller.body then return end

        -- Convert screen click to game world offset
        -- The game renders in a 2D canvas — we need to figure out the offset from player
        local bl = getBaseLayer()
        if not bl then return end

        local mousePos = input.Position
        local px, py = getPlayerPixelPos()
        if px == 0 and py == 0 then return end

        -- Calculate offset in pixels, then scale to game units
        local dx = mousePos.X - px
        local dy = mousePos.Y - py

        -- Game units roughly map 1:1 with some scale factor
        local pos = me.controller.body.position
        me.controller.body.position = {
            X = (pos.X or 0) + dx * 0.5,
            Y = (pos.Y or 0) + dy * 0.5,
        }
    end)
end)

---------- NEW: AUTO RIFT/PORTAL ----------
task.spawn(function()
    while alive() do
        if G().AutoRift then
            pcall(function()
                local scene = findScene()
                if not scene then return end
                local gameObjects = rawget(scene, "_gameObjects")
                if not gameObjects then return end

                local me = findMyPlayer()
                if not me or not me.controller or not me.controller.body then return end
                local myPos = me.controller.body.position

                for _, obj in gameObjects do
                    if typeof(obj) == "table" then
                        local name = rawget(obj, "name") or rawget(obj, "type") or ""
                        if typeof(name) == "string" and (string.find(string.lower(name), "rift") or string.find(string.lower(name), "portal")) then
                            local oPos = nil
                            pcall(function() oPos = obj.body.position end)
                            if oPos then
                                local dx = (oPos.X or 0) - (myPos.X or 0)
                                local dy = (oPos.Y or 0) - (myPos.Y or 0)
                                local dist = math.sqrt(dx*dx + dy*dy)
                                if dist < 100 then
                                    -- Press E to interact
                                    VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                                    task.wait(0.05)
                                    VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                                end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(1)
    end
end)

---------- NEW: AUTO TP LOOT (item drops, not orbs) ----------
task.spawn(function()
    if not getgc then return end
    local _lootCache = {}
    local _lastLootScan = 0

    while alive() do
        local cfg = G()
        if not cfg.AutoTPLoot then task.wait(1); continue end

        -- Scan for loot every 2s
        if tick() - _lastLootScan > 2 then
            _lootCache = {}
            pcall(function()
                local scene = findScene()
                if scene then
                    local objs = rawget(scene, "_gameObjects")
                    if objs then
                        for _, obj in objs do
                            if typeof(obj) == "table"
                               and rawget(obj, "spawned") == true
                               and not rawget(obj, "hostile")
                               and not rawget(obj, "Collected")
                               and rawget(obj, "body") then
                                -- Loot items typically have a "pickup" or "item" type
                                local tp = rawget(obj, "type") or rawget(obj, "name") or ""
                                if typeof(tp) == "string" and (string.find(string.lower(tp), "item") or string.find(string.lower(tp), "loot") or string.find(string.lower(tp), "drop") or string.find(string.lower(tp), "chest") or string.find(string.lower(tp), "pickup")) then
                                    table.insert(_lootCache, obj)
                                end
                            end
                            if #_lootCache >= 20 then break end
                        end
                    end
                end
            end)
            _lastLootScan = tick()
        end

        -- TP each loot to player
        local me = findMyPlayer()
        if me and #_lootCache > 0 then
            local myPos
            pcall(function() myPos = me.controller.body.position end)
            if myPos then
                for _, loot in _lootCache do
                    pcall(function()
                        if loot.body and rawget(loot, "spawned") then
                            loot.body.position = myPos
                            S.lootCollected += 1
                        end
                    end)
                end
            end
        end

        task.wait(0.5)
    end
end)

---------- NEW: ANTI-STAFF DETECTION ----------
local _staffNames = {"admin", "moderator", "mod", "staff", "developer", "dev", "owner", "gm", "gamemaster"}
local _staffDetected = false

task.spawn(function()
    while alive() do
        if G().AntiStaff then
            pcall(function()
                for _, plr in Players:GetPlayers() do
                    if plr == Player then continue end
                    local name = string.lower(plr.Name)
                    local display = string.lower(plr.DisplayName)
                    local isStaff = false

                    for _, staffKey in _staffNames do
                        if string.find(name, staffKey) or string.find(display, staffKey) then
                            isStaff = true; break
                        end
                    end

                    -- Check for admin tools in character
                    if not isStaff and plr.Character then
                        for _, tool in plr.Character:GetChildren() do
                            if tool:IsA("Tool") then
                                local tName = string.lower(tool.Name)
                                if string.find(tName, "admin") or string.find(tName, "ban") or string.find(tName, "kick") then
                                    isStaff = true; break
                                end
                            end
                        end
                    end

                    if isStaff and not _staffDetected then
                        _staffDetected = true
                        -- Disable all exploit toggles
                        local cfg = G()
                        for k, v in cfg do
                            if type(v) == "boolean" and k ~= "AutoSave" and k ~= "AntiStaff" then
                                cfg[k] = false
                            end
                        end
                        -- Restore originals
                        pcall(function()
                            local me = findMyPlayer()
                            if me then
                                if _origFireRate then me.fireRate = _origFireRate end
                                if _origAbilityRate then me.abilityRate = _origAbilityRate end
                                local ctrl = rawget(me, "controller")
                                if ctrl and _origSpeed then ctrl.speedScalar = _origSpeed end
                            end
                        end)
                        warn("[Aurora] Staff detected: " .. plr.Name .. " — all exploits disabled")
                    end
                end

                -- Reset if staff leaves
                if _staffDetected then
                    local stillHere = false
                    for _, plr in Players:GetPlayers() do
                        if plr == Player then continue end
                        local name = string.lower(plr.Name)
                        local display = string.lower(plr.DisplayName)
                        for _, staffKey in _staffNames do
                            if string.find(name, staffKey) or string.find(display, staffKey) then
                                stillHere = true; break
                            end
                        end
                        if stillHere then break end
                    end
                    if not stillHere then _staffDetected = false end
                end
            end)
        end
        task.wait(5)
    end
end)

---------- NEW: MOB HUNT — auto-walk toward nearest enemy ----------
task.spawn(function()
    local _huntHeldH, _huntHeldV = nil, nil
    local function releaseHunt()
        if _huntHeldH then pcall(function() VIM:SendKeyEvent(false, _huntHeldH, false, game) end); _huntHeldH = nil end
        if _huntHeldV then pcall(function() VIM:SendKeyEvent(false, _huntHeldV, false, game) end); _huntHeldV = nil end
    end

    while alive() do
        local cfg = G()
        if cfg.MobHunt and not cfg.OrbitTarget then
            pcall(function()
                local px, py = getPlayerPixelPos()
                if px == 0 and py == 0 then releaseHunt(); return end

                local enemy = findNearestEnemy()
                if enemy and enemy.frame and enemy.frame.Parent then
                    local dx = enemy.px - px
                    local dy = enemy.py - py
                    local dist = math.sqrt(dx*dx + dy*dy)

                    if dist > 20 then
                        local needH = math.abs(dx) > 8 and (dx > 0 and Enum.KeyCode.D or Enum.KeyCode.A) or nil
                        local needV = math.abs(dy) > 8 and (dy > 0 and Enum.KeyCode.S or Enum.KeyCode.W) or nil

                        if needH ~= _huntHeldH then
                            if _huntHeldH then VIM:SendKeyEvent(false, _huntHeldH, false, game) end
                            if needH then VIM:SendKeyEvent(true, needH, false, game) end
                            _huntHeldH = needH
                        end
                        if needV ~= _huntHeldV then
                            if _huntHeldV then VIM:SendKeyEvent(false, _huntHeldV, false, game) end
                            if needV then VIM:SendKeyEvent(true, needV, false, game) end
                            _huntHeldV = needV
                        end
                    else
                        releaseHunt()
                    end
                else
                    releaseHunt()
                end
            end)
        else
            releaseHunt()
        end
        task.wait(0.1)
    end
end)

---------- NEW: BOSS HUNT — find and TP to bosses ----------
local _cachedBosses = {}
local _lastBossScan = 0

local function scanBosses()
    if not getgc then return end
    if tick() - _lastBossScan < 3 then return end

    _cachedBosses = {}
    pcall(function()
        for _, obj in getgc(true) do
            if typeof(obj) == "table" and rawget(obj, "hostile") == true
               and rawget(obj, "spawned") == true and rawget(obj, "hp") then
                local hp = obj.hp or 0
                local name = rawget(obj, "name") or rawget(obj, "type") or ""
                -- Bosses: high HP or name contains boss/elite/mini
                local isBoss = false
                if hp > 500 then isBoss = true end
                if typeof(name) == "string" then
                    local ln = string.lower(name)
                    if string.find(ln, "boss") or string.find(ln, "elite") or string.find(ln, "mini") or string.find(ln, "king") or string.find(ln, "queen") or string.find(ln, "champion") or string.find(ln, "lord") then
                        isBoss = true
                    end
                end
                if isBoss then
                    table.insert(_cachedBosses, {
                        obj = obj,
                        id = rawget(obj, "objectID"),
                        name = typeof(name) == "string" and name or "Unknown",
                        hp = hp,
                    })
                end
                if #_cachedBosses >= 10 then break end
            end
        end
    end)
    _lastBossScan = tick()
end

task.spawn(function()
    if not getgc then return end
    task.wait(4)

    while alive() do
        local cfg = G()
        if cfg.BossHunt then
            scanBosses()
            local me = findMyPlayer()
            if me and me.controller and me.controller.body and #_cachedBosses > 0 then
                local targetBoss = nil

                if cfg.TargetBoss == "Any" then
                    targetBoss = _cachedBosses[1]
                else
                    for _, b in _cachedBosses do
                        if string.find(string.lower(b.name), string.lower(cfg.TargetBoss)) then
                            targetBoss = b; break
                        end
                    end
                    if not targetBoss then targetBoss = _cachedBosses[1] end
                end

                if targetBoss and targetBoss.obj then
                    pcall(function()
                        local bPos = targetBoss.obj.body.position
                        if bPos then
                            local myPos = me.controller.body.position
                            local dx = (bPos.X or 0) - (myPos.X or 0)
                            local dy = (bPos.Y or 0) - (myPos.Y or 0)
                            local dist = math.sqrt(dx*dx + dy*dy)
                            if dist > 50 then
                                -- TP close to boss
                                me.controller.body.position = {
                                    X = (bPos.X or 0) + 30,
                                    Y = (bPos.Y or 0),
                                }
                            end
                        end
                    end)
                end
            end
        end
        task.wait(2)
    end
end)

---------- IMPROVED: Auto Collect EXP Orbs ----------
-- Scan getgc in background thread, move ALL orbs to player on Heartbeat
local _orbCache = {}

-- Background scanner — runs every 1s, populates _orbCache (increased from 50 to 200)
task.spawn(function()
    if not getgc then return end
    while alive() do
        if G().AutoCollectOrbs then
            local fresh = {}
            for _, obj in getgc(true) do
                if typeof(obj) == "table" and rawget(obj, "Collected") and rawget(obj, "body")
                   and rawget(obj, "spawned") == true and rawget(obj, "value") then
                    table.insert(fresh, obj)
                    if #fresh >= 200 then break end
                end
            end
            _orbCache = fresh
        end
        task.wait(1)
    end
end)

-- Mover — Heartbeat, moves ALL cached orbs per frame (no round-robin, no stutter)
local _orbIdx = 1
local _orbConn = RunService.Heartbeat:Connect(function()
    if not alive() then _orbConn:Disconnect() return end
    if not G().AutoCollectOrbs or #_orbCache == 0 or not _cachedMe then return end

    local playerPos
    pcall(function() playerPos = _cachedMe.controller.body.position end)
    if not playerPos then return end

    -- Move ALL orbs to player each frame
    for i = 1, #_orbCache do
        local orb = _orbCache[i]
        if orb and rawget(orb, "spawned") and orb.body then
            pcall(function()
                orb.body.position = playerPos
                S.orbsCollected += 1
            end)
        end
    end
end)
getgenv().__AURORA_PQ_ORBS = _orbConn

---------- MOB ESP ----------
task.spawn(function()
    local espRegistry = {}
    while alive() and task.wait(0.5) do
        pcall(function()
            local enemies = G().MobESP and findEnemies() or {}
            local espSet = {}
            for _, e in enemies do
                espSet[e.frame] = true
                if not espRegistry[e.frame] then
                    -- Red border box around enemy — parented to enemy frame so it moves with it
                    local box = Instance.new("Frame")
                    box.Name = "AuroraESP"
                    box.Size = UDim2.new(1, 6, 1, 6)
                    box.Position = UDim2.fromOffset(-3, -3)
                    box.BackgroundTransparency = 1
                    box.BorderSizePixel = 0
                    box.ZIndex = e.frame.ZIndex + 1

                    -- 4 edge lines for the box
                    local function edge(sz, pos)
                        local l = Instance.new("Frame")
                        l.Size = sz; l.Position = pos
                        l.BackgroundColor3 = Color3.fromRGB(255, 40, 40)
                        l.BackgroundTransparency = 0.1
                        l.BorderSizePixel = 0
                        l.ZIndex = box.ZIndex
                        l.Parent = box
                        return l
                    end
                    edge(UDim2.new(1, 0, 0, 2), UDim2.new(0, 0, 0, 0))  -- top
                    edge(UDim2.new(1, 0, 0, 2), UDim2.new(0, 0, 1, -2)) -- bottom
                    edge(UDim2.new(0, 2, 1, 0), UDim2.new(0, 0, 0, 0))  -- left
                    edge(UDim2.new(0, 2, 1, 0), UDim2.new(1, -2, 0, 0)) -- right

                    box.Parent = e.frame
                    espRegistry[e.frame] = {box = box}
                end
            end
            for target, entry in espRegistry do
                if not espSet[target] or not G().MobESP then
                    pcall(function() entry.box:Destroy() end)
                    espRegistry[target] = nil
                end
            end
        end)
    end
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
    gold     = Color3.fromRGB(240, 180, 30),
    cyan     = Color3.fromRGB(0, 200, 220),
    orange   = Color3.fromRGB(255, 160, 40),
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
local gui = create("ScreenGui", { Name = "Aurora", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50, IgnoreGuiInset = true })
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

---------- MOBILE DETECTION ----------
local _viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920, 1080)
local _isMobile = UIS.TouchEnabled and (_viewport.X < 1200)
local _scale = _isMobile and math.clamp(_viewport.X / 700, 0.55, 0.85) or 1

---------- LAYOUT ----------
local SIDEBAR_W = 110; local TOTAL_W = 660; local TOTAL_H = 455; local TOP_H = 40; local GAP = 6
local CONTENT_X = SIDEBAR_W + GAP; local CONTENT_Y = TOP_H + 4; local CONTENT_H = TOTAL_H - CONTENT_Y - 6
local AVAIL_W = TOTAL_W - CONTENT_X - 6; local LEFT_PW = math.floor(AVAIL_W * 0.58); local RIGHT_PW = AVAIL_W - LEFT_PW - GAP

---------- MAIN ----------
local main = create("Frame", { Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H), Position = _isMobile and UDim2.new(0.5, -TOTAL_W * _scale / 2, 0, 40) or UDim2.fromOffset(16, 60), BackgroundColor3 = C.bg, BackgroundTransparency = 0, BorderSizePixel = 0, Active = true, ClipsDescendants = true }, gui)
corner(main, 12); stroke(main, C.stroke, 1, 0.2)
if _scale ~= 1 then create("UIScale", { Scale = _scale }, main) end

---------- TOP BAR ----------
local topBar = create("Frame", { Name = "TopBar", Size = UDim2.new(1, 0, 0, TOP_H), BackgroundColor3 = C.sidebar, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 5 }, main)
corner(topBar, 12)
create("Frame", { Name = "TopDivider", Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.stroke, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 5 }, topBar)
create("ImageLabel", { Name = "Logo", Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1, Image = "rbxassetid://77299357494181", ScaleType = Enum.ScaleType.Fit, ZIndex = 6 }, topBar)
lbl(topBar, { Name = "Title", Size = UDim2.new(0, 80, 1, 0), Position = UDim2.fromOffset(44, 0), Text = "Aurora", TextSize = 14, Font = Enum.Font.GothamBlack, TextColor3 = C.accent, ZIndex = 6 })

local gameName = "[ALPHA] Pixel Quest!"
pcall(function() gameName = game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).Name end)
lbl(topBar, { Name = "Game", Size = UDim2.new(0, 200, 1, 0), Position = UDim2.new(1, -310, 0, 0), Text = gameName, TextSize = 11, Font = Enum.Font.Gotham, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 6 })

local minBtn = create("Frame", { Name = "Min", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -72, 0.5, -15), BackgroundTransparency = 1, Active = true, ZIndex = 6 }, topBar)
lbl(minBtn, { Size = UDim2.new(1,0,1,0), Text = "\xE2\x80\x93", TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7 })
local closeBtn = create("Frame", { Name = "Close", Size = UDim2.fromOffset(30, 30), Position = UDim2.new(1, -38, 0.5, -15), BackgroundTransparency = 1, Active = true, ZIndex = 6 }, topBar)
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
    { name = "Combat",   color = Color3.fromRGB(0, 180, 220) },
    { name = "Defense",  color = Color3.fromRGB(255, 80, 80) },
    { name = "Movement", color = Color3.fromRGB(100, 220, 100) },
    { name = "Loot",     color = Color3.fromRGB(240, 180, 30) },
    { name = "Visuals",  color = Color3.fromRGB(255, 200, 80) },
    { name = "Utility",  color = Color3.fromRGB(180, 130, 255) },
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
        p.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 45)
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

local function sliderRow(name, cfgKey, minVal, maxVal, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Size = UDim2.new(1,0,0,32), BackgroundColor3 = C.card, BorderSizePixel = 0, LayoutOrder = o,
    }, panel)
    corner(row, 8)
    lbl(row, {Size=UDim2.new(0.35,0,1,0), Position=UDim2.fromOffset(8,0), Text=name, TextSize=9, Font=Enum.Font.GothamSemibold, TextColor3=C.dim})
    local valLbl = lbl(row, {Size=UDim2.new(0.15,0,1,0), Position=UDim2.new(0.85,0,0,0), Text=string.format("%.1f", CFG[cfgKey] or minVal), TextSize=9, Font=Enum.Font.GothamBold, TextColor3=C.accent, TextXAlignment=Enum.TextXAlignment.Center})
    local trackFrame = create("Frame", {Size=UDim2.new(0.45,0,0,6), Position=UDim2.new(0.38,0,0.5,-3), BackgroundColor3=C.sliderBg, BorderSizePixel=0}, row)
    corner(trackFrame, 3)
    local fillFrame = create("Frame", {Size=UDim2.new(math.clamp(((CFG[cfgKey] or minVal) - minVal) / (maxVal - minVal), 0, 1),0,1,0), BackgroundColor3=C.accent, BorderSizePixel=0}, trackFrame)
    corner(fillFrame, 3)
    local knob = create("Frame", {Size=UDim2.fromOffset(14,14), Position=UDim2.new(fillFrame.Size.X.Scale, -7, 0.5, -7), BackgroundColor3=C.text, BorderSizePixel=0, Active=true, ZIndex=3}, trackFrame)
    corner(knob, 7)
    local dragging = false
    knob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = true end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and CFG.AutoSave then pcall(function() saveCFG() end) end
            dragging = false
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local rel = math.clamp((input.Position.X - trackFrame.AbsolutePosition.X) / trackFrame.AbsoluteSize.X, 0, 1)
            local val = minVal + rel * (maxVal - minVal)
            val = math.floor(val * 10 + 0.5) / 10
            CFG[cfgKey] = val
            fillFrame.Size = UDim2.new(rel, 0, 1, 0)
            knob.Position = UDim2.new(rel, -7, 0.5, -7)
            valLbl.Text = string.format("%.1f", val)
        end
    end)
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

local function cycleSelector(name, cfgKey, options, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "C_" .. name, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(0.5,0,1,0), Position = UDim2.fromOffset(10,0), Text = name, TextSize = 11, Font = Enum.Font.GothamSemibold, TextColor3 = C.dim })
    local valLabel = lbl(row, {
        Name = "CycleVal", Size = UDim2.new(0.45,-8,1,0), Position = UDim2.new(0.5,4,0,0),
        Text = tostring(CFG[cfgKey] or options[1]), TextSize = 11, Font = Enum.Font.GothamBold,
        TextColor3 = C.accent, TextXAlignment = Enum.TextXAlignment.Right,
    })
    connectClick(row, function()
        local cur = CFG[cfgKey]
        local idx = 1
        for i, v in options do
            if v == cur then idx = i; break end
        end
        idx = (idx % #options) + 1
        CFG[cfgKey] = options[idx]
        valLabel.Text = tostring(options[idx])
        if CFG.AutoSave then saveCFG() end
    end)
    return row, valLabel
end

local function textInputRow(name, cfgKey, panel)
    panel = panel or _curLeft
    local o = nextOrder(panel)
    local row = create("Frame", {
        Name = "TI_" .. name, Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.card,
        BackgroundTransparency = 0, BorderSizePixel = 0, LayoutOrder = o, Active = true,
    }, panel)
    corner(row, 8)
    lbl(row, { Size = UDim2.new(0.4,0,1,0), Position = UDim2.fromOffset(10,0), Text = name, TextSize = 11, Font = Enum.Font.GothamSemibold, TextColor3 = C.dim })
    local box = create("TextBox", {
        Size = UDim2.new(0.55,-8,0,22), Position = UDim2.new(0.42,0,0.5,-11),
        BackgroundColor3 = C.sliderBg, BorderSizePixel = 0,
        Text = tostring(CFG[cfgKey] or ""), PlaceholderText = "Enter name...",
        TextColor3 = C.text, PlaceholderColor3 = C.dim,
        Font = Enum.Font.Gotham, TextSize = 11, ClearTextOnFocus = false,
    }, row)
    corner(box, 6)
    box.FocusLost:Connect(function()
        CFG[cfgKey] = box.Text
        if CFG.AutoSave then saveCFG() end
    end)
    return row
end

---------- TAB 1: COMBAT ----------
setPanel(leftContainers[1], rightContainers[1])

sectionHeader("Attack", _curLeft)
toggleRow("Auto Attack", "AutoAttack", _curLeft)
toggleRow("Aim Assist", "AimAssist", _curLeft)
toggleRow("Auto Fire", "AutoFire", _curLeft)
toggleRow("Fast Attack", "FastAttack", _curLeft)
sliderRow("Fire Rate", "FireRateVal", 0.01, 100, _curLeft)
toggleRow("Fast Ability", "FastAbility", _curLeft)
sliderRow("Ability Rate", "AbilityVal", 0.01, 100, _curLeft)
toggleRow("No Cooldowns", "NoCooldowns", _curLeft)

sectionHeader("Aura", _curLeft)
toggleRow("Kill Aura", "KillAura", _curLeft)
sliderRow("Aura Range", "KillAuraRange", 50, 1000, _curLeft)
toggleRow("Spam Hit", "SpamHit", _curLeft)
sliderRow("Hit Rate", "SpamHitRate", 1, 100, _curLeft)
sliderRow("Speed Value", "SpeedValue", 1, 100, _curLeft)
sliderRow("Desync Value", "DesyncValue", 1.5, 100, _curLeft)

sectionHeader("Hunting", _curLeft)
toggleRow("Mob Hunt", "MobHunt", _curLeft)
toggleRow("Boss Hunt", "BossHunt", _curLeft)
cycleSelector("Target Boss", "TargetBoss", {"Any", "Boss", "Elite", "King", "Queen", "Champion", "Lord", "Mini"}, _curLeft)

sectionHeader("Boss Actions", _curLeft)
actionButton("TP to Closest Boss", C.orange, _curLeft, function()
    scanBosses()
    local me = findMyPlayer()
    if me and me.controller and me.controller.body and #_cachedBosses > 0 then
        pcall(function()
            local boss = _cachedBosses[1]
            if boss and boss.obj and boss.obj.body then
                me.controller.body.position = {
                    X = (boss.obj.body.position.X or 0) + 30,
                    Y = boss.obj.body.position.Y or 0,
                }
            end
        end)
    end
end)

sectionHeader("Projectile Mods", _curRight)
toggleRow("Mod Range", "ModRange", _curRight)
sliderRow("Range", "ProjRange", 0.1, 100, _curRight)
toggleRow("Mod Speed", "ModSpeed", _curRight)
sliderRow("Speed", "ProjSpeed", 0.1, 100, _curRight)
toggleRow("Mod Dmg Min", "ModDmgMin", _curRight)
sliderRow("Dmg Min", "ProjDmgMin", 0.1, 100, _curRight)
toggleRow("Mod Dmg Max", "ModDmgMax", _curRight)
sliderRow("Dmg Max", "ProjDmgMax", 0.1, 100, _curRight)
toggleRow("Mod Blasts", "ModBlasts", _curRight)
sliderRow("Blasts", "ProjBlasts", 1, 12, _curRight)
toggleRow("Mod Hits", "ModHits", _curRight)
sliderRow("Hits/Entity", "ProjHits", 1, 12, _curRight)
toggleRow("Mod AoE", "ModAoE", _curRight)
sliderRow("AoE Radius", "ProjAoE", 0, 12, _curRight)
toggleRow("Mod Penetrate", "ModPen", _curRight)
sliderRow("Def Pen", "ProjPen", 0, 1, _curRight)
toggleRow("Mod Max Hits", "ModMaxHits", _curRight)
sliderRow("Max Hits", "MaxHitsVal", 1, 100, _curRight)

sectionHeader("Combat Stats", _curRight)
local _infoAttacks = infoRow("Attacks", "0", _curRight)
local _infoRetreats = infoRow("Retreats", "0", _curRight)
local _infoKills = infoRow("Kill Aura Hits", "0", _curRight)
local _infoEnemy = infoRow("Nearest Mob", "---", _curRight)
local _infoBosses = infoRow("Bosses Found", "0", _curRight)

sectionHeader("Player", _curRight)
local _infoHP = infoRow("Health", "---", _curRight)
local _infoMana = infoRow("Mana", "---", _curRight)
local _infoLevel = infoRow("Level", "---", _curRight)

---------- TAB 2: DEFENSE ----------
setPanel(leftContainers[2], rightContainers[2])

sectionHeader("Protection", _curLeft)
toggleRow("Godmode (Hide Proj)", "Godmode", _curLeft)
toggleRow("Anti-Staff", "AntiStaff", _curLeft)

sectionHeader("Retreat", _curLeft)
toggleRow("Auto Potion", "AutoPotion", _curLeft)
toggleRow("Auto Retreat", "AutoRetreat", _curLeft)
toggleRow("Panic TP", "PanicTP", _curLeft)
sliderRow("Panic HP %", "PanicHPPct", 5, 50, _curLeft)

sectionHeader("Defense Stats", _curRight)
local _infoProjHidden = infoRow("Proj Hidden", "0", _curRight)
local _infoPanicTPs = infoRow("Panic TPs", "0", _curRight)
local _infoStaff = infoRow("Staff Detected", "No", _curRight)

---------- TAB 3: MOVEMENT ----------
setPanel(leftContainers[3], rightContainers[3])

sectionHeader("Speed", _curLeft)
toggleRow("Desync Speed", "DesyncSpeed", _curLeft)
sliderRow("Speed Multi", "SpeedValue", 1, 10, _curLeft)
toggleRow("Desync Speed", "DesyncSpeed", _curLeft)
sliderRow("Desync Multi", "DesyncValue", 1.5, 5, _curLeft)

sectionHeader("Teleport", _curLeft)
toggleRow("Orbit Target", "OrbitTarget", _curLeft)
toggleRow("Noclip", "Noclip", _curLeft)
toggleRow("TP Mode (Click)", "TPMode", _curLeft)

sectionHeader("Follow", _curLeft)
toggleRow("Follow Player", "FollowPlayer", _curLeft)
textInputRow("Target Name", "FollowTarget", _curLeft)

sectionHeader("Auto", _curLeft)
toggleRow("Auto Interact", "AutoInteract", _curLeft)
toggleRow("Auto Rift/Portal", "AutoRift", _curLeft)

sectionHeader("Movement Info", _curRight)
local _infoOrbit = infoRow("Orbit", "Off", _curRight)
local _infoStatus = infoRow("Status", "Idle", _curRight)
local _infoFollowing = infoRow("Following", "None", _curRight)
local _infoTPMode = infoRow("TP Mode", "Off", _curRight)

---------- TAB 4: LOOT ----------
setPanel(leftContainers[4], rightContainers[4])

sectionHeader("Collection", _curLeft)
toggleRow("Auto Collect Orbs", "AutoCollectOrbs", _curLeft)
toggleRow("Auto TP Loot", "AutoTPLoot", _curLeft)

sectionHeader("Loot Stats", _curRight)
local _infoOrbsCollected = infoRow("Orbs Moved", "0", _curRight)
local _infoLootCollected = infoRow("Loot Collected", "0", _curRight)

---------- TAB 5: VISUALS ----------
setPanel(leftContainers[5], rightContainers[5])

sectionHeader("ESP", _curLeft)
toggleRow("Mob ESP", "MobESP", _curLeft)

sectionHeader("Visual Info", _curRight)
local _infoMobCount = infoRow("Mobs Found", "0", _curRight)

---------- TAB 6: UTILITY ----------
setPanel(leftContainers[6], rightContainers[6])

sectionHeader("Safety", _curLeft)
toggleRow("Anti-AFK", "AntiAFK", _curLeft)

sectionHeader("Session", _curRight)
local _infoRuntime = infoRow("Runtime", "0m", _curRight)

---------- TAB 7: CONFIG ----------
setPanel(leftContainers[7], rightContainers[7])

sectionHeader("Config Management", _curLeft)
toggleRow("Auto-Save", "AutoSave", _curLeft)

actionButton("Save Config", C.green, _curLeft, function() saveCFG() end)
actionButton("Load Config", C.accent, _curLeft, function() loadSavedCFG() end)
actionButton("Reset All", C.red, _curLeft, function()
    for k, v in CFG do
        if type(v) == "boolean" then CFG[k] = false end
    end
    CFG.AutoSave = true
    CFG.TargetBoss = "Any"
    CFG.FollowTarget = ""
    saveCFG()
end)

sectionHeader("Config Info", _curRight)
infoRow("File", _cfgFileName, _curRight)

sectionHeader("Active Features", _curRight)
local _cfgActiveList = lbl(rightContainers[7], {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 120),
    Text = "None", TextSize = 10, Font = Enum.Font.Gotham, TextColor3 = C.dim,
    TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
    LayoutOrder = nextOrder(rightContainers[7]),
})

---------- STATUS UPDATE LOOP ----------
task.spawn(function()
    while alive() and task.wait(jitter(1, 0.5)) do
        pcall(function()
            local cfg = G()
            _infoAttacks.Text = tostring(S.attacks)
            _infoRetreats.Text = tostring(S.retreats)
            _infoKills.Text = tostring(S.kills)

            local enemy = _cachedEnemy
            _infoEnemy.Text = (enemy and enemy.frame and enemy.frame.Parent) and "Detected" or "None"

            -- Boss count
            scanBosses()
            _infoBosses.Text = tostring(#_cachedBosses)

            _infoHP.Text = getHealthText()
            _infoMana.Text = getManaText()
            _infoLevel.Text = getLevelText()

            -- Defense stats
            _infoProjHidden.Text = tostring(S.projHidden)
            _infoPanicTPs.Text = tostring(S.panicTPs)
            _infoStaff.Text = _staffDetected and "YES" or "No"

            -- Movement stats
            _infoOrbit.Text = cfg.OrbitTarget and "Active" or "Off"
            _infoStatus.Text = cfg.AutoAttack and "Attacking" or (cfg.AimAssist and "Aiming" or "Idle")
            _infoFollowing.Text = (cfg.FollowPlayer and cfg.FollowTarget ~= "") and cfg.FollowTarget or "None"
            _infoTPMode.Text = cfg.TPMode and "Active" or "Off"

            -- Loot stats
            _infoOrbsCollected.Text = tostring(S.orbsCollected)
            _infoLootCollected.Text = tostring(S.lootCollected)

            -- Visuals
            local enemies = findEnemies()
            _infoMobCount.Text = tostring(#enemies)

            local elapsed = tick() - S.session
            local mins = math.floor(elapsed / 60)
            local hrs = math.floor(mins / 60)
            _infoRuntime.Text = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local active = {}
            for k, v in cfg do
                if type(v) == "boolean" and v and k ~= "AutoSave" then table.insert(active, k) end
            end
            _cfgActiveList.Text = #active > 0 and table.concat(active, "\n") or "None"
            _cfgActiveList.Size = UDim2.new(1, 0, 0, math.max(60, #active * 14 + 45))
        end)
    end
end)

switchTab(1)
print("[Aurora v4] Pixel Quest loaded — 16 new features")

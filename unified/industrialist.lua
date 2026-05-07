--!native
-- Aurora/industrialist v0.6.0
-- AUTH: client-only (no remote calls — all features are visual or local-physics)
-- v0.4.0: + Aurora v5 UI scaffold (5 tabs: Movement / Aerial / Visuals / Misc / Info)
-- v0.6.0: PLACEMENT LAG FIX — removed Workspace.DescendantAdded listeners (were firing
--   hundreds of times per machine placement). Smokestacks now scanned once at boot only;
--   new factories will smoke. Performance Mode applied only on transition (not per-add).
--   Net: zero per-placement listener overhead.
-- Game: Industrialist by Mamytema Studios
--   PlaceId 9312740628 (Ingame) / RootPlaceId 9192423027
--   UniverseId 3448264866
--   "Factory construction and expansion game inspired by Mindustry, Factorio"
-- TESTED: 2026-04-28 / Industrialist live session

-- Architecture notes (from initial recon):
--   • Old Remotes pattern (named REs/RFs in ReplicatedStorage)
--   • PlacementSystem.Buy / Place / Delete drives the build flow
--   • Research.Unlock / Update / Get drives the tech tree
--   • Pollution = Lighting.PollutionAtmosphere (TweenService-animated by player score)
--   • No leaderstats — currency tracked elsewhere (HUD.CurrencyHolder)
--   • DEBUG ScreenGui present in shipped client — worth probing later
--   • Honeypot risks: PermissionsNetwork.AdminAction (do NOT fire)

-- ============================================================
-- COMPAT
-- ============================================================
local gethui = rawget(_G, "gethui") or function() return game:GetService("CoreGui") end

-- ============================================================
-- ZOMBIE-PROOF SESSION
-- ============================================================
if getgenv().__AURORA_INDUSTRIALIST_CFG2 then
    for k, v in pairs(getgenv().__AURORA_INDUSTRIALIST_CFG2) do
        if type(v) == "boolean" then getgenv().__AURORA_INDUSTRIALIST_CFG2[k] = false end
    end
end
pcall(function()
    if getgenv().__AURORA_INDUSTRIALIST_CONNS then
        for _, c in ipairs(getgenv().__AURORA_INDUSTRIALIST_CONNS) do pcall(c.Disconnect, c) end
    end
end)
getgenv().__AURORA_INDUSTRIALIST_CONNS = {}

getgenv().__AURORA_INDUSTRIALIST_SESSION = tick()
local _mySession = getgenv().__AURORA_INDUSTRIALIST_SESSION
local function alive() return getgenv().__AURORA_INDUSTRIALIST_SESSION == _mySession end

-- ============================================================
-- CFG
-- ============================================================
getgenv().__AURORA_INDUSTRIALIST_CFG3 = {
    -- Visual
    NoFog = true,
    DisableSmokeStacks = true,
    DisableDOF = true,
    PerformanceMode = false,    -- aggressive: kill all non-pollution particles + lower render

    -- Movement
    SpeedEnabled = false,
    SpeedValue = 50,            -- vanilla 22, max 100
    JumpEnabled = false,
    JumpValue = 100,            -- vanilla 50, max 200
    InfiniteJump = false,
    Noclip = false,             -- pass through walls/machines
    Fly = false,                -- toggle with key
    FlySpeed = 80,              -- studs/sec
    FlyKey = Enum.KeyCode.F2,   -- toggle key

    -- Camera
    FreeCam = false,            -- detach camera, WASD+mouse
    FreeCamKey = Enum.KeyCode.F1,
    FreeCamSpeed = 100,

    -- QoL
    AntiAFK = true,

    -- UI state
    PanelOpen = true,
    ActiveTab = "Movement",

    _GameName = "Industrialist",
    _Version = "0.6.0",
}
local CFG = getgenv().__AURORA_INDUSTRIALIST_CFG3
local CONNS = getgenv().__AURORA_INDUSTRIALIST_CONNS
local function track(c) table.insert(CONNS, c); return c end

-- ============================================================
-- SERVICES + STATE
-- ============================================================
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer

-- ============================================================
-- FEATURE: NO POLLUTION / NO FOG
-- Property-listener-based — beats game's TweenService animation
-- of pollution density by snapping back every frame the tween writes.
-- ============================================================
local function isSmokeStackParticle(d)
    if not d:IsA("ParticleEmitter") or not d.Parent then return false end
    local p = d.Parent
    if p.Name:lower():find("smokestack") then return true end
    local pp = p.Parent
    if pp and pp.Name:lower():find("smokestack") then return true end
    return false
end

local function lockAtmosphere(atm)
    if not atm or not atm:IsA("Atmosphere") then return end
    local function flatten()
        if not alive() or not CFG.NoFog or not atm.Parent then return end
        if atm.Density ~= 0 then atm.Density = 0 end
        if atm.Haze ~= 0 then atm.Haze = 0 end
        if atm.Glare ~= 0 then atm.Glare = 0 end
    end
    flatten()
    track(atm:GetPropertyChangedSignal("Density"):Connect(flatten))
    track(atm:GetPropertyChangedSignal("Haze"):Connect(flatten))
    track(atm:GetPropertyChangedSignal("Glare"):Connect(flatten))
end

local function lockColorCorrection(cc)
    if not cc or not cc:IsA("ColorCorrectionEffect") then return end
    local function disable()
        if not alive() or not CFG.NoFog or not cc.Parent then return end
        if cc.Enabled then cc.Enabled = false end
    end
    disable()
    track(cc:GetPropertyChangedSignal("Enabled"):Connect(disable))
end

local function lockDOF(dof)
    if not dof or not dof:IsA("DepthOfFieldEffect") then return end
    local function disable()
        if not alive() or not CFG.NoFog or not CFG.DisableDOF or not dof.Parent then return end
        if dof.Enabled then dof.Enabled = false end
    end
    disable()
    track(dof:GetPropertyChangedSignal("Enabled"):Connect(disable))
end

local function lockSmokeStack(pe)
    if not isSmokeStackParticle(pe) then return end
    local function disable()
        if not alive() or not CFG.NoFog or not CFG.DisableSmokeStacks or not pe.Parent then return end
        if pe.Enabled then pe.Enabled = false end
    end
    disable()
    track(pe:GetPropertyChangedSignal("Enabled"):Connect(disable))
end

local function enableNoFog()
    for _, c in ipairs(Lighting:GetChildren()) do
        if c:IsA("Atmosphere") and c.Name:lower():find("pollut") then
            lockAtmosphere(c)
        elseif c:IsA("ColorCorrectionEffect") and c.Name:lower():find("pollut") then
            lockColorCorrection(c)
        elseif c:IsA("DepthOfFieldEffect") then
            lockDOF(c)
        end
    end
    for _, d in ipairs(Workspace:GetDescendants()) do
        if isSmokeStackParticle(d) then lockSmokeStack(d) end
    end
    track(Lighting.ChildAdded:Connect(function(c)
        if not alive() or not CFG.NoFog then return end
        task.defer(function()
            if not c.Parent then return end
            if c:IsA("Atmosphere") and c.Name:lower():find("pollut") then
                lockAtmosphere(c)
            elseif c:IsA("ColorCorrectionEffect") and c.Name:lower():find("pollut") then
                lockColorCorrection(c)
            elseif c:IsA("DepthOfFieldEffect") then
                lockDOF(c)
            end
        end)
    end))
    -- v0.6.0: Workspace.DescendantAdded REMOVED — was the placement-lag culprit.
    -- New machines placed after script load will have visible smokestacks until next reload.
end

-- ============================================================
-- FEATURE: WALKSPEED + JUMPPOWER + INFINITE JUMP
-- Heartbeat poll (250ms) so CFG toggles auto-apply, plus auto-
-- restore to vanilla when CFG is flipped off. Cheaper than 60Hz
-- and beats Industrialist's HUDHandler periodic resets.
-- ============================================================
local RunService = game:GetService("RunService")

local function enableMovement()
    -- Heartbeat poll for speed + jump
    local _last = 0
    track(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        local now = tick()
        if now - _last < 0.25 then return end
        _last = now

        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not hum then return end

        if CFG.SpeedEnabled then
            if hum.WalkSpeed ~= CFG.SpeedValue then hum.WalkSpeed = CFG.SpeedValue end
        else
            if hum.WalkSpeed > 22.5 then hum.WalkSpeed = 22 end
        end
        if CFG.JumpEnabled then
            hum.UseJumpPower = true
            if hum.JumpPower ~= CFG.JumpValue then hum.JumpPower = CFG.JumpValue end
        else
            if hum.JumpPower > 51 then hum.JumpPower = 50 end
        end
    end))

    -- Infinite jump
    track(UIS.JumpRequest:Connect(function()
        if not alive() or not CFG.InfiniteJump then return end
        local char = LP.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end))
end

-- ============================================================
-- FEATURE: ANTI-AFK
-- Industrialist will idle-kick after 20min. VirtualUser click
-- on Idled signal resets the timer client-side without input.
-- ============================================================
local function enableAntiAFK()
    track(LP.Idled:Connect(function()
        if not alive() or not CFG.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

-- ============================================================
-- FEATURE: NOCLIP
-- Heartbeat-loop sets CanCollide=false on every character part
-- whenever the toggle is on. Restored to true the moment toggle flips.
-- ============================================================
local function enableNoclip()
    track(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        local char = LP.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
                if CFG.Noclip and p.CanCollide then
                    p.CanCollide = false
                elseif not CFG.Noclip and not p.CanCollide and p.Name ~= "Handle" then
                    -- Don't force back to true — game manages this when toggle is off
                end
            end
        end
    end))
end

-- ============================================================
-- FEATURE: FLY
-- BodyVelocity on HumanoidRootPart, WASD + Space/LShift = up/down,
-- direction relative to current camera. Toggle with FlyKey (F2 default).
-- Cleanly detaches BV when disabled or character respawns.
-- ============================================================
local Camera = workspace.CurrentCamera
local function getRoot()
    local char = LP.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local _flyBV, _flyBG = nil, nil
local function disposeFly()
    if _flyBV then pcall(function() _flyBV:Destroy() end); _flyBV = nil end
    if _flyBG then pcall(function() _flyBG:Destroy() end); _flyBG = nil end
end

local function enableFly()
    -- Apply: every Heartbeat compute desired velocity from input + camera
    track(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        local hrp = getRoot()
        if not CFG.Fly or not hrp then
            if _flyBV or _flyBG then disposeFly() end
            return
        end
        if not _flyBV or not _flyBV.Parent then
            disposeFly()
            _flyBV = Instance.new("BodyVelocity")
            _flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            _flyBV.Velocity = Vector3.zero
            _flyBV.Parent = hrp
            _flyBG = Instance.new("BodyGyro")
            _flyBG.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            _flyBG.P = 9000
            _flyBG.D = 1000
            _flyBG.CFrame = hrp.CFrame
            _flyBG.Parent = hrp
        end
        local move = Vector3.zero
        local cam = Camera.CFrame
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.yAxis end
        if move.Magnitude > 0 then move = move.Unit * CFG.FlySpeed end
        _flyBV.Velocity = move
        _flyBG.CFrame = cam
    end))

    -- Toggle key
    track(UIS.InputBegan:Connect(function(input, gp)
        if not alive() or gp then return end
        if input.KeyCode == CFG.FlyKey then CFG.Fly = not CFG.Fly end
    end))

    -- Cleanup on respawn
    track(LP.CharacterRemoving:Connect(disposeFly))
end

-- ============================================================
-- FEATURE: FREECAM
-- Detach camera from character, WASD + mouse-look. Toggle with FreeCamKey.
-- Restores Custom subject + scriptable=false on disable.
-- ============================================================
local _freeCamPos, _freeCamOrigSubject, _freeCamOrigType = nil, nil, nil
local function disposeFreeCam()
    if _freeCamOrigType ~= nil then
        pcall(function()
            Camera.CameraType = _freeCamOrigType
            Camera.CameraSubject = _freeCamOrigSubject
        end)
    end
    _freeCamPos, _freeCamOrigSubject, _freeCamOrigType = nil, nil, nil
end

local function enableFreeCam()
    track(RunService.RenderStepped:Connect(function(dt)
        if not alive() then return end
        if not CFG.FreeCam then
            if _freeCamPos then disposeFreeCam() end
            return
        end
        if not _freeCamPos then
            _freeCamOrigType = Camera.CameraType
            _freeCamOrigSubject = Camera.CameraSubject
            Camera.CameraType = Enum.CameraType.Scriptable
            _freeCamPos = Camera.CFrame
        end
        local move = Vector3.zero
        local cam = _freeCamPos
        if UIS:IsKeyDown(Enum.KeyCode.W) then move = move + cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.S) then move = move - cam.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then move = move - cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.D) then move = move + cam.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.yAxis end
        if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then move = move - Vector3.yAxis end
        if move.Magnitude > 0 then move = move.Unit * CFG.FreeCamSpeed * dt end
        _freeCamPos = CFrame.new(cam.Position + move) * (cam - cam.Position)
        Camera.CFrame = _freeCamPos
    end))

    -- Toggle key
    track(UIS.InputBegan:Connect(function(input, gp)
        if not alive() or gp then return end
        if input.KeyCode == CFG.FreeCamKey then CFG.FreeCam = not CFG.FreeCam end
    end))
end

-- ============================================================
-- FEATURE: PERFORMANCE MODE
-- Aggressive: disables ALL ParticleEmitters (not just smokestacks),
-- ALL Beam/Trail effects, all Decal transparency tweaking. Use on
-- low-end PCs to reclaim FPS in big factories.
-- ============================================================
local _perfApplied = false
local function applyPerfMode(on)
    for _, d in ipairs(Workspace:GetDescendants()) do
        if d:IsA("ParticleEmitter") and not isSmokeStackParticle(d) then
            pcall(function() d.Enabled = not on end)
        elseif d:IsA("Beam") or d:IsA("Trail") then
            pcall(function() d.Enabled = not on end)
        end
    end
    _perfApplied = on
end

local function enablePerfMode()
    -- v0.6.0: 1Hz throttled state-watcher (was every Heartbeat).
    -- Workspace.DescendantAdded REMOVED — the per-placement listener was a
    -- major placement-lag contributor. PerfMode now toggles once on state
    -- change; new effects placed after activation won't be auto-disabled.
    local _last = 0
    track(RunService.Heartbeat:Connect(function()
        if not alive() then return end
        local now = tick(); if now - _last < 1 then return end; _last = now
        if CFG.PerformanceMode and not _perfApplied then applyPerfMode(true) end
        if not CFG.PerformanceMode and _perfApplied then applyPerfMode(false) end
    end))
end

-- ============================================================
-- FEATURE: AURORA v5 UI
-- 2-column layout (sidebar + main), 5 tabs, pill toggle, drag.
-- Applies v5 lessons: transparent sidebar (rounded clip), no glow
-- frames, slider-row Active=true, alive() local, watermark bleed.
-- ============================================================
local TweenService = game:GetService("TweenService")

local function enableUI()
    -- Cleanup any prior instance
    for _, parent in ipairs({
        gethui(),
        pcall(function() return game:GetService("CoreGui") end) and game:GetService("CoreGui") or nil,
        LP:FindFirstChild("PlayerGui"),
    }) do
        if parent then
            for _, name in ipairs({ "AuroraIndustrialistUI", "AuroraIndustrialistPill" }) do
                local existing = parent:FindFirstChild(name)
                if existing then pcall(function() existing:Destroy() end) end
            end
        end
    end

    local C = {
        bg      = Color3.fromRGB(8, 8, 15),
        bg2     = Color3.fromRGB(12, 12, 24),
        bg3     = Color3.fromRGB(19, 19, 42),
        border  = Color3.fromRGB(22, 22, 42),
        border2 = Color3.fromRGB(42, 42, 68),
        text    = Color3.fromRGB(245, 245, 250),
        text2   = Color3.fromRGB(160, 160, 180),
        text3   = Color3.fromRGB(98, 98, 122),
        pink    = Color3.fromRGB(252, 110, 142),
        purple  = Color3.fromRGB(192, 132, 252),
        green   = Color3.fromRGB(0, 200, 100),
        red     = Color3.fromRGB(255, 80, 80),
        white   = Color3.fromRGB(255, 255, 255),
    }
    local F_SANS, F_SEMI, F_BOLD, F_MONO = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold, Enum.Font.Code

    local function create(cls, props, parent)
        local i = Instance.new(cls)
        if props then for k, v in pairs(props) do i[k] = v end end
        if parent then i.Parent = parent end
        return i
    end
    local function corner(p, r) local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, r or 6); c.Parent = p; return c end
    local function stroke(p, col, th, tr)
        local s = Instance.new("UIStroke")
        s.Color = col or C.border; s.Thickness = th or 1; s.Transparency = tr or 0
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; s.Parent = p; return s
    end
    local function grad(p, c1, c2, rot)
        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, c1), ColorSequenceKeypoint.new(1, c2) })
        g.Rotation = rot or 0; g.Parent = p; return g
    end
    local function padAll(p, v)
        local pp = Instance.new("UIPadding")
        pp.PaddingTop = UDim.new(0, v); pp.PaddingBottom = UDim.new(0, v)
        pp.PaddingLeft = UDim.new(0, v); pp.PaddingRight = UDim.new(0, v); pp.Parent = p; return pp
    end

    local TOTAL_W, TOTAL_H = 720, 480
    local SIDEBAR_W, MAIN_W = 168, 552

    local screenGui = create("ScreenGui", {
        Name = "AuroraIndustrialistUI", DisplayOrder = 9999, ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
    })
    local _pOk = pcall(function() screenGui.Parent = gethui() end)
    if not _pOk then pcall(function() screenGui.Parent = LP:WaitForChild("PlayerGui") end) end

    local main = create("Frame", {
        Name = "Main", Size = UDim2.fromOffset(TOTAL_W, TOTAL_H),
        Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = C.bg, BorderSizePixel = 0,
        ClipsDescendants = true, Visible = CFG.PanelOpen,
    }, screenGui)
    corner(main, 14); stroke(main, C.border2, 1, 0)

    -- Watermark — under content layer, bleeds through transparent panels
    create("TextLabel", {
        Name = "Watermark", Size = UDim2.fromOffset(700, 120),
        Position = UDim2.fromOffset(TOTAL_W / 2, TOTAL_H / 2),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        RichText = true, Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>',
        Font = F_BOLD, TextSize = 60, TextTransparency = 0.85, ZIndex = 1,
    }, main)

    local content = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 2 }, main)

    -- Sidebar (transparent so rounded corners show through)
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
    create("TextLabel", {
        Size = UDim2.fromOffset(SIDEBAR_W - 28, 24), Position = UDim2.fromOffset(14, 15),
        BackgroundTransparency = 1, RichText = true,
        Text = '<font color="#FC6E8E">Aurorahub</font><font color="#F5F5FA">.net</font>',
        Font = F_BOLD, TextSize = 13, TextColor3 = C.text,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, wordmarkRow)
    create("Frame", {
        Size = UDim2.fromOffset(SIDEBAR_W - 20, 1), Position = UDim2.fromOffset(10, 54),
        BackgroundColor3 = C.border, BorderSizePixel = 0,
    }, sidebar)

    -- Tabs
    local TABS = {
        { name = "Movement", icon = "●" },
        { name = "Aerial",   icon = "◆" },
        { name = "Visuals",  icon = "◉" },
        { name = "Misc",     icon = "≡" },
        { name = "Info",     icon = "✦" },
    }
    local tabMap, panelMap = {}, {}

    local function paintTabs()
        for name, t in pairs(tabMap) do
            local on = (CFG.ActiveTab == name)
            t.accent.Visible = on
            t.bg.BackgroundTransparency = on and 0.85 or 1
            t.label.TextColor3 = on and C.text or C.text2
            t.label.Font = on and F_SEMI or F_SANS
            t.icon.TextColor3 = on and C.pink or C.text3
        end
    end

    local TAB_Y0, TAB_H, TAB_GAP = 66, 34, 3
    local function makeTabRow(tinfo, yPos)
        local row = create("Frame", {
            Name = "Tab_" .. tinfo.name, Size = UDim2.fromOffset(SIDEBAR_W - 20, TAB_H),
            Position = UDim2.fromOffset(10, yPos),
            BackgroundColor3 = C.pink, BackgroundTransparency = 1,
            BorderSizePixel = 0, Active = true,
        }, sidebar)
        corner(row, 6)
        local bgGrad = Instance.new("UIGradient")
        bgGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.pink), ColorSequenceKeypoint.new(1, C.bg2) })
        bgGrad.Parent = row
        local accent = create("Frame", {
            Size = UDim2.fromOffset(2, TAB_H - 14), Position = UDim2.fromOffset(0, 7),
            BackgroundColor3 = C.pink, BorderSizePixel = 0, Visible = false,
        }, row)
        corner(accent, 1)
        local icon = create("TextLabel", {
            Size = UDim2.fromOffset(18, TAB_H), Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1, Text = tinfo.icon,
            Font = F_BOLD, TextSize = 12, TextColor3 = C.text3,
        }, row)
        local label = create("TextLabel", {
            Size = UDim2.fromOffset(SIDEBAR_W - 64, TAB_H), Position = UDim2.fromOffset(36, 0),
            BackgroundTransparency = 1, Text = tinfo.name,
            Font = F_SANS, TextSize = 12, TextColor3 = C.text2,
            TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        tabMap[tinfo.name] = { bg = row, accent = accent, icon = icon, label = label }
        return row
    end

    -- Forward-declare switchTab
    local switchTab = function(_) end
    for idx, tinfo in ipairs(TABS) do
        local y = TAB_Y0 + (idx - 1) * (TAB_H + TAB_GAP)
        local row = makeTabRow(tinfo, y)
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                switchTab(tinfo.name)
            end
        end)
    end

    -- Panel factory (single panel per tab — simpler than sailor's 3-column)
    local function makePanel(tabName, accent, title)
        local p = create("Frame", {
            Name = tabName .. "_Panel", Size = UDim2.fromOffset(MAIN_W, TOTAL_H),
            Position = UDim2.fromOffset(SIDEBAR_W, 0),
            BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true,
            Visible = (tabName == CFG.ActiveTab),
        }, content)

        create("TextLabel", {
            Size = UDim2.fromOffset(MAIN_W - 32, 36), Position = UDim2.fromOffset(16, 14),
            BackgroundTransparency = 1, Text = title,
            Font = F_MONO, TextSize = 10, TextColor3 = accent,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        }, p)
        create("Frame", {
            Size = UDim2.fromOffset(MAIN_W, 1), Position = UDim2.fromOffset(0, 48),
            BackgroundColor3 = C.border, BorderSizePixel = 0,
        }, p)

        local scroll = create("ScrollingFrame", {
            Size = UDim2.fromOffset(MAIN_W, TOTAL_H - 50), Position = UDim2.fromOffset(0, 50),
            BackgroundTransparency = 1, BorderSizePixel = 0,
            ScrollBarThickness = 2, ScrollBarImageColor3 = accent,
            CanvasSize = UDim2.fromOffset(0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        }, p)
        padAll(scroll, 14)
        local list = Instance.new("UIListLayout")
        list.Padding = UDim.new(0, 2); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = scroll
        panelMap[tabName] = { frame = p, scroll = scroll }
        return scroll
    end

    local mvScroll  = makePanel("Movement", C.pink,   "MOVEMENT")
    local aeScroll  = makePanel("Aerial",   C.purple, "AERIAL")
    local vsScroll  = makePanel("Visuals",  C.pink,   "VISUALS")
    local mScroll   = makePanel("Misc",     C.pink,   "MISC")
    local iScroll   = makePanel("Info",     C.pink,   "INFO")

    switchTab = function(tabName)
        if not panelMap[tabName] then tabName = "Movement" end
        CFG.ActiveTab = tabName
        paintTabs()
        for tn, p in pairs(panelMap) do p.frame.Visible = (tn == tabName) end
    end

    -- Component builders
    local function sectionHeader(parent, icon, label, order)
        local row = create("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = order }, parent)
        create("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromOffset(0, 35), BackgroundColor3 = C.border, BorderSizePixel = 0 }, row)
        local bar = create("Frame", { Size = UDim2.fromOffset(3, 12), Position = UDim2.fromOffset(0, 14), BackgroundColor3 = C.white, BorderSizePixel = 0 }, row)
        corner(bar, 1); grad(bar, C.pink, C.purple, 90)
        create("TextLabel", {
            Size = UDim2.new(1, -12, 0, 36), Position = UDim2.fromOffset(12, 0),
            BackgroundTransparency = 1, Text = icon .. "  " .. label,
            Font = F_BOLD, TextSize = 11, TextColor3 = C.text,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
        }, row)
    end

    local function toggleRow(parent, label, cfgKey, order)
        if CFG[cfgKey] == nil then CFG[cfgKey] = false end
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, LayoutOrder = order, Active = true,
        }, parent)
        create("TextLabel", {
            Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Text = label,
            Font = F_SEMI, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local track = create("Frame", {
            Size = UDim2.fromOffset(36, 20), Position = UDim2.new(1, -36, 0.5, -10),
            BackgroundColor3 = C.bg3, BorderSizePixel = 0,
        }, row)
        corner(track, 10)
        local trackStroke = stroke(track, C.border2, 1, 0)
        local trackGrad = Instance.new("UIGradient")
        trackGrad.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.pink), ColorSequenceKeypoint.new(1, C.purple) })
        trackGrad.Enabled = false; trackGrad.Parent = track
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
            TweenService:Create(knob, TweenInfo.new(0.15), { Position = UDim2.fromOffset(on and 19 or 3, 3) }):Play()
        end
        paint()
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                CFG[cfgKey] = not CFG[cfgKey]; paint()
            end
        end)
        -- Repaint loop so external CFG changes (key toggles like E for Fly) reflect in UI
        task.spawn(function()
            local lastVal = CFG[cfgKey]
            while track.Parent and alive() and row.Parent do
                if CFG[cfgKey] ~= lastVal then lastVal = CFG[cfgKey]; paint() end
                task.wait(0.25)
            end
        end)
    end

    local function sliderRow(parent, label, cfgKey, minV, maxV, step, order)
        if CFG[cfgKey] == nil then CFG[cfgKey] = minV end
        local row = create("Frame", {
            Size = UDim2.new(1, 0, 0, 42), BackgroundTransparency = 1,
            LayoutOrder = order, Active = true,
        }, parent)
        create("TextLabel", {
            Size = UDim2.new(0.7, 0, 0, 18), BackgroundTransparency = 1, Text = label,
            Font = F_SEMI, TextSize = 12, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        local fmtVal = function(v) return (step < 1) and string.format("%.1f", v) or tostring(math.floor(v)) end
        local valLabel = create("TextLabel", {
            Size = UDim2.new(0.3, 0, 0, 18), Position = UDim2.new(0.7, 0, 0, 0),
            BackgroundTransparency = 1, Text = fmtVal(CFG[cfgKey]),
            Font = F_MONO, TextSize = 11, TextColor3 = C.pink,
            TextXAlignment = Enum.TextXAlignment.Right,
        }, row)
        local trackBar = create("Frame", {
            Size = UDim2.new(1, 0, 0, 4), Position = UDim2.new(0, 0, 0, 28),
            BackgroundColor3 = C.bg3, BorderSizePixel = 0,
        }, row)
        corner(trackBar, 2); stroke(trackBar, C.border, 1, 0)
        local pct0 = math.clamp((CFG[cfgKey] - minV) / math.max(1e-6, maxV - minV), 0, 1)
        local fill = create("Frame", {
            Size = UDim2.new(pct0, 0, 1, 0), BackgroundColor3 = C.white, BorderSizePixel = 0,
        }, trackBar)
        corner(fill, 2); grad(fill, C.pink, C.purple, 0)
        local knob = create("Frame", {
            Size = UDim2.fromOffset(14, 14), Position = UDim2.new(pct0, -7, 0.5, -7),
            BackgroundColor3 = C.white, BorderSizePixel = 0, ZIndex = 3,
        }, trackBar)
        corner(knob, 7); stroke(knob, C.pink, 2, 0)
        local dragging = false
        local function update(x)
            local p0 = trackBar.AbsolutePosition.X; local w = trackBar.AbsoluteSize.X
            local rel = math.clamp((x - p0) / math.max(1, w), 0, 1)
            local raw = minV + (maxV - minV) * rel
            local snapped = math.floor(raw / step + 0.5) * step
            snapped = math.clamp(snapped, minV, maxV)
            if step >= 1 then snapped = math.floor(snapped) end
            CFG[cfgKey] = snapped
            local newPct = math.clamp((snapped - minV) / math.max(1e-6, maxV - minV), 0, 1)
            fill.Size = UDim2.new(newPct, 0, 1, 0)
            knob.Position = UDim2.new(newPct, -7, 0.5, -7)
            valLabel.Text = fmtVal(snapped)
        end
        row.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = true; update(inp.Position.X)
            end
        end)
        track(UIS.InputChanged:Connect(function(inp)
            if not alive() then return end
            if dragging and (inp.UserInputType == Enum.UserInputType.MouseMovement
                or inp.UserInputType == Enum.UserInputType.Touch) then
                update(inp.Position.X)
            end
        end))
        track(UIS.InputEnded:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end))
    end

    local function infoRow(parent, label, val, valColor, order)
        local row = create("Frame", { Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1, LayoutOrder = order }, parent)
        create("TextLabel", {
            Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Text = label,
            Font = F_SEMI, TextSize = 11, TextColor3 = C.text2, TextXAlignment = Enum.TextXAlignment.Left,
        }, row)
        create("TextLabel", {
            Size = UDim2.fromScale(0.5, 1), Position = UDim2.fromScale(0.5, 0),
            BackgroundTransparency = 1, Text = tostring(val),
            Font = F_MONO, TextSize = 10, TextColor3 = valColor or C.text,
            TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd,
        }, row)
    end

    -- POPULATE: Movement
    do
        local n = 0; local function ord() n = n + 1; return n end
        sectionHeader(mvScroll, "●", "Walk + Jump", ord())
        toggleRow(mvScroll, "Walk Speed Boost", "SpeedEnabled", ord())
        sliderRow(mvScroll, "Walk Speed", "SpeedValue", 22, 100, 1, ord())
        toggleRow(mvScroll, "Jump Power Boost", "JumpEnabled", ord())
        sliderRow(mvScroll, "Jump Power", "JumpValue", 50, 200, 5, ord())
        toggleRow(mvScroll, "Infinite Jump", "InfiniteJump", ord())
        sectionHeader(mvScroll, "◉", "Phasing", ord())
        toggleRow(mvScroll, "Noclip (walk through machines)", "Noclip", ord())
    end

    -- POPULATE: Aerial
    do
        local n = 0; local function ord() n = n + 1; return n end
        sectionHeader(aeScroll, "●", "Fly", ord())
        toggleRow(aeScroll, "Fly (or press F2)", "Fly", ord())
        sliderRow(aeScroll, "Fly Speed", "FlySpeed", 30, 300, 5, ord())
        sectionHeader(aeScroll, "◆", "FreeCam", ord())
        toggleRow(aeScroll, "FreeCam (or press F1)", "FreeCam", ord())
        sliderRow(aeScroll, "FreeCam Speed", "FreeCamSpeed", 30, 400, 10, ord())
    end

    -- POPULATE: Visuals
    do
        local n = 0; local function ord() n = n + 1; return n end
        sectionHeader(vsScroll, "●", "Pollution", ord())
        toggleRow(vsScroll, "No Fog (Atmosphere/CC/DOF)", "NoFog", ord())
        toggleRow(vsScroll, "Disable Smoke Stacks", "DisableSmokeStacks", ord())
        sectionHeader(vsScroll, "◉", "Performance", ord())
        toggleRow(vsScroll, "Performance Mode (kill all FX)", "PerformanceMode", ord())
    end

    -- POPULATE: Misc
    do
        local n = 0; local function ord() n = n + 1; return n end
        sectionHeader(mScroll, "●", "Quality of Life", ord())
        toggleRow(mScroll, "Anti-AFK (defeat 20min idle kick)", "AntiAFK", ord())
    end

    -- POPULATE: Info
    do
        local n = 0; local function ord() n = n + 1; return n end
        sectionHeader(iScroll, "●", "Game", ord())
        infoRow(iScroll, "Title",     "Industrialist",                       C.text,  ord())
        infoRow(iScroll, "Creator",   "Mamytema Studios",                    C.text2, ord())
        infoRow(iScroll, "Genre",     "Factory tycoon",                      C.text2, ord())
        infoRow(iScroll, "PlaceId",   tostring(game.PlaceId),                C.text2, ord())
        infoRow(iScroll, "Universe",  tostring(game.GameId),                 C.text2, ord())
        sectionHeader(iScroll, "◉", "Script", ord())
        infoRow(iScroll, "Aurora",    "v" .. CFG._Version,                   C.pink,  ord())
        infoRow(iScroll, "CFG",       "__AURORA_INDUSTRIALIST_CFG3",         C.text3, ord())
        infoRow(iScroll, "Author",    "Aurorahub.net",                       C.pink,  ord())
        sectionHeader(iScroll, "✦", "Keybinds", ord())
        infoRow(iScroll, "Toggle Fly",     "E",  C.text,  ord())
        infoRow(iScroll, "Toggle FreeCam", "F1", C.text,  ord())
        infoRow(iScroll, "Fly Move",       "WASD + Space + LShift",  C.text2, ord())
        infoRow(iScroll, "FreeCam Move",   "WASD + Space + LCtrl",   C.text2, ord())
        sectionHeader(iScroll, "▣", "Tips", ord())
        create("TextLabel", {
            Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
            Text = "• NoFog only hides VISUAL pollution — the server-side\n  pollution score that gates income is not yet patched.\n• Auto-research / auto-buy / auto-place pending arg-shape capture\n  via auto-map (interact in build mode while spy is active).",
            Font = F_SANS, TextSize = 11, TextColor3 = C.text3, TextWrapped = true,
            TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
            LayoutOrder = ord(),
        }, iScroll)
    end

    paintTabs()

    -- Floating pill — separate ScreenGui so it stays visible when main is hidden
    local pillGui = create("ScreenGui", {
        Name = "AuroraIndustrialistPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true,
    })
    local _pillOk = pcall(function() pillGui.Parent = gethui() end)
    if not _pillOk then pcall(function() pillGui.Parent = LP:WaitForChild("PlayerGui") end) end

    local pill = create("Frame", {
        Name = "Pill", Size = UDim2.fromOffset(160, 36),
        Position = UDim2.new(1, -180, 0, 22),
        BackgroundColor3 = C.bg, BackgroundTransparency = 0.15,
        BorderSizePixel = 0, Active = true,
    }, pillGui)
    corner(pill, 18); stroke(pill, C.border2, 1, 0)

    local pillDotGlow = create("Frame", {
        Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(9, 9),
        BackgroundColor3 = C.green, BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 1,
    }, pill); corner(pillDotGlow, 9)
    local pillDotGlowInner = create("Frame", {
        Size = UDim2.fromOffset(12, 12), Position = UDim2.fromOffset(12, 12),
        BackgroundColor3 = C.green, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 2,
    }, pill); corner(pillDotGlowInner, 6)
    create("Frame", {
        Size = UDim2.fromOffset(8, 8), Position = UDim2.fromOffset(14, 14),
        BackgroundColor3 = C.green, BorderSizePixel = 0, ZIndex = 3,
    }, pill)

    -- Breathing pulse
    task.spawn(function()
        if not alive() then return end
        TweenService:Create(pillDotGlow, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.55, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(7, 7) }):Play()
        TweenService:Create(pillDotGlowInner, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
            { BackgroundTransparency = 0.35 }):Play()
    end)

    create("TextLabel", {
        Size = UDim2.fromOffset(60, 36), Position = UDim2.fromOffset(28, 0),
        BackgroundTransparency = 1, Text = "Aurora",
        Font = F_BOLD, TextSize = 12, TextColor3 = C.pink, TextXAlignment = Enum.TextXAlignment.Left,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(10, 36), Position = UDim2.fromOffset(82, 0),
        BackgroundTransparency = 1, Text = "·", Font = F_BOLD, TextSize = 14, TextColor3 = C.text3,
    }, pill)
    create("TextLabel", {
        Size = UDim2.fromOffset(72, 36), Position = UDim2.fromOffset(94, 0),
        BackgroundTransparency = 1, Text = "Industrial",
        Font = F_SEMI, TextSize = 11, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left,
    }, pill)

    pill.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            CFG.PanelOpen = not CFG.PanelOpen
            main.Visible = CFG.PanelOpen
        end
    end)

    -- Drag (wordmark + top strip)
    local topDrag = create("Frame", {
        Name = "TopDragStrip", Size = UDim2.fromOffset(MAIN_W, 48),
        Position = UDim2.fromOffset(SIDEBAR_W, 0),
        BackgroundTransparency = 1, BorderSizePixel = 0, Active = true, ZIndex = 3,
    }, content)

    local _drag = { active = false, start = nil, startPos = nil }
    local function attachDrag(handle)
        handle.InputBegan:Connect(function(inp)
            if inp.UserInputType == Enum.UserInputType.MouseButton1
                or inp.UserInputType == Enum.UserInputType.Touch then
                _drag.active = true; _drag.start = inp.Position; _drag.startPos = main.Position
            end
        end)
    end
    attachDrag(wordmarkRow); attachDrag(topDrag)
    track(UIS.InputChanged:Connect(function(inp)
        if not alive() then return end
        if _drag.active and (inp.UserInputType == Enum.UserInputType.MouseMovement
            or inp.UserInputType == Enum.UserInputType.Touch) then
            local d = inp.Position - _drag.start
            main.Position = UDim2.new(_drag.startPos.X.Scale, _drag.startPos.X.Offset + d.X,
                _drag.startPos.Y.Scale, _drag.startPos.Y.Offset + d.Y)
        end
    end))
    track(UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            _drag.active = false
        end
    end))

    -- Minimize + Close
    local minBtn = create("Frame", {
        Name = "Minimize", Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(TOTAL_W - 62, 13),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
    }, content); corner(minBtn, 11); stroke(minBtn, C.border2, 1, 0)
    create("Frame", {
        Size = UDim2.fromOffset(10, 2), Position = UDim2.new(0.5, -5, 0.5, -1),
        BackgroundColor3 = C.text2, BorderSizePixel = 0, ZIndex = 6,
    }, minBtn)
    minBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            CFG.PanelOpen = false; main.Visible = false
        end
    end)

    local closeBtn = create("Frame", {
        Name = "Close", Size = UDim2.fromOffset(22, 22),
        Position = UDim2.fromOffset(TOTAL_W - 32, 13),
        BackgroundColor3 = C.bg3, BorderSizePixel = 0, Active = true, ZIndex = 5,
    }, content); corner(closeBtn, 11); stroke(closeBtn, C.border2, 1, 0)
    create("TextLabel", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "×",
        Font = F_BOLD, TextSize = 16, TextColor3 = C.text2, ZIndex = 6,
    }, closeBtn)
    closeBtn.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
            or inp.UserInputType == Enum.UserInputType.Touch then
            getgenv().__AURORA_INDUSTRIALIST_SESSION = 0
            task.wait(0.05)
            pcall(function() screenGui:Destroy() end)
            pcall(function() pillGui:Destroy() end)
        end
    end)
end

-- ============================================================
-- BOOT
-- ============================================================
enableNoFog()
enableMovement()
enableAntiAFK()
enableNoclip()
enableFly()
enableFreeCam()
enablePerfMode()
enableUI()

print(("[Aurora/Industrialist v%s] loaded — NoFog:%s Speed:%s Jump:%s InfJump:%s Noclip:%s Fly:%s(E) FreeCam:%s(F1) Perf:%s AFK:%s"):format(
    CFG._Version,
    tostring(CFG.NoFog),
    tostring(CFG.SpeedEnabled),
    tostring(CFG.JumpEnabled),
    tostring(CFG.InfiniteJump),
    tostring(CFG.Noclip),
    tostring(CFG.Fly),
    tostring(CFG.FreeCam),
    tostring(CFG.PerformanceMode),
    tostring(CFG.AntiAFK)
))

-- ============================================================
-- RUNTIME TOGGLE HELPERS (use in console while playing)
-- ============================================================
-- Movement:
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.SpeedEnabled = true
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.SpeedValue = 80
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.JumpEnabled = true
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.InfiniteJump = true
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.Noclip = true
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.Fly = true              -- or press F2
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.FlySpeed = 200
--
-- Camera:
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.FreeCam = true          -- or press F1
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.FreeCamSpeed = 250
--
-- Visuals:
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.NoFog = false           -- restore vanilla fog
-- getgenv().__AURORA_INDUSTRIALIST_CFG3.PerformanceMode = true  -- low-end FPS boost

-- ============================================================
-- INTEL (recon 2026-04-29 via MCP)
-- ============================================================
-- Currency display: HUD.CurrencyHolder.{Money,RP,Snowflakes} TextLabels
--   updated by HUD.HUDHandler (LocalScript, decompile blocked).
--   Sample state: Money "$5,758,955" / RP "8,126RP" / Snowflakes (event).
--   No leaderstats, no LP.PlayerData folder — values live in HUDHandler upvalues.
-- Active code (from GetCode RF, any input): "hmCFG-2666"
--   Redemption path unconfirmed — GetCode is a lookup not redeem.
-- Placement classes (HUD.Tools.ToolHandler.Inventory.Placement.*):
--   PlacementSystemClient (modern), PlacementSystemClientoldprehistoric (legacy),
--   PlacementSystemClienta (alpha) — ALL are placement-UI ghosts (rotation arrows,
--   position preview), NOT remote-fire wrappers. Methods: start/stop/setRotation/
--   getTarget/setModel/dispose. Don't use these for auto-buy.
-- Buy/Place arg shapes: NOT YET CAPTURED — auto-map needs user interaction.
--   Likely shape (TBD): Buy { ID = "<id-string>", Count = <int> }; Place { ... }
-- Spy hook quirk: pcall(R.FireServer, R, ...) FAILS through __namecall hook —
--   ALWAYS use pcall(function() R:FireServer(...) end) closure-wrapped pattern.
-- Pro-dev tier: PARTIAL — LP attribute write succeeds locally but server doesn't
--   honor it (HUD reads from internal table, not LP attributes). Standard tier.
-- DEBUG ScreenGui: just a perf overlay (TPS/ms graphs per machine type).
--   Not a wildcard. "@OnlyTwentyCharacters" Twitter handle visible.

-- ============================================================
-- TODO (next session)
-- ============================================================
-- [ ] auto-map 60s with user interacting — capture Buy/Place/Research.Unlock arg shapes
-- [ ] Auto-research (Research.Unlock RE) — single-arg likely
-- [ ] Auto-buy machines (PlacementSystem.Buy RE) — needs arg shape
-- [ ] Auto-place factories (PlacementSystem.Place RE) — needs arg shape + ratios
-- [ ] Promo code redeem path — check CodeFrameHolder UI handler, "hmCFG-2666"
-- [ ] getgc patch for currency multiplier (Wave/Potassium only)
-- [ ] Pollution-multiplier patch via getgc (less pollution = more money mechanic)
-- [ ] Aurora v5 UI scaffold (sidebar + tabs: Movement / Visuals / Auto / Misc)
-- [ ] Add to loader GAMES_BY_ID (PlaceIds 9312740628 + 9192423027)
-- [ ] AH copy at aurorahub/industrialist.lua (Wave/Potassium-only, strip compat)

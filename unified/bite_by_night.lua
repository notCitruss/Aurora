--// Aurora v5 — Bite By Night
--// DWS Edition (Wave/Potassium/Fluxus/Delta/Xeno/Arceus X)
--// PlaceId: 70845479499574
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill + in-game Alert + Direction arrow

getgenv().AuroraTier = getgenv().AuroraTier or "private"

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting     = game:GetService("Lighting")
local UIS          = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Player       = Players.LocalPlayer

-- Cleanup old UI (Xeno-safe: each parent chain in its own pcall)
for _, n in ipairs({"Aurora", "AuroraPill", "AuroraAlert", "AuroraDir"}) do
    pcall(function() if typeof(gethui) == "function" then local o = gethui():FindFirstChild(n); if o then o:Destroy() end end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
end
task.wait(0.1)

---------- ZOMBIE KILL ----------
if getgenv().__AURORA_BN_CFG then
    for k, v in pairs(getgenv().__AURORA_BN_CFG) do
        if type(v) == "boolean" then getgenv().__AURORA_BN_CFG[k] = false end
    end
end
pcall(function() if getgenv().__AURORA_BN_SPEED then getgenv().__AURORA_BN_SPEED:Disconnect() end end)
pcall(function() if getgenv().__AURORA_BN_NOCLIP then getgenv().__AURORA_BN_NOCLIP:Disconnect() end end)
getgenv().__AURORA_BN_SESSION = tick()
local _mySession = getgenv().__AURORA_BN_SESSION
local function alive() return getgenv().__AURORA_BN_SESSION == _mySession end

---------- GAME REFS (preserved verbatim from v4) ----------
local WS = game.Workspace
local GAME_STATE = WS:FindFirstChild("GAME")

local function getGameVal(name)
    if not GAME_STATE then return nil end
    local v = GAME_STATE:FindFirstChild(name)
    return v and v.Value or nil
end

local function getGameMap()
    local maps = WS:FindFirstChild("MAPS")
    if not maps then return nil end
    return maps:FindFirstChild("GAME MAP")
end

local function getKillerModel()
    local folder = WS:FindFirstChild("PLAYERS")
    if not folder then return nil end
    local killerFolder = folder:FindFirstChild("KILLER")
    if not killerFolder then return nil end
    local children = killerFolder:GetChildren()
    return children[1]
end

local function getKillerHumanoid(model)
    if not model then return nil end
    return model:FindFirstChildOfClass("Humanoid")
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
local function _promptAlive(p)
    local ok, r = pcall(function() return p and p.Parent and p.Enabled end)
    return ok and r
end
-- Cross-executor prompt firing: fireproximityprompt on Wave/Potassium/Delta,
-- InputHoldBegin + VIM E-key hold as fallback for Xeno and others.
local function safeFirePrompt(prompt)
    if not _promptAlive(prompt) then return end
    local holdTime = prompt.HoldDuration or 0
    pcall(function() if _HAS.firepp then fireproximityprompt(prompt) end end)
    task.wait(0.1)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local oh = prompt.HoldDuration
        prompt.HoldDuration = 0
        prompt:InputHoldBegin()
        task.wait(math.max(0.15, holdTime + 0.2))
        prompt:InputHoldEnd()
        prompt.HoldDuration = oh
    end)
    if not _promptAlive(prompt) then return end
    pcall(function()
        local VIM = game:GetService("VirtualInputManager")
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(math.max(0.2, holdTime + 0.2))
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end
-- Type-safe remote lookup
local function safeRE(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteEvent")) and obj or nil
end
local function safeRF(parent, name)
    local obj = parent and parent:FindFirstChild(name)
    return (obj and obj:IsA("RemoteFunction")) and obj or nil
end
local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

---------- CONFIG (v5: getgenv-backed for zombie-kill) ----------
if not getgenv().__AURORA_BN_CFG then
    getgenv().__AURORA_BN_CFG = {
        -- ESP (v4 keys preserved exactly)
        KillerESP       = false,
        GeneratorESP    = false,
        FuseBoxESP      = false,
        FusePointESP    = false,
        TrapESP         = false,
        EscapeESP       = false,
        SurvivorESP     = false,
        CameraESP       = false,
        -- Alerts
        KillerAlert     = false,
        KillerDirection = false,
        -- Vision
        Fullbright      = false,
        NoBlind         = false,
        -- Movement / utility
        SpeedBoost      = false,
        AntiAFK         = false,
        Noclip          = false,
        InfStamina      = false,
        UnlockJump      = false,
        KillerSpeed     = false,
        -- Auto
        AutoEscape      = false,
        AutoRepairGen   = false,
        -- Config behavior
        AutoSave        = false,
        -- v5 UI state (only additions)
        ActiveTab       = "ESP",
        PanelOpen       = true,
    }
else
    local c = getgenv().__AURORA_BN_CFG
    if c.ActiveTab == nil then c.ActiveTab = "ESP" end
    if c.PanelOpen == nil then c.PanelOpen = true end
end
local CFG = getgenv().__AURORA_BN_CFG

---------- TOGGLE SAVE/LOAD (preserved v4 filename) ----------
local _cfgFileName = "aurora_cfg_bite_by_night.json"

local function loadSavedCFG()
    local saved = nil
    pcall(function() saved = HttpService:JSONDecode(readfile(_cfgFileName)) end)
    if not saved then saved = getgenv()["AuroraCFG_bite_by_night"] end
    if saved and type(saved) == "table" then
        for k, v in pairs(saved) do
            if CFG[k] ~= nil and type(CFG[k]) == type(v) then CFG[k] = v end
        end
    end
end

local function saveCFG()
    pcall(function() if _HAS.writefile then writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end end)
    getgenv()["AuroraCFG_bite_by_night"] = CFG
end

loadSavedCFG()

---------- LIGHTING BACKUP (preserved verbatim from v4) ----------
local originalAmbient        = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local originalClockTime      = Lighting.ClockTime
local originalFogEnd         = Lighting.FogEnd
local originalFogStart       = Lighting.FogStart
local originalFogColor       = Lighting.FogColor

---------- ESP CLEANUP REGISTRY (preserved verbatim from v4) ----------
local espRegistry = {}

local function createESP(target, color, labelText)
    if not target or not target.Parent then return end
    if target:FindFirstChild("AuroraESP") then return end

    local hl = Instance.new("Highlight")
    hl.Name = "AuroraESP"
    hl.FillColor = color
    hl.FillTransparency = 0.5
    hl.OutlineColor = color
    hl.OutlineTransparency = 0
    hl.Adornee = target
    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = target

    local bb = Instance.new("BillboardGui")
    bb.Name = "AuroraESPLabel"
    bb.Size = UDim2.fromOffset(220, 44)
    bb.StudsOffset = Vector3.new(0, 4, 0)
    bb.AlwaysOnTop = true
    bb.MaxDistance = 500
    bb.Parent = target

    local lbl = Instance.new("TextLabel")
    lbl.Name = "ESPText"
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = color
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 13
    lbl.TextStrokeTransparency = 0
    lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    lbl.Text = labelText
    lbl.Active = false
    lbl.Parent = bb

    espRegistry[target] = {hl = hl, bb = bb, lbl = lbl}
end

local function clearESP(target)
    if not target then return end
    local entry = espRegistry[target]
    if entry then
        pcall(function() entry.hl:Destroy() end)
        pcall(function() entry.bb:Destroy() end)
        espRegistry[target] = nil
    end
    pcall(function()
        local hl = target:FindFirstChild("AuroraESP"); if hl then hl:Destroy() end
        local bb = target:FindFirstChild("AuroraESPLabel"); if bb then bb:Destroy() end
    end)
end

local function clearAllESP()
    for target, _ in pairs(espRegistry) do
        clearESP(target)
    end
    espRegistry = {}
end

local function updateESPLabel(target, text)
    local entry = espRegistry[target]
    if entry and entry.lbl and entry.lbl.Parent then
        entry.lbl.Text = text
    end
end

local function getDistance(model)
    local char = Player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 0 end
    local root = model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChildOfClass("BasePart")
    if not root then return 0 end
    return math.floor((hrp.Position - root.Position).Magnitude)
end

---------- KILLER ALERT UI (preserved — separate ScreenGui, 3-step Xeno-safe parent) ----------
local alertGui = Instance.new("ScreenGui")
alertGui.Name = "AuroraAlert"
alertGui.ResetOnSpawn = false
alertGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
alertGui.DisplayOrder = 100
do
    local _aOk = false
    if _HAS.gethui then _aOk = pcall(function() alertGui.Parent = gethui() end) end
    if not _aOk then _aOk = pcall(function() alertGui.Parent = game:GetService("CoreGui") end) end
    if not _aOk then pcall(function() alertGui.Parent = Player:WaitForChild("PlayerGui") end) end
end

local alertFrame = Instance.new("Frame")
alertFrame.Name = "AlertFrame"
alertFrame.Size = UDim2.fromOffset(340, 52)
alertFrame.AnchorPoint = Vector2.new(0.5, 0)
alertFrame.Position = UDim2.new(0.5, 0, 0, 18)
alertFrame.BackgroundColor3 = Color3.fromRGB(180, 20, 20)
alertFrame.BackgroundTransparency = 0.15
alertFrame.BorderSizePixel = 0
alertFrame.Visible = false
alertFrame.Parent = alertGui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 10); c.Parent = alertFrame
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 60, 60); s.Thickness = 2; s.Transparency = 0.1; s.Parent = alertFrame
end

local alertLabel = Instance.new("TextLabel")
alertLabel.Name = "AlertText"
alertLabel.Size = UDim2.new(1, 0, 1, 0)
alertLabel.BackgroundTransparency = 1
alertLabel.Font = Enum.Font.GothamBold
alertLabel.TextSize = 15
alertLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
alertLabel.TextXAlignment = Enum.TextXAlignment.Center
alertLabel.TextYAlignment = Enum.TextYAlignment.Center
alertLabel.TextStrokeTransparency = 0
alertLabel.Text = "KILLER NEARBY!"
alertLabel.Active = false
alertLabel.Parent = alertFrame

---------- DIRECTION ARROW UI (preserved — separate ScreenGui, 3-step Xeno-safe parent) ----------
local dirGui = Instance.new("ScreenGui")
dirGui.Name = "AuroraDir"
dirGui.ResetOnSpawn = false
dirGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dirGui.DisplayOrder = 99
do
    local _dOk = false
    if _HAS.gethui then _dOk = pcall(function() dirGui.Parent = gethui() end) end
    if not _dOk then _dOk = pcall(function() dirGui.Parent = game:GetService("CoreGui") end) end
    if not _dOk then pcall(function() dirGui.Parent = Player:WaitForChild("PlayerGui") end) end
end

local dirFrame = Instance.new("Frame")
dirFrame.Name = "DirFrame"
dirFrame.Size = UDim2.fromOffset(44, 44)
dirFrame.AnchorPoint = Vector2.new(0.5, 0.5)
dirFrame.Position = UDim2.new(0.5, 0, 0.85, 0)
dirFrame.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
dirFrame.BackgroundTransparency = 0.3
dirFrame.BorderSizePixel = 0
dirFrame.Visible = false
dirFrame.Parent = dirGui
do
    local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 22); c.Parent = dirFrame
    local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255, 80, 80); s.Thickness = 2; s.Transparency = 0.2; s.Parent = dirFrame
end

local dirArrow = Instance.new("TextLabel")
dirArrow.Name = "Arrow"
dirArrow.Size = UDim2.new(1, 0, 1, 0)
dirArrow.BackgroundTransparency = 1
dirArrow.Font = Enum.Font.GothamBold
dirArrow.TextSize = 22
dirArrow.TextColor3 = Color3.fromRGB(255, 255, 255)
dirArrow.TextXAlignment = Enum.TextXAlignment.Center
dirArrow.TextYAlignment = Enum.TextYAlignment.Center
dirArrow.Text = "\xE2\x86\x91"
dirArrow.Active = false
dirArrow.Parent = dirFrame

---------- NOCLIP LOOP (preserved verbatim from v4) ----------
local _noclipConn = nil
local _noclipWasOn = false
task.spawn(function()
    while alive() and task.wait(0.2) do
        if CFG.Noclip and not _noclipWasOn then
            _noclipWasOn = true
            _noclipConn = RunService.RenderStepped:Connect(function()
                pcall(function()
                    local char = Player.Character
                    if not char then return end
                    for _, part in char:GetDescendants() do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end)
            end)
        elseif not CFG.Noclip and _noclipWasOn then
            _noclipWasOn = false
            if _noclipConn then _noclipConn:Disconnect(); _noclipConn = nil end
            pcall(function()
                local char = Player.Character
                if char then
                    for _, part in char:GetDescendants() do
                        if part:IsA("BasePart") then part.CanCollide = true end
                    end
                end
            end)
        end
    end
end)

---------- SPEED LOOP (preserved verbatim from v4) ----------
local _speedWasOn = false
task.spawn(function()
    while alive() and task.wait(0.3) do
        pcall(function()
            local char = Player.Character
            if not char then return end
            if CFG.SpeedBoost then
                char:SetAttribute("WalkSpeed", 24)
                char:SetAttribute("RunSpeed", 36)
                _speedWasOn = true
            elseif _speedWasOn then
                char:SetAttribute("WalkSpeed", 12)
                char:SetAttribute("RunSpeed", 24)
                _speedWasOn = false
            end
        end)
    end
end)

---------- ANTI-AFK LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() do
        task.wait(jitter(240, 72.0))
        if not alive() then break end
        if CFG.AntiAFK then
            pcall(function()
                local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = hrp.CFrame * CFrame.new(0, 0.1, 0) end
            end)
        end
    end
end)

---------- FULLBRIGHT LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() and task.wait(jitter(2, 0.6)) do
        if CFG.Fullbright then
            pcall(function()
                Lighting.Ambient = Color3.fromRGB(255, 255, 255)
                Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
                Lighting.ClockTime = 14
                Lighting.FogEnd = 100000
                Lighting.FogStart = 99000
            end)
        end
    end
end)

---------- INF STAMINA (preserved verbatim from v4) ----------
local _staminaConn = nil
local _staminaCharConn = nil

local function hookStamina(char)
    if _staminaConn then pcall(function() _staminaConn:Disconnect() end) end
    _staminaConn = char:GetAttributeChangedSignal("Stamina"):Connect(function()
        if not CFG.InfStamina then return end
        local max = char:GetAttribute("MaxStamina") or 0
        local cur = char:GetAttribute("Stamina") or 0
        if max > 0 and cur < max then
            char:SetAttribute("Stamina", max)
        end
    end)
end

task.spawn(function()
    if Player.Character then
        pcall(function() hookStamina(Player.Character) end)
    end
    _staminaCharConn = Player.CharacterAdded:Connect(function(c)
        task.wait(1)
        pcall(function() hookStamina(c) end)
    end)
end)

task.spawn(function()
    while alive() and task.wait(0.05) do
        if CFG.InfStamina then
            pcall(function()
                local char = Player.Character
                if char then
                    local max = char:GetAttribute("MaxStamina") or 0
                    if max > 0 then char:SetAttribute("Stamina", max) end
                end
            end)
        end
    end
end)

---------- AUTO ESCAPE LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        if CFG.AutoEscape then
            pcall(function()
                local canEscape = WS.GAME and WS.GAME:FindFirstChild("CAN_ESCAPE")
                if canEscape and canEscape.Value == true then
                    local gameMap = getGameMap()
                    local escapes = gameMap and gameMap:FindFirstChild("Escapes")
                    if escapes then
                        for _, e in escapes:GetChildren() do
                            local hrp = Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local ok, pos = pcall(function() return e:GetPivot().Position end)
                                if ok then hrp.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end
                            end
                            break
                        end
                    end
                end
            end)
        end
    end
end)

---------- NO BLINDNESS LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        if CFG.NoBlind then
            pcall(function()
                local ui = Player.PlayerGui:FindFirstChild("UI")
                if ui then
                    for _, d in ui:GetDescendants() do
                        if d:IsA("Frame") and (d.Name == "Black" or d.Name:lower():find("blind") or d.Name == "MobileOverlay") then
                            d.BackgroundTransparency = 1
                            d.Visible = false
                        end
                    end
                end
            end)
        end
    end
end)

---------- KILLER SPEED BOOST LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        if CFG.KillerSpeed then
            pcall(function()
                local char = Player.Character
                if char and char:GetAttribute("Team") == "Killer" then
                    char:SetAttribute("WalkSpeed", 28)
                    char:SetAttribute("RunSpeed", 35)
                end
            end)
        end
    end
end)

---------- AUTO REPAIR GENERATOR (preserved verbatim from v4) ----------
local _autoGenVIM; pcall(function() _autoGenVIM = game:GetService("VirtualInputManager") end)
local _autoGenHolding = false
task.spawn(function()
    while alive() and task.wait(0.2) do
        if not CFG.AutoRepairGen then
            if _autoGenHolding and _autoGenVIM then
                pcall(function() _autoGenVIM:SendKeyEvent(false, Enum.KeyCode.E, false, game) end)
                _autoGenHolding = false
            end

        end
        pcall(function()
            local char = Player.Character
            if not char or char:GetAttribute("Team") ~= "Survivor" then return end
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hrp or not hum then return end
            local gameMap = workspace:FindFirstChild("MAPS") and workspace.MAPS:FindFirstChild("GAME MAP")
            local gens = gameMap and gameMap:FindFirstChild("Generators")
            if not gens then return end

            local bestPoint, bestDist = nil, math.huge
            for _, gen in gens:GetChildren() do
                for _, d in gen:GetDescendants() do
                    if d:IsA("ProximityPrompt") and d.ActionText == "Fix" and d.Enabled then
                        local pointPart = d.Parent
                        if pointPart and pointPart:IsA("BasePart") then
                            local dist = (pointPart.Position - hrp.Position).Magnitude
                            if dist < bestDist then bestDist = dist; bestPoint = pointPart end
                        end
                    end
                end
            end

            if not bestPoint then return end

            if not _autoGenVIM then return end

            if bestDist > 4 then
                hum:MoveTo(bestPoint.Position)
                if _autoGenHolding then
                    _autoGenVIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    _autoGenHolding = false
                end
            else
                if not _autoGenHolding then
                    _autoGenVIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    _autoGenHolding = true
                end
            end
        end)
    end
end)

---------- UNLOCK JUMP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() and task.wait(0.1) do
        if CFG.UnlockJump then
            pcall(function()
                local char = Player.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum then
                    hum.JumpHeight = 7.2
                    hum.JumpPower = 50
                end
            end)
        end
    end
end)

---------- KILLER ALERT + DIRECTION LOOP (preserved verbatim from v4) ----------
local alertFlash = false
local _killerNearState = false
local _killerDistState = 0
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        pcall(function()
            if not (CFG.KillerAlert or CFG.KillerDirection) then
                alertFrame.Visible = false
                dirFrame.Visible = false
                _killerNearState = false
                return
            end
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                alertFrame.Visible = false
                dirFrame.Visible = false
                _killerNearState = false
                return
            end

            local killerModel = getKillerModel()
            if not killerModel then
                alertFrame.Visible = false
                dirFrame.Visible = false
                _killerNearState = false
                return
            end

            local killerRoot = killerModel:FindFirstChild("HumanoidRootPart")
                or killerModel:FindFirstChildOfClass("BasePart")
            if not killerRoot then
                alertFrame.Visible = false
                dirFrame.Visible = false
                _killerNearState = false
                return
            end

            local dist = math.floor((hrp.Position - killerRoot.Position).Magnitude)
            _killerDistState = dist

            if CFG.KillerAlert then
                if dist <= 60 then
                    alertFlash = not alertFlash
                    alertFrame.Visible = true
                    alertLabel.Text = "KILLER NEARBY!  " .. dist .. "m away"
                    alertFrame.BackgroundTransparency = alertFlash and 0.1 or 0.35
                    _killerNearState = true
                else
                    alertFrame.Visible = false
                    _killerNearState = false
                end
            else
                alertFrame.Visible = false
            end

            if CFG.KillerDirection then
                dirFrame.Visible = true
                local cam = WS.CurrentCamera
                if cam then
                    local screenPos, onScreen = cam:WorldToScreenPoint(killerRoot.Position)
                    local center = cam.ViewportSize / 2
                    local dx = screenPos.X - center.X
                    local dy = screenPos.Y - center.Y
                    local angle = math.deg(math.atan2(dx, -dy))
                    dirFrame.Rotation = angle
                end
            else
                dirFrame.Visible = false
            end
        end)
    end
end)

---------- ESP UPDATE LOOP (preserved verbatim from v4) ----------
task.spawn(function()
    while alive() and task.wait(0.3) do
        pcall(function()
            local map = getGameMap()

            local killerModel = getKillerModel()
            if CFG.KillerESP and killerModel then
                local hum = getKillerHumanoid(killerModel)
                local hp = hum and math.floor(hum.Health) or 0
                local maxHp = hum and math.floor(hum.MaxHealth) or 1750
                local dist = getDistance(killerModel)
                local killerName = ""
                for _, folder in WS.PLAYERS:GetChildren() do
                    if folder.Name == "KILLER" then
                        for _, mdl in folder:GetChildren() do
                            killerName = mdl.Name
                        end
                    end
                end
                local lbl = (killerName ~= "" and killerName or "Killer") ..
                    "  |  HP " .. hp .. "/" .. maxHp ..
                    "  |  " .. dist .. "m"
                createESP(killerModel, Color3.fromRGB(220, 40, 40), lbl)
                updateESPLabel(killerModel, lbl)
            elseif not CFG.KillerESP and killerModel then
                clearESP(killerModel)
            end

            if map then
                local genFolder = map:FindFirstChild("Generators")
                if genFolder then
                    for _, gen in genFolder:GetChildren() do
                        if CFG.GeneratorESP then
                            local dist = getDistance(gen)
                            local lbl = "Generator  |  " .. dist .. "m"
                            createESP(gen, Color3.fromRGB(60, 200, 80), lbl)
                            updateESPLabel(gen, lbl)
                        else
                            clearESP(gen)
                        end
                    end
                end

                local fuseFolder = map:FindFirstChild("FuseBoxes")
                if fuseFolder then
                    for _, fuse in fuseFolder:GetChildren() do
                        if CFG.FuseBoxESP then
                            local dist = getDistance(fuse)
                            local lbl = "Fuse Box  |  " .. dist .. "m"
                            createESP(fuse, Color3.fromRGB(240, 200, 30), lbl)
                            updateESPLabel(fuse, lbl)
                        else
                            clearESP(fuse)
                        end
                    end
                end

                local escFolder = map:FindFirstChild("Escapes")
                if escFolder then
                    for _, esc in escFolder:GetChildren() do
                        if CFG.EscapeESP then
                            local dist = getDistance(esc)
                            local lbl = "EXIT  |  " .. dist .. "m"
                            createESP(esc, Color3.fromRGB(30, 200, 220), lbl)
                            updateESPLabel(esc, lbl)
                        else
                            clearESP(esc)
                        end
                    end
                end

                local camFolder = map:FindFirstChild("Cameras")
                if camFolder then
                    for _, cam in camFolder:GetChildren() do
                        if CFG.CameraESP then
                            local dist = getDistance(cam)
                            local lbl = "Camera  |  " .. dist .. "m"
                            createESP(cam, Color3.fromRGB(240, 130, 30), lbl)
                            updateESPLabel(cam, lbl)
                        else
                            clearESP(cam)
                        end
                    end
                end
            end

            local ignoreFolder = WS:FindFirstChild("IGNORE")
            if ignoreFolder then
                for _, obj in ignoreFolder:GetChildren() do
                    if obj.Name == "FusePoint" and obj:IsA("BasePart") then
                        if CFG.FusePointESP then
                            local dist = math.floor(
                                (Player.Character and Player.Character:FindFirstChild("HumanoidRootPart")
                                    and (Player.Character.HumanoidRootPart.Position - obj.Position).Magnitude) or 0
                            )
                            createESP(obj, Color3.fromRGB(200, 80, 200), "Battery  |  " .. dist .. "m")
                            updateESPLabel(obj, "Fuse Point  |  " .. dist .. "m")
                        else
                            clearESP(obj)
                        end
                    elseif obj.Name == "Trap" and obj:IsA("Model") then
                        if CFG.TrapESP then
                            local dist = getDistance(obj)
                            createESP(obj, Color3.fromRGB(255, 50, 50), "TRAP!  |  " .. dist .. "m")
                            updateESPLabel(obj, "TRAP!  |  " .. dist .. "m")
                        else
                            clearESP(obj)
                        end
                    end
                end
            end

            local playersFolder = WS:FindFirstChild("PLAYERS")
            if playersFolder then
                local aliveFolder = playersFolder:FindFirstChild("ALIVE")
                if aliveFolder then
                    for _, surv in aliveFolder:GetChildren() do
                        if CFG.SurvivorESP then
                            local hum = surv:FindFirstChildOfClass("Humanoid")
                            local hp = hum and math.floor(hum.Health) or 100
                            local dist = getDistance(surv)
                            local lbl = surv.Name .. "  |  " .. hp .. "HP  |  " .. dist .. "m"
                            createESP(surv, Color3.fromRGB(60, 120, 255), lbl)
                            updateESPLabel(surv, lbl)
                        else
                            clearESP(surv)
                        end
                    end
                end
            end
        end)
    end
end)

-- ========================================================================
-- ========================================================================
-- V5 3-COLUMN UI (Sidebar + Panel Alpha + Panel Beta + Live Game + Pill)
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
-- SCREENGUI + PARENT (Xeno-safe: each parent in own pcall)
--========================================================================
local screenGui = create("ScreenGui", {
    Name = "Aurora", DisplayOrder = 9999, ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true,
})
local _pOk = false
if _HAS.gethui then _pOk = pcall(function() screenGui.Parent = gethui() end) end
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

-- Centered brand watermark (bleeds through transparent panels/scrolls)
local watermark = create("TextLabel", {
    Name = "Watermark",
    Size = UDim2.fromOffset(800, 120),
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
    { name = "ESP",     icon = "◉" },
    { name = "Alerts",  icon = "◆" },
    { name = "Utility", icon = "≡" },
    { name = "Auto",    icon = "●" },
    { name = "Configs", icon = "□" },
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

-- Forward-declare switchTab / popup helpers
local switchTab        = function(_) end
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

local TAB_NAMES = { "ESP", "Alerts", "Utility", "Auto", "Configs", "Settings" }
local TAB_ACCENT = {
    ESP      = C.pink,
    Alerts   = C.purple,
    Utility  = C.pink,
    Auto     = C.pink,
    Configs  = C.pink,
    Settings = C.pink,
}
local PANEL_TITLES = {
    ESP      = { alpha = "ESP TOGGLES",  beta = "TARGET INFO"  },
    Alerts   = { alpha = "ALERTS",       beta = "ALERT STATUS" },
    Utility  = { alpha = "MOVEMENT",     beta = "PLAYER INFO"  },
    Auto     = { alpha = "AUTOMATION",   beta = "AUTO STATUS"  },
    Configs  = { alpha = "CONFIG",       beta = "ACTIVE"       },
    Settings = { alpha = "UI",           beta = "ABOUT"        },
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
    if not panels[tabName] then tabName = "ESP" end
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

closeOpenPopup = function()
    if _openPopup and _openPopup.frame then
        _openPopup.frame.Visible = false
        if _openPopup.onClose then _openPopup.onClose() end
    end
    _openPopup = nil
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
-- POPULATE: ESP
--========================================================================
local oE_a, oE_b = 0, 0
local function nEa() oE_a = oE_a + 1; return oE_a end
local function nEb() oE_b = oE_b + 1; return oE_b end

sectionHeader(scrolls["ESP_alpha"], "◆", "Killer",   nEa())
toggleRow    (scrolls["ESP_alpha"], "Killer ESP",    "KillerESP",   nEa())
toggleRow    (scrolls["ESP_alpha"], "Survivor ESP",  "SurvivorESP", nEa())

sectionHeader(scrolls["ESP_alpha"], "◉", "Objects",  nEa())
toggleRow    (scrolls["ESP_alpha"], "Generator ESP",  "GeneratorESP", nEa())
toggleRow    (scrolls["ESP_alpha"], "Fuse Box ESP",   "FuseBoxESP",   nEa())
toggleRow    (scrolls["ESP_alpha"], "Fuse Point ESP", "FusePointESP", nEa())
toggleRow    (scrolls["ESP_alpha"], "Camera ESP",     "CameraESP",    nEa())
toggleRow    (scrolls["ESP_alpha"], "Trap ESP",       "TrapESP",      nEa())
toggleRow    (scrolls["ESP_alpha"], "Escape ESP",     "EscapeESP",    nEa())

sectionHeader(scrolls["ESP_alpha"], "✦", "Clear", nEa())
actionBtn(scrolls["ESP_alpha"], "Clear All ESP", C.bg3, nEa(), function()
    clearAllESP()
end)

sectionHeader(scrolls["ESP_beta"], "◆", "Killer", nEb())
local _infoKillerDist = infoRow(scrolls["ESP_beta"], "Killer Dist", "---", C.text,   nEb())
local _infoKillerHP   = infoRow(scrolls["ESP_beta"], "Killer HP",   "---", C.text,   nEb())
local _infoTeam       = infoRow(scrolls["ESP_beta"], "Your Team",   "---", C.pink,   nEb())

sectionHeader(scrolls["ESP_beta"], "◉", "Game State", nEb())
local _infoGameState  = infoRow(scrolls["ESP_beta"], "Phase",       "---", C.text,   nEb())
local _infoCanEscape  = infoRow(scrolls["ESP_beta"], "Can Escape",  "---", C.text,   nEb())
local _infoSurvivors  = infoRow(scrolls["ESP_beta"], "Alive",       "---", C.pink,   nEb())

sectionHeader(scrolls["ESP_beta"], "✦", "Notes", nEb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "ESP redraws every 0.3s.\nToggle the category off to\nimmediately clear its ESP.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nEb(),
}, scrolls["ESP_beta"])

--========================================================================
-- POPULATE: ALERTS
--========================================================================
local oAl_a, oAl_b = 0, 0
local function nAla() oAl_a = oAl_a + 1; return oAl_a end
local function nAlb() oAl_b = oAl_b + 1; return oAl_b end

sectionHeader(scrolls["Alerts_alpha"], "◆", "Killer Awareness", nAla())
toggleRow    (scrolls["Alerts_alpha"], "Killer Alert",     "KillerAlert",     nAla())
toggleRow    (scrolls["Alerts_alpha"], "Killer Direction", "KillerDirection", nAla())

sectionHeader(scrolls["Alerts_alpha"], "◉", "Vision", nAla())
toggleRow    (scrolls["Alerts_alpha"], "Fullbright", "Fullbright", nAla(), function(on)
    if not on then
        pcall(function()
            Lighting.Ambient        = originalAmbient
            Lighting.OutdoorAmbient = originalOutdoorAmbient
            Lighting.ClockTime      = originalClockTime
            Lighting.FogEnd         = originalFogEnd
            Lighting.FogStart       = originalFogStart
        end)
    end
end)
toggleRow    (scrolls["Alerts_alpha"], "No Blindness", "NoBlind", nAla())

sectionHeader(scrolls["Alerts_beta"], "◆", "Alert Info", nAlb())
local _infoAlertStatus  = infoRow(scrolls["Alerts_beta"], "Alert Mode",    "Off", C.text,  nAlb())
local _infoKillerNearby = infoRow(scrolls["Alerts_beta"], "Killer Nearby", "No",  C.text,  nAlb())
local _infoDirMode      = infoRow(scrolls["Alerts_beta"], "Direction",     "Off", C.text,  nAlb())

sectionHeader(scrolls["Alerts_beta"], "✦", "Tips", nAlb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 100), BackgroundTransparency = 1,
    Text = "Killer Alert banner shows when\nthe killer is <= 60m away.\n\nDirection arrow points toward\nthe killer in screen-space.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAlb(),
}, scrolls["Alerts_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nUa() oU_a = oU_a + 1; return oU_a end
local function nUb() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "◆", "Movement", nUa())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost",  "SpeedBoost", nUa())
toggleRow    (scrolls["Utility_alpha"], "Noclip",       "Noclip",     nUa())
toggleRow    (scrolls["Utility_alpha"], "Unlock Jump",  "UnlockJump", nUa())
toggleRow    (scrolls["Utility_alpha"], "Inf Stamina",  "InfStamina", nUa())

sectionHeader(scrolls["Utility_alpha"], "◉", "Safety", nUa())
toggleRow    (scrolls["Utility_alpha"], "Anti-AFK", "AntiAFK", nUa())

sectionHeader(scrolls["Utility_alpha"], "▣", "Killer Only", nUa())
toggleRow    (scrolls["Utility_alpha"], "Killer Speed", "KillerSpeed", nUa())

sectionHeader(scrolls["Utility_beta"], "◆", "Player", nUb())
local _infoHealth   = infoRow(scrolls["Utility_beta"], "Health",  "---", C.text,  nUb())
local _infoStamina  = infoRow(scrolls["Utility_beta"], "Stamina", "---", C.text,  nUb())
local _infoUTeam    = infoRow(scrolls["Utility_beta"], "Team",    "---", C.pink,  nUb())

sectionHeader(scrolls["Utility_beta"], "◉", "Session", nUb())
local _infoRuntime  = infoRow(scrolls["Utility_beta"], "Runtime", "0m",    C.text2, nUb())
local _infoStatus   = infoRow(scrolls["Utility_beta"], "Status",  "Idle",  C.text2, nUb())

sectionHeader(scrolls["Utility_beta"], "✦", "Notes", nUb())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Speed Boost sets WalkSpeed=24.\nKiller Speed only activates while\nteamed as Killer.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUb(),
}, scrolls["Utility_beta"])

--========================================================================
-- POPULATE: AUTO
--========================================================================
local oAu_a, oAu_b = 0, 0
local function nAua() oAu_a = oAu_a + 1; return oAu_a end
local function nAub() oAu_b = oAu_b + 1; return oAu_b end

sectionHeader(scrolls["Auto_alpha"], "●", "Automation", nAua())
toggleRow    (scrolls["Auto_alpha"], "Auto Repair Gen", "AutoRepairGen", nAua())
toggleRow    (scrolls["Auto_alpha"], "Auto Escape",     "AutoEscape",    nAua())

sectionHeader(scrolls["Auto_alpha"], "✦", "Notes", nAua())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Auto Repair Gen walks to the nearest\ngenerator and holds E to repair\n(Survivor team only).\n\nAuto Escape teleports to an escape\npoint once the round is escapable.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAua(),
}, scrolls["Auto_alpha"])

sectionHeader(scrolls["Auto_beta"], "●", "Auto Status", nAub())
local _infoAutoStatus = infoRow(scrolls["Auto_beta"], "Mode",   "Idle", C.pink,  nAub())
local _infoGenHold    = infoRow(scrolls["Auto_beta"], "Gen Hold", "---", C.text, nAub())
local _infoEscapeRdy  = infoRow(scrolls["Auto_beta"], "Escape Ready", "---", C.text, nAub())

sectionHeader(scrolls["Auto_beta"], "✦", "Tips", nAub())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Disable Auto Repair Gen before\nleaving Survivor team to release\nthe E key hold.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAub(),
}, scrolls["Auto_beta"])

--========================================================================
-- POPULATE: CONFIGS
--========================================================================
local oC_a, oC_b = 0, 0
local function nCa() oC_a = oC_a + 1; return oC_a end
local function nCb() oC_b = oC_b + 1; return oC_b end

sectionHeader(scrolls["Configs_alpha"], "●", "Config", nCa())
toggleRow    (scrolls["Configs_alpha"], "Auto-Save", "AutoSave", nCa())
actionBtn    (scrolls["Configs_alpha"], "Save Config", C.green, nCa(), function() saveCFG() end)
actionBtn    (scrolls["Configs_alpha"], "Load Config", C.bg3,   nCa(), function() loadSavedCFG() end)
actionBtn    (scrolls["Configs_alpha"], "Reset All",   C.red,   nCa(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    saveCFG()
end)

sectionHeader(scrolls["Configs_alpha"], "✦", "Info", nCa())
infoRow(scrolls["Configs_alpha"], "File", _cfgFileName, C.text3, nCa())

sectionHeader(scrolls["Configs_beta"], "◆", "Active Features", nCb())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 320),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nCb(),
}, scrolls["Configs_beta"])

--========================================================================
-- POPULATE: SETTINGS
--========================================================================
local oS_a, oS_b = 0, 0
local function nSa() oS_a = oS_a + 1; return oS_a end
local function nSb() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "UI", nSa())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nSa(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI", C.red, nSa(), function()
    task.wait(0.3)
    getgenv().__AURORA_BN_SESSION = 0
    pcall(function() screenGui:Destroy() end)
    pcall(function() pillGui:Destroy() end)
    pcall(function() alertGui:Destroy() end)
    pcall(function() dirGui:Destroy() end)
    clearAllESP()
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About", nSb())
infoRow(scrolls["Settings_beta"], "Game",    "Bite By Night",                 C.text,  nSb())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),          C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion),     C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",           C.pink,  nSb())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                            C.text2, nSb())
infoRow(scrolls["Settings_beta"], "Save",    _cfgFileName,                    C.text3, nSb())

--========================================================================
-- POPULATE: LIVE GAME (persistent)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end

sectionHeader(liveScroll, "◉", "Session", nL())
local _liveRuntime  = infoRow(liveScroll, "Runtime", "0m",   C.text2, nL())
local _liveStatus   = infoRow(liveScroll, "Status",  "Idle", C.pink,  nL())

sectionHeader(liveScroll, "●", "Player", nL())
local _liveHealth   = infoRow(liveScroll, "Health",  "---", C.text,  nL())
local _liveStamina  = infoRow(liveScroll, "Stamina", "---", C.text,  nL())
local _liveTeam     = infoRow(liveScroll, "Team",    "---", C.pink,  nL())

sectionHeader(liveScroll, "◆", "Killer", nL())
local _liveKillerDist   = infoRow(liveScroll, "Dist",   "---", C.text,  nL())
local _liveKillerHP     = infoRow(liveScroll, "HP",     "---", C.text,  nL())
local _liveKillerNear   = infoRow(liveScroll, "Nearby", "No",  C.text,  nL())

sectionHeader(liveScroll, "▣", "Round", nL())
local _livePhase    = infoRow(liveScroll, "Phase",  "---", C.text,  nL())
local _liveEscape   = infoRow(liveScroll, "Escape", "---", C.text,  nL())
local _liveAlive    = infoRow(liveScroll, "Alive",  "---", C.pink,  nL())

--========================================================================
-- FLOATING PILL
--========================================================================
local pillGui = create("ScreenGui", {
    Name = "AuroraPill", DisplayOrder = 9998, ResetOnSpawn = false, IgnoreGuiInset = true,
})
local _pillOk = false
if _HAS.gethui then _pillOk = pcall(function() pillGui.Parent = gethui() end) end
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
        getgenv().__AURORA_BN_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
        pcall(function() alertGui:Destroy() end)
        pcall(function() dirGui:Destroy() end)
        clearAllESP()
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
local _sessionStart = tick()
task.spawn(function()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            local char = Player.Character
            local hpTxt, stamTxt, teamTxt = "---", "---", "---"
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hpTxt = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) end
                local stam    = char:GetAttribute("Stamina")
                local maxStam = char:GetAttribute("MaxStamina")
                if stam and maxStam then stamTxt = math.floor(stam) .. "/" .. math.floor(maxStam) end
                local team = char:GetAttribute("Team")
                teamTxt = team or "---"
            end

            local killerModel = getKillerModel()
            local killerDistTxt, killerHPTxt, killerNearTxt = "---", "---", "---"
            if killerModel then
                local dist = getDistance(killerModel)
                killerDistTxt = dist .. "m"
                local killerHum = getKillerHumanoid(killerModel)
                if killerHum then
                    killerHPTxt = math.floor(killerHum.Health) .. "/" .. math.floor(killerHum.MaxHealth)
                end
                killerNearTxt = (dist <= 60) and "YES" or "No"
            end

            local phaseTxt, canEscTxt = "---", "---"
            if GAME_STATE then
                local phase = GAME_STATE:FindFirstChild("Phase")
                phaseTxt = phase and tostring(phase.Value) or "---"
                local canEsc = GAME_STATE:FindFirstChild("CAN_ESCAPE")
                canEscTxt = canEsc and tostring(canEsc.Value) or "---"
            end

            local aliveTxt = "---"
            local playersFolder = WS:FindFirstChild("PLAYERS")
            local aliveFolder = playersFolder and playersFolder:FindFirstChild("ALIVE")
            aliveTxt = aliveFolder and tostring(#aliveFolder:GetChildren()) or "---"

            local elapsed = tick() - _sessionStart
            local mins    = math.floor(elapsed / 60)
            local hrs     = math.floor(mins / 60)
            local rtime   = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            local anyOn = false
            for k, v in pairs(CFG) do
                if type(v) == "boolean" and v and k ~= "AutoSave" and k ~= "PanelOpen" then
                    anyOn = true; break
                end
            end

            -- Mode label
            local mode = "Idle"
            if CFG.AutoRepairGen then mode = "Repairing"
            elseif CFG.AutoEscape then mode = "Escaping"
            elseif CFG.KillerAlert and _killerNearState then mode = "Alert"
            elseif anyOn then mode = "Running" end

            -- ESP tab
            _infoKillerDist.Text = killerDistTxt
            _infoKillerHP.Text   = killerHPTxt
            _infoTeam.Text       = teamTxt
            _infoGameState.Text  = phaseTxt
            _infoCanEscape.Text  = canEscTxt
            _infoSurvivors.Text  = aliveTxt

            -- Alerts tab
            _infoAlertStatus.Text  = CFG.KillerAlert and "ON" or "Off"
            _infoKillerNearby.Text = killerNearTxt
            _infoDirMode.Text      = CFG.KillerDirection and "ON" or "Off"

            -- Utility tab
            _infoHealth.Text  = hpTxt
            _infoStamina.Text = stamTxt
            _infoUTeam.Text   = teamTxt
            _infoRuntime.Text = rtime
            _infoStatus.Text  = anyOn and "Running" or "Idle"

            -- Auto tab
            _infoAutoStatus.Text = mode
            _infoGenHold.Text    = _autoGenHolding and "YES" or "No"
            _infoEscapeRdy.Text  = (canEscTxt == "true") and "YES" or "No"

            -- Live Game
            _liveRuntime.Text     = rtime
            _liveStatus.Text      = mode
            _liveHealth.Text      = hpTxt
            _liveStamina.Text     = stamTxt
            _liveTeam.Text        = teamTxt
            _liveKillerDist.Text  = killerDistTxt
            _liveKillerHP.Text    = killerHPTxt
            _liveKillerNear.Text  = killerNearTxt
            _livePhase.Text       = phaseTxt
            _liveEscape.Text      = canEscTxt
            _liveAlive.Text       = aliveTxt

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
switchTab(CFG.ActiveTab or "ESP")

print("[Aurora v5] Bite By Night loaded")

--// Aurora v5 — Bite By Night
--// AuroraHub Edition (Wave / Potassium)
--// PlaceId: 70845479499574
--// 3-Column HUD: Sidebar + Panel Alpha + Panel Beta + Live Game + floating pill

getgenv().AuroraTier = getgenv().AuroraTier or "private"

--========================================================================
-- SERVICES
--========================================================================
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local Lighting       = game:GetService("Lighting")
local UIS            = game:GetService("UserInputService")
local HttpService    = game:GetService("HttpService")
local Player         = Players.LocalPlayer

--========================================================================
-- CLEANUP (old + new gui names)
--========================================================================
for _, n in ipairs({"Aurora", "AuroraHubUI", "AuroraHubPill", "AuroraAlert", "AuroraDir"}) do
    pcall(function() local o = Player.PlayerGui:FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(n); if o then o:Destroy() end end)
    pcall(function()
        if typeof(gethui) == "function" then
            local o = gethui():FindFirstChild(n); if o then o:Destroy() end
        end
    end)
end

--========================================================================
-- SESSION KILL + alive()  (PRESERVED __AURORA_BN_ prefix)
--========================================================================
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

--========================================================================
-- GAME REFS
--========================================================================
local WS = game.Workspace
local GAME_STATE = WS:FindFirstChild("GAME")

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

--========================================================================
-- JITTER
--========================================================================
local function jitter(base, range)
    return base + math.random() * (range or base * 0.3)
end

--========================================================================
-- CONFIG (getgenv-backed; PRESERVED __AURORA_BN_CFG)
--========================================================================
if not getgenv().__AURORA_BN_CFG then
    getgenv().__AURORA_BN_CFG = {
        KillerESP       = false,
        GeneratorESP    = false,
        FuseBoxESP      = false,
        FusePointESP    = false,
        TrapESP         = false,
        EscapeESP       = false,
        SurvivorESP     = false,
        CameraESP       = false,
        KillerAlert     = false,
        KillerDirection = false,
        Fullbright      = false,
        SpeedBoost      = false,
        AntiAFK         = false,
        Noclip          = false,
        InfStamina      = false,
        AutoEscape      = false,
        NoBlind         = false,
        KillerSpeed     = false,
        AutoRepairGen   = false,
        UnlockJump      = false,
        AutoSave        = false,
        -- v5 UI state
        ActiveTab       = "ESP",
        PanelOpen       = true,
    }
end
local CFG = getgenv().__AURORA_BN_CFG

--========================================================================
-- SAVE / LOAD (preserved _cfgFileName)
--========================================================================
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
    pcall(function() writefile(_cfgFileName, HttpService:JSONEncode(CFG)) end)
    getgenv()["AuroraCFG_bite_by_night"] = CFG
end

loadSavedCFG()

--========================================================================
-- LIGHTING BACKUP
--========================================================================
local originalAmbient = Lighting.Ambient
local originalOutdoorAmbient = Lighting.OutdoorAmbient
local originalClockTime = Lighting.ClockTime
local originalFogEnd = Lighting.FogEnd
local originalFogStart = Lighting.FogStart
local originalFogColor = Lighting.FogColor

--========================================================================
-- ESP CLEANUP REGISTRY
--========================================================================
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

--========================================================================
-- KILLER ALERT UI (separate ScreenGui — functional in-game HUD, preserved)
--========================================================================
local alertGui = Instance.new("ScreenGui")
alertGui.Name = "AuroraAlert"
alertGui.ResetOnSpawn = false
alertGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
alertGui.DisplayOrder = 100
do
    local ok = pcall(function()
        local _aOk = false; if typeof(gethui) == "function" then _aOk = pcall(function() alertGui.Parent = gethui() end) end; if not _aOk then _aOk = pcall(function() alertGui.Parent = game:GetService("CoreGui") end) end; if not _aOk then alertGui.Parent = Player.PlayerGui end
    end)
    if not ok then alertGui.Parent = Player.PlayerGui end
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

--========================================================================
-- DIRECTION ARROW UI (separate ScreenGui — preserved)
--========================================================================
local dirGui = Instance.new("ScreenGui")
dirGui.Name = "AuroraDir"
dirGui.ResetOnSpawn = false
dirGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
dirGui.DisplayOrder = 99
do
    local ok = pcall(function()
        local _dOk = false; if typeof(gethui) == "function" then _dOk = pcall(function() dirGui.Parent = gethui() end) end; if not _dOk then _dOk = pcall(function() dirGui.Parent = game:GetService("CoreGui") end) end; if not _dOk then dirGui.Parent = Player.PlayerGui end
    end)
    if not ok then dirGui.Parent = Player.PlayerGui end
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

--========================================================================
-- NOCLIP LOOP (PRESERVED)
--========================================================================
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
                    for _, part in ipairs(char:GetDescendants()) do
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
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = true end
                    end
                end
            end)
        end
    end
end)

--========================================================================
-- SPEED LOOP (PRESERVED)
--========================================================================
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

--========================================================================
-- ANTI-AFK LOOP (PRESERVED)
--========================================================================
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

--========================================================================
-- FULLBRIGHT LOOP (PRESERVED)
--========================================================================
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

--========================================================================
-- INF STAMINA (PRESERVED)
--========================================================================
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

--========================================================================
-- AUTO ESCAPE LOOP (PRESERVED)
--========================================================================
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        if CFG.AutoEscape then
            pcall(function()
                local canEscape = WS.GAME and WS.GAME:FindFirstChild("CAN_ESCAPE")
                if canEscape and canEscape.Value == true then
                    local gameMap = getGameMap()
                    local escapes = gameMap and gameMap:FindFirstChild("Escapes")
                    if escapes then
                        for _, e in ipairs(escapes:GetChildren()) do
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

--========================================================================
-- NO BLINDNESS LOOP (PRESERVED)
--========================================================================
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        if CFG.NoBlind then
            pcall(function()
                local ui = Player.PlayerGui:FindFirstChild("UI")
                if ui then
                    for _, d in ipairs(ui:GetDescendants()) do
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

--========================================================================
-- KILLER SPEED BOOST LOOP (PRESERVED)
--========================================================================
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

--========================================================================
-- AUTO REPAIR GENERATOR (PRESERVED)
--========================================================================
local _autoGenVIM; pcall(function() _autoGenVIM = Instance.new("VirtualInputManager") end)
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
            for _, gen in ipairs(gens:GetChildren()) do
                for _, d in ipairs(gen:GetDescendants()) do
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

--========================================================================
-- UNLOCK JUMP (PRESERVED)
--========================================================================
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

--========================================================================
-- KILLER ALERT + DIRECTION LOOP (PRESERVED)
--========================================================================
local alertFlash = false
task.spawn(function()
    while alive() and task.wait(jitter(0.5, 0.5)) do
        pcall(function()
            if not (CFG.KillerAlert or CFG.KillerDirection) then
                alertFrame.Visible = false
                dirFrame.Visible = false
                return
            end
            local char = Player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then
                alertFrame.Visible = false
                dirFrame.Visible = false
                return
            end

            local killerModel = getKillerModel()
            if not killerModel then
                alertFrame.Visible = false
                dirFrame.Visible = false
                return
            end

            local killerRoot = killerModel:FindFirstChild("HumanoidRootPart")
                or killerModel:FindFirstChildOfClass("BasePart")
            if not killerRoot then
                alertFrame.Visible = false
                dirFrame.Visible = false
                return
            end

            local dist = math.floor((hrp.Position - killerRoot.Position).Magnitude)

            if CFG.KillerAlert then
                if dist <= 60 then
                    alertFlash = not alertFlash
                    alertFrame.Visible = true
                    alertLabel.Text = "KILLER NEARBY!  " .. dist .. "m away"
                    alertFrame.BackgroundTransparency = alertFlash and 0.1 or 0.35
                else
                    alertFrame.Visible = false
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

--========================================================================
-- ESP UPDATE LOOP (PRESERVED)
--========================================================================
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
                for _, folder in ipairs(WS.PLAYERS:GetChildren()) do
                    if folder.Name == "KILLER" then
                        for _, mdl in ipairs(folder:GetChildren()) do
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
                    for _, gen in ipairs(genFolder:GetChildren()) do
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
                    for _, fuse in ipairs(fuseFolder:GetChildren()) do
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
                    for _, esc in ipairs(escFolder:GetChildren()) do
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
                    for _, cam in ipairs(camFolder:GetChildren()) do
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
                for _, obj in ipairs(ignoreFolder:GetChildren()) do
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
                    for _, surv in ipairs(aliveFolder:GetChildren()) do
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
    { name = "ESP",      icon = "●" },
    { name = "Alerts",   icon = "◆" },
    { name = "Utility",  icon = "◉" },
    { name = "Auto",     icon = "≡" },
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

-- Forward-declare popup helpers (defined later; currently no dropdowns but needed for drag + minimize)
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
local TAB_NAMES = { "ESP", "Alerts", "Utility", "Auto", "Configs", "Settings" }
local TAB_ACCENT = {
    ESP = C.pink, Alerts = C.red, Utility = C.pink,
    Auto = C.pink, Configs = C.pink, Settings = C.pink,
}
local PANEL_TITLES = {
    ESP      = { alpha = "ENTITIES", beta = "OBJECTS"   },
    Alerts   = { alpha = "KILLER",   beta = "VISION"    },
    Utility  = { alpha = "MOVEMENT", beta = "SAFETY"    },
    Auto     = { alpha = "REPAIR",   beta = "ESCAPE"    },
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
local function nE() oE_a = oE_a + 1; return oE_a end
local function nEB() oE_b = oE_b + 1; return oE_b end

sectionHeader(scrolls["ESP_alpha"], "●", "Killer",                    nE())
toggleRow    (scrolls["ESP_alpha"], "Killer ESP",   "KillerESP",      nE())
toggleRow    (scrolls["ESP_alpha"], "Survivor ESP", "SurvivorESP",    nE())

sectionHeader(scrolls["ESP_alpha"], "✦", "Notes",                     nE())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1,
    Text = "Killer ESP shows the active killer with HP + distance.\nSurvivor ESP shows teammates alive with HP.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nE(),
}, scrolls["ESP_alpha"])

sectionHeader(scrolls["ESP_beta"],  "◉", "Objectives",                nEB())
toggleRow    (scrolls["ESP_beta"],  "Generator ESP",  "GeneratorESP", nEB())
toggleRow    (scrolls["ESP_beta"],  "Fuse Box ESP",   "FuseBoxESP",   nEB())
toggleRow    (scrolls["ESP_beta"],  "Fuse Point ESP", "FusePointESP", nEB())
toggleRow    (scrolls["ESP_beta"],  "Escape ESP",     "EscapeESP",    nEB())

sectionHeader(scrolls["ESP_beta"],  "▣", "Environment",               nEB())
toggleRow    (scrolls["ESP_beta"],  "Camera ESP", "CameraESP", nEB())
toggleRow    (scrolls["ESP_beta"],  "Trap ESP",   "TrapESP",   nEB())

--========================================================================
-- POPULATE: ALERTS
--========================================================================
local oA_a, oA_b = 0, 0
local function nA() oA_a = oA_a + 1; return oA_a end
local function nAB() oA_b = oA_b + 1; return oA_b end

sectionHeader(scrolls["Alerts_alpha"], "◆", "Killer Awareness",      nA())
toggleRow    (scrolls["Alerts_alpha"], "Killer Alert",     "KillerAlert",     nA())
toggleRow    (scrolls["Alerts_alpha"], "Killer Direction", "KillerDirection", nA())

sectionHeader(scrolls["Alerts_alpha"], "✦", "Notes",                  nA())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Alert flashes when killer is within 60m.\nDirection arrow rotates to point at killer — shown at bottom of screen.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nA(),
}, scrolls["Alerts_alpha"])

sectionHeader(scrolls["Alerts_beta"], "◉", "Vision",                  nAB())
toggleRow    (scrolls["Alerts_beta"], "Fullbright",   "Fullbright", nAB(), function(on)
    if not on then
        pcall(function()
            Lighting.Ambient = originalAmbient
            Lighting.OutdoorAmbient = originalOutdoorAmbient
            Lighting.ClockTime = originalClockTime
            Lighting.FogEnd = originalFogEnd
            Lighting.FogStart = originalFogStart
        end)
    end
end)
toggleRow    (scrolls["Alerts_beta"], "No Blindness", "NoBlind",    nAB())

sectionHeader(scrolls["Alerts_beta"], "✦", "Tips",                    nAB())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1,
    Text = "Fullbright lights the map + disables fog.\nNo Blindness removes killer blind overlays + camera distortion.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAB(),
}, scrolls["Alerts_beta"])

--========================================================================
-- POPULATE: UTILITY
--========================================================================
local oU_a, oU_b = 0, 0
local function nU() oU_a = oU_a + 1; return oU_a end
local function nUB() oU_b = oU_b + 1; return oU_b end

sectionHeader(scrolls["Utility_alpha"], "◉", "Movement",              nU())
toggleRow    (scrolls["Utility_alpha"], "Speed Boost", "SpeedBoost", nU())
toggleRow    (scrolls["Utility_alpha"], "Noclip",      "Noclip",     nU())
toggleRow    (scrolls["Utility_alpha"], "Unlock Jump", "UnlockJump", nU())
toggleRow    (scrolls["Utility_alpha"], "Inf Stamina", "InfStamina", nU())

sectionHeader(scrolls["Utility_alpha"], "✦", "Tips",                  nU())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 70), BackgroundTransparency = 1,
    Text = "Speed Boost: 24 walk / 36 run (survivor default 12/24).\nUnlock Jump: jump height 7.2, power 50.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nU(),
}, scrolls["Utility_alpha"])

sectionHeader(scrolls["Utility_beta"], "●", "Safety",                 nUB())
toggleRow    (scrolls["Utility_beta"], "Anti-AFK", "AntiAFK", nUB())

sectionHeader(scrolls["Utility_beta"], "◆", "Killer Only",            nUB())
toggleRow    (scrolls["Utility_beta"], "Killer Speed", "KillerSpeed", nUB())

sectionHeader(scrolls["Utility_beta"], "✦", "Notes",                  nUB())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 80), BackgroundTransparency = 1,
    Text = "Anti-AFK teleports you 0.1 studs every ~4m to prevent disconnect.\nKiller Speed only boosts when your Team attr = Killer.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nUB(),
}, scrolls["Utility_beta"])

--========================================================================
-- POPULATE: AUTO
--========================================================================
local oAu_a, oAu_b = 0, 0
local function nAu() oAu_a = oAu_a + 1; return oAu_a end
local function nAuB() oAu_b = oAu_b + 1; return oAu_b end

sectionHeader(scrolls["Auto_alpha"], "≡", "Automation",                nAu())
toggleRow    (scrolls["Auto_alpha"], "Auto Repair Gen", "AutoRepairGen", nAu())
toggleRow    (scrolls["Auto_alpha"], "Auto Escape",     "AutoEscape",    nAu())

sectionHeader(scrolls["Auto_alpha"], "✦", "How it works",              nAu())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1,
    Text = "Auto Repair Gen: walks to nearest generator Fix prompt and holds E until done.\nAuto Escape: waits for CAN_ESCAPE, then TPs to nearest exit.\nBoth require Survivor team.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAu(),
}, scrolls["Auto_alpha"])

sectionHeader(scrolls["Auto_beta"], "✦", "Status",                    nAuB())
create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1,
    Text = "Keep an eye on the Live Game column for Auto Status.\nRepair only runs while the game is active.\nEscape only runs once escape gates are powered.",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text3,
    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    LayoutOrder = nAuB(),
}, scrolls["Auto_beta"])

--========================================================================
-- POPULATE: CONFIGS
--========================================================================
local oC_a, oC_b = 0, 0
local function nC() oC_a = oC_a + 1; return oC_a end
local function nCB() oC_b = oC_b + 1; return oC_b end

sectionHeader(scrolls["Configs_alpha"], "●", "Config",                nC())
toggleRow    (scrolls["Configs_alpha"], "Auto-Save", "AutoSave", nC())
actionBtn    (scrolls["Configs_alpha"], "Save Config", C.green, nC(), function() saveCFG() end)
actionBtn    (scrolls["Configs_alpha"], "Load Config", C.bg3,   nC(), function() loadSavedCFG() end)
actionBtn    (scrolls["Configs_alpha"], "Reset All",   C.red,   nC(), function()
    for k, v in pairs(CFG) do
        if type(v) == "boolean" and k ~= "PanelOpen" then CFG[k] = false end
    end
    saveCFG()
end)

sectionHeader(scrolls["Configs_beta"], "▣", "Info",                   nCB())
infoRow      (scrolls["Configs_beta"], "File", _cfgFileName, C.text2, nCB())

sectionHeader(scrolls["Configs_beta"], "✦", "Active Features",        nCB())
local _cfgActiveLabel = create("TextLabel", {
    Name = "ActiveList", Size = UDim2.new(1, 0, 0, 180),
    BackgroundTransparency = 1, Text = "None",
    Font = F_SANS, TextSize = 11, TextColor3 = C.text2,
    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
    TextWrapped = true, LayoutOrder = nCB(),
}, scrolls["Configs_beta"])

--========================================================================
-- POPULATE: SETTINGS
--========================================================================
local oS_a, oS_b = 0, 0
local function nS() oS_a = oS_a + 1; return oS_a end
local function nSB() oS_b = oS_b + 1; return oS_b end

sectionHeader(scrolls["Settings_alpha"], "●", "UI",                   nS())
actionBtn    (scrolls["Settings_alpha"], "Reset Position", C.bg3, nS(), function()
    main.Position = UDim2.fromScale(0.5, 0.5)
end)
actionBtn    (scrolls["Settings_alpha"], "Destroy UI",     C.red, nS(), function()
    task.wait(0.3)
    getgenv().__AURORA_BN_SESSION = 0
    pcall(function() screenGui:Destroy() end)
    pcall(function() if pillGui then pillGui:Destroy() end end)
    pcall(function() if alertGui then alertGui:Destroy() end end)
    pcall(function() if dirGui then dirGui:Destroy() end end)
end)

sectionHeader(scrolls["Settings_beta"], "✦", "About",                 nSB())
infoRow(scrolls["Settings_beta"], "Game",    "Bite By Night",           C.text,  nSB())
infoRow(scrolls["Settings_beta"], "PlaceId", tostring(game.PlaceId),    C.text2, nSB())
infoRow(scrolls["Settings_beta"], "Version", tostring(game.PlaceVersion), C.text2, nSB())
infoRow(scrolls["Settings_beta"], "Hub",     "Aurorahub.net",           C.pink,  nSB())
infoRow(scrolls["Settings_beta"], "Build",   "v5",                       C.text2, nSB())

--========================================================================
-- POPULATE: LIVE GAME (persistent)
--========================================================================
local oL = 0
local function nL() oL = oL + 1; return oL end
sectionHeader(liveScroll, "◉", "Session",                             nL())
local _infoRuntime    = infoRow(liveScroll, "Runtime",    "0m",   C.text2, nL())

sectionHeader(liveScroll, "◆", "Killer",                              nL())
local _infoKillerDist = infoRow(liveScroll, "Distance",   "—",    C.text2, nL())
local _infoKillerHP   = infoRow(liveScroll, "HP",         "—",    C.text2, nL())
local _infoKillerNear = infoRow(liveScroll, "Nearby",     "No",   C.text2, nL())

sectionHeader(liveScroll, "●", "Player",                              nL())
local _infoTeam       = infoRow(liveScroll, "Team",       "—",    C.text2, nL())
local _infoHealth     = infoRow(liveScroll, "Health",     "—",    C.text2, nL())
local _infoStamina    = infoRow(liveScroll, "Stamina",    "—",    C.text2, nL())

sectionHeader(liveScroll, "▣", "Game",                                nL())
local _infoGameState  = infoRow(liveScroll, "Phase",      "—",    C.text2, nL())
local _infoCanEscape  = infoRow(liveScroll, "Can Escape", "—",    C.text2, nL())
local _infoSurvivors  = infoRow(liveScroll, "Alive",      "—",    C.pink,  nL())

sectionHeader(liveScroll, "≡", "Auto",                                nL())
local _infoAutoStatus = infoRow(liveScroll, "Status",     "Idle", C.pink,  nL())
local _infoAlertStat  = infoRow(liveScroll, "Alert",      "Off",  C.text2, nL())

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
-- DRAG
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

-- Global outside-click handler for dropdowns (no dropdowns yet, kept for parity)
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
        getgenv().__AURORA_BN_SESSION = 0
        task.wait(0.05)
        pcall(function() screenGui:Destroy() end)
        pcall(function() pillGui:Destroy() end)
        pcall(function() alertGui:Destroy() end)
        pcall(function() dirGui:Destroy() end)
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
    local _sessionStart = tick()
    while alive() do
        task.wait(jitter(1, 0.3))
        if not alive() then break end
        pcall(function()
            -- Session
            local elapsed = tick() - _sessionStart
            local mins = math.floor(elapsed / 60)
            local hrs  = math.floor(mins / 60)
            _infoRuntime.Text = hrs > 0 and string.format("%dh %dm", hrs, mins % 60) or string.format("%dm", mins)

            -- Player
            local char = Player.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then _infoHealth.Text = math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) end
                local stam = char:GetAttribute("Stamina")
                local maxStam = char:GetAttribute("MaxStamina")
                if stam and maxStam then _infoStamina.Text = math.floor(stam) .. "/" .. math.floor(maxStam) end
                local team = char:GetAttribute("Team")
                _infoTeam.Text = team or "—"
            end

            -- Killer
            local killerModel = getKillerModel()
            if killerModel then
                local dist = getDistance(killerModel)
                _infoKillerDist.Text = dist .. "m"
                local killerHum = getKillerHumanoid(killerModel)
                if killerHum then
                    _infoKillerHP.Text = math.floor(killerHum.Health) .. "/" .. math.floor(killerHum.MaxHealth)
                else
                    _infoKillerHP.Text = "—"
                end
                _infoKillerNear.Text = (dist <= 60) and "YES" or "No"
            else
                _infoKillerDist.Text = "—"
                _infoKillerHP.Text = "—"
                _infoKillerNear.Text = "—"
            end

            -- Game State
            pcall(function()
                if GAME_STATE then
                    local phase = GAME_STATE:FindFirstChild("Phase")
                    _infoGameState.Text = phase and tostring(phase.Value) or "—"
                    local canEsc = GAME_STATE:FindFirstChild("CAN_ESCAPE")
                    _infoCanEscape.Text = canEsc and tostring(canEsc.Value) or "—"
                end
            end)

            pcall(function()
                local playersFolder = WS:FindFirstChild("PLAYERS")
                local aliveFolder = playersFolder and playersFolder:FindFirstChild("ALIVE")
                _infoSurvivors.Text = aliveFolder and tostring(#aliveFolder:GetChildren()) or "—"
            end)

            _infoAlertStat.Text = CFG.KillerAlert and "ON" or "Off"

            -- Auto
            if CFG.AutoRepairGen then _infoAutoStatus.Text = "Repairing"
            elseif CFG.AutoEscape then _infoAutoStatus.Text = "Escaping"
            else _infoAutoStatus.Text = "Idle" end

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
switchTab(CFG.ActiveTab or "ESP")

print("[Aurora v5] Bite By Night loaded")

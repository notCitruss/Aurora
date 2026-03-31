--// Aurora — RTS Godmode
--// Made by notCitruss
--// Infinite resources, max tech, huge army cap

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Player = Players.LocalPlayer

---------- CONFIG ----------
local CFG = {
    InfiniteResources = false,
    InfiniteMoney = false,
    MaxTech = false,
    MaxPop = false,
}

---------- CORE ----------
local function getStats()
    local pf = workspace:FindFirstChild("Game")
    if not pf then return nil end
    pf = pf:FindFirstChild("PlayerFolders")
    if not pf then return nil end
    pf = pf:FindFirstChild(Player.Name)
    if not pf then return nil end
    return pf:FindFirstChild("Stats")
end

-- Resource loop
RunService.Heartbeat:Connect(function()
    local stats = getStats()
    if not stats then return end

    if CFG.InfiniteResources then
        pcall(function()
            stats.Wood.Value = 999999
            stats.Stone.Value = 999999
            stats.MaxEnergy.Value = 99999
            -- DON'T touch CurrentEnergy - let the game manage it naturally
            -- Available energy = MaxEnergy - CurrentEnergy
        end)
    end

    if CFG.InfiniteMoney then
        pcall(function()
            if stats.Money.Value < 999999 then
                stats.Money.Value = 999999
            end
        end)
    end

    if CFG.MaxTech then
        pcall(function() stats.TechLevel.Value = 10 end)
    end

    if CFG.MaxPop then
        pcall(function() stats.MaxPop.Value = 9999 end)
    end
end)

---------- AURORA UI ----------
local PINK = Color3.fromRGB(255, 105, 140)
local PINK_DARK = Color3.fromRGB(220, 70, 110)
local PINK_LIGHT = Color3.fromRGB(255, 180, 200)
local WHITE = Color3.fromRGB(255, 255, 255)
local BG = Color3.fromRGB(245, 245, 248)
local TEXT_DARK = Color3.fromRGB(40, 40, 50)
local TEXT_MED = Color3.fromRGB(100, 100, 110)
local OFF_BG = Color3.fromRGB(225, 225, 230)

for _, n in {"Aurora"} do
    local old = Player.PlayerGui:FindFirstChild(n)
    if old then old:Destroy() end
end

local gui = Instance.new("ScreenGui")
gui.Name = "Aurora"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Player.PlayerGui

local main = Instance.new("Frame")
main.Size = UDim2.fromOffset(260, 0)
main.Position = UDim2.fromOffset(20, 150)
main.BackgroundColor3 = BG
main.BorderSizePixel = 0
main.Parent = gui
main.Active = true
main.Draggable = true
main.ClipsDescendants = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- Shadow
local shadow = Instance.new("ImageLabel", main)
shadow.Size = UDim2.new(1, 30, 1, 30)
shadow.Position = UDim2.fromOffset(-15, -15)
shadow.BackgroundTransparency = 1
shadow.Image = "rbxassetid://6014261993"
shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
shadow.ImageTransparency = 0.6
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(49, 49, 450, 450)
shadow.ZIndex = 0

-- Title
local titleBar = Instance.new("Frame", main)
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = PINK
titleBar.BorderSizePixel = 0
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 10)
local titleFix = Instance.new("Frame", titleBar)
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = PINK
titleFix.BorderSizePixel = 0

Instance.new("TextLabel", titleBar).Size = UDim2.fromOffset(30, 30)
    ;(function(l) l.Position = UDim2.fromOffset(8, 7) l.BackgroundTransparency = 1
    l.Text = "\xF0\x9F\x8C\xB8" l.TextSize = 22 end)(titleBar:FindFirstChildOfClass("TextLabel"))

local t = Instance.new("TextLabel", titleBar)
t.Size = UDim2.new(1, -72, 0, 22)
t.Position = UDim2.fromOffset(38, 4)
t.BackgroundTransparency = 1
t.Text = "Aurora"
t.TextColor3 = WHITE
t.TextSize = 17
t.Font = Enum.Font.GothamBold
t.TextXAlignment = Enum.TextXAlignment.Left

local s = Instance.new("TextLabel", titleBar)
s.Size = UDim2.new(1, -40, 0, 12)
s.Position = UDim2.fromOffset(38, 26)
s.BackgroundTransparency = 1
s.Text = "by notCitruss \xE2\x80\x94 RTS Godmode"
s.TextColor3 = Color3.fromRGB(255, 220, 230)
s.TextSize = 10
s.Font = Enum.Font.Gotham
s.TextXAlignment = Enum.TextXAlignment.Left

-- Status
local statusBar = Instance.new("Frame", main)
statusBar.Size = UDim2.new(1, 0, 0, 24)
statusBar.Position = UDim2.fromOffset(0, 44)
statusBar.BackgroundColor3 = Color3.fromRGB(252, 248, 250)
statusBar.BorderSizePixel = 0

local status = Instance.new("TextLabel", statusBar)
status.Size = UDim2.new(1, -12, 1, 0)
status.Position = UDim2.fromOffset(6, 0)
status.BackgroundTransparency = 1
status.Text = "Idle"
status.TextColor3 = TEXT_MED
status.TextSize = 9
status.Font = Enum.Font.Gotham
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextTruncate = Enum.TextTruncate.AtEnd

local y = 72
local contentItems = {}
local function track(obj) table.insert(contentItems, obj) return obj end

local function addToggle(label, key)
    local row = track(Instance.new("Frame", main))
    row.Size = UDim2.new(1, -16, 0, 28)
    row.Position = UDim2.new(0, 8, 0, y)
    row.BackgroundTransparency = 1

    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -56, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = TEXT_DARK
    lbl.TextSize = 12
    lbl.Font = Enum.Font.GothamSemibold
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local toggle = Instance.new("Frame", row)
    toggle.Size = UDim2.fromOffset(44, 20)
    toggle.Position = UDim2.new(1, -44, 0.5, -10)
    toggle.BorderSizePixel = 0
    toggle.Active = true
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(1, 0)

    local circle = Instance.new("Frame", toggle)
    circle.Size = UDim2.fromOffset(14, 14)
    circle.BorderSizePixel = 0
    circle.BackgroundColor3 = WHITE
    Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

    local function refresh()
        local on = CFG[key]
        toggle.BackgroundColor3 = on and PINK or OFF_BG
        circle.Position = on and UDim2.new(1, -17, 0.5, -7) or UDim2.fromOffset(3, 3)
    end

    toggle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            CFG[key] = not CFG[key]
            refresh()
        end
    end)

    refresh()
    y += 30
end

local function addSep()
    local sep = track(Instance.new("Frame", main))
    sep.Size = UDim2.new(1, -24, 0, 1)
    sep.Position = UDim2.new(0, 12, 0, y)
    sep.BackgroundColor3 = Color3.fromRGB(220, 215, 220)
    sep.BorderSizePixel = 0
    y += 6
end

local function addHeader(text)
    local h = track(Instance.new("TextLabel", main))
    h.Size = UDim2.new(1, -16, 0, 14)
    h.Position = UDim2.new(0, 8, 0, y)
    h.BackgroundTransparency = 1
    h.Text = text
    h.TextColor3 = PINK_DARK
    h.TextSize = 10
    h.Font = Enum.Font.GothamBold
    h.TextXAlignment = Enum.TextXAlignment.Left
    y += 16
end

addHeader("EXPLOITS")
addToggle("Infinite Resources", "InfiniteResources")
addToggle("Infinite Money", "InfiniteMoney")
addToggle("Max Tech Level (10)", "MaxTech")
addToggle("Max Population (9999)", "MaxPop")

addSep()

-- Info panel
local infoFrame = track(Instance.new("Frame", main))
infoFrame.Size = UDim2.new(1, -16, 0, 70)
infoFrame.Position = UDim2.new(0, 8, 0, y)
infoFrame.BackgroundColor3 = Color3.fromRGB(252, 248, 250)
infoFrame.BorderSizePixel = 0
Instance.new("UICorner", infoFrame).CornerRadius = UDim.new(0, 6)
Instance.new("UIStroke", infoFrame).Color = PINK_LIGHT

local infoText = Instance.new("TextLabel", infoFrame)
infoText.Size = UDim2.new(1, -12, 1, 0)
infoText.Position = UDim2.fromOffset(6, 0)
infoText.BackgroundTransparency = 1
infoText.Text = "Loading..."
infoText.TextColor3 = TEXT_DARK
infoText.TextSize = 9
infoText.Font = Enum.Font.Gotham
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Top
infoText.TextWrapped = true
y += 76

local fullH = y + 4
main.Size = UDim2.fromOffset(260, fullH)

-- Mini flower button
local miniBtn = Instance.new("Frame", gui)
miniBtn.Size = UDim2.fromOffset(44, 44)
miniBtn.Position = main.Position
miniBtn.BackgroundColor3 = PINK
miniBtn.BorderSizePixel = 0
miniBtn.Visible = false
miniBtn.Active = true
Instance.new("UICorner", miniBtn).CornerRadius = UDim.new(1, 0)
do
    local mf = Instance.new("Frame", miniBtn)
    mf.Size = UDim2.fromOffset(30, 30); mf.Position = UDim2.fromOffset(7, 7); mf.BackgroundTransparency = 1
    for i = 0, 4 do
        local a = math.rad(i * 72 - 90)
        local p = Instance.new("Frame", mf)
        p.Size = UDim2.fromOffset(11, 11)
        p.Position = UDim2.fromOffset(15 + math.cos(a) * 8 - 5, 15 + math.sin(a) * 8 - 5)
        p.BackgroundColor3 = Color3.fromRGB(255, 210, 225); p.BackgroundTransparency = 0.1; p.BorderSizePixel = 0; p.Rotation = i * 72
        Instance.new("UICorner", p).CornerRadius = UDim.new(0, 5)
    end
    local mc = Instance.new("Frame", mf)
    mc.Size = UDim2.fromOffset(6, 6); mc.Position = UDim2.fromOffset(12, 12)
    mc.BackgroundColor3 = WHITE; mc.BackgroundTransparency = 0.1; mc.BorderSizePixel = 0
    Instance.new("UICorner", mc).CornerRadius = UDim.new(1, 0)
end

-- Minimize
local mb = Instance.new("Frame", titleBar)
mb.Size = UDim2.fromOffset(26, 26)
mb.Position = UDim2.new(1, -30, 0.5, -13)
mb.BackgroundTransparency = 1
mb.Active = true
local mbLbl = Instance.new("TextLabel", mb)
mbLbl.Size = UDim2.new(1, 0, 1, 0); mbLbl.BackgroundTransparency = 1
mbLbl.Text = "\xE2\x88\x92"; mbLbl.TextColor3 = WHITE; mbLbl.TextSize = 22; mbLbl.Font = Enum.Font.GothamBold

mb.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        miniBtn.Position = main.Position
        main.Visible = false
        miniBtn.Visible = true
    end
end)
miniBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        main.Position = miniBtn.Position
        miniBtn.Visible = false
        main.Visible = true
    end
end)

---------- UPDATER ----------
task.spawn(function()
    while task.wait(0.5) do
        pcall(function()
            local stats = getStats()
            if not stats then
                status.Text = "No stats found"
                return
            end

            local active = {}
            if CFG.InfiniteResources then table.insert(active, "Res") end
            if CFG.InfiniteMoney then table.insert(active, "$$$") end
            if CFG.MaxTech then table.insert(active, "Tech") end
            if CFG.MaxPop then table.insert(active, "Pop") end

            if #active > 0 then
                status.Text = "ACTIVE: " .. table.concat(active, " + ")
                status.TextColor3 = PINK_DARK
            else
                status.Text = "Idle — toggle exploits above"
                status.TextColor3 = TEXT_MED
            end

            local money = stats.Money.Value
            local wood = stats.Wood.Value
            local stone = stats.Stone.Value
            local maxE = stats.MaxEnergy.Value
            local curE = stats.CurrentEnergy.Value
            local tech = stats.TechLevel.Value
            local pop = stats.CurrentPop.Value
            local maxPop = stats.MaxPop.Value

            infoText.Text = string.format(
                "Money: $%.0f | Wood: %d | Stone: %d\nEnergy: %d/%d (avail: %d)\nTech: %d | Pop: %d/%d\nGame Time: %ds",
                money, wood, stone,
                curE, maxE, maxE - curE,
                tech, pop, maxPop,
                workspace.Game.GameTime.Value)
        end)
    end
end)

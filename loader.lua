--// Aurora V3 Universal Loader — Splash + Key System + Script Loading
--// Made by notCitruss | 2026
--// Usage: loadstring(game:HttpGet("https://keys.dallaswebstudio.net/loader.lua"))()

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Player = Players.LocalPlayer

---------- CONSTANTS ----------
local BASE_URL = "https://keys.dallaswebstudio.net/script/"
local KEY_API = "https://keys.dallaswebstudio.net"
local KEY_LINK = "https://work.ink/2sxb/aurora"
local KEY_LINK_2 = "https://link-target.net/4830946/ckqnMuwLtVoa"
local KEY_LINK_3 = "https://loot-link.com/s?ENzanDOy"
local KEY_FILE = "aurora_key.txt"

---------- GAME REGISTRY ----------
local GAMES_BY_ID = {
    [107095834793267] = "oil_empire_autofarm",
    [96840410521899]  = "timber_autofarm",
    [75251063577391]  = "brainrot_heroes_autofarm",
    [77393318863643]  = "aura_ascension",
    [135668295983945] = "skill_point_legends",
    [125007306703268] = "skill_point_incremental",
    [125007306703270] = "skill_point_incremental",
    [138665815682498] = "aim_incremental",
    [124311897657957] = "break_a_lucky_block",
    [124473577469410] = "be_a_lucky_block",
    [77595602575472]  = "zombie_game",
    [126763981794917] = "timber_spin_simulator",
    [105555311806207] = "build_a_zoo",
    [133832344745984] = "shovel_it",
    [98642908897459]  = "larp_roblox_ceo_tycoon",
    [122079988266644] = "idle_potato_game",
    [131756752872026] = "dive_down",
    [83622406313819]  = "loot_up",
    [286090429]       = "arsenal",
    [2133507413]      = "arsenal",
    [127794225497302]      = "abyss",
    [127794225497302]      = "abyss",
    [606849621]       = "jailbreak",
    [109073199927285]      = "tsunami",
    [109073199927285]      = "tsunami",
    [109983668079237]     = "sab",
    [109397169461300]      = "sniper_duels",
    [109397169461300]      = "sniper_duels",
    [16653555262]      = "swing_obby",
    [4924922222]      = "brookhaven",
    [79546208627805]     = "ninety_nine_nights",
    [2753915549]      = "blox_fruits",
    [70845479499574]  = "bite_by_night",
    [80003276594057]  = "pixel_quest",
    [92173115378522]  = "split_the_sea",
    [132391015411211] = "split_or_steal",
    [77747658251236]  = "sailor_piece",
}

local GAMES_BY_NAME = {
    ["oil empire"]            = "oil_empire_autofarm",
    ["timber!"]               = "timber_autofarm",
    ["aura ascension"]        = "aura_ascension",
    ["+1 skill point legends"] = "skill_point_legends",
    ["brainrot heroes"]       = "brainrot_heroes_autofarm",
    ["skill point legends"]   = "skill_point_legends",
    ["skill point rpg"]       = "skill_point_incremental",
    ["skill point incremental"] = "skill_point_incremental",
    ["aim incremental"]       = "aim_incremental",
    ["break a lucky block"]   = "break_a_lucky_block",
    ["be a lucky block"]      = "be_a_lucky_block",
    ["zombie"]                = "zombie_game",
    ["timber spin"]           = "timber_spin_simulator",
    ["build a zoo"]           = "build_a_zoo",
    ["shovel it"]             = "shovel_it",
    ["larp as roblox ceo"]    = "larp_roblox_ceo_tycoon",
    ["roblox ceo tycoon"]     = "larp_roblox_ceo_tycoon",
    ["idle potato"]           = "idle_potato_game",
    ["idle potato game"]      = "idle_potato_game",
    ["dive down"]             = "dive_down",
    ["loot up"]               = "loot_up",
    ["loot up!"]              = "loot_up",
    ["arsenal"]               = "arsenal",
    ["abyss"]                 = "abyss",
    ["jailbreak"]             = "jailbreak",
    ["tsunami"]               = "tsunami",
    ["escape the tsunami"]    = "tsunami",
    ["sab"]                   = "sab",
    ["steal a brainrot"]      = "sab",
    ["sniper duels"]          = "sniper_duels",
    ["swing obby"]            = "swing_obby",
    ["brookhaven"]            = "brookhaven",
    ["99 nights"]             = "ninety_nine_nights",
    ["blox fruits"]           = "blox_fruits",
    ["bite by night"]         = "bite_by_night",
    ["pixel quest"]           = "pixel_quest",
    ["split the sea"]         = "split_the_sea",
    ["split or steal"]        = "split_or_steal",
    ["sailor piece"]          = "sailor_piece",
}

---------- HWID ----------
local HWID = "nohwid"
pcall(function() if gethwid then HWID = gethwid() end end)
pcall(function() if HWID == "nohwid" and getexecutorhwid then HWID = getexecutorhwid() end end)
pcall(function() if HWID == "nohwid" and identifyexecutor then HWID = tostring(identifyexecutor()) .. "_" .. tostring(Player.UserId) end end)

---------- DETECT GAME ----------
local placeId = game.PlaceId
local placeName = "Unknown"
pcall(function() placeName = MarketplaceService:GetProductInfo(placeId).Name or "Unknown" end)
local placeNameLower = placeName:lower()

local scriptName = GAMES_BY_ID[placeId]
if not scriptName then
    for pattern, name in pairs(GAMES_BY_NAME) do
        if placeNameLower:find(pattern) then scriptName = name; break end
    end
end

---------- KEY FUNCTIONS ----------
local function readKey()
    local ok, key = pcall(function()
        if isfile and isfile(KEY_FILE) then return readfile(KEY_FILE) end
        return nil
    end)
    return ok and key or nil
end

local function saveKey(key)
    pcall(function()
        if writefile then writefile(KEY_FILE, key) end
    end)
end

local function validateKey(key)
    if not key or #key < 10 then return false, "free" end
    local ok, result = pcall(function()
        local uid = tostring(Player.UserId)
        local resp = game:HttpGet(KEY_API .. "/validate?key=" .. key .. "&uid=" .. uid .. "&lock=" .. HWID, true)
        local data = HttpService:JSONDecode(resp)
        if data and data.valid == true then
            return { valid = true, tier = data.tier or "premium" }
        end
        return { valid = false, tier = "free" }
    end)
    if ok and result and result.valid then
        return true, result.tier
    end
    return false, "free"
end

---------- CLEANUP OLD GUIs ----------
for _, n in {"Aurora", "AuroraLoader", "AuroraKey", "AuroraV3", "AuroraV3Loader"} do
    pcall(function() Player.PlayerGui:FindFirstChild(n):Destroy() end)
    pcall(function() if gethui then gethui():FindFirstChild(n):Destroy() end end)
    pcall(function() game:GetService("CoreGui"):FindFirstChild(n):Destroy() end)
end

---------- STATE ----------
local savedKey = nil

--// (Phase 1 splash removed — goes straight to key check)

--// ============================================================
--// PHASE 2: KEY CHECK (saved key)
--// ============================================================

savedKey = readKey()
local keyValid = false
if savedKey then
    local valid, tier = validateKey(savedKey)
    keyValid = valid
    if valid then
        getgenv().AuroraTier = tier
        getgenv().AuroraKeyTier = tier
    end
end

--// ============================================================
--// PHASE 3: KEY SYSTEM UI (if key not valid)
--// ============================================================

if not keyValid then
    savedKey = nil

    -- Color palette
    local C = {
        bg = Color3.fromRGB(35, 35, 55),
        panel = Color3.fromRGB(25, 25, 40),
        card = Color3.fromRGB(22, 22, 35),
        accent = Color3.fromRGB(252, 110, 142),
        text = Color3.fromRGB(235, 235, 245),
        dim = Color3.fromRGB(130, 130, 155),
        muted = Color3.fromRGB(70, 70, 90),
        green = Color3.fromRGB(80, 200, 120),
        purple = Color3.fromRGB(140, 80, 200),
        inputBg = Color3.fromRGB(12, 12, 20),
    }

    -- Helpers
    local function create(class, props, parent)
        local inst = Instance.new(class)
        for k, v in pairs(props) do
            if k ~= "Children" then
                inst[k] = v
            end
        end
        if parent then inst.Parent = parent end
        return inst
    end

    local function corner(parent, radius)
        return create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
    end

    local function stroke(parent, color, thickness)
        local s = create("UIStroke", {
            Color = color,
            Thickness = thickness or 1,
            Transparency = 0.2,
            ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
        }, parent)
        return s
    end

    local function glass(parent)
        parent.BackgroundTransparency = 0.10
        parent.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
        local s = Instance.new("UIStroke", parent)
        s.Color = Color3.fromRGB(252, 110, 142)
        s.Thickness = 2
        s.Transparency = 0.2
        s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        return parent
    end

    local function makeButton(frame)
        frame.Active = true
        return frame
    end

    local function connectClick(frame, callback)
        frame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                callback()
            end
        end)
    end

    local function label(parent, props)
        local defaults = {
            BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold,
            TextColor3 = C.text,
            TextSize = 12,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextYAlignment = Enum.TextYAlignment.Center,
            BorderSizePixel = 0,
            Active = false,
        }
        for k, v in pairs(defaults) do
            if props[k] == nil then props[k] = v end
        end
        return create("TextLabel", props, parent)
    end

    -- ScreenGui
    local gui = create("ScreenGui", {
        Name = "Aurora",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        DisplayOrder = 50,
        IgnoreGuiInset = true,
    })
    local guiOk = pcall(function()
        gui.Parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
    end)
    if not guiOk then
        gui.Parent = Player.PlayerGui
    end

    -- Shadow
    local shadow = create("ImageLabel", {
        Name = "Shadow",
        Size = UDim2.new(0, 780 + 44, 0, 460 + 44),
        Position = UDim2.new(0.5, -390 - 22, 0.5, -230 - 22),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014261993",
        ImageColor3 = Color3.fromRGB(80, 40, 80),
        ImageTransparency = 1,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        ZIndex = 0,
    }, gui)

    -- Main Frame (invisible container)
    local main = create("Frame", {
        Name = "Main",
        Size = UDim2.fromOffset(780, 460),
        Position = UDim2.new(0.5, -390, 0.5, -230),
        BackgroundColor3 = Color3.fromRGB(30, 30, 50),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Active = true,
        Draggable = true,
        ClipsDescendants = true,
    }, gui)
    corner(main, 14)

    -- Entrance animation
    task.spawn(function()
        local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        TweenService:Create(shadow, tweenInfo, { ImageTransparency = 0.8 }):Play()
    end)

    -- Keep shadow synced to main position
    local shadowConn = RunService.RenderStepped:Connect(function()
        shadow.Position = main.Position + UDim2.fromOffset(-22, -22)
    end)

    --// ========== LEFT PANEL (180px) — User Info ==========
    local leftPanel = create("Frame", {
        Name = "LeftPanel",
        Size = UDim2.new(0, 180, 1, -8),
        Position = UDim2.fromOffset(4, 4),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, main)
    corner(leftPanel, 12)
    glass(leftPanel)

    create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
    }, leftPanel)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, leftPanel)

    -- Header
    label(leftPanel, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 14),
        Text = "\xF0\x9F\x91\xA4 User Info",
        TextColor3 = C.accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    -- Avatar
    local avatarFrame = create("Frame", {
        Name = "AvatarFrame",
        Size = UDim2.fromOffset(60, 60),
        BackgroundTransparency = 1,
        LayoutOrder = 2,
    }, leftPanel)

    local avatarImg = create("ImageLabel", {
        Name = "Avatar",
        Size = UDim2.fromOffset(60, 60),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        Image = "",
    }, avatarFrame)
    corner(avatarImg, 30)
    stroke(avatarImg, C.accent, 2)

    task.spawn(function()
        local thumbOk, thumbContent = pcall(function()
            return Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
        end)
        if thumbOk and thumbContent then
            avatarImg.Image = thumbContent
        else
            avatarImg.Image = "https://www.roblox.com/headshot-thumbnail/image?userId=" .. Player.UserId .. "&width=100&height=100&format=png"
        end
    end)

    -- Username
    label(leftPanel, {
        Name = "Username",
        Size = UDim2.new(1, 0, 0, 16),
        Text = Player.Name,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 3,
    })

    -- Info Rows
    local function infoRow(parent, icon, lbl, val, order)
        local row = create("Frame", {
            Name = "Row_" .. lbl,
            Size = UDim2.new(1, -8, 0, 34),
            BackgroundColor3 = Color3.fromRGB(18, 18, 28),
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            LayoutOrder = order,
        }, parent)
        corner(row, 6)
        stroke(row, C.accent, 1)
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 4),
        }, row)
        label(row, {
            Size = UDim2.new(1, 0, 0, 11),
            Position = UDim2.fromOffset(0, 0),
            Text = icon .. " " .. lbl,
            TextSize = 9,
            TextColor3 = C.dim,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        local valLabel = label(row, {
            Name = "Value",
            Size = UDim2.new(1, 0, 0, 12),
            Position = UDim2.fromOffset(0, 10),
            Text = val,
            TextSize = 10,
            TextColor3 = C.text,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })
        return valLabel
    end

    -- Executor
    local execName = "Unknown"
    pcall(function() execName = identifyexecutor() or "Unknown" end)
    infoRow(leftPanel, "\xF0\x9F\x96\xA5\xEF\xB8\x8F", "Executor", tostring(execName), 4)

    -- Device
    local deviceStr = "PC"
    pcall(function()
        if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
            deviceStr = "Mobile"
        end
    end)
    infoRow(leftPanel, "\xF0\x9F\x92\xBB", "Device", deviceStr, 5)

    -- HWID
    local hwidStr = "N/A"
    pcall(function()
        local hw = HWID
        if hw and hw ~= "nohwid" and #hw > 8 then
            hwidStr = hw:sub(1, 8) .. "..."
        elseif hw and hw ~= "nohwid" then
            hwidStr = hw
        end
    end)
    infoRow(leftPanel, "\xF0\x9F\x94\x91", "HWID", hwidStr, 6)

    -- Game Name
    local gameDisplay = placeName
    pcall(function()
        if #gameDisplay > 25 then
            gameDisplay = gameDisplay:sub(1, 25) .. "..."
        end
    end)
    infoRow(leftPanel, "\xF0\x9F\x8E\xAE", "Game", gameDisplay, 7)

    -- Session Timer
    local sessionLabel = label(leftPanel, {
        Name = "Session",
        Size = UDim2.new(1, 0, 0, 18),
        Text = "00:00",
        TextSize = 14,
        TextColor3 = C.accent,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 8,
    })

    -- Ping
    local pingLabel = label(leftPanel, {
        Name = "Ping",
        Size = UDim2.new(1, 0, 0, 14),
        Text = "0 ms",
        TextSize = 11,
        TextColor3 = C.green,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 9,
    })

    -- Clock
    local clockLabel = label(leftPanel, {
        Name = "Clock",
        Size = UDim2.new(1, 0, 0, 12),
        Text = "12:00:00 AM",
        TextSize = 10,
        TextColor3 = C.dim,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 10,
    })

    -- Connection Status Bar (anchored to bottom, outside layout)
    local connBar = create("Frame", {
        Name = "ConnBar",
        Size = UDim2.new(1, -16, 0, 22),
        Position = UDim2.new(0, 8, 1, -30),
        BackgroundColor3 = C.green,
        BorderSizePixel = 0,
    }, leftPanel)
    corner(connBar, 6)

    label(connBar, {
        Size = UDim2.new(1, -12, 1, 0),
        Position = UDim2.fromOffset(6, 0),
        Text = "Connected to Aurora",
        TextSize = 9,
        TextColor3 = C.text,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Live updates (session, ping, clock)
    local sessionStart = os.clock()

    task.spawn(function()
        while gui.Parent do
            local elapsed = math.floor(os.clock() - sessionStart)
            local mins = math.floor(elapsed / 60)
            local secs = elapsed % 60
            pcall(function() sessionLabel.Text = string.format("%02d:%02d", mins, secs) end)

            local ping = 0
            pcall(function() ping = math.floor(Player:GetNetworkPing() * 1000) end)
            pcall(function()
                pingLabel.Text = tostring(ping) .. " ms"
                if ping < 100 then
                    pingLabel.TextColor3 = C.green
                elseif ping < 200 then
                    pingLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                else
                    pingLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end)

            pcall(function() clockLabel.Text = os.date("%I:%M:%S %p") end)

            task.wait(1)
        end
    end)

    --// ========== CENTER PANEL (398px) — Key Entry ==========
    local centerPanel = create("Frame", {
        Name = "CenterPanel",
        Size = UDim2.new(0, 398, 1, -8),
        Position = UDim2.fromOffset(190, 4),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    }, main)
    corner(centerPanel, 12)
    glass(centerPanel)

    create("UIPadding", {
        PaddingTop = UDim.new(0, 14),
        PaddingLeft = UDim.new(0, 16),
        PaddingRight = UDim.new(0, 16),
        PaddingBottom = UDim.new(0, 10),
    }, centerPanel)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, centerPanel)

    -- Logo Area
    local logoFrame = create("Frame", {
        Name = "LogoArea",
        Size = UDim2.new(1, 0, 0, 70),
        BackgroundTransparency = 1,
        LayoutOrder = 1,
    }, centerPanel)

    label(logoFrame, {
        Size = UDim2.new(1, 0, 0, 38),
        Position = UDim2.fromOffset(0, 0),
        Text = "\xF0\x9F\x8C\xB8",
        TextSize = 36,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    local titleRow = create("Frame", {
        Size = UDim2.new(1, 0, 0, 24),
        Position = UDim2.fromOffset(0, 36),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, logoFrame)

    label(titleRow, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "Aurora",
        TextSize = 22,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    label(logoFrame, {
        Size = UDim2.new(1, 0, 0, 12),
        Position = UDim2.fromOffset(0, 58),
        Text = "\xF0\x9F\x94\x92 Secured by notCitruss",
        TextSize = 9,
        TextColor3 = C.dim,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    -- Discord CTA Pill
    local discordPill = create("Frame", {
        Name = "DiscordCTA",
        Size = UDim2.new(1, 0, 0, 30),
        BackgroundColor3 = C.card,
        BorderSizePixel = 0,
        LayoutOrder = 2,
    }, centerPanel)
    corner(discordPill, 15)
    stroke(discordPill, C.accent)
    makeButton(discordPill)

    label(discordPill, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "\xF0\x9F\x8E\xAE Join our Discord for free keys!",
        TextSize = 10,
        TextColor3 = C.dim,
        Font = Enum.Font.GothamSemibold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(discordPill, function()
        pcall(function()
            if setclipboard then setclipboard("https://discord.gg/Ny22WZjg7c") end
        end)
    end)

    -- Key Input Area (uses UIListLayout for clean stacking)
    local keySection = create("Frame", {
        Name = "KeySection",
        Size = UDim2.new(1, 0, 0, 164),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 3,
    }, centerPanel)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 6),
    }, keySection)

    -- Row 1: Key Input
    local keyInput = create("TextBox", {
        Name = "KeyInput",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.inputBg,
        BorderSizePixel = 0,
        Text = "",
        PlaceholderText = "Enter your key...",
        PlaceholderColor3 = C.muted,
        TextColor3 = C.text,
        TextSize = 13,
        Font = Enum.Font.GothamSemibold,
        ClearTextOnFocus = false,
        LayoutOrder = 1,
    }, keySection)
    corner(keyInput, 8)
    stroke(keyInput, Color3.fromRGB(40, 40, 60))
    create("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, keyInput)

    -- Row 2: Redeem button (full width)
    local redeemBtn = create("Frame", {
        Name = "Redeem",
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
        LayoutOrder = 2,
    }, keySection)
    corner(redeemBtn, 8)
    makeButton(redeemBtn)

    local redeemLabel = label(redeemBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "\xE2\x9C\x93 Redeem Key",
        TextSize = 13,
        TextColor3 = C.text,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(redeemBtn, function()
        local key = keyInput.Text:gsub("%s+", "")
        if #key < 10 then
            redeemLabel.Text = "No key entered!"
            redeemLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            task.delay(1.5, function()
                pcall(function()
                    redeemLabel.Text = "\xE2\x9C\x93 Redeem Key"
                    redeemLabel.TextColor3 = C.text
                end)
            end)
            return
        end
        redeemLabel.Text = "Checking..."
        redeemLabel.TextColor3 = C.dim
        task.spawn(function()
            local ok, resp = pcall(function()
                local uid = tostring(Player.UserId)
                local raw = game:HttpGet(KEY_API .. "/validate?key=" .. key .. "&uid=" .. uid .. "&lock=" .. HWID, true)
                return HttpService:JSONDecode(raw)
            end)
            if ok and resp and resp.valid then
                local tier = resp.tier or "premium"
                getgenv().AuroraTier = tier
                getgenv().AuroraKeyTier = tier
                redeemLabel.Text = tier == "private" and "Private Key Valid!" or "Key Valid!"
                redeemLabel.TextColor3 = C.green
                saveKey(key)
                task.wait(1)
                savedKey = key
                pcall(function() shadowConn:Disconnect() end)
                gui:Destroy()
            else
                local errMsg = (ok and resp and resp.error) or "Invalid or expired key"
                redeemLabel.Text = errMsg
                redeemLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                task.delay(2, function()
                    pcall(function()
                        redeemLabel.Text = "\xE2\x9C\x93 Redeem Key"
                        redeemLabel.TextColor3 = C.text
                    end)
                end)
            end
        end)
    end)

    -- Divider label
    label(keySection, {
        Size = UDim2.new(1, 0, 0, 14),
        Text = "Get a free key:",
        TextSize = 10,
        TextColor3 = C.dim,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Center,
        LayoutOrder = 3,
    })

    -- Row 3: Ad link buttons (Work.ink + Linkvertise + LootLabs)
    local adRow = create("Frame", {
        Name = "AdRow",
        Size = UDim2.new(1, 0, 0, 34),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 4,
    }, keySection)

    -- Work.ink (left third, accent bg)
    local getKeyBtn = create("Frame", {
        Name = "GetKey",
        Size = UDim2.new(0.333, -4, 1, 0),
        Position = UDim2.fromOffset(0, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 65),
        BorderSizePixel = 0,
    }, adRow)
    corner(getKeyBtn, 8)
    stroke(getKeyBtn, C.accent)
    makeButton(getKeyBtn)

    local getKeyLabel = label(getKeyBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "Work.ink",
        TextSize = 11,
        TextColor3 = C.accent,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(getKeyBtn, function()
        pcall(function() if setclipboard then setclipboard(KEY_LINK) end end)
        getKeyLabel.Text = "Copied!"
        getKeyLabel.TextColor3 = C.green
        task.delay(1.5, function() pcall(function() getKeyLabel.Text = "Work.ink"; getKeyLabel.TextColor3 = C.accent end) end)
    end)

    -- Linkvertise (center third, blue)
    local lvBtn = create("Frame", {
        Name = "LinkvertiseKey",
        Size = UDim2.new(0.333, -4, 1, 0),
        Position = UDim2.new(0.333, 2, 0, 0),
        BackgroundColor3 = Color3.fromRGB(40, 40, 65),
        BorderSizePixel = 0,
    }, adRow)
    corner(lvBtn, 8)
    stroke(lvBtn, Color3.fromRGB(100, 180, 255))
    makeButton(lvBtn)

    local lvLabel = label(lvBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "Linkvertise",
        TextSize = 11,
        TextColor3 = Color3.fromRGB(100, 180, 255),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(lvBtn, function()
        pcall(function() if setclipboard then setclipboard(KEY_LINK_2) end end)
        lvLabel.Text = "Copied!"
        lvLabel.TextColor3 = C.green
        task.delay(1.5, function() pcall(function() lvLabel.Text = "Linkvertise"; lvLabel.TextColor3 = Color3.fromRGB(100, 180, 255) end) end)
    end)

    -- LootLabs (right third, green)
    local llBtn = create("Frame", {
        Name = "LootLabsKey",
        Size = UDim2.new(0.333, -2, 1, 0),
        Position = UDim2.new(0.666, 4, 0, 0),
        BackgroundColor3 = Color3.fromRGB(40, 55, 40),
        BorderSizePixel = 0,
    }, adRow)
    corner(llBtn, 8)
    stroke(llBtn, Color3.fromRGB(80, 200, 120))
    makeButton(llBtn)

    local llLabel = label(llBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "LootLabs",
        TextSize = 11,
        TextColor3 = Color3.fromRGB(80, 200, 120),
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(llBtn, function()
        pcall(function() if setclipboard then setclipboard(KEY_LINK_3) end end)
        llLabel.Text = "Copied!"
        llLabel.TextColor3 = C.green
        task.delay(1.5, function() pcall(function() llLabel.Text = "LootLabs"; llLabel.TextColor3 = Color3.fromRGB(80, 200, 120) end) end)
    end)

    -- Bottom Action Bar (Discord + Copy HWID)
    local actionBar = create("Frame", {
        Name = "ActionBar",
        Size = UDim2.new(1, -24, 0, 36),
        Position = UDim2.fromOffset(12, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        LayoutOrder = 4,
    }, centerPanel)

    create("UIListLayout", {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
    }, actionBar)

    local actionBtns = {
        { "\xF0\x9F\x8E\xAE Discord", 1, function()
            pcall(function()
                if setclipboard then setclipboard("https://discord.gg/Ny22WZjg7c") end
            end)
        end },
        { "\xF0\x9F\x93\x8B Copy HWID", 2, function()
            pcall(function()
                if setclipboard then
                    local hw = HWID ~= "nohwid" and HWID or "N/A"
                    setclipboard(hw)
                end
            end)
        end },
    }

    for _, data in pairs(actionBtns) do
        local btn = create("Frame", {
            Size = UDim2.fromOffset(125, 36),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
            LayoutOrder = data[2],
        }, actionBar)
        corner(btn, 8)
        stroke(btn, Color3.fromRGB(40, 40, 60))
        makeButton(btn)
        local btnLbl = label(btn, {
            Size = UDim2.new(1, 0, 1, 0),
            Text = data[1],
            TextSize = 11,
            TextColor3 = C.dim,
            Font = Enum.Font.GothamSemibold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })
        connectClick(btn, function()
            local orig = data[1]
            btnLbl.TextColor3 = C.accent
            btnLbl.Text = "Copied!"
            data[3]()
            task.delay(1.5, function()
                pcall(function()
                    btnLbl.TextColor3 = C.dim
                    btnLbl.Text = orig
                end)
            end)
        end)
    end

    -- Premium Bar
    local premBar = create("Frame", {
        Name = "PremiumBar",
        Size = UDim2.new(1, 0, 0, 50),
        BackgroundColor3 = C.purple,
        BorderSizePixel = 0,
        LayoutOrder = 5,
    }, centerPanel)
    corner(premBar, 10)
    makeButton(premBar)

    create("UIGradient", {
        Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, C.purple),
            ColorSequenceKeypoint.new(1, C.accent),
        }),
        Rotation = 0,
    }, premBar)

    label(premBar, {
        Size = UDim2.new(0.6, 0, 0, 18),
        Position = UDim2.fromOffset(12, 8),
        Text = "\xF0\x9F\x91\x91 Get Premium Access",
        TextSize = 14,
        TextColor3 = C.text,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    label(premBar, {
        Size = UDim2.new(0.6, 0, 0, 12),
        Position = UDim2.fromOffset(12, 28),
        Text = "Instant delivery \xC2\xB7 24/7 support",
        TextSize = 10,
        TextColor3 = Color3.fromRGB(220, 200, 230),
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    local buyBtn = create("Frame", {
        Name = "BuyBtn",
        Size = UDim2.fromOffset(64, 32),
        Position = UDim2.new(1, -78, 0.5, -16),
        BackgroundColor3 = C.accent,
        BorderSizePixel = 0,
    }, premBar)
    corner(buyBtn, 6)
    makeButton(buyBtn)

    local buyLbl = label(buyBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "Buy",
        TextSize = 12,
        TextColor3 = C.text,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(buyBtn, function()
        pcall(function()
            if setclipboard then setclipboard("https://discord.gg/Ny22WZjg7c") end
        end)
        buyLbl.Text = "Copied!"
        buyLbl.TextColor3 = C.green
        task.delay(1.5, function()
            pcall(function()
                buyLbl.Text = "Buy"
                buyLbl.TextColor3 = C.text
            end)
        end)
    end)

    --// ========== RIGHT PANEL (180px) — Changelog ==========
    local rightPanel = create("Frame", {
        Name = "RightPanel",
        Size = UDim2.new(0, 180, 1, -8),
        Position = UDim2.fromOffset(594, 4),
        BackgroundColor3 = C.panel,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
    }, main)
    corner(rightPanel, 12)
    glass(rightPanel)

    local rightScroll = create("ScrollingFrame", {
        Name = "Scroll",
        Size = UDim2.new(1, -14, 1, 0),
        Position = UDim2.fromOffset(14, 0),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = C.accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.fromOffset(0, 0),
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, rightPanel)

    create("UIPadding", {
        PaddingTop = UDim.new(0, 10),
        PaddingLeft = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 10),
        PaddingBottom = UDim.new(0, 10),
    }, rightScroll)

    create("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 8),
    }, rightScroll)

    -- Changelog Header
    label(rightScroll, {
        Name = "Header",
        Size = UDim2.new(1, 0, 0, 14),
        Text = "\xF0\x9F\x93\x8B Changelog",
        TextColor3 = C.accent,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = 1,
    })

    -- Changelog entries
    local changelogData = {
        {
            badge = "NEW",
            badgeColor = C.accent,
            version = "3.0 \xC2\xB7 Apr 1, 2026",
            items = {
                "\xC2\xB7 HWID key locking",
                "\xC2\xB7 11 games supported",
                "\xC2\xB7 Premium UI redesign",
            },
            order = 2,
        },
        {
            badge = "2.5",
            badgeColor = C.card,
            version = "2.5 \xC2\xB7 Mar 31, 2026",
            items = {
                "\xC2\xB7 Security hardening",
                "\xC2\xB7 Scripts in Worker KV",
                "\xC2\xB7 Mobile scroll support",
            },
            order = 3,
        },
        {
            badge = "2.0",
            badgeColor = C.card,
            version = "2.0 \xC2\xB7 Mar 31, 2026",
            items = {
                "\xC2\xB7 Work.ink monetization",
                "\xC2\xB7 Key system launched",
                "\xC2\xB7 Discord notifications",
            },
            order = 4,
        },
        {
            badge = "1.0",
            badgeColor = C.card,
            version = "1.0 \xC2\xB7 Mar 30, 2026",
            items = {
                "\xC2\xB7 Initial release",
                "\xC2\xB7 9 game scripts",
                "\xC2\xB7 Universal loader",
            },
            order = 5,
        },
    }

    for _, entry in pairs(changelogData) do
        local itemHeight = 14 + 13 + (#entry.items * 12) + 4
        local entryFrame = create("Frame", {
            Name = "Entry_" .. entry.badge,
            Size = UDim2.new(1, 0, 0, itemHeight),
            BackgroundColor3 = C.card,
            BorderSizePixel = 0,
            LayoutOrder = entry.order,
        }, rightScroll)
        corner(entryFrame, 6)
        create("UIPadding", {
            PaddingLeft = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 4),
            PaddingRight = UDim.new(0, 4),
        }, entryFrame)

        -- Badge pill
        local badgeWidth = math.max(#entry.badge * 6 + 8, 28)
        local badgePill = create("Frame", {
            Size = UDim2.fromOffset(badgeWidth, 14),
            Position = UDim2.fromOffset(0, 0),
            BackgroundColor3 = entry.badgeColor,
            BorderSizePixel = 0,
        }, entryFrame)
        corner(badgePill, 4)
        label(badgePill, {
            Size = UDim2.new(1, 0, 1, 0),
            Text = entry.badge,
            TextSize = 8,
            TextColor3 = C.text,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Center,
        })

        -- Version text
        label(entryFrame, {
            Size = UDim2.new(1, 0, 0, 12),
            Position = UDim2.fromOffset(0, 16),
            Text = entry.version,
            TextSize = 10,
            TextColor3 = C.text,
            Font = Enum.Font.GothamBold,
            TextXAlignment = Enum.TextXAlignment.Left,
        })

        -- Bullet items
        for i, item in pairs(entry.items) do
            label(entryFrame, {
                Size = UDim2.new(1, 0, 0, 10),
                Position = UDim2.fromOffset(0, 28 + (i - 1) * 12),
                Text = item,
                TextSize = 9,
                TextColor3 = C.dim,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
            })
        end
    end

    --// ========== MINIMIZE / RESTORE FLOWER ==========
    local miniBtn = create("Frame", {
        Name = "MiniBtn",
        Size = UDim2.fromOffset(44, 44),
        Position = main.Position,
        BackgroundColor3 = C.accent,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        Visible = false,
        Active = true,
    }, gui)
    corner(miniBtn, 22)
    stroke(miniBtn, C.accent, 2)

    label(miniBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "\xF0\x9F\x8C\xB8",
        TextSize = 22,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextYAlignment = Enum.TextYAlignment.Center,
    })

    -- Custom drag for flower + tap to restore
    do
        local dragging = false
        local dragStart, startPos
        local totalDrag = 0

        miniBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                totalDrag = 0
                dragStart = input.Position
                startPos = miniBtn.Position
            end
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local d = input.Position - dragStart
                totalDrag = math.abs(d.X) + math.abs(d.Y)
                miniBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                dragging = false
                if totalDrag < 8 then
                    miniBtn.Visible = false
                    main.Visible = true
                    shadow.Visible = true
                end
            end
        end)
    end

    -- Minimize button (top-right of main)
    local minBtn = create("Frame", {
        Name = "MinimizeBtn",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -64, 0, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, main)
    makeButton(minBtn)
    label(minBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "\xE2\x88\x92",
        TextSize = 22,
        TextColor3 = C.dim,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(minBtn, function()
        main.Visible = false
        shadow.Visible = false
        miniBtn.Position = main.Position + UDim2.fromOffset(320, 180)
        miniBtn.Visible = true
    end)

    -- Close button (top-right of main)
    local closeBtn = create("Frame", {
        Name = "CloseBtn",
        Size = UDim2.fromOffset(28, 28),
        Position = UDim2.new(1, -32, 0, 6),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
    }, main)
    makeButton(closeBtn)
    label(closeBtn, {
        Size = UDim2.new(1, 0, 1, 0),
        Text = "x",
        TextSize = 18,
        TextColor3 = C.dim,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Center,
    })

    connectClick(closeBtn, function()
        pcall(function() shadowConn:Disconnect() end)
        miniBtn:Destroy()
        gui:Destroy()
    end)

    -- Wait for valid key (poll every 5s to prevent rate limit burn)
    while not savedKey or not validateKey(savedKey) do
        task.wait(5)
        savedKey = readKey()
    end

    pcall(function() shadowConn:Disconnect() end)
    pcall(function() miniBtn:Destroy() end)
    pcall(function() gui:Destroy() end)
end

--// ============================================================
--// PHASE 4: LOADING SPLASH + SCRIPT EXECUTION
--// ============================================================

if scriptName and savedKey then
    -- Mini splash while loading script
    local loadGui = Instance.new("ScreenGui")
    loadGui.Name = "AuroraLoading"
    loadGui.DisplayOrder = 100
    loadGui.IgnoreGuiInset = true
    loadGui.ResetOnSpawn = false
    pcall(function() loadGui.Parent = Player.PlayerGui end)
    if not loadGui.Parent then pcall(function() loadGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end) end

    local loadOverlay = Instance.new("Frame", loadGui)
    loadOverlay.Size = UDim2.new(1, 0, 1, 0)
    loadOverlay.BackgroundColor3 = Color3.fromRGB(8, 8, 14)
    loadOverlay.BackgroundTransparency = 0.3
    loadOverlay.BorderSizePixel = 0

    local loadTitle = Instance.new("TextLabel", loadGui)
    loadTitle.Size = UDim2.new(0.85, 0, 0, 110)
    loadTitle.Position = UDim2.new(0.075, 0, 0.5, -55)
    loadTitle.BackgroundTransparency = 1
    loadTitle.Text = "AURORA"
    loadTitle.TextColor3 = Color3.fromRGB(252, 110, 142)
    loadTitle.TextTransparency = 0
    loadTitle.TextSize = 180
    loadTitle.Font = Enum.Font.GothamBlack
    loadTitle.BorderSizePixel = 0

    local loadStatus = Instance.new("TextLabel", loadGui)
    loadStatus.Size = UDim2.new(0.4, 0, 0, 18)
    loadStatus.Position = UDim2.new(0.3, 0, 0.5, 60)
    loadStatus.BackgroundTransparency = 1
    loadStatus.Text = "Loading " .. (scriptName:gsub("_", " ")) .. "..."
    loadStatus.TextColor3 = Color3.fromRGB(200, 200, 215)
    loadStatus.TextSize = 13
    loadStatus.Font = Enum.Font.Gotham
    loadStatus.BorderSizePixel = 0

    task.wait(0.5)

    -- Fetch script
    local uid = tostring(Player.UserId)
    -- Private tier tries private script first, falls back to public
    local tier = getgenv().AuroraTier or "free"
    local url
    if tier == "private" then
        url = BASE_URL .. "private/" .. scriptName .. "?key=" .. savedKey .. "&uid=" .. uid .. "&lock=" .. HWID
    else
        url = BASE_URL .. scriptName .. "?key=" .. savedKey .. "&uid=" .. uid .. "&lock=" .. HWID
    end

    loadStatus.Text = "Downloading..."
    local success, result = pcall(function() return game:HttpGet(url) end)

    -- If private script not found, fall back to public version
    if tier == "private" and (not success or not result or result:find("script not found")) then
        url = BASE_URL .. scriptName .. "?key=" .. savedKey .. "&uid=" .. uid .. "&lock=" .. HWID
        success, result = pcall(function() return game:HttpGet(url) end)
    end

    if success and result and #result > 0 then
        loadStatus.Text = "Executing..."
        task.wait(0.3)

        loadStatus.Text = "Ready"
        loadStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
        task.wait(0.3)

        -- Fade out
        local fadeOut = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        TweenService:Create(loadOverlay, fadeOut, {BackgroundTransparency = 1}):Play()
        TweenService:Create(loadTitle, fadeOut, {TextTransparency = 1}):Play()
        TweenService:Create(loadStatus, fadeOut, {TextTransparency = 1}):Play()
        task.wait(1.1)
        pcall(function() loadGui:Destroy() end)

        -- Execute the script
        local loadSuccess, loadErr = pcall(function() loadstring(result)() end)
        if not loadSuccess then
            warn("[Aurora] Script execution error: " .. tostring(loadErr))
        end

        -- Analytics heartbeat + error reporting
        task.spawn(function()
            pcall(function()
                local heartbeatUrl = KEY_API .. "/api/heartbeat?game=" .. HttpService:UrlEncode(scriptName or "unknown") .. "&hwid=" .. HttpService:UrlEncode(HWID) .. "&version=1&executor=" .. HttpService:UrlEncode(tostring(identifyexecutor and identifyexecutor() or "unknown"))
                if savedKey then heartbeatUrl = heartbeatUrl .. "&key=" .. HttpService:UrlEncode(savedKey) end
                game:HttpGet(heartbeatUrl)
            end)
            if not loadSuccess and loadErr then
                pcall(function()
                    local errUrl = KEY_API .. "/api/heartbeat?game=" .. HttpService:UrlEncode(scriptName or "unknown") .. "&hwid=" .. HttpService:UrlEncode(HWID) .. "&version=ERROR&executor=" .. HttpService:UrlEncode(tostring(loadErr):sub(1, 100))
                    game:HttpGet(errUrl)
                end)
            end
        end)
    else
        loadStatus.Text = "Failed to download script"
        loadStatus.TextColor3 = Color3.fromRGB(255, 80, 80)
        task.wait(3)
        pcall(function() loadGui:Destroy() end)
        warn("[Aurora] Failed to download script for: " .. tostring(scriptName))
    end
elseif not scriptName then
    -- Load universal script as fallback
    pcall(function()
        loadStatus.Text = "Loading Universal..."
        loadStatus.TextColor3 = Color3.fromRGB(252, 110, 142)
    end)
    local uniOk, uniSource = pcall(function()
        local url = BASE_URL .. "universal"
        if getgenv().AuroraTier == "private" then
            local pUrl = BASE_URL .. "private/universal"
            local pOk, pSrc = pcall(function() return game:HttpGet(pUrl) end)
            if pOk and pSrc and #pSrc > 100 then return pSrc end
        end
        return game:HttpGet(url)
    end)
    if uniOk and uniSource and #uniSource > 100 then
        pcall(function()
            loadStatus.Text = "Ready!"
            loadStatus.TextColor3 = Color3.fromRGB(80, 200, 120)
        end)
        task.wait(0.5)
        pcall(function() loadGui:Destroy() end)
        local fn = loadstring(uniSource)
        if fn then fn() end
    else
        pcall(function()
            loadStatus.Text = "No script for this game"
            loadStatus.TextColor3 = Color3.fromRGB(255, 180, 50)
        end)
        task.wait(3)
        pcall(function() loadGui:Destroy() end)
    end
end

--[[
    Aurora MCP Connector v2.5
    Advanced bridge between Roblox and Aurora MCP Server
    Now with built-in Aurora Spy (replaces Cobalt)
]]--

--// Wait for game to load \\--
if not game:IsLoaded() then
    game.Loaded:Wait()
end

--// Variables \\--
local BridgeURL = getgenv().AuroraBridgeURL or getgenv().BridgeURL or ... or "localhost:16384"

--// Aurora Banner \\--
local function PrintBanner()
    print("")
    print("  ╔══════════════════════════════════════╗")
    print("  ║         Aurora MCP v2.5              ║")
    print("  ║   Advanced Roblox MCP Bridge         ║")
    print("  ║   Built-in Aurora Spy                ║")
    print("  ╚══════════════════════════════════════╝")
    print("  Connecting to: " .. BridgeURL)
    print("")
end
PrintBanner()

--// Libraries \\--
-- Lua 5.1+ base64 v3.0 (c) 2009 by Alex Kloss <alexthkloss@web.de>
-- licensed under the terms of the LGPL2

-- character table string
local b='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

-- encoding
function base64_encode(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

--// Functions \\--

local LuaEncode
do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet("https://raw.githubusercontent.com/chadhyatt/LuaEncode/refs/heads/master/src/LuaEncode.lua"))()
    end)
    if ok and type(res) == "function" then
        LuaEncode = res
    else
        warn("[Aurora] LuaEncode fetch failed, using stub: " .. tostring(res))
        LuaEncode = function(v) return tostring(v) end
    end
end
local cloneref = cloneref or function(x) return x end
local decompile = decompile or function(scriptPath: Script | ModuleScript | LocalScript): string
    local okBytecode: boolean, bytecode: string = pcall(getscriptbytecode, scriptPath)

    if not okBytecode then
        return `-- Failed to get script bytecode, error:\n\n--[[\n{bytecode}\n--]]`
    end

    local okRequest: boolean, httpResult = pcall(request, {
        Url = "https://medal.upio.dev/decompile",
        Method = "POST",
        Body = base64_encode(bytecode),
        Headers = {
            ["Content-Type"] = "text/plain"
        },
    })

    if not okRequest then
        return `-- Failed to decompile, error:\n\n--[[\n{httpResult}\n--]]`
    end

    if httpResult.StatusCode ~= 200 then
        return `-- Error occurred while requesting the API, error:\n\n--[[\n{httpResult.Body}\n--]]`
    end

    return string.gsub(httpResult.Body, string.char(0x00CD), " ")
end
local getnilinstances = getnilinstances or function() return {} end
local getscriptbytecode = getscriptbytecode or function(x) error("Unable to get script bytecode.") end

--// Services \\--
local RobloxReplicatedStorage = cloneref(game:GetService("RobloxReplicatedStorage"))
local VirtualInputManager = cloneref(Instance.new("VirtualInputManager"))
local MarketplaceService = cloneref(game:GetService("MarketplaceService"))
local CoreGui = cloneref(game:GetService("CoreGui"))
local CorePackages = cloneref(game:GetService("CorePackages"))
local HttpService = cloneref(game:GetService("HttpService"))
local LogService = cloneref(game:GetService("LogService"))
local Players = cloneref(game:GetService("Players"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

--// Compatibility Check \\--
-- Diagnostic: print what WS-related globals the executor exposes
print("[Aurora] WS diag — WebSocket:", typeof(WebSocket),
      "WebSocket.connect:", typeof(WebSocket) == "table" and typeof(WebSocket.connect) or "n/a",
      "syn.websocket:", typeof(syn) == "table" and typeof(syn.websocket) or "n/a",
      "http.websocket:", typeof(http) == "table" and typeof(http.websocket) or "n/a")

local WebSocketAvailable = (
    typeof(WebSocket) ~= "nil" and
    typeof(WebSocket.connect) == "function"
) and (getgenv().DisableWebSocket ~= true)
print("[Aurora] WebSocketAvailable:", WebSocketAvailable)

--// Registration Info \\--
local function GetRegistrationInfo()
    local player = Players.LocalPlayer
    local placeName = "Unknown"
    pcall(function()
        local productInfo = MarketplaceService:GetProductInfo(game.PlaceId)
        placeName = productInfo.Name
    end)
    return {
        type = "register",
        username = player and player.Name or "Unknown",
        userId = player and player.UserId or 0,
        placeId = game.PlaceId,
        jobId = game.JobId,
        placeName = placeName,
    }
end

--// Base Bridge Class \\--
local BaseBridge = {}; do
    BaseBridge.__index = BaseBridge
    
    function BaseBridge:BindToType(type, callback)
        self.Callbacks[type] = callback
    end
    
    function BaseBridge:HandleMessage(data)
        if self.Callbacks[data.type] then
            local success, result = pcall(function()
                return self.Callbacks[data.type](data)
            end)
    
            if success and result == nil then
                return nil
            end
    
            return self:FormatResponse(result, data.id, not success)
        end
        return nil
    end
    
    function BaseBridge:FormatResponse(message, id, isError)
        if isError then
            return {
                error = tostring(message),
                success = false,
                id = id
            }
        end
        
        local output = message
        if typeof(output) ~= "table" then
            output = { output }
        end
    
        return {
            output = LuaEncode(output, {
                Prettify = true
            }),
            success = true,
            id = id
        }
    end
    
    function BaseBridge:IsAlive()
        local success, result = pcall(function()
            local response
            local thread = task.spawn(function()
                local success, data = pcall(request, {
                    Url = "http://" .. BridgeURL,
                    Method = "GET"
                })

                if success then
                    response = data
                end
            end)

            local start = os.clock()
            repeat task.wait(0.05) until response ~= nil or os.clock() - start > 0.5

            if response == nil then
                task.cancel(thread)
                return false
            end
    
            -- 426 = Upgrade Required (WebSocket), 200 = HTTP mode
            if response.StatusCode == 426 or response.StatusCode == 200 then
                return true
            end
    
            return false
        end)
    
        if not success then
            return false
        end
    
        return result
    end
end

--// WebSocket Bridge \\--
local WebSocketBridge = setmetatable({}, {__index = BaseBridge}); do
    WebSocketBridge.__index = WebSocketBridge
    
    function WebSocketBridge.new()
        local self = setmetatable({}, WebSocketBridge)
    
        --// Yield until the server is alive with exponential backoff \\--
        local retryDelay = 0.5
        local maxRetryDelay = 3
        local maxAttempts = 5
        local attempts = 0
        
        while not self:IsAlive() do
            attempts += 1
            if attempts >= maxAttempts then
                error("Failed to connect to bridge server after " .. maxAttempts .. " attempts")
            end
            task.wait(retryDelay)
            retryDelay = math.min(retryDelay * 1.5, maxRetryDelay)
        end
    
        --// Connect to the server with timeout \\--
        local wsConnection = nil
        local connectionThread = task.spawn(function()
            local success, result = pcall(function()
                return WebSocket.connect("ws://" .. BridgeURL)
            end)
            if success then
                wsConnection = result
            end
        end)
        
        local connectionStart = os.clock()
        repeat task.wait(0.05) until wsConnection ~= nil or os.clock() - connectionStart > 3

        if wsConnection == nil then
            task.cancel(connectionThread)
            error("WebSocket connection timed out after 3 seconds")
        end
        
        self.WebSocket = wsConnection
        self.Connected = true
        self.Callbacks = {}
        self.ClientId = nil

        --// Send registration \\--
        self.WebSocket:Send(HttpService:JSONEncode(GetRegistrationInfo()))

        self.AliveThread = task.spawn(function()
            while task.wait(1) do
                if self:IsAlive() or not self.Connected then
                    continue
                end
                
                self.Connected = false
                break
            end
    
            pcall(function()
                self.WebSocket:Close()
            end)
        end)
    
        --// On Message \\--
        self.WebSocket.OnMessage:Connect(function(message)
            local data = HttpService:JSONDecode(message)

            --// Handle registration response \\--
            if data.type == "registered" then
                self.ClientId = data.clientId
                return
            end

            local response = self:HandleMessage(data)
            if response then
                self.WebSocket:Send(HttpService:JSONEncode(response))
            end
        end)
    
        --// On Close \\--
        self.WebSocket.OnClose:Connect(function()
            self.Connected = false
        end)
    
        return self
    end
    
    function WebSocketBridge:WaitForDisconnect()
        while self.Connected do
            task.wait(0.1)
        end
    end
end

--// HTTP Polling Bridge \\--
local HTTPBridge = setmetatable({}, {__index = BaseBridge}); do
    HTTPBridge.__index = HTTPBridge
    
    function HTTPBridge.new()
        local self = setmetatable({}, HTTPBridge)
    
        --// Yield until the server is alive with exponential backoff \\--
        local retryDelay = 0.5
        local maxRetryDelay = 3
        local maxAttempts = 5
        local attempts = 0
        
        while not self:IsAlive() do
            attempts += 1
            if attempts >= maxAttempts then
                error("Failed to connect to bridge server after " .. maxAttempts .. " attempts")
            end
            task.wait(retryDelay)
            retryDelay = math.min(retryDelay * 1.5, maxRetryDelay)
        end
    
        self.Connected = true
        self.Callbacks = {}
        self.PollInterval = 0.1
        self.ClientId = nil

        --// Register with the server \\--
        pcall(function()
            local regResponse = request({
                Url = "http://" .. BridgeURL .. "/register",
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(GetRegistrationInfo()),
            })
            if regResponse.StatusCode == 200 and regResponse.Body then
                local regData = HttpService:JSONDecode(regResponse.Body)
                self.ClientId = regData.clientId
            end
        end)
    
        --// Start polling thread \\--
        self.PollThread = task.spawn(function()
            local consecutiveFailures = 0
            
            while self.Connected do
                local success, _ = pcall(function()
                    local pollUrl = "http://" .. BridgeURL .. "/poll"
                    if self.ClientId then
                        pollUrl = pollUrl .. "?clientId=" .. self.ClientId
                    end
                    local response = request({
                        Url = pollUrl,
                        Method = "GET"
                    })

                    --// Structural: bridge doesn't support HTTP polling at all \\--
                    if response.StatusCode == 404 then
                        warn("[Aurora] HTTP /poll returned 404 — bridge is WebSocket-only. Stopping reconnect storm. Use a WebSocket-capable executor, or set getgenv().DisableWebSocket=false before loading.")
                        getgenv().__AURORA_HTTP_UNSUPPORTED = true
                        self.Connected = false
                        return
                    end

                    --// Server might be down \\--
                    if response.StatusCode ~= 204 and response.StatusCode ~= 200 then
                        consecutiveFailures += 1
                        if consecutiveFailures >= 3 then
                            self.Connected = false
                        end

                        return
                    end
                    
                    consecutiveFailures = 0
    
                    --// Handle response \\--
                    if response.Body and response.Body ~= "" then
                        local data = HttpService:JSONDecode(response.Body)
                        if data == nil or data.type == nil then return end
                        
                        local result = self:HandleMessage(data)
                        if result == nil then return end
                        
                        --// Send response back \\--
                        request({
                            Url = "http://" .. BridgeURL .. "/respond",
                            Method = "POST",
                            Headers = {
                                ["Content-Type"] = "application/json"
                            },
                            Body = HttpService:JSONEncode(result)
                        })
                    end
                end)
    
                if not success then
                    consecutiveFailures += 1
                    if consecutiveFailures >= 3 then
                        self.Connected = false
                    end
                end
    
                task.wait(self.PollInterval)
            end
        end)
    
        return self
    end
    
    function HTTPBridge:WaitForDisconnect()
        while self.Connected do
            task.wait(0.1)
        end
    end
end

--// Create Bridge \\--
local function CreateBridge()
    if WebSocketAvailable then
        local success, bridge = pcall(function()
            return WebSocketBridge.new()
        end)
        
        if success then
            return bridge
        else
            warn("WebSocket bridge failed to initialize, falling back to HTTP polling: " .. tostring(bridge))
        end
    end

    return HTTPBridge.new()
end

--// Script Source Mapping \\--
local ScriptSourcesMap = {
    HasFinishedMapping = false
}

local ScriptInstanceMap = setmetatable({}, { __mode = "v" })
local SourcesToMap, MappedSources = 0, 0
local HasStartedMapping = false

local function MapScriptSource(script)
    local debugId = script:GetDebugId()
    if ScriptSourcesMap[debugId] then return end

    for attempt = 1, 10 do
        local success, decompOutput = pcall(decompile, script)
        if not success then
            task.wait(0.5)
            continue
        end
    
        ScriptSourcesMap[debugId] = decompOutput
        MappedSources += 1
        break
    end

    ScriptInstanceMap[debugId] = script
    script.Destroying:Once(function()
        ScriptInstanceMap[debugId] = nil
    end)
end

local function GetScriptByDebugId(debugId)
    local CachedInstance = ScriptInstanceMap[debugId]
    if CachedInstance then
        return CachedInstance
    end

    for _, script in game:QueryDescendants("LuaSourceContainer") do
        if script:IsA("Script") and script.RunContext == Enum.RunContext.Server then continue end
        if script:GetDebugId() ~= debugId then continue end
        
        ScriptInstanceMap[debugId] = script
        return script
    end

    for _, script in getnilinstances() do
        if not script:IsA("LuaSourceContainer") then continue end

        if script:IsA("Script") and script.RunContext ~= Enum.RunContext.Client then continue end
        if script:GetDebugId() ~= debugId then continue end
        
        ScriptInstanceMap[debugId] = script
        return script
    end

    return nil
end

local function ShouldMapScript(script)        
    local IsServerScript = script:IsA("Script") and script.RunContext == Enum.RunContext.Server
    if IsServerScript then return false end

    local IsRobloxScript = script.RobloxLocked or script:IsDescendantOf(CoreGui) or script:IsDescendantOf(CorePackages)
    if IsRobloxScript then return false end

    local IsAlreadyMapped = ScriptSourcesMap[script:GetDebugId()]
    if IsAlreadyMapped then return false end

    local HasBytecode = pcall(getscriptbytecode, script)
    if not HasBytecode then return false end

    return true
end

local function StartScriptMapping()
    if HasStartedMapping then return end
    HasStartedMapping = true

    game.DescendantAdded:Connect(function(script)
        if not script:IsA("LuaSourceContainer") then
            return
        end

        if not ShouldMapScript(script) then return end
        MapScriptSource(script)
    end)

    local CategoriesToMap = {
        game:QueryDescendants("LuaSourceContainer"),
        getnilinstances()
    }

    --// Map script sources \\--
    task.spawn(function()
        local ValidScripts = {}
        for _, category in CategoriesToMap do
            for _, script in category do
                if not script:IsA("LuaSourceContainer") then continue end
                if not ShouldMapScript(script) then continue end

                table.insert(ValidScripts, script)
            end
        end

        SourcesToMap = #ValidScripts

        for idx, scriptObject in ValidScripts do
            task.defer(MapScriptSource, scriptObject)
            if idx % 250 == 0 then task.wait(0.1) end
        end

        ScriptSourcesMap.HasFinishedMapping = true
    end)
end

--// Start mapping immediately unless disabled \\--
if not getgenv().DisableInitialScriptDecompMapping then
    StartScriptMapping()
end

--// Parse Query \\--
local function ConvertEscapes(str)
    local ConvertedStr = str:gsub("\\n", "\n"):gsub("\\r", "\r"):gsub("\\t", "\t")
    return ConvertedStr
end

local function GetLineInfo(source)
    local lineStarts = {1}
    local i = 1
    while true do
        local found = source:find("\n", i, true)
        if not found then break end
        table.insert(lineStarts, found + 1)
        i = found + 1
    end
    return lineStarts
end

local function GetLineNumber(lineStarts, pos)
    local low, high = 1, #lineStarts
    local res = 1
    while low <= high do
        local mid = math.floor((low + high) / 2)
        if lineStarts[mid] <= pos then
            res = mid
            low = mid + 1
        else
            high = mid - 1
        end
    end
    return res
end

local function ParseQuery(query)
    local stringMatchQueries = {}
    do  
        local queries = {}
        local isEscaping = false
        local currentQuery = ""
        
        for idx, query in query:split("|") do
            local lastChar = string.sub(query, #query)

            --// Handle escaping \\--
            if lastChar == "\\" then
                local escapedQuery = string.sub(query, 1, #query - 1)
                if isEscaping then
                    currentQuery ..= escapedQuery .. "|"
                else
                    isEscaping = true
                    currentQuery = escapedQuery .. "|"
                end
                continue
            elseif isEscaping then
                isEscaping = false
                currentQuery ..= query
            else
                currentQuery = query
            end

            --// Check for AND queries (split by &) \\--
            if currentQuery:find("&") then
                local andParts = currentQuery:split("&")
                local andQueries = {}
                
                for _, part in andParts do
                    if part ~= "" then
                        table.insert(andQueries, part)
                    end
                end
                
                if #andQueries > 1 then
                    table.insert(queries, { AndQueries = andQueries })
                elseif #andQueries == 1 then
                    table.insert(queries, andQueries[1])
                end
            else
                table.insert(queries, currentQuery)
            end
        end

        for _, query in queries do
            if typeof(query) == "string" then
                if query == "" then continue end
                table.insert(stringMatchQueries, ConvertEscapes(query))
            elseif typeof(query) == "table" and query.AndQueries then
                local convertedAnd = {}
                for _, andQuery in query.AndQueries do
                    table.insert(convertedAnd, ConvertEscapes(andQuery))
                end
                table.insert(stringMatchQueries, { AndQueries = convertedAnd })
            end
        end
    end

    return stringMatchQueries
end

--// Aurora Spy v3 (built-in, replaces Cobalt) \\--
do
    local Spy = {
        _version    = "3.0",
        _active     = false,
        _paused     = false,
        _watchAll   = false,
        _watching   = {},
        _ignoring   = {},
        _blocked    = {},
        _stats      = {},
        _hooked     = false,
        _log        = {},
        _logIndex   = 0,
        _maxLog     = 200,
        _logFull    = false,
        _console     = {},
        _consoleIndex = 0,
        _maxConsole  = 500,
        _consoleFull = false,
        _incomingHooks = {},
    }

    local function ringWrite(buf, idxKey, maxKey, fullKey, entry)
        Spy[idxKey] = Spy[idxKey] % Spy[maxKey] + 1
        buf[Spy[idxKey]] = entry
        if Spy[idxKey] == Spy[maxKey] then Spy[fullKey] = true end
    end

    local function ringRead(buf, idxKey, maxKey, fullKey, limit)
        local results = {}
        local total = Spy[fullKey] and Spy[maxKey] or Spy[idxKey]
        local count = math.min(limit, total)
        for i = 0, count - 1 do
            local idx = ((Spy[idxKey] - i - 1) % Spy[maxKey]) + 1
            local entry = buf[idx]
            if entry then table.insert(results, entry) end
        end
        return results
    end

    -- Lightweight arg serializer — minimal allocations for the hot path
    local function serializeArg(v)
        local t = typeof(v)
        if t == "string" then return { type = "string", value = v:sub(1, 200) }
        elseif t == "number" then return { type = "number", value = tostring(v) }
        elseif t == "boolean" then return { type = "boolean", value = tostring(v) }
        elseif t == "buffer" then return { type = "buffer", value = "buf(" .. buffer.len(v) .. ")" }
        elseif t == "Instance" then
            local ok, n = pcall(function() return v.Name end)
            return { type = "Instance", value = ok and n or "Instance" }
        elseif t == "Vector3" then return { type = "Vector3", value = tostring(v) }
        elseif t == "CFrame" then return { type = "CFrame", value = tostring(v):sub(1, 80) }
        elseif t == "table" then return { type = "table", value = "<table:#" .. #v .. ">" }
        elseif t == "nil" then return { type = "nil", value = "nil" }
        else return { type = t, value = t } end
    end

    local function serializeArgs(args)
        local result = {}
        local n = math.min(#args, 8)
        for i = 1, n do result[i] = serializeArg(args[i]) end
        return result
    end

    -- Per-remote rate limiting
    Spy._lastLogPerRemote = {}

    -- Core capture logic (shared by __namecall and hookfunction)
    local function captureCall(remoteName, method, ...)
        -- Block check
        if Spy._blocked[remoteName] then
            if method == "FireServer" then return true, nil end
            return true, nil
        end

        -- Quick bail if inactive
        if not Spy._active or Spy._paused then return false end

        -- Check ignore patterns
        for pattern in Spy._ignoring do
            if remoteName:find(pattern) then return false end
        end

        -- Check if watching
        if not Spy._watchAll and not Spy._watching[remoteName] then return false end

        -- Always increment stats
        Spy._stats[remoteName] = (Spy._stats[remoteName] or 0) + 1

        -- Per-remote rate limit
        local now = os.clock()
        local lastTime = Spy._lastLogPerRemote[remoteName] or 0
        if now - lastTime >= 0.1 then
            Spy._lastLogPerRemote[remoteName] = now
            local args = { ... }
            local caller = ""
            pcall(function() caller = debug.info(3, "s") or "" end)

            local idx = Spy._logIndex % Spy._maxLog + 1
            Spy._logIndex = idx
            Spy._log[idx] = {
                remote   = remoteName,
                method   = method,
                dir      = "out",
                args     = serializeArgs(args),
                argCount = #args,
                origin   = caller,
                time     = now,
            }
            if idx == Spy._maxLog then Spy._logFull = true end
        end

        return false
    end

    local oldNamecall
    local function installHook()
        if Spy._hooked then return end
        Spy._hooked = true

        -- Hook 1: __namecall (catches colon syntax: remote:FireServer())
        oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()

            if method == "FireServer" or method == "InvokeServer" then
                local ok, remoteName = pcall(function() return self.Name end)
                if ok and remoteName then
                    local blocked = captureCall(remoteName, method, ...)
                    if blocked then
                        if method == "FireServer" then return end
                        return nil
                    end
                end
            end

            return oldNamecall(self, ...)
        end))

        -- Hook 2: hookfunction on FireServer/InvokeServer
        -- Catches dot-syntax calls: remote.FireServer(remote, args) — used by Knit
        pcall(function()
            local RE = Instance.new("RemoteEvent")
            local oldFire = hookfunction(RE.FireServer, newcclosure(function(self, ...)
                local ok, remoteName = pcall(function() return self.Name end)
                if ok and remoteName then
                    local blocked = captureCall(remoteName, "FireServer", ...)
                    if blocked then return end
                end
                return oldFire(self, ...)
            end))
            RE:Destroy()
        end)

        pcall(function()
            local RF = Instance.new("RemoteFunction")
            local oldInvoke = hookfunction(RF.InvokeServer, newcclosure(function(self, ...)
                local ok, remoteName = pcall(function() return self.Name end)
                if ok and remoteName then
                    local blocked = captureCall(remoteName, "InvokeServer", ...)
                    if blocked then return nil end
                end
                return oldInvoke(self, ...)
            end))
            RF:Destroy()
        end)
    end

    local function hookIncoming(remote)
        if Spy._incomingHooks[remote] then return end
        local ok, isEvent = pcall(function()
            return remote:IsA("RemoteEvent") or remote:IsA("UnreliableRemoteEvent")
        end)
        if not ok or not isEvent then return end

        local ok2, conn = pcall(function()
            return remote.OnClientEvent:Connect(function(...)
                if not shouldCapture(remote.Name) then return end
                local args = { ... }
                ringWrite(Spy._log, "_logIndex", "_maxLog", "_logFull", {
                    remote   = remote.Name,
                    method   = "OnClientEvent",
                    dir      = "in",
                    args     = serializeArgs(args),
                    argCount = #args,
                    origin   = "server",
                    time     = os.clock(),
                })
                Spy._stats[remote.Name] = (Spy._stats[remote.Name] or 0) + 1
            end)
        end)
        if ok2 then
            Spy._incomingHooks[remote] = conn
        end
    end

    pcall(function()
        LogService.MessageOut:Connect(function(msg, msgType)
            ringWrite(Spy._console, "_consoleIndex", "_maxConsole", "_consoleFull", {
                msg  = tostring(msg):sub(1, 1000),
                type = tostring(msgType),
                time = os.clock(),
            })
        end)
    end)

    function Spy:Watch(names)
        if type(names) == "string" then names = { names } end
        for _, n in names do self._watching[n] = true end
        self._active = true
        installHook()
    end

    function Spy:WatchPattern(pattern)
        local count = 0
        for _, d in ReplicatedStorage:GetDescendants() do
            local ok, isRemote = pcall(function()
                return d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")
            end)
            if ok and isRemote then
                if d.Name:lower():find(pattern:lower()) then
                    self._watching[d.Name] = true
                    count = count + 1
                end
            end
        end
        self._active = true
        installHook()
        return count
    end

    function Spy:WatchAll()
        self._watchAll = true
        self._active = true
        installHook()
        -- Outgoing capture via __namecall is sufficient (no OnClientEvent hooks)
        -- This prevents freezes on high-frequency remotes like ByteNetReliable
    end

    function Spy:WatchIncoming(names)
        -- Incoming capture available for specific low-frequency remotes only
        if type(names) == "string" then names = { names } end
        for _, name in names do
            for _, d in ReplicatedStorage:GetDescendants() do
                if d.Name == name then
                    hookIncoming(d)
                end
            end
        end
    end

    function Spy:Ignore(patterns)
        if type(patterns) == "string" then patterns = { patterns } end
        for _, p in patterns do self._ignoring[p] = true end
    end

    function Spy:Block(names)
        if type(names) == "string" then names = { names } end
        for _, n in names do self._blocked[n] = true end
    end

    function Spy:Unblock(names)
        if type(names) == "string" then names = { names } end
        for _, n in names do self._blocked[n] = nil end
    end

    function Spy:Stop()
        self._active = false
        self._watchAll = false
        self._watching = {}
        for _, conn in self._incomingHooks do
            pcall(function() conn:Disconnect() end)
        end
        self._incomingHooks = {}
    end

    function Spy:Clear()
        self._log = {}
        self._logIndex = 0
        self._logFull = false
        self._stats = {}
        self._lastLogPerRemote = {}
    end

    function Spy:Read(limit)
        return ringRead(self._log, "_logIndex", "_maxLog", "_logFull", limit or 50)
    end

    function Spy:GetConsole(limit)
        return ringRead(self._console, "_consoleIndex", "_maxConsole", "_consoleFull", limit or 50)
    end

    function Spy:List(filter)
        local remotes = {}
        for _, d in ReplicatedStorage:GetDescendants() do
            local ok, isRemote = pcall(function()
                return d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")
            end)
            if ok and isRemote then
                if not filter or d.Name:lower():find(filter:lower()) then
                    local ok2, path = pcall(function() return d:GetFullName() end)
                    table.insert(remotes, {
                        name  = d.Name,
                        class = d.ClassName,
                        path  = ok2 and path:sub(1, 120) or d.Name,
                    })
                end
            end
        end
        return remotes
    end

    function Spy:Summary()
        local wc = 0; for _ in self._watching do wc = wc + 1 end
        local sc = 0; for _ in self._stats do sc = sc + 1 end
        local bc = 0; for _ in self._blocked do bc = bc + 1 end
        return {
            version        = self._version,
            active         = self._active,
            paused         = self._paused,
            watchAll       = self._watchAll,
            watchingCount  = wc,
            blockedCount   = bc,
            logEntries     = self._logFull and self._maxLog or self._logIndex,
            maxLog         = self._maxLog,
            uniqueRemotes  = sc,
            consoleEntries = self._consoleFull and self._maxConsole or self._consoleIndex,
            hooked         = self._hooked,
        }
    end

    function Spy:PresetKnit()
        self:Ignore({ "Replica_" })
        for _, d in ReplicatedStorage:GetDescendants() do
            local ok, isRemote = pcall(function()
                return d:IsA("RemoteEvent") or d:IsA("RemoteFunction")
            end)
            if ok and isRemote then
                local ok2, path = pcall(function() return d:GetFullName() end)
                if ok2 and path:find("Knit") then
                    self._watching[d.Name] = true
                end
            end
        end
        self._active = true
        installHook()
        return "Knit preset loaded"
    end

    function Spy:PresetByteNet()
        self:Watch({ "ByteNetReliable", "ByteNetUnreliable" })
        return "ByteNet preset loaded"
    end

    function Spy:PresetCombat()
        self:Watch({ "Primary", "Attack", "Fireball", "Ultimate", "DidDodge", "CoinEvent", "Damage", "Hit", "PoppingBubbleDamage", "DealDamage", "Interaction" })
        return "Combat preset loaded"
    end

    function Spy:PresetEconomy()
        self:WatchPattern("sell")
        self:WatchPattern("buy")
        self:WatchPattern("coin")
        self:WatchPattern("claim")
        self:WatchPattern("shop")
        return "Economy preset loaded"
    end

    getgenv().AuroraSpy = Spy
    _G.Spy = Spy
    print("[Aurora] Spy loaded — hook deferred until first watch")
end

--// Aurora Spy GUI (Cobalt-style Remote Spy Interface) \\--
do
    if getgenv().DisableAuroraSpy then
        print("[Aurora] DisableAuroraSpy flag set — skipping Spy GUI")
        return
    end
    local Spy = getgenv().AuroraSpy
    if not Spy then warn("[Aurora] Spy not loaded, skipping GUI") end

    if Spy then
        local UIS = cloneref(game:GetService("UserInputService"))
        local RunService = cloneref(game:GetService("RunService"))
        local guiParent = (typeof(gethui) == "function" and gethui()) or CoreGui

        -- Destroy old GUI
        pcall(function()
            for _, n in {"AuroraSpy"} do
                pcall(function() local old = CoreGui:FindFirstChild(n); if old then old:Destroy() end end)
                pcall(function() if gethui then local old = gethui():FindFirstChild(n); if old then old:Destroy() end end end)
            end
        end)

        -- Theme (Aurora dark glass)
        local C = {
            bg       = Color3.fromRGB(35, 35, 55),
            card     = Color3.fromRGB(25, 25, 38),
            titleBg  = Color3.fromRGB(20, 20, 32),
            accent   = Color3.fromRGB(252, 110, 142),
            text     = Color3.fromRGB(235, 235, 245),
            dim      = Color3.fromRGB(130, 130, 155),
            muted    = Color3.fromRGB(70, 70, 90),
            event    = Color3.fromRGB(91, 155, 213),
            func     = Color3.fromRGB(112, 198, 112),
            red      = Color3.fromRGB(239, 68, 68),
            yellow   = Color3.fromRGB(234, 179, 8),
            scrollBar = Color3.fromRGB(252, 110, 142),
            divider  = Color3.fromRGB(50, 50, 70),
        }

        -- ScreenGui
        local gui = Instance.new("ScreenGui")
        gui.Name = "AuroraSpy"
        gui.ResetOnSpawn = false
        gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        gui.DisplayOrder = 999
        gui.Parent = guiParent

        -- Main Frame
        local main = Instance.new("Frame")
        main.Name = "Main"
        main.Size = UDim2.fromOffset(650, 460)
        main.Position = UDim2.new(1, -660, 0, 10)
        main.BackgroundColor3 = C.bg
        main.BorderSizePixel = 0
        main.Active = true
        main.ClipsDescendants = true
        main.Parent = gui
        do local _c = Instance.new("UICorner"); _c.CornerRadius = UDim.new(0, 12); _c.Parent = main end
        local mainStroke = Instance.new("UIStroke")
        mainStroke.Color = C.accent
        mainStroke.Thickness = 1.5
        mainStroke.Transparency = 0.3
        mainStroke.Parent = main

        -- ═══ Title Bar (transparent — main bg shows through, corners stay clean) ═══
        local titleBar = Instance.new("Frame")
        titleBar.Name = "TitleBar"
        titleBar.Size = UDim2.new(1, 0, 0, 34)
        titleBar.BackgroundTransparency = 1
        titleBar.BorderSizePixel = 0
        titleBar.Active = true
        titleBar.Parent = main

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Text = "  🌸 Aurora Spy"
        titleLabel.Size = UDim2.new(1, -80, 1, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.TextColor3 = C.text
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextSize = 13
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Active = false
        titleLabel.Parent = titleBar

        -- Dragging
        local dragging, dragStart, startPos
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = main.Position
            end
        end)
        titleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        UIS.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)

        -- Close button (Frame + Active)
        local closeBtn = Instance.new("Frame")
        closeBtn.Size = UDim2.fromOffset(36, 36)
        closeBtn.Position = UDim2.new(1, -36, 0, 0)
        closeBtn.BackgroundTransparency = 1
        closeBtn.Active = true
        closeBtn.Parent = titleBar
        local closeLbl = Instance.new("TextLabel")
        closeLbl.Text = "×"
        closeLbl.Size = UDim2.new(1, 0, 1, 0)
        closeLbl.BackgroundTransparency = 1
        closeLbl.TextColor3 = C.dim
        closeLbl.Font = Enum.Font.GothamBold
        closeLbl.TextSize = 18
        closeLbl.Active = false
        closeLbl.Parent = closeBtn
        closeBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                Spy:Stop()
                gui:Destroy()
            elseif input.UserInputType == Enum.UserInputType.MouseMovement then
                closeLbl.TextColor3 = C.red
            end
        end)
        closeBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                closeLbl.TextColor3 = C.dim
            end
        end)

        -- Minimize button
        local minBtn = Instance.new("Frame")
        minBtn.Size = UDim2.fromOffset(36, 36)
        minBtn.Position = UDim2.new(1, -72, 0, 0)
        minBtn.BackgroundTransparency = 1
        minBtn.Active = true
        minBtn.Parent = titleBar
        local minLbl = Instance.new("TextLabel")
        minLbl.Text = "−"
        minLbl.Size = UDim2.new(1, 0, 1, 0)
        minLbl.BackgroundTransparency = 1
        minLbl.TextColor3 = C.dim
        minLbl.Font = Enum.Font.GothamBold
        minLbl.TextSize = 18
        minLbl.Active = false
        minLbl.Parent = minBtn
        local minimized = false
        local fullSize = main.Size
        minBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                minimized = not minimized
                main.Size = minimized and UDim2.fromOffset(650, 35) or fullSize
            elseif input.UserInputType == Enum.UserInputType.MouseMovement then
                minLbl.TextColor3 = C.text
            end
        end)
        minBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                minLbl.TextColor3 = C.dim
            end
        end)

        -- Accent line below title bar
        local accentLine = Instance.new("Frame")
        accentLine.Size = UDim2.new(1, 0, 0, 1)
        accentLine.Position = UDim2.new(0, 0, 0, 34)
        accentLine.BackgroundColor3 = C.accent
        accentLine.BackgroundTransparency = 0.5
        accentLine.BorderSizePixel = 0
        accentLine.Parent = main

        -- ═══ Toolbar (transparent — no bg overlap on corners) ═══
        local toolbar = Instance.new("Frame")
        toolbar.Size = UDim2.new(1, 0, 0, 28)
        toolbar.Position = UDim2.new(0, 0, 0, 35)
        toolbar.BackgroundTransparency = 1
        toolbar.BorderSizePixel = 0
        toolbar.Parent = main

        -- Clear button
        local clearBtn = Instance.new("Frame")
        clearBtn.Size = UDim2.fromOffset(50, 20)
        clearBtn.Position = UDim2.fromOffset(8, 4)
        clearBtn.BackgroundColor3 = C.bg
        clearBtn.BorderSizePixel = 0
        clearBtn.Active = true
        clearBtn.Parent = toolbar
        do local _c = Instance.new("UICorner"); _c.CornerRadius = UDim.new(0, 6); _c.Parent = clearBtn end
        local clearLbl = Instance.new("TextLabel")
        clearLbl.Text = "Clear"
        clearLbl.Size = UDim2.new(1, 0, 1, 0)
        clearLbl.BackgroundTransparency = 1
        clearLbl.TextColor3 = C.dim
        clearLbl.Font = Enum.Font.GothamSemibold
        clearLbl.TextSize = 10
        clearLbl.Active = false
        clearLbl.Parent = clearBtn

        -- Stats label
        local statsLabel = Instance.new("TextLabel")
        statsLabel.Size = UDim2.new(0, 200, 1, 0)
        statsLabel.Position = UDim2.new(1, -208, 0, 0)
        statsLabel.BackgroundTransparency = 1
        statsLabel.TextColor3 = C.dim
        statsLabel.Font = Enum.Font.Gotham
        statsLabel.TextSize = 10
        statsLabel.TextXAlignment = Enum.TextXAlignment.Right
        statsLabel.Text = "0 remotes"
        statsLabel.Active = false
        statsLabel.Parent = toolbar

        -- ═══ Body (split panels) ═══
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 1, -63)
        body.Position = UDim2.new(0, 0, 0, 63)
        body.BackgroundTransparency = 1
        body.Parent = main

        -- Divider line
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(0, 1, 1, -8)
        divider.Position = UDim2.new(0.5, 0, 0, 4)
        divider.BackgroundColor3 = C.divider
        divider.BorderSizePixel = 0
        divider.Parent = body

        -- Left: remote list
        local remoteList = Instance.new("ScrollingFrame")
        remoteList.Name = "RemoteList"
        remoteList.Size = UDim2.new(0.5, 0, 1, 0)
        remoteList.BackgroundTransparency = 1
        remoteList.BorderSizePixel = 0
        remoteList.ScrollBarThickness = 3
        remoteList.ScrollBarImageColor3 = C.scrollBar
        remoteList.CanvasSize = UDim2.new(0, 0, 0, 0)
        remoteList.AutomaticCanvasSize = Enum.AutomaticSize.Y
        remoteList.Parent = body
        local rlLayout = Instance.new("UIListLayout")
        rlLayout.SortOrder = Enum.SortOrder.LayoutOrder
        rlLayout.Padding = UDim.new(0, 1)
        rlLayout.Parent = remoteList

        -- Right: detail panel (transparent — entries have card bg)
        local detailPanel = Instance.new("Frame")
        detailPanel.Size = UDim2.new(0.5, -1, 1, 0)
        detailPanel.Position = UDim2.new(0.5, 1, 0, 0)
        detailPanel.BackgroundTransparency = 1
        detailPanel.BorderSizePixel = 0
        detailPanel.Parent = body

        -- Detail header (transparent — text + buttons only)
        local detailHeader = Instance.new("Frame")
        detailHeader.Size = UDim2.new(1, 0, 0, 28)
        detailHeader.BackgroundTransparency = 1
        detailHeader.BorderSizePixel = 0
        detailHeader.Parent = detailPanel

        local detailTitle = Instance.new("TextLabel")
        detailTitle.Text = "  Select a remote"
        detailTitle.Size = UDim2.new(1, -100, 1, 0)
        detailTitle.BackgroundTransparency = 1
        detailTitle.TextColor3 = C.dim
        detailTitle.Font = Enum.Font.GothamSemibold
        detailTitle.TextSize = 11
        detailTitle.TextXAlignment = Enum.TextXAlignment.Left
        detailTitle.TextTruncate = Enum.TextTruncate.AtEnd
        detailTitle.Active = false
        detailTitle.Parent = detailHeader

        -- Block button
        local blockBtn = Instance.new("Frame")
        blockBtn.Size = UDim2.fromOffset(44, 18)
        blockBtn.Position = UDim2.new(1, -96, 0, 5)
        blockBtn.BackgroundColor3 = C.bg
        blockBtn.BorderSizePixel = 0
        blockBtn.Active = true
        blockBtn.Visible = false
        blockBtn.Parent = detailHeader
        do local _c = Instance.new("UICorner"); _c.CornerRadius = UDim.new(0, 4); _c.Parent = blockBtn end
        local blockLbl = Instance.new("TextLabel")
        blockLbl.Text = "Block"
        blockLbl.Size = UDim2.new(1, 0, 1, 0)
        blockLbl.BackgroundTransparency = 1
        blockLbl.TextColor3 = C.dim
        blockLbl.Font = Enum.Font.GothamSemibold
        blockLbl.TextSize = 9
        blockLbl.Active = false
        blockLbl.Parent = blockBtn

        -- Ignore button
        local ignoreBtn = Instance.new("Frame")
        ignoreBtn.Size = UDim2.fromOffset(46, 18)
        ignoreBtn.Position = UDim2.new(1, -48, 0, 5)
        ignoreBtn.BackgroundColor3 = C.bg
        ignoreBtn.BorderSizePixel = 0
        ignoreBtn.Active = true
        ignoreBtn.Visible = false
        ignoreBtn.Parent = detailHeader
        do local _c = Instance.new("UICorner"); _c.CornerRadius = UDim.new(0, 4); _c.Parent = ignoreBtn end
        local ignoreLbl = Instance.new("TextLabel")
        ignoreLbl.Text = "Ignore"
        ignoreLbl.Size = UDim2.new(1, 0, 1, 0)
        ignoreLbl.BackgroundTransparency = 1
        ignoreLbl.TextColor3 = C.dim
        ignoreLbl.Font = Enum.Font.GothamSemibold
        ignoreLbl.TextSize = 9
        ignoreLbl.Active = false
        ignoreLbl.Parent = ignoreBtn

        -- Call list
        local callList = Instance.new("ScrollingFrame")
        callList.Size = UDim2.new(1, 0, 1, -28)
        callList.Position = UDim2.new(0, 0, 0, 28)
        callList.BackgroundTransparency = 1
        callList.BorderSizePixel = 0
        callList.ScrollBarThickness = 3
        callList.ScrollBarImageColor3 = C.scrollBar
        callList.CanvasSize = UDim2.new(0, 0, 0, 0)
        callList.AutomaticCanvasSize = Enum.AutomaticSize.Y
        callList.Parent = detailPanel
        local clLayout = Instance.new("UIListLayout")
        clLayout.SortOrder = Enum.SortOrder.LayoutOrder
        clLayout.Padding = UDim.new(0, 2)
        clLayout.Parent = callList
        local clPadding = Instance.new("UIPadding")
        clPadding.PaddingLeft = UDim.new(0, 6)
        clPadding.PaddingRight = UDim.new(0, 6)
        clPadding.PaddingTop = UDim.new(0, 4)
        clPadding.Parent = callList

        -- ═══ State ═══
        local remoteEntries = {}
        local selectedRemote = nil
        local ignoredRemotes = {}
        local lastLogIndex = 0

        -- Forward declarations
        local refreshDetailPanel

        -- Create remote entry
        local function createRemoteEntry(remoteName, className, callCount)
            local entry = Instance.new("Frame")
            entry.Name = remoteName
            entry.Size = UDim2.new(1, 0, 0, 26)
            entry.BackgroundColor3 = C.card
            entry.BorderSizePixel = 0
            entry.Active = true
            entry.LayoutOrder = -callCount
            entry.Parent = remoteList

            local icon = Instance.new("TextLabel")
            icon.Text = className == "RemoteFunction" and "◇" or "◆"
            icon.Size = UDim2.fromOffset(18, 26)
            icon.Position = UDim2.fromOffset(6, 0)
            icon.BackgroundTransparency = 1
            icon.TextColor3 = className == "RemoteFunction" and C.func or C.event
            icon.Font = Enum.Font.Gotham
            icon.TextSize = 10
            icon.Active = false
            icon.Parent = entry

            local nameLabel = Instance.new("TextLabel")
            nameLabel.Text = remoteName
            nameLabel.Size = UDim2.new(1, -76, 1, 0)
            nameLabel.Position = UDim2.fromOffset(22, 0)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextColor3 = C.text
            nameLabel.Font = Enum.Font.Gotham
            nameLabel.TextSize = 11
            nameLabel.TextXAlignment = Enum.TextXAlignment.Left
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.Active = false
            nameLabel.Parent = entry

            local countLabel = Instance.new("TextLabel")
            countLabel.Text = tostring(callCount)
            countLabel.Size = UDim2.fromOffset(46, 26)
            countLabel.Position = UDim2.new(1, -52, 0, 0)
            countLabel.BackgroundTransparency = 1
            countLabel.TextColor3 = C.dim
            countLabel.Font = Enum.Font.Gotham
            countLabel.TextSize = 10
            countLabel.TextXAlignment = Enum.TextXAlignment.Right
            countLabel.Active = false
            countLabel.Parent = entry

            -- Hover
            entry.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    if selectedRemote ~= remoteName then
                        entry.BackgroundColor3 = C.bg
                    end
                end
            end)
            entry.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseMovement then
                    if selectedRemote ~= remoteName then
                        entry.BackgroundColor3 = C.card
                    end
                end
            end)

            -- Click to select
            entry.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1
                or input.UserInputType == Enum.UserInputType.Touch then
                    if selectedRemote and remoteEntries[selectedRemote] then
                        remoteEntries[selectedRemote].frame.BackgroundColor3 = C.card
                    end
                    selectedRemote = remoteName
                    entry.BackgroundColor3 = Color3.fromRGB(50, 35, 60)
                    refreshDetailPanel()
                end
            end)

            remoteEntries[remoteName] = {
                frame = entry,
                countLabel = countLabel,
                className = className,
            }
        end

        -- Refresh detail panel
        refreshDetailPanel = function()
            for _, child in callList:GetChildren() do
                if child:IsA("Frame") then child:Destroy() end
            end

            if not selectedRemote then
                detailTitle.Text = "  Select a remote"
                detailTitle.TextColor3 = C.dim
                blockBtn.Visible = false
                ignoreBtn.Visible = false
                return
            end

            local entryData = remoteEntries[selectedRemote]
            if not entryData then return end

            detailTitle.Text = "  " .. selectedRemote
            detailTitle.TextColor3 = entryData.className == "RemoteFunction" and C.func or C.event
            blockBtn.Visible = true
            ignoreBtn.Visible = true

            local isBlocked = Spy._blocked[selectedRemote]
            blockLbl.Text = isBlocked and "Unblk" or "Block"
            blockLbl.TextColor3 = isBlocked and C.red or C.dim
            blockBtn.BackgroundColor3 = isBlocked and Color3.fromRGB(60, 20, 20) or C.bg

            local isIgnored = ignoredRemotes[selectedRemote]
            ignoreLbl.Text = isIgnored and "Show" or "Ignore"
            ignoreLbl.TextColor3 = isIgnored and C.yellow or C.dim

            -- Get logs for selected remote
            local logs = Spy:Read(200)
            local remoteLogs = {}
            for _, entry in logs do
                if entry.remote == selectedRemote then
                    table.insert(remoteLogs, entry)
                end
            end

            for i, log in remoteLogs do
                if i > 50 then break end

                local callFrame = Instance.new("Frame")
                callFrame.Size = UDim2.new(1, -12, 0, 0)
                callFrame.BackgroundColor3 = C.card
                callFrame.BorderSizePixel = 0
                callFrame.AutomaticSize = Enum.AutomaticSize.Y
                callFrame.LayoutOrder = i
                callFrame.Parent = callList
                do local _c = Instance.new("UICorner"); _c.CornerRadius = UDim.new(0, 4); _c.Parent = callFrame end
                local cfPad = Instance.new("UIPadding")
                cfPad.PaddingLeft = UDim.new(0, 8)
                cfPad.PaddingRight = UDim.new(0, 8)
                cfPad.PaddingTop = UDim.new(0, 4)
                cfPad.PaddingBottom = UDim.new(0, 4)
                cfPad.Parent = callFrame

                local dirText = log.dir == "out" and "→ " or "← "
                local header = Instance.new("TextLabel")
                header.Text = dirText .. log.method
                header.Size = UDim2.new(1, 0, 0, 13)
                header.BackgroundTransparency = 1
                header.TextColor3 = log.dir == "out" and C.event or C.func
                header.Font = Enum.Font.GothamSemibold
                header.TextSize = 10
                header.TextXAlignment = Enum.TextXAlignment.Left
                header.Active = false
                header.Parent = callFrame

                -- Script origin (which script called this remote)
                local originText = ""
                if log.origin and log.origin ~= "" and log.origin ~= "[C]" and log.origin ~= "server" then
                    local scriptPath = tostring(log.origin)
                    scriptPath = scriptPath:gsub("^%[string \"", ""):gsub("\"%]$", "")
                    originText = scriptPath
                elseif log.origin == "server" then
                    originText = "← server"
                end

                local nextY = 13
                if originText ~= "" then
                    local originLabel = Instance.new("TextLabel")
                    originLabel.Text = "📄 " .. originText
                    originLabel.Size = UDim2.new(1, 0, 0, 11)
                    originLabel.Position = UDim2.fromOffset(0, nextY)
                    originLabel.BackgroundTransparency = 1
                    originLabel.TextColor3 = C.accent
                    originLabel.Font = Enum.Font.RobotoMono
                    originLabel.TextSize = 9
                    originLabel.TextXAlignment = Enum.TextXAlignment.Left
                    originLabel.TextTruncate = Enum.TextTruncate.AtEnd
                    originLabel.Active = false
                    originLabel.Parent = callFrame
                    nextY = nextY + 12
                end

                local argsText = ""
                if log.args and #log.args > 0 then
                    local parts = {}
                    for j, arg in log.args do
                        local val = arg.value or "?"
                        if arg.type == "string" then val = '"' .. val .. '"' end
                        table.insert(parts, "  [" .. j .. "] " .. arg.type .. ": " .. val)
                    end
                    argsText = table.concat(parts, "\n")
                else
                    argsText = "  (no args)"
                end

                local argsLabel = Instance.new("TextLabel")
                argsLabel.Text = argsText
                argsLabel.Size = UDim2.new(1, 0, 0, 0)
                argsLabel.Position = UDim2.fromOffset(0, nextY)
                argsLabel.AutomaticSize = Enum.AutomaticSize.Y
                argsLabel.BackgroundTransparency = 1
                argsLabel.TextColor3 = C.dim
                argsLabel.Font = Enum.Font.RobotoMono
                argsLabel.TextSize = 9
                argsLabel.TextXAlignment = Enum.TextXAlignment.Left
                argsLabel.TextWrapped = true
                argsLabel.Active = false
                argsLabel.Parent = callFrame
            end

            if #remoteLogs == 0 then
                local empty = Instance.new("TextLabel")
                empty.Text = "No calls captured yet"
                empty.Size = UDim2.new(1, 0, 0, 30)
                empty.BackgroundTransparency = 1
                empty.TextColor3 = C.muted
                empty.Font = Enum.Font.Gotham
                empty.TextSize = 10
                empty.Active = false
                empty.Parent = callList
            end
        end

        -- Block handler
        blockBtn.InputBegan:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) and selectedRemote then
                if Spy._blocked[selectedRemote] then
                    Spy:Unblock({ selectedRemote })
                else
                    Spy:Block({ selectedRemote })
                end
                refreshDetailPanel()
            end
        end)

        -- Ignore handler
        ignoreBtn.InputBegan:Connect(function(input)
            if (input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch) and selectedRemote then
                if ignoredRemotes[selectedRemote] then
                    ignoredRemotes[selectedRemote] = nil
                    if remoteEntries[selectedRemote] then
                        remoteEntries[selectedRemote].frame.Visible = true
                    end
                else
                    ignoredRemotes[selectedRemote] = true
                    if remoteEntries[selectedRemote] then
                        remoteEntries[selectedRemote].frame.Visible = false
                    end
                end
                refreshDetailPanel()
            end
        end)

        -- Clear handler
        clearBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
                Spy:Clear()
                selectedRemote = nil
                for _, data in remoteEntries do
                    data.frame:Destroy()
                end
                remoteEntries = {}
                ignoredRemotes = {}
                refreshDetailPanel()
            end
        end)
        clearBtn.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                clearBtn.BackgroundColor3 = C.card
            end
        end)
        clearBtn.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseMovement then
                clearBtn.BackgroundColor3 = C.bg
            end
        end)

        -- Auto watch all (Cobalt behavior)
        Spy:WatchAll()

        -- Update loop — only show remotes that have actually fired (Cobalt behavior)
        task.spawn(function()
            while gui and gui.Parent do
                local totalRemotes = 0
                for name, count in Spy._stats do
                    totalRemotes += 1
                    if remoteEntries[name] then
                        remoteEntries[name].countLabel.Text = tostring(count)
                        remoteEntries[name].frame.LayoutOrder = -count
                    else
                        local className = "RemoteEvent"
                        for _, d in ReplicatedStorage:GetDescendants() do
                            if d.Name == name then
                                pcall(function() className = d.ClassName end)
                                break
                            end
                        end
                        createRemoteEntry(name, className, count)
                        if ignoredRemotes[name] then
                            remoteEntries[name].frame.Visible = false
                        end
                    end
                end

                statsLabel.Text = totalRemotes .. " remotes  |  " .. (Spy._logFull and Spy._maxLog or Spy._logIndex) .. " logs"

                task.wait(0.5)
            end
        end)

        print("[Aurora] Spy GUI loaded — watching all remotes")
    end
end

--// Main Loop (wrapped in task.spawn so connector load doesn't block the caller) \\--
task.spawn(function()
local reconnectCount = 0
local lastConnectStart = 0
local rapidReconnects = 0
while true do
    -- Structural exit: bridge doesn't support HTTP polling on this server
    if getgenv().__AURORA_HTTP_UNSUPPORTED then
        warn("[Aurora] HTTP polling unsupported by bridge. Exiting reconnect loop. Reload with a WebSocket-capable executor to use MCP.")
        break
    end
    -- Reconnect-storm breaker: if we reconnected within 5s of the last attempt, count it.
    -- After 3 rapid reconnects (storm indicator), bail out — prevents the zombie-client pileup
    -- that happens when WS falls back to HTTP but bridge is WS-only.
    local now = os.clock()
    if now - lastConnectStart < 5 and lastConnectStart > 0 then
        rapidReconnects += 1
        if rapidReconnects >= 3 then
            warn("[Aurora] Reconnect storm detected (3+ reconnects within 5s). Giving up to protect game performance.")
            warn("[Aurora] Likely cause: executor's WebSocket failing, bridge falling back to HTTP which is unsupported. Check executor WS or restart game.")
            break
        end
    else
        rapidReconnects = 0
    end
    lastConnectStart = now
    reconnectCount += 1
    if reconnectCount > 1 then
        print("[Aurora] Reconnecting... (attempt " .. tostring(reconnectCount) .. ")")
    end

    local success, Bridge = pcall(CreateBridge)

    if not success then
        warn("[Aurora] Failed to create bridge: " .. tostring(Bridge))
        task.wait(3)
        continue
    end

    print("[Aurora] Connected to MCP server via " .. (WebSocketAvailable and "WebSocket" or "HTTP") .. "")
    reconnectCount = 0

    Bridge:BindToType("execute", function(data)
        setthreadidentity(8)
        local fn = loadstring(data.source or data.code)
        local ok, err = pcall(fn)
        if not ok then
            return { success = false, error = tostring(err) }
        end
        return { success = true }
    end)

    Bridge:BindToType("get-console-output", function(data)
        local limit = data.limit or 50
        local logsOrder = data.logsOrder or "NewestFirst"

        local logs = LogService:GetLogHistory()
        local results = {}
        
        if logsOrder == "NewestFirst" then
            for i = #logs, 1, -1 do
                if #results >= limit then break end
                table.insert(results, logs[i])
            end
        else
            for _, log in logs do
                if #results >= limit then break end
                table.insert(results, log)
            end
        end

        return { count = #LogService:GetLogHistory(), limited = #LogService:GetLogHistory() > limit, results = results }
    end)

    Bridge:BindToType("get-data-by-code", function(data)
        setthreadidentity(8)
        local dataOutput = table.pack(loadstring(data.source or data.code)())
        return dataOutput
    end)

    Bridge:BindToType("eval", function(data)
        setthreadidentity(8)
        local dataOutput = table.pack(loadstring(data.code or data.source)())
        return dataOutput
    end)

    Bridge:BindToType("get-script-content", function(data)
        --// Handle GC'd script proxies: debugId is passed directly, skip loadstring \\--
        if data.debugId then
            local cached = ScriptSourcesMap[data.debugId]
            assert(cached, "No cached source found for GC'd ScriptProxy with DebugId: " .. tostring(data.debugId))
            return cached
        end

        setthreadidentity(8)
        local scriptInstance = loadstring(data.source)()

        assert(typeof(scriptInstance) == "Instance", "Script instance is not an instance.")
        assert(scriptInstance:IsA("LuaSourceContainer"), "Script instance is not a LuaSourceContainer (Script, LocalScript, or ModuleScript).")
        assert(not (scriptInstance:IsA("Script") and scriptInstance.RunContext == Enum.RunContext.Server), "Script instance is a Server Script.")

        if not ScriptSourcesMap[scriptInstance:GetDebugId()] then
            MapScriptSource(scriptInstance)
        end

        return ScriptSourcesMap[scriptInstance:GetDebugId()]
    end)

    Bridge:BindToType("search-instances", function(data)
        local rootInstance = loadstring("return " .. data.root)()
        local instances = rootInstance:QueryDescendants(data.selector)
        
        local limit = data.limit or 50
        local results = {}
        
        for i, instance in instances do
            if i > limit then break end

            table.insert(results, {
                Name = instance.Name,
                ClassName = instance.ClassName,
                InstancePath = instance,
                DebugId = instance:GetDebugId()
            })
        end
        
        return {
            count = #instances,
            limited = #instances > limit,
            results = results
        }
    end)

    Bridge:BindToType("get-game-info", function(data)
        local productInfo = MarketplaceService:GetProductInfo(game.PlaceId)
        
        return {
            PlaceId = game.PlaceId,
            GameId = game.GameId,
            PlaceVersion = game.PlaceVersion,
            PlaceName = productInfo.Name,
            PlaceDescription = productInfo.Description,
            Creator = productInfo.Creator.Name,
            CreatorType = tostring(productInfo.Creator.CreatorType),
            CreatorId = productInfo.Creator.CreatorTargetId,
            JobId = game.JobId,
            ServerType = RobloxReplicatedStorage.GetServerType:InvokeServer()
        }
    end)

    Bridge:BindToType("get-descendants-tree", function(data)
        local rootInstance = loadstring("return " .. data.root)()
        assert(typeof(rootInstance) == "Instance", "Root path did not resolve to a valid Instance.")

        local maxDepth = data.maxDepth or 3
        local maxChildren = data.maxChildren or 50
        local classFilter = data.classFilter or ""
        local hasFilter = classFilter ~= ""

        local function buildTree(instance, depth)
            if depth > maxDepth then
                return nil
            end

            local children = instance:GetChildren()
            local childNodes = {}
            local shown = 0
            local total = #children

            for _, child in children do
                if shown >= maxChildren then break end

                if hasFilter and not child:IsA(classFilter) then
                    -- Even if this child doesn't match, check if any descendant might
                    -- Only skip if we're at max depth anyway
                    if depth < maxDepth then
                        local subtree = buildTree(child, depth + 1)
                        if subtree and subtree.Children and #subtree.Children > 0 then
                            table.insert(childNodes, subtree)
                            shown += 1
                        end
                    end
                    continue
                end

                local node = {
                    Name = child.Name,
                    ClassName = child.ClassName,
                    ChildCount = #child:GetChildren()
                }

                if depth < maxDepth and node.ChildCount > 0 then
                    local subtree = buildTree(child, depth + 1)
                    if subtree then
                        node.Children = subtree.Children
                    end
                end

                table.insert(childNodes, node)
                shown += 1
            end

            return {
                Name = instance.Name,
                ClassName = instance.ClassName,
                ChildCount = total,
                TruncatedAt = if shown < total then shown else nil,
                Children = childNodes
            }
        end

        return buildTree(rootInstance, 0)
    end)

    --// Aurora Spy MCP Bindings \\--

    Bridge:BindToType("spy-init", function(data)
        local Spy = getgenv().AuroraSpy
        if Spy then
            return { status = "loaded", info = Spy:Summary() }
        end
        return { error = "Aurora Spy failed to initialize" }
    end)

    Bridge:BindToType("spy-watch", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")

        if data.preset then
            local presetMap = {
                knit    = function() return Spy:PresetKnit() end,
                bytenet = function() return Spy:PresetByteNet() end,
                combat  = function() return Spy:PresetCombat() end,
                economy = function() return Spy:PresetEconomy() end,
            }
            local fn = presetMap[data.preset]
            if fn then return { status = "ok", message = fn() } end
            return { error = "Unknown preset: " .. tostring(data.preset) }
        end

        if data.ignore then Spy:Ignore(data.ignore) end

        if data.pattern then
            local count = Spy:WatchPattern(data.pattern)
            return { status = "watching", message = "Watching " .. count .. " remotes matching: " .. data.pattern }
        elseif data.all then
            Spy:WatchAll()
            return { status = "watching_all", message = "Watching all remotes (outgoing + incoming)" }
        elseif data.remotes then
            Spy:Watch(data.remotes)
            if data.incoming then Spy:WatchIncoming(data.remotes) end
            return { status = "watching", message = "Watching: " .. table.concat(data.remotes, ", ") }
        end

        return { error = "Provide remotes, pattern, preset, or all=true" }
    end)

    Bridge:BindToType("spy-logs", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")
        local logs = Spy:Read(data.limit or 50)
        if data.filter and data.filter ~= "" then
            local filtered = {}
            for _, entry in logs do
                if entry.remote:lower():find(data.filter:lower(), 1, true) then
                    table.insert(filtered, entry)
                end
            end
            logs = filtered
        end
        return { count = #logs, results = logs }
    end)

    Bridge:BindToType("spy-stats", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")
        return { stats = Spy._stats, summary = Spy:Summary() }
    end)

    Bridge:BindToType("spy-list", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")
        local remotes = Spy:List(data.filter)
        return { count = #remotes, remotes = remotes }
    end)

    Bridge:BindToType("spy-clear", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")
        Spy:Clear()
        return { status = "cleared" }
    end)

    Bridge:BindToType("spy-block", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")
        if data.remotes then Spy:Block(data.remotes) end
        if data.unblock then Spy:Unblock(data.unblock) end
        return { status = "ok", blocked = Spy._blocked }
    end)

    Bridge:BindToType("spy-console", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")
        return { count = 0, entries = Spy:GetConsole(data.limit or 50) }
    end)

    Bridge:BindToType("search-scripts-sources", function(data)
        --// If mapping was deferred, start it now and wait for it to finish \\--
        if not HasStartedMapping then
            StartScriptMapping()
        end

        assert(ScriptSourcesMap.HasFinishedMapping, "The bridge is still mapping all script sources (" .. tostring(MappedSources) .. "/" .. tostring(SourcesToMap) .. ") please try again later.")

        local stringMatchQueries = ParseQuery(data.query)
        local limit = data.limit or 50
        local contextLines = data.contextLines or 2
        local totalMatches = 0
        local maxMatchesPerScript = data.maxMatchesPerScript or 20

        --// Pre-compute query info \\--
        local queryInfo = {}
        for idx, query in stringMatchQueries do
            local isLogicalAND = typeof(query) == "table"
            local isMultiLine = false
            
            if isLogicalAND then
                for _, q in query.AndQueries do
                    if not q:find("\n", 1, true) then continue end
                    
                    isMultiLine = true
                    break
                end
            else
                isMultiLine = query:find("\n", 1, true) ~= nil
            end
            
            queryInfo[idx] = { isLogicalAND = isLogicalAND, isMultiLine = isMultiLine }
        end

        --// Filter scripts that we need to process (search) \\--
        local matchingScripts = {}
        local count = 0
        
        for debugId, source in ScriptSourcesMap do
            if debugId == "HasFinishedMapping" then continue end
            if #matchingScripts >= limit then break end

            --// Rate limit \\--
            count += 1
            if count % 200 == 0 then task.wait() end

            --// Pre-check \\--
            local hasAnyPotentialMatch = false
            for idx, query in stringMatchQueries do
                local info = queryInfo[idx]
                
                if info.isLogicalAND then
                    local allPartsMatch = true
                    for _, andQuery in query.AndQueries do
                        if not source:find(andQuery, 1, true) then
                            allPartsMatch = false
                            break
                        end
                    end
                    if allPartsMatch then
                        hasAnyPotentialMatch = true
                        break
                    end
                elseif source:find(query, 1, true) then
                    hasAnyPotentialMatch = true
                    break
                end
            end

            if not hasAnyPotentialMatch then continue end
            
            table.insert(matchingScripts, { debugId = debugId, source = source })
        end

        --// Process matching scripts \\--
        local results = {}
        
        for _, scriptData in matchingScripts do
            if #results >= limit then break end
            
            local debugId = scriptData.debugId
            local source = scriptData.source
            
            --// Build line info lazily \\--
            local lines = nil
            local lineStarts = nil
            
            local function EnsureLineInfo()
                if lines then return end
                lines = {}
                local pos = 1
                local len = #source
                while pos <= len do
                    local newlinePos = source:find("\n", pos, true)
                    if newlinePos then
                        table.insert(lines, source:sub(pos, newlinePos - 1))
                        pos = newlinePos + 1
                    else
                        table.insert(lines, source:sub(pos))
                        break
                    end
                end
                lineStarts = GetLineInfo(source)
            end

            local function AddMatch(matchingLines, startLine, endLine, matchedContent)
                EnsureLineInfo()
                
                local before = {}
                for i = math.max(1, startLine - contextLines), startLine - 1 do
                    table.insert(before, { lineNumber = i, content = lines[i] or "" })
                end
                
                local after = {}
                for i = endLine + 1, math.min(#lines, endLine + contextLines) do
                    table.insert(after, { lineNumber = i, content = lines[i] or "" })
                end
                
                local content
                if startLine == endLine then
                    content = matchedContent or lines[startLine] or ""
                else
                    content = {}
                    for i = startLine, endLine do
                        table.insert(content, { lineNumber = i, content = lines[i] or "" })
                    end
                end
                
                table.insert(matchingLines, {
                    lineNumber = startLine,
                    endLineNumber = endLine,
                    content = content,
                    before = before,
                    after = after
                })
            end

            --// Find all matching lines \\--
            local matchingLines = {}
            local matchedPositions = {}
            
            for idx, query in stringMatchQueries do
                if #matchingLines >= maxMatchesPerScript then break end
                
                local info = queryInfo[idx]
                
                if info.isMultiLine then
                    EnsureLineInfo()

                    local searchStart = 1
                    while #matchingLines < maxMatchesPerScript do
                        local matchStart, matchEnd
                        
                        if info.isLogicalAND then
                            local allMatch = true
                            local minStart, maxEnd = math.huge, 0
                            for _, andQuery in query.AndQueries do
                                local s, e = source:find(andQuery, searchStart, true)
                                if not s then
                                    allMatch = false
                                    break
                                end

                                minStart = math.min(minStart, s)
                                maxEnd = math.max(maxEnd, e)
                            end

                            if allMatch then matchStart, matchEnd = minStart, maxEnd end
                        else
                            matchStart, matchEnd = source:find(query, searchStart, true)
                        end
                        
                        if not matchStart then break end
                        
                        local posKey = matchStart
                        if not matchedPositions[posKey] then
                            matchedPositions[posKey] = true
                            local startLine = GetLineNumber(lineStarts, matchStart)
                            local endLine = GetLineNumber(lineStarts, matchEnd)
                            local matchedContent = source:sub(matchStart, matchEnd)
                            AddMatch(matchingLines, startLine, endLine, matchedContent)
                        end

                        searchStart = matchEnd + 1
                    end

                else
                    
                    local searchStart = 1
                    while #matchingLines < maxMatchesPerScript do
                        local matchStart, matchEnd
                        
                        if info.isLogicalAND then
                            -- For AND queries, find first query then verify others on same line
                            local firstQuery = query.AndQueries[1]
                            matchStart, matchEnd = source:find(firstQuery, searchStart, true)
                            
                            if matchStart then
                                -- Find line boundaries
                                local lineStart = source:sub(1, matchStart):match(".*\n()") or 1
                                local lineEnd = source:find("\n", matchEnd, true) or (#source + 1)
                                local lineContent = source:sub(lineStart, lineEnd - 1)
                                
                                -- Check all AND queries match on this line
                                local allMatch = true
                                for i = 2, #query.AndQueries do
                                    if not lineContent:find(query.AndQueries[i], 1, true) then
                                        allMatch = false
                                        break
                                    end
                                end
                                
                                if not allMatch then
                                    searchStart = lineEnd + 1
                                    continue
                                end
                                
                                matchStart = lineStart
                                matchEnd = lineEnd - 1
                            end
                        else
                            matchStart, matchEnd = source:find(query, searchStart, true)
                        end
                        
                        if not matchStart then break end
                        
                        EnsureLineInfo()
                        local lineNumber = GetLineNumber(lineStarts, matchStart)
                        
                        if not matchedPositions[lineNumber] then
                            matchedPositions[lineNumber] = true
                            AddMatch(matchingLines, lineNumber, lineNumber, lines[lineNumber])
                        end
                        
                        local nextNewline = source:find("\n", matchEnd, true)
                        if not nextNewline then break end
                        searchStart = nextNewline + 1
                    end
                end
            end

            if #matchingLines == 0 then continue end

            local scriptRef = GetScriptByDebugId(debugId)
            local scriptPath = scriptRef and scriptRef or "<ScriptProxy: " .. debugId .. ">"

            totalMatches += #matchingLines
            table.insert(results, {
                Script = scriptPath,
                MatchCount = #matchingLines,
                Matches = matchingLines
            })
        end

        return {
            count = #results,
            totalMatches = totalMatches,
            limited = #results >= limit,
            results = results
        }
    end)

    Bridge:BindToType("type-text-box", function(data)
        local path = data.path
        local text = data.string or data.text
        local enter = data.enter
        local useKeyPress = data.useKeyPress

        local textBox
        if typeof(path) == "string" then
            textBox = loadstring("return " .. path)()
        else
            textBox = path
        end
        
        assert(typeof(textBox) == "Instance", "Path did not resolve to a valid Instance.")
        assert(textBox:IsA("TextBox"), "Resolved Instance is not a TextBox.")

        textBox:CaptureFocus()
        task.wait(0.05)
        
        if useKeyPress then
            local success = pcall(function()
                for i = 1, #text do
                    VirtualInputManager:SendTextInput(text:sub(i, i), nil, game)
                    task.wait(0.01)
                end
            end)
            
            if not success and type(keypress) == "function" then
                for i = 1, #text do
                    local char = text:sub(i, i):upper()
                    local byte = char:byte()
                    if byte then
                        keypress(byte)
                        task.wait(0.01)
                        if type(keyrelease) == "function" then
                            keyrelease(byte)
                        end
                    end
                end
            end
        else
            textBox.Text = text
        end

        if enter then
            if useKeyPress then
                if type(keypress) == "function" then
                    keypress(0x0D)
                    task.wait(0.01)
                    if type(keyrelease) == "function" then
                        keyrelease(0x0D)
                    end
                else
                    pcall(function()
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                        task.wait(0.01)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                    end)
                end
            end
            textBox:ReleaseFocus(true)
        else
            textBox:ReleaseFocus(false)
        end

        return {
            status = "success",
            message = "Successfully typed into TextBox."
        }
    end)

    Bridge:BindToType("click-button", function(data)
        local path = data.path
        local action = data.Action or data.action

        local button
        if typeof(path) == "string" then
            button = loadstring("return " .. path)()
        else
            button = path
        end

        assert(typeof(button) == "Instance", "Path did not resolve to a valid Instance.")
        assert(button:IsA("GuiButton"), "Resolved Instance is not a GuiButton (e.g., TextButton or ImageButton).")
        assert(typeof(firesignal) == "function", "Your executor does not support 'firesignal', which is required for this command.")

        local Signals = {"Activated", "MouseButton1Down", "MouseButton2Down", "MouseButton1Click", "MouseButton2Click"}
        
        if action then
            assert(table.find(Signals, action), "Invalid action provided. Valid actions are: " .. table.concat(Signals, ", "))
            firesignal(button[action])
        else
            for _, signalName in pairs(Signals) do
                pcall(function() firesignal(button[signalName]) end)
            end
        end

        return {
            status = "success",
            message = "Successfully fired click signals on Button."
        }
    end)

    --// Utility Tools \\--

    Bridge:BindToType("fire-remote", function(data)
        setthreadidentity(8)
        local remote = nil
        for _, d in ReplicatedStorage:GetDescendants() do
            if d.Name == data.remote and (d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")) then
                remote = d
                break
            end
        end
        assert(remote, "Remote not found: " .. tostring(data.remote))

        local method = data.method or "FireServer"
        local argsStr = data.args or ""

        if argsStr ~= "" then
            local argsFn = loadstring("return " .. argsStr)
            local args = {argsFn()}
            if method == "InvokeServer" then
                return remote:InvokeServer(unpack(args))
            else
                remote:FireServer(unpack(args))
                return { status = "fired", remote = data.remote, method = method, argCount = #args }
            end
        else
            if method == "InvokeServer" then
                return remote:InvokeServer()
            else
                remote:FireServer()
                return { status = "fired", remote = data.remote, method = method }
            end
        end
    end)

    Bridge:BindToType("tp-to", function(data)
        local player = Players.LocalPlayer
        local char = player.Character
        assert(char and char:FindFirstChild("HumanoidRootPart"), "Character not loaded")
        local hrp = char.HumanoidRootPart

        if data.target then
            setthreadidentity(8)
            local target = loadstring("return " .. data.target)()
            assert(typeof(target) == "Instance", "Target is not an Instance")
            if target:IsA("BasePart") then
                hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 5, 0))
            elseif target:IsA("Model") then
                hrp.CFrame = target:GetPivot() + Vector3.new(0, 5, 0)
            else
                error("Target must be a BasePart or Model")
            end
        else
            hrp.CFrame = CFrame.new(data.x or 0, data.y or 0, data.z or 0)
        end

        return { status = "teleported", position = tostring(hrp.Position) }
    end)

    Bridge:BindToType("get-inventory", function(data)
        local player = Players.LocalPlayer
        local backpack = player:FindFirstChild("Backpack")
        local char = player.Character
        local items = {}

        if backpack then
            for _, item in backpack:GetChildren() do
                table.insert(items, { name = item.Name, class = item.ClassName })
            end
        end
        if char then
            for _, item in char:GetChildren() do
                if item:IsA("Tool") or item:IsA("BackpackItem") then
                    table.insert(items, { name = item.Name, class = item.ClassName, equipped = true })
                end
            end
        end

        return { count = #items, items = items }
    end)

    Bridge:BindToType("get-player-stats", function(data)
        local player = Players.LocalPlayer
        local stats = {}

        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            for _, stat in leaderstats:GetChildren() do
                pcall(function() stats[stat.Name] = stat.Value end)
            end
        end

        for _, folderName in {"Stats", "Data", "PlayerData", "PlayerStats", "Values"} do
            local folder = player:FindFirstChild(folderName)
            if folder then
                for _, stat in folder:GetChildren() do
                    pcall(function() stats[folderName .. "/" .. stat.Name] = stat.Value end)
                end
            end
        end

        local char = player.Character
        local health, maxHealth, walkSpeed = 0, 0, 16
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                health = hum.Health
                maxHealth = hum.MaxHealth
                walkSpeed = hum.WalkSpeed
            end
        end

        return {
            username = player.Name,
            userId = player.UserId,
            health = health,
            maxHealth = maxHealth,
            walkSpeed = walkSpeed,
            stats = stats,
        }
    end)

    Bridge:BindToType("get-remotes-map", function(data)
        local Spy = getgenv().AuroraSpy
        local remotes = {}

        for _, d in ReplicatedStorage:GetDescendants() do
            local ok, isRemote = pcall(function()
                return d:IsA("RemoteEvent") or d:IsA("RemoteFunction") or d:IsA("UnreliableRemoteEvent")
            end)
            if ok and isRemote then
                local name = d.Name
                local entry = {
                    name = name,
                    class = d.ClassName,
                    path = d:GetFullName(),
                    calls = Spy and Spy._stats[name] or 0,
                }

                if Spy and Spy._log then
                    for i = 1, Spy._maxLog do
                        local log = Spy._log[i]
                        if log and log.remote == name and log.args then
                            local sig = {}
                            for j, arg in log.args do
                                sig[j] = arg.type
                            end
                            entry.argTypes = sig
                            entry.method = log.method
                            entry.sampleArgs = log.args
                            break
                        end
                    end
                end

                table.insert(remotes, entry)
            end
        end

        table.sort(remotes, function(a, b) return a.calls > b.calls end)
        return { count = #remotes, remotes = remotes }
    end)

    Bridge:BindToType("auto-map", function(data)
        local Spy = getgenv().AuroraSpy
        assert(Spy, "Aurora Spy not loaded")

        local duration = math.min(data.duration or 30, 90)

        Spy:Clear()
        if not Spy._active then Spy:WatchAll() end

        task.wait(duration)

        local remotes = {}
        for name, count in Spy._stats do
            local entry = { name = name, calls = count, argTypes = {}, method = "", sampleArgs = {} }

            for i = 1, Spy._maxLog do
                local log = Spy._log[i]
                if log and log.remote == name and log.args then
                    local sig = {}
                    for j, arg in log.args do
                        sig[j] = arg.type
                    end
                    entry.argTypes = sig
                    entry.method = log.method
                    entry.sampleArgs = log.args
                    break
                end
            end

            for _, d in ReplicatedStorage:GetDescendants() do
                if d.Name == name then
                    entry.class = d.ClassName
                    entry.path = d:GetFullName()
                    break
                end
            end

            table.insert(remotes, entry)
        end

        table.sort(remotes, function(a, b) return a.calls > b.calls end)

        return {
            duration = duration,
            totalRemotes = #remotes,
            remotes = remotes,
        }
    end)

    Bridge:BindToType("patch", function(data)
        setthreadidentity(8)

        if data.code then
            local fn = loadstring(data.code)
            local result = fn()
            return { status = "patched", result = tostring(result) }
        end

        assert(data.target, "Provide target (global path) or code")
        local valueFn = loadstring("return " .. (data.value or "nil"))
        local newValue = valueFn()

        loadstring(data.target .. " = ...")(newValue)

        return { status = "patched", target = data.target, value = tostring(newValue) }
    end)

    Bridge:WaitForDisconnect()

    warn("[Aurora] Disconnected from MCP server. Reconnecting in 2s...")
    task.wait(2)
end
end)


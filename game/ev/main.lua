-- ========================================================================== --
--                      RZPRIVATE - EVADE (OBSIDIAN VERSION)                  --
--                            by iruz | version 3.0                           --
-- ========================================================================== --

-- ========================================================================== --
--                            SERVICES & MODULES                               --
-- ========================================================================== --

local RunService         = game:GetService("RunService")
local Players            = game:GetService("Players")
local player             = Players.LocalPlayer
local UserInputService   = game:GetService("UserInputService")
local TeleportService    = game:GetService("TeleportService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local VirtualUser        = game:GetService("VirtualUser")
local TweenService       = game:GetService("TweenService")
local GuiService         = game:GetService("GuiService")
local StarterGui         = game:GetService("StarterGui")
local Lighting           = game:GetService("Lighting")
local placeId            = game.PlaceId
local jobId              = game.JobId

-- ========================================================================== --
--                            LOAD OBSIDIAN LIBRARY                           --
-- ========================================================================== --

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

-- ========================================================================== --
--                         NOTIFICATION SYSTEM                                --
-- ========================================================================== --

local isScriptLoading = true

local function Success(title, message, duration)
    if isScriptLoading then return end
    Library:Notify({
        Title = title,
        Description = message,
        Time = duration or 2,
    })
end

local function Error(title, message, duration)
    if isScriptLoading then return end
    Library:Notify({
        Title = "❌ " .. title,
        Description = message,
        Time = duration or 3,
    })
end

local function Info(title, message, duration)
    if isScriptLoading then return end
    Library:Notify({
        Title = "ℹ️ " .. title,
        Description = message,
        Time = duration or 2,
    })
end

local function Warning(title, message, duration)
    if isScriptLoading then return end
    Library:Notify({
        Title = "⚠️ " .. title,
        Description = message,
        Time = duration or 2,
    })
end

-- ========================================================================== --
--                         AUTO SELF REVIVE MODULE                            --
-- ========================================================================== --

local AutoSelfReviveModule = (function()
    local enabled = false
    local method = "Spawnpoint"
    local connections = {}
    local lastSavedPosition = nil
    local hasRevived = false
    local isReviving = false

    local function cleanupConnections()
        for _, conn in pairs(connections) do
            if conn and conn.Disconnect then
                pcall(function() conn:Disconnect() end)
            end
        end
        connections = {}
    end

    local function handleDowned(character)
        local success, isDowned = pcall(function()
            return character:GetAttribute("Downed")
        end)
        
        if success and isDowned and not isReviving then
            isReviving = true

            if method == "Spawnpoint" then
                if not hasRevived then
                    hasRevived = true
                    local char = player.Character
                    if char then
                        local hum = char:WaitForChild("Humanoid", 5)
                        if hum then
                            pcall(function()
                                ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
                            end)
                            Success("Auto Self Revive", "Reviving at spawnpoint...", 2)
                        end
                    end

                    task.delay(10, function()
                        hasRevived = false
                    end)
                    task.delay(1, function()
                        isReviving = false
                    end)
                else
                    isReviving = false
                end
            elseif method == "Fake Revive" then
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    lastSavedPosition = hrp.Position
                end

                task.spawn(function()
                    pcall(function()
                        ReplicatedStorage:WaitForChild("Events"):WaitForChild("Player"):WaitForChild("ChangePlayerMode")
                            :FireServer(true)
                    end)

                    Success("Auto Self Revive", "Saving position and reviving...", 2)

                    local newCharacter
                    repeat
                        newCharacter = player.Character
                        task.wait()
                    until newCharacter and newCharacter:FindFirstChild("HumanoidRootPart") and newCharacter ~= character

                    if newCharacter then
                        local newHRP = newCharacter:FindFirstChild("HumanoidRootPart")
                        if lastSavedPosition and newHRP then
                            task.wait(0.1)
                            pcall(function()
                                newHRP.CFrame = CFrame.new(lastSavedPosition)
                            end)
                            Success("Auto Self Revive", "Teleported back to saved position!", 2)
                        end
                    end

                    isReviving = false
                end)
            end
        end
    end

    local function setupCharacter(character)
        if not character then return end
        task.wait(0.5)

        local downedConnection = character:GetAttributeChangedSignal("Downed"):Connect(function()
            handleDowned(character)
        end)

        table.insert(connections, downedConnection)
    end

    local function start()
        if enabled then return end
        enabled = true

        cleanupConnections()

        local character = player.Character
        if character then
            setupCharacter(character)
        end

        local charAddedConnection = player.CharacterAdded:Connect(function(newChar)
            setupCharacter(newChar)
        end)

        table.insert(connections, charAddedConnection)

        Success("Auto Self Revive", "Enabled with method: " .. method, 2)
    end

    local function stop()
        if not enabled then return end
        enabled = false

        cleanupConnections()
        hasRevived = false
        isReviving = false
        lastSavedPosition = nil

        Info("Auto Self Revive", "Disabled", 2)
    end

    return {
        Start = start,
        Stop = stop,
        SetMethod = function(newMethod)
            method = newMethod
            if enabled then
                Info("Auto Self Revive", "Method changed to: " .. newMethod, 2)
            end
        end,
        IsEnabled = function()
            return enabled
        end
    }
end)()

-- ========================================================================== --
--                         INSTANT REVIVE MODULE                              --
-- ========================================================================== --

local InstantReviveModule = (function()
    local enabled = false
    local reviveWhileEmoting = false
    local reviveDelay = 0.15
    local reviveRange = 10
    
    local handle = nil
    local stateConnection = nil
    local isCurrentlyEmoting = false
    
    local interactEvent = ReplicatedStorage:WaitForChild("Events")
        :WaitForChild("Character"):WaitForChild("Interact")
    
    -- Check if player is emoting
    local function updateEmoteStatus()
        if not player.Character then
            isCurrentlyEmoting = false
            return
        end
        local state = player.Character:GetAttribute("State")
        isCurrentlyEmoting = state and string.find(state, "Emoting")
    end
    
    -- Check if player is downed
    local function isPlayerDowned(pl)
        if not pl or not pl.Character then return false end
        local char = pl.Character
        
        -- Check Downed attribute
        if char:GetAttribute("Downed") then return true end
        
        -- Check humanoid health
        local hum = char:FindFirstChild("Humanoid")
        if hum and hum.Health <= 0 then return true end
        
        return false
    end
    
    -- Main revive loop
    local function reviveLoop()
        while enabled do
            -- Skip if emoting and reviveWhileEmoting is disabled
            if isCurrentlyEmoting and not reviveWhileEmoting then
                task.wait(0.3)
                continue
            end
            
            local myChar = player.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") then
                local myHRP = myChar.HumanoidRootPart
                
                -- Loop through all players
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                        if isPlayerDowned(pl) then
                            local dist = (myHRP.Position - pl.Character.HumanoidRootPart.Position).Magnitude
                            
                            -- Revive if in range
                            if dist <= reviveRange then
                                pcall(function()
                                    interactEvent:FireServer("Revive", true, pl.Name)
                                end)
                            end
                        end
                    end
                end
            end
            
            task.wait(reviveDelay)
        end
    end
    
    -- Start instant revive
    local function start()
        if handle then return end
        enabled = true
        
        updateEmoteStatus()
        
        -- Setup emote detection
        if player.Character then
            stateConnection = player.Character:GetAttributeChangedSignal("State"):Connect(updateEmoteStatus)
        end
        
        -- Handle character respawn
        player.CharacterAdded:Connect(function(char)
            if stateConnection then stateConnection:Disconnect() end
            stateConnection = char:GetAttributeChangedSignal("State"):Connect(updateEmoteStatus)
            updateEmoteStatus()
        end)
        
        -- Start revive loop
        handle = task.spawn(reviveLoop)
        
        Success("Instant Revive", "Activated (Delay: " .. reviveDelay .. "s)", 2)
    end
    
    -- Stop instant revive
    local function stop()
        enabled = false
        
        if handle then
            task.cancel(handle)
            handle = nil
        end
        
        if stateConnection then
            stateConnection:Disconnect()
            stateConnection = nil
        end
        
        isCurrentlyEmoting = false
        
        Info("Instant Revive", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        SetDelay = function(delay)
            reviveDelay = delay
            Success("Instant Revive", "Delay set to " .. delay .. "s", 1)
        end,
        SetReviveWhileEmoting = function(state)
            reviveWhileEmoting = state
        end,
        SetRange = function(range)
            reviveRange = range
            Success("Instant Revive", "Range set to " .. range .. " studs", 1)
        end
    }
end)()

-- ========================================================================== --
--                         AUTO WHISTLE MODULE                                --
-- ========================================================================== --

local AutoWhistleModule = (function()
    local enabled = false
    local whistleHandle = nil
    local whistleDelay = 1 -- detik
    
    local function startWhistle()
        if whistleHandle then return end
        
        whistleHandle = task.spawn(function()
            while enabled do
                pcall(function()
                    ReplicatedStorage.Events.Character.Whistle:FireServer()
                end)
                task.wait(whistleDelay)
            end
            whistleHandle = nil
        end)
    end
    
    local function stopWhistle()
        enabled = false
        if whistleHandle then
            task.cancel(whistleHandle)
            whistleHandle = nil
        end
    end
    
    local function start()
        if enabled then return end
        enabled = true
        startWhistle()
        Success("Auto Whistle", "Activated", 2)
    end
    
    local function stop()
        if not enabled then return end
        enabled = false
        stopWhistle()
        Info("Auto Whistle", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        SetDelay = function(delay) 
            whistleDelay = delay 
            Success("Auto Whistle", "Delay set to " .. delay .. "s", 1)
        end
    }
end)()

-- ========================================================================== --
--                         AUTO FARM MONEY MODULE                             --
-- ========================================================================== --

local AutoFarmMoneyModule = (function()
    local enabled = false
    local farmConnection = nil
    local reviveRange = 15
    local loopDelay = 0.25
    
    local interactEvent = ReplicatedStorage:WaitForChild("Events")
        :WaitForChild("Character"):WaitForChild("Interact")
    
    -- Check if player is downed
    local function isPlayerDowned(pl)
        if not pl or not pl.Character then return false end
        local char = pl.Character
        
        -- Check Downed attribute
        if char:GetAttribute("Downed") == true then
            return true
        end
        
        -- Check in Ragdolls folder
        local ragdollsFolder = workspace:FindFirstChild("Game") 
            and workspace.Game:FindFirstChild("Ragdolls")
        if ragdollsFolder and ragdollsFolder:FindFirstChild(pl.Name) then
            return true
        end
        
        return false
    end
    
    -- Get downed player's position (even if ragdoll)
    local function getDownedRootPart(pl)
        -- Try normal character first
        if pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
            return pl.Character.HumanoidRootPart
        end
        
        -- Try ragdoll folder
        local ragdollsFolder = workspace:FindFirstChild("Game") 
            and workspace.Game:FindFirstChild("Ragdolls")
        if ragdollsFolder then
            local ragdoll = ragdollsFolder:FindFirstChild(pl.Name)
            if ragdoll then
                return ragdoll:FindFirstChild("HumanoidRootPart") 
                    or ragdoll:FindFirstChild("Torso") 
                    or ragdoll:FindFirstChild("Head") 
                    or ragdoll:FindFirstChildWhichIsA("BasePart")
            end
        end
        return nil
    end
    
    -- Main farm loop
    local function farmLoop()
        while enabled do
            local character = player.Character
            local securityPart = workspace:FindFirstChild("SecurityPart")
            
            if not securityPart then
                Warning("Auto Farm Money", "SecurityPart not found in workspace!", 3)
                task.wait(5)
                continue
            end
            
            -- If we're downed, auto respawn
            if character and character:GetAttribute("Downed") then
                pcall(function()
                    ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
                end)
                
                -- Teleport to safe spot after respawn
                task.wait(1)
                local newChar = player.Character
                if newChar and newChar:FindFirstChild("HumanoidRootPart") then
                    newChar.HumanoidRootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
                end
                task.wait(1)
            
            -- If we're alive, revive others
            elseif character and character:FindFirstChild("HumanoidRootPart") then
                local myHRP = character.HumanoidRootPart
                local downedFound = false
                
                -- Find downed players
                for _, pl in ipairs(Players:GetPlayers()) do
                    if pl ~= player and isPlayerDowned(pl) then
                        local targetRoot = getDownedRootPart(pl)
                        if targetRoot then
                            downedFound = true
                            local dist = (myHRP.Position - targetRoot.Position).Magnitude
                            
                            -- Teleport to downed player if far
                            if dist > reviveRange then
                                local targetPos = targetRoot.Position
                                myHRP.CFrame = CFrame.new(targetPos.X, targetPos.Y - 5, targetPos.Z)
                                task.wait(0.1)
                            end
                            
                            -- Revive
                            pcall(function()
                                interactEvent:FireServer("Revive", true, pl.Name)
                            end)
                            task.wait(0.2)
                        end
                    end
                end
                
                -- If no downed players, stay at safe spot
                if not downedFound and not character:GetAttribute("Downed") then
                    myHRP.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
                end
            end
            
            task.wait(loopDelay)
        end
    end
    
    local function start()
        if farmConnection then return end
        enabled = true
        
        farmConnection = task.spawn(farmLoop)
        
        Success("Auto Farm Money", "Activated - Stay alive & revive for money", 3)
    end
    
    local function stop()
        enabled = false
        
        if farmConnection then
            task.cancel(farmConnection)
            farmConnection = nil
        end
        
        Info("Auto Farm Money", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end
    }
end)()

-- ========================================================================== --
--                         AUTO FARM TICKETS MODULE                           --
-- ========================================================================== --

local AutoFarmTicketsModule = (function()
    local enabled = false
    local farmConnection = nil
    local yOffset = 15
    local currentTicket = nil
    local ticketProcessedTime = 0
    
    local function farmLoop()
        while enabled do
            local character = player.Character
            if not character then 
                task.wait(1)
                continue 
            end
            
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if not humanoidRootPart then 
                task.wait(1)
                continue 
            end
            
            local securityPart = workspace:FindFirstChild("SecurityPart")
            if not securityPart then
                Warning("Auto Farm Tickets", "SecurityPart not found!", 3)
                task.wait(5)
                continue
            end
            
            -- Auto respawn if downed
            if character:GetAttribute("Downed") then
                pcall(function()
                    ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
                end)
                humanoidRootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
                task.wait(1)
                continue
            end
            
            -- Find tickets
            local tickets = workspace:FindFirstChild("Game") 
                and workspace.Game:FindFirstChild("Effects") 
                and workspace.Game.Effects:FindFirstChild("Tickets")
            
            if tickets then
                local activeTickets = tickets:GetChildren()
                
                if #activeTickets > 0 then
                    -- Select ticket
                    if not currentTicket or not currentTicket.Parent then
                        currentTicket = activeTickets[1]
                        ticketProcessedTime = tick()
                    end
                    
                    -- Farm ticket
                    if currentTicket and currentTicket.Parent then
                        local ticketPart = currentTicket:FindFirstChild("HumanoidRootPart") 
                            or (currentTicket:IsA("BasePart") and currentTicket)
                        
                        if ticketPart then
                            -- Hover above ticket
                            local targetPosition = ticketPart.Position + Vector3.new(0, yOffset, 0)
                            humanoidRootPart.CFrame = CFrame.new(targetPosition)
                            
                            -- Dive down to collect after delay
                            if tick() - ticketProcessedTime > 0.1 then
                                humanoidRootPart.CFrame = ticketPart.CFrame
                            end
                        else
                            currentTicket = nil
                        end
                    else
                        -- No ticket, go to safe spot
                        humanoidRootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
                        currentTicket = nil
                    end
                else
                    -- No tickets available
                    humanoidRootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
                    currentTicket = nil
                end
            else
                -- Tickets folder not found
                humanoidRootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
                currentTicket = nil
            end
            
            task.wait(0.05)
        end
    end
    
    local function start()
        if farmConnection then return end
        enabled = true
        currentTicket = nil
        
        farmConnection = task.spawn(farmLoop)
        
        Success("Auto Farm Tickets", "Activated - Collecting tickets automatically", 3)
    end
    
    local function stop()
        enabled = false
        currentTicket = nil
        
        if farmConnection then
            task.cancel(farmConnection)
            farmConnection = nil
        end
        
        -- Return to safe spot
        local character = player.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            local securityPart = workspace:FindFirstChild("SecurityPart")
            if humanoidRootPart and securityPart then
                humanoidRootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
            end
        end
        
        Info("Auto Farm Tickets", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end
    }
end)()

-- ========================================================================== --
--                         AFK FARM MODULE                                    --
-- ========================================================================== --

local AFKFarmModule = (function()
    local enabled = false
    local farmConnection = nil
    
    local function farmLoop()
        while enabled do
            local securityPart = workspace:FindFirstChild("SecurityPart")
            if not securityPart then 
                task.wait(1)
                continue 
            end
            
            local character = player.Character
            if not character then 
                task.wait(1)
                continue 
            end
            
            local rootPart = character:FindFirstChild("HumanoidRootPart")
            if not rootPart then 
                task.wait(1)
                continue 
            end
            
            -- Stay at safe spot if not downed
            if not character:GetAttribute("Downed") then
                rootPart.CFrame = securityPart.CFrame + Vector3.new(0, 3, 0)
            end
            
            task.wait(0.1)
        end
    end
    
    local function start()
        if farmConnection then return end
        enabled = true
        
        farmConnection = task.spawn(farmLoop)
        
        Success("AFK Farm", "Activated - Staying safe at SecurityPart", 2)
    end
    
    local function stop()
        enabled = false
        
        if farmConnection then
            task.cancel(farmConnection)
            farmConnection = nil
        end
        
        Info("AFK Farm", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end
    }
end)()

-- ========================================================================== --
--                         PLAYER ADJUSTMENTS MODULE                          --
-- ========================================================================== --

local PlayerAdjustmentsModule = (function()
    local currentSettings = {
        Speed = 1500,
        JumpCap = 1,
        AirStrafeAcceleration = 187
    }
    
    local applyMode = "Not Optimized" -- atau "Optimized"
    
    -- Required fields untuk deteksi movement tables
    local requiredFields = {
        "Friction", "AirStrafeAcceleration", "JumpHeight", "RunDeaccel",
        "JumpSpeedMultiplier", "JumpCap", "SprintCap", "WalkSpeedMultiplier",
        "BhopEnabled", "Speed", "AirAcceleration", "RunAccel", "SprintAcceleration"
    }
    
    -- Check apakah table punya semua field yang dibutuhkan
    local function hasAllFields(tbl)
        if type(tbl) ~= "table" then return false end
        
        for _, field in ipairs(requiredFields) do
            if rawget(tbl, field) == nil then return false end
        end
        
        return true
    end
    
    -- Cari semua movement config tables di game
    local function getConfigTables()
        local tables = {}
        
        for _, obj in ipairs(getgc(true)) do
            local success, result = pcall(function()
                if hasAllFields(obj) then 
                    return obj 
                end
            end)
            
            if success and result then
                table.insert(tables, result)
            end
        end
        
        return tables
    end
    
    -- Apply callback ke semua tables
    local function applyToTables(callback)
        local targets = getConfigTables()
        
        if #targets == 0 then
            Warning("Player Settings", "No config tables found!", 2)
            return
        end
        
        if applyMode == "Optimized" then
            -- Optimized: batch apply dengan delay
            task.spawn(function()
                for i, tableObj in ipairs(targets) do
                    if tableObj and typeof(tableObj) == "table" then
                        pcall(callback, tableObj)
                    end
                    
                    -- Delay setiap 3 tables
                    if i % 3 == 0 then
                        task.wait()
                    end
                end
            end)
        else
            -- Not Optimized: langsung apply semua
            for i, tableObj in ipairs(targets) do
                if tableObj and typeof(tableObj) == "table" then
                    pcall(callback, tableObj)
                end
            end
        end
    end
    
    -- Set speed
    local function setSpeed(speed)
        local val = tonumber(speed)
        if val and val >= 1450 and val <= 100000000 then
            currentSettings.Speed = val
            
            applyToTables(function(obj)
                obj.Speed = val
            end)
            
            Success("Player Speed", "Set to: " .. val, 1)
            return true
        else
            Error("Player Speed", "Value must be between 1450 and 100000000", 2)
            return false
        end
    end
    
    -- Set jump cap
    local function setJumpCap(cap)
        local val = tonumber(cap)
        if val and val >= 0.1 and val <= 5000000 then
            currentSettings.JumpCap = val
            
            applyToTables(function(obj)
                obj.JumpCap = val
            end)
            
            Success("Jump Cap", "Set to: " .. val, 1)
            return true
        else
            Error("Jump Cap", "Value must be between 0.1 and 5000000", 2)
            return false
        end
    end
    
    -- Set air strafe acceleration
    local function setStrafeAccel(accel)
        local val = tonumber(accel)
        if val and val >= 1 and val <= 1000000000 then
            currentSettings.AirStrafeAcceleration = val
            
            applyToTables(function(obj)
                obj.AirStrafeAcceleration = val
            end)
            
            Success("Strafe Accel", "Set to: " .. val, 1)
            return true
        else
            Error("Strafe Accel", "Value must be between 1 and 1000000000", 2)
            return false
        end
    end
    
    -- Set apply mode
    local function setApplyMode(mode)
        applyMode = mode
        Info("Apply Mode", "Changed to: " .. mode, 1)
    end
    
    return {
        SetSpeed = setSpeed,
        SetJumpCap = setJumpCap,
        SetStrafeAccel = setStrafeAccel,
        SetApplyMode = setApplyMode,
        GetCurrentSettings = function() return currentSettings end,
        GetApplyMode = function() return applyMode end
    }
end)()

-- ========================================================================== --
--                         JUMP POWER SYSTEM                                  --
-- ========================================================================== --

local JumpPowerModule = (function()
    local jumpPowerValue = 3.5
    local maxJumps = math.huge
    local currentJumpCount = 0
    local jumpHumanoid = nil
    local jumpRootPart = nil
    
    local stateConnection = nil
    local jumpConnection = nil
    local charConnection = nil
    
    -- Setup jump system untuk character
    local function setupCharacter(character)
        if not character then return end
        
        -- Cleanup old connections
        if stateConnection then stateConnection:Disconnect() stateConnection = nil end
        if jumpConnection then jumpConnection:Disconnect() jumpConnection = nil end
        
        task.wait(0.5)
        
        jumpHumanoid = character:FindFirstChild("Humanoid")
        jumpRootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not jumpHumanoid or not jumpRootPart then return end
        
        currentJumpCount = 0
        
        -- Reset jump count saat landing
        stateConnection = jumpHumanoid.StateChanged:Connect(function(oldState, newState)
            if newState == Enum.HumanoidStateType.Landed then
                currentJumpCount = 0
            end
        end)
        
        -- Handle jumping
        jumpConnection = jumpHumanoid.Jumping:Connect(function(isJumping)
            if isJumping and currentJumpCount < maxJumps then
                currentJumpCount = currentJumpCount + 1
                jumpHumanoid.JumpHeight = jumpPowerValue
                
                -- Apply impulse for multi-jump
                if currentJumpCount > 1 and jumpRootPart then
                    jumpRootPart:ApplyImpulse(Vector3.new(0, jumpPowerValue * jumpRootPart.Mass, 0))
                end
            end
        end)
    end
    
    -- Initialize
    local function initialize()
        -- Setup current character
        if player.Character then
            task.spawn(function()
                setupCharacter(player.Character)
            end)
        end
        
        -- Setup for future characters
        charConnection = player.CharacterAdded:Connect(function(newChar)
            setupCharacter(newChar)
        end)
    end
    
    -- Set jump power value
    local function setJumpPower(value)
        local val = tonumber(value)
        if val and val > 0 and val <= 1000 then
            jumpPowerValue = val
            
            if jumpHumanoid then
                jumpHumanoid.JumpHeight = val
            end
            
            Success("Jump Power", "Set to: " .. val, 1)
            return true
        else
            Error("Jump Power", "Value must be between 0.1 and 1000", 2)
            return false
        end
    end
    
    -- Cleanup
    local function cleanup()
        if stateConnection then stateConnection:Disconnect() end
        if jumpConnection then jumpConnection:Disconnect() end
        if charConnection then charConnection:Disconnect() end
    end
    
    -- Auto-initialize
    initialize()
    
    return {
        SetJumpPower = setJumpPower,
        GetJumpPower = function() return jumpPowerValue end,
        Cleanup = cleanup
    }
end)()

-- ========================================================================== --
--                         FOV ADJUSTMENT MODULE                              --
-- ========================================================================== --

local FOVModule = (function()
    local changeSettingRemote = ReplicatedStorage:WaitForChild("Events")
        :WaitForChild("Data"):WaitForChild("ChangeSetting")
    local updatedEvent = ReplicatedStorage:WaitForChild("Modules")
        :WaitForChild("Client"):WaitForChild("Settings"):WaitForChild("Updated")
    
    local function setFOV(fov)
        local num = tonumber(fov)
        if num and num >= 1 and num <= 1000 then
            pcall(function()
                changeSettingRemote:InvokeServer(2, num)
                updatedEvent:Fire(2, num)
            end)
            
            Success("FOV", "Set to: " .. num, 1)
            return true
        else
            Error("FOV", "Value must be between 1 and 1000", 2)
            return false
        end
    end
    
    return {
        SetFOV = setFOV
    }
end)()

-- ========================================================================== --
--                         TELEPORT MODULE (EXTERNAL)                          --
-- ========================================================================== --

local TeleportModule = (function()
    local TELEPORT_MODULE_URL = "https://raw.githubusercontent.com/dedgbom-dotcom/hi/refs/heads/main/game/ev/modules/TeleportModule.lua"
    
    local moduleData = nil
    local loadError = nil
    local lastLoadTime = nil
    local currentMap = "Unknown"
    local mapCheckConnection = nil
    local isStartup = true
    
    local function detectCurrentMap()
        local gameFolder = workspace:FindFirstChild("Game")
        if gameFolder then
            local mapFolder = gameFolder:FindFirstChild("Map")
            if mapFolder then
                local mapName = mapFolder:GetAttribute("MapName")
                if mapName and mapName ~= "" then
                    return mapName
                end
            end
        end
        return "Unknown"
    end
    
    local function handleMapChange(newMap)
        if isStartup then return end
        
        if newMap == "Unknown" then
            Warning("Map Detection", "Could not detect current map!", 3)
            return
        end
        
        if not moduleData then
            return
        end
        
        if moduleData and moduleData.HasMapData and moduleData.HasMapData(newMap) then
            local mapCount = moduleData.GetMapCount and moduleData.GetMapCount() or 0
            Success("Map Detected", newMap .. " (" .. mapCount .. " maps available)", 3)
        else
            if moduleData then
                Warning("Map Not Found", newMap .. " - Please refresh database", 4)
            end
        end
    end

    local function startMapMonitoring()
        if mapCheckConnection then
            mapCheckConnection:Disconnect()
        end
        
        mapCheckConnection = RunService.Heartbeat:Connect(function()
            local newMap = detectCurrentMap()
            if newMap ~= currentMap then
                currentMap = newMap
                handleMapChange(newMap)
            end
        end)
    end
    
    local function stopMapMonitoring()
        if mapCheckConnection then
            mapCheckConnection:Disconnect()
            mapCheckConnection = nil
        end
    end
    
    local function loadFromGitHub()
        loadError = nil
        local success, result = pcall(function()
            print("📡 Loading Teleport Module from GitHub...")
            local script = game:HttpGet(TELEPORT_MODULE_URL)
            return loadstring(script)()
        end)
        
        if success and result then
            moduleData = result
            lastLoadTime = os.time()
            
            currentMap = detectCurrentMap()
            handleMapChange(currentMap)
            
            print("✅ Teleport Module loaded! Maps: " .. (result.GetMapCount and result.GetMapCount() or "?"))
            return true
        else
            loadError = tostring(result)
            warn("❌ Failed to load Teleport Module:", loadError)
            Error("Teleport Module", "Failed to load: " .. loadError, 5)
            return false
        end
    end
    
    loadFromGitHub()
    startMapMonitoring()
    
    task.delay(3, function()
        isStartup = false
    end)

    game:GetService("Players").PlayerRemoving:Connect(function(leavingPlayer)
        if leavingPlayer == player then
            stopMapMonitoring()
        end
    end)
    
    local function validateCharacter()
        local char = player.Character
        if not char then
            Error("Teleport", "Character not found!", 2)
            return nil, nil
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Error("Teleport", "HumanoidRootPart not found!", 2)
            return nil, nil
        end

        return char, hrp
    end

    local function safeTeleport(hrp, targetPosition, filterInstances)
        filterInstances = filterInstances or {}
        local teleportPos = targetPosition + Vector3.new(0, 5, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = filterInstances
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local ray = workspace:Raycast(teleportPos, Vector3.new(0, -10, 0), raycastParams)
        if ray then
            teleportPos = ray.Position + Vector3.new(0, 3, 0)
        end

        hrp.CFrame = CFrame.new(teleportPos)
        return true
    end

    local function getCurrentMap()
        return currentMap
    end

    local function placeTeleporter(cframe)
        if not cframe then
            Error("Teleport", "Invalid teleporter position!", 2)
            return false
        end

        task.spawn(function()
            pcall(function()
                local args = { [1] = 0, [2] = 16 }
                ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("ToolAction"):FireServer(unpack(args))
            end)

            task.wait(1)

            pcall(function()
                local args2 = { [1] = 1, [2] = { [1] = "Teleporter", [2] = cframe } }
                ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("ToolAction"):FireServer(unpack(args2))
            end)

            task.wait(1)

            pcall(function()
                local args3 = { [1] = 0, [2] = 15 }
                ReplicatedStorage:WaitForChild("Events"):WaitForChild("Character"):WaitForChild("ToolAction"):FireServer(unpack(args3))
            end)

            Success("Teleporter Placed", "Teleporter successfully placed!", 2)
        end)

        return true
    end

    return {
        IsLoaded = function() return moduleData ~= nil end,
        GetError = function() return loadError end,
        GetLastLoad = function() return lastLoadTime end,
        GetCurrentMap = getCurrentMap,
        
        Refresh = function()
            stopMapMonitoring()
            local success = loadFromGitHub()
            startMapMonitoring()
            if success then
                Success("Teleport Module", "Refreshed successfully! Maps: " .. (moduleData.GetMapCount and moduleData.GetMapCount() or "?"), 3)
            else
                Error("Teleport Module", "Refresh failed: " .. (loadError or "Unknown error"), 5)
            end
            return success
        end,
        
        HasMapData = function(mapName)
            return moduleData and moduleData.HasMapData and moduleData.HasMapData(mapName) or false
        end,
        GetMapSpot = function(mapName, spotType)
            return moduleData and moduleData.GetMapSpot and moduleData.GetMapSpot(mapName, spotType) or nil
        end,
        GetAllMapNames = function()
            return moduleData and moduleData.GetAllMapNames and moduleData.GetAllMapNames() or {}
        end,
        GetMapCount = function()
            return moduleData and moduleData.GetMapCount and moduleData.GetMapCount() or 0
        end,
        GetLastUpdate = function()
            return moduleData and moduleData.GetLastUpdate and moduleData.GetLastUpdate() or "Unknown"
        end,
        
        TeleportPlayer = function(spotType)
            if not moduleData then
                Error("Teleport", "Module not loaded! Click Refresh first.", 3)
                return false
            end
            
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end
            
            local mapName = currentMap
            if mapName == "Unknown" then
                Error("Teleport", "Could not detect map name!", 2)
                return false
            end

            if not moduleData.HasMapData(mapName) then
                Error("Teleport", "Map '" .. mapName .. "' not in database! Click Refresh to update.", 4)
                return false
            end

            local cframe = moduleData.GetMapSpot(mapName, spotType)
            if not cframe then
                Error("Teleport", "No " .. spotType .. " spot found for " .. mapName, 3)
                return false
            end

            Info("Teleporting", "Teleporting to " .. spotType .. " for " .. mapName .. "...", 2)
            return safeTeleport(hrp, cframe.Position, { char })
        end,
        
        PlaceTeleporter = function(spotType)
            if not moduleData then
                Error("Teleport", "Module not loaded! Click Refresh first.", 3)
                return false
            end
            
            local mapName = currentMap
            if mapName == "Unknown" then
                Error("Teleport", "Could not detect map name!", 2)
                return false
            end

            if not moduleData.HasMapData(mapName) then
                Error("Teleport", "Map '" .. mapName .. "' not in database! Click Refresh to update.", 4)
                return false
            end

            local cframe = moduleData.GetMapSpot(mapName, spotType)
            if not cframe then
                Error("Teleport", "No " .. spotType .. " spot found for " .. mapName, 3)
                return false
            end

            Info("Placing Teleporter", "Placing " .. spotType .. " teleporter for " .. mapName .. "...", 2)
            return placeTeleporter(cframe)
        end
    }
end)()

-- ========================================================================== --
--                         TELEPORT FEATURES MODULE                           --
-- ========================================================================== --

local TeleportFeaturesModule = (function()
    local function validateCharacter()
        local success, char = pcall(function()
            return player.Character
        end)
        
        if not success or not char then
            Error("Teleport", "Character not found!", 2)
            return nil, nil
        end

        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then
            Error("Teleport", "HumanoidRootPart not found!", 2)
            return nil, nil
        end

        return char, hrp
    end

    local function safeTeleport(hrp, targetPosition, filterInstances)
        filterInstances = filterInstances or {}
        local teleportPos = targetPosition + Vector3.new(0, 5, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = filterInstances
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

        local raySuccess, ray = pcall(function()
            return workspace:Raycast(teleportPos, Vector3.new(0, -10, 0), raycastParams)
        end)
        
        if raySuccess and ray then
            teleportPos = ray.Position + Vector3.new(0, 3, 0)
        end

        local setSuccess, setErr = pcall(function()
            hrp.CFrame = CFrame.new(teleportPos)
        end)
        
        return setSuccess
    end

    local function findNearestTicketInternal()
        local success, gameFolder = pcall(function()
            return workspace:FindFirstChild("Game")
        end)
        
        if not success or not gameFolder then return nil end

        local effects = gameFolder:FindFirstChild("Effects")
        if not effects then return nil end

        local tickets = effects:FindFirstChild("Tickets")
        if not tickets then return nil end

        local char = player.Character
        if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end

        local hrp = char.HumanoidRootPart
        local nearestTicket = nil
        local nearestDistance = math.huge

        for _, ticket in pairs(tickets:GetChildren()) do
            if ticket:IsA("BasePart") or ticket:IsA("Model") then
                local ticketPart = ticket:IsA("Model") and ticket:FindFirstChild("HumanoidRootPart") or ticket
                if ticketPart and ticketPart:IsA("BasePart") then
                    local distSuccess, dist = pcall(function()
                        return (hrp.Position - ticketPart.Position).Magnitude
                    end)
                    if distSuccess and dist and dist < nearestDistance then
                        nearestDistance = dist
                        nearestTicket = ticketPart
                    end
                end
            end
        end

        return nearestTicket
    end

    local function isPlayerDowned(pl)
        local success, result = pcall(function()
            if not pl or not pl.Character then return false end
            local char = pl.Character
            if char:GetAttribute("Downed") then return true end
            local hum = char:FindFirstChild("Humanoid")
            if hum and hum.Health <= 0 then return true end
            return false
        end)
        return success and result or false
    end

    local function findNearestDownedPlayer()
        local char, hrp = validateCharacter()
        if not char or not hrp then return nil end

        local nearestPlayer = nil
        local nearestDistance = math.huge

        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                if isPlayerDowned(pl) then
                    local distSuccess, dist = pcall(function()
                        return (hrp.Position - pl.Character.HumanoidRootPart.Position).Magnitude
                    end)
                    if distSuccess and dist and dist < nearestDistance then
                        nearestDistance = dist
                        nearestPlayer = pl
                    end
                end
            end
        end

        return nearestPlayer, nearestDistance
    end

    local function getPlayerList()
        local playerNames = {}
        for _, pl in pairs(Players:GetPlayers()) do
            if pl ~= player then
                table.insert(playerNames, pl.Name)
            end
        end
        table.sort(playerNames)
        return #playerNames > 0 and playerNames or { "No players available" }
    end

    return {
        GetPlayerList = getPlayerList,
        TeleportToPlayer = function(playerName)
            if not playerName or playerName == "No players available" then
                Error("Teleport", "No player selected!", 2)
                return false
            end

            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local targetPlayer = Players:FindFirstChild(playerName)
            if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                Error("Teleport", playerName .. " not found or no character!", 2)
                return false
            end

            local targetHRP = targetPlayer.Character.HumanoidRootPart
            safeTeleport(hrp, targetHRP.Position, { char, targetPlayer.Character })
            Success("Teleport", "Teleported to " .. playerName, 2)
            return true
        end,
        TeleportToRandomPlayer = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local players = {}
            for _, pl in pairs(Players:GetPlayers()) do
                if pl ~= player and pl.Character and pl.Character:FindFirstChild("HumanoidRootPart") then
                    table.insert(players, pl)
                end
            end

            if #players == 0 then
                Error("Teleport", "No other players found!", 2)
                return false
            end

            local randomPlayer = players[math.random(1, #players)]
            local targetHRP = randomPlayer.Character.HumanoidRootPart
            safeTeleport(hrp, targetHRP.Position, { char, randomPlayer.Character })
            Success("Teleport", "Teleported to " .. randomPlayer.Name, 2)
            return true
        end,
        TeleportToNearestDowned = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local nearestPlayer, distance = findNearestDownedPlayer()
            if not nearestPlayer then
                Error("Teleport", "No downed players found!", 2)
                return false
            end

            local targetHRP = nearestPlayer.Character.HumanoidRootPart
            safeTeleport(hrp, targetHRP.Position, { char, nearestPlayer.Character })
            Success("Teleport", "Teleported to " .. nearestPlayer.Name .. " (" .. math.floor(distance) .. " studs)", 2)
            return true
        end,
        TeleportToRandomObjective = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local objectives = {}
            local gameFolder = workspace:FindFirstChild("Game")
            if not gameFolder then
                Error("Teleport", "Game folder not found!", 2)
                return false
            end

            local mapFolder = gameFolder:FindFirstChild("Map")
            if not mapFolder then
                Error("Teleport", "Map folder not found!", 2)
                return false
            end

            local partsFolder = mapFolder:FindFirstChild("Parts")
            if not partsFolder then
                Error("Teleport", "Parts folder not found!", 2)
                return false
            end

            local objectivesFolder = partsFolder:FindFirstChild("Objectives")
            if not objectivesFolder then
                Error("Teleport", "Objectives folder not found!", 2)
                return false
            end

            for _, obj in pairs(objectivesFolder:GetChildren()) do
                if obj:IsA("Model") then
                    local primaryPart = obj.PrimaryPart
                    if not primaryPart then
                        for _, part in pairs(obj:GetChildren()) do
                            if part:IsA("BasePart") then
                                primaryPart = part
                                break
                            end
                        end
                    end

                    if primaryPart then
                        table.insert(objectives, {
                            Name = obj.Name,
                            Part = primaryPart
                        })
                    end
                end
            end

            if #objectives == 0 then
                Error("Teleport", "No objectives found!", 2)
                return false
            end

            local selectedObjective = objectives[math.random(1, #objectives)]
            safeTeleport(hrp, selectedObjective.Part.Position, { char })
            Success("Teleport", "Teleported to " .. selectedObjective.Name, 2)
            return true
        end,
        TeleportToNearestTicket = function()
            local char, hrp = validateCharacter()
            if not char or not hrp then return false end

            local ticket = findNearestTicketInternal()
            if not ticket then
                Error("Teleport", "No tickets found!", 2)
                return false
            end

            safeTeleport(hrp, ticket.Position, { char })
            Success("Teleport", "Teleported to nearest ticket!", 2)
            return true
        end
    }
end)()

-- ========================================================================== --
--                         SERVER UTILITIES MODULE                            --
-- ========================================================================== --

local ServerUtils = (function()
    local function getServerLink()
        return string.format("https://www.roblox.com/games/start?placeId=%d&jobId=%s", placeId, jobId)
    end

    local function joinServerByPlaceId(targetPlaceId, modeName)
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                targetPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Join Failed", "Could not fetch " .. modeName .. " servers!", 3)
            return
        end

        local availableServers = {}
        for _, server in ipairs(servers.data) do
            if server.playing < server.maxPlayers then
                table.insert(availableServers, server)
            end
        end

        if #availableServers == 0 then
            Error("Join Failed", "No available " .. modeName .. " servers found!", 3)
            return
        end

        table.sort(availableServers, function(a, b) return a.playing > b.playing end)
        local targetServer = availableServers[1]

        Library:Notify({
            Title = "Joining " .. modeName,
            Description = "Teleporting to server with " ..
                targetServer.playing .. "/" .. targetServer.maxPlayers .. " players",
            Time = 3
        })

        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(targetPlaceId, targetServer.id, player)
        end)

        if not teleportSuccess then
            Error("Join Failed", "Teleport error: " .. tostring(teleportErr), 3)
        end
    end

    local function serverHop(minPlayers)
        minPlayers = minPlayers or 5
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Server Hop", "Failed to fetch servers!", 3)
            return false
        end

        local filteredServers = {}
        for _, server in ipairs(servers.data) do
            if server.playing >= minPlayers and server.playing < server.maxPlayers then
                table.insert(filteredServers, server)
            end
        end

        if #filteredServers == 0 then
            Info("Server Hop", "No servers with " .. minPlayers .. "+ players", 3)
            return false
        end

        local randomServer = filteredServers[math.random(1, #filteredServers)]
        
        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, randomServer.id, player)
        end)

        if not teleportSuccess then
            Error("Server Hop", "Teleport failed: " .. tostring(teleportErr), 3)
            return false
        end

        return true
    end

    local function hopToSmallestServer()
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                placeId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Server Hop", "Failed to fetch servers!", 3)
            return false
        end

        table.sort(servers.data, function(a, b) return a.playing < b.playing end)
        if not servers.data[1] then
            Error("Server Hop", "No servers found!", 3)
            return false
        end

        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(placeId, servers.data[1].id, player)
        end)

        if not teleportSuccess then
            Error("Server Hop", "Teleport failed: " .. tostring(teleportErr), 3)
            return false
        end

        return true
    end

    local function joinLowestServer(targetPlaceId, modeName)
        local success, servers = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" ..
                targetPlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)

        if not success or not servers or not servers.data then
            Error("Join Failed", "Could not fetch " .. modeName .. " servers!", 3)
            return
        end

        local availableServers = {}
        for _, server in ipairs(servers.data) do
            if server.playing < server.maxPlayers then
                table.insert(availableServers, server)
            end
        end

        if #availableServers == 0 then
            Error("Join Failed", "No available " .. modeName .. " servers found!", 3)
            return
        end

        table.sort(availableServers, function(a, b) return a.playing < b.playing end)
        local targetServer = availableServers[1]

        Library:Notify({
            Title = "Joining " .. modeName,
            Description = "Teleporting to server with " ..
                targetServer.playing .. "/" .. targetServer.maxPlayers .. " players",
            Time = 3
        })

        local teleportSuccess, teleportErr = pcall(function()
            TeleportService:TeleportToPlaceInstance(targetPlaceId, targetServer.id, player)
        end)

        if not teleportSuccess then
            Error("Join Failed", "Teleport error: " .. tostring(teleportErr), 3)
        end
    end

    return {
        GetServerLink = getServerLink,
        JoinServerByPlaceId = joinServerByPlaceId,
        JoinLowestServer = joinLowestServer,
        ServerHop = serverHop,
        HopToSmallestServer = hopToSmallestServer
    }
end)()

-- ========================================================================== --
--                         AUTO PLACE TELEPORTER SYSTEM                       --
-- ========================================================================== --

local autoPlaceTeleporterEnabled = false
local autoPlaceTeleporterType = "Far"
local gameStats = workspace:WaitForChild("Game"):WaitForChild("Stats")

gameStats:GetAttributeChangedSignal("RoundStarted"):Connect(function()
    if not autoPlaceTeleporterEnabled then return end
    local roundStarted = gameStats:GetAttribute("RoundStarted")
    local roundsCompleted = gameStats:GetAttribute("RoundsCompleted") or 0
    if not roundStarted and roundsCompleted < 3 then
        task.spawn(function()
            task.wait(3)
            local character = player.Character or player.CharacterAdded:Wait()
            character:WaitForChild("HumanoidRootPart")
            task.wait(1)
            TeleportModule.PlaceTeleporter(autoPlaceTeleporterType)
            Info("Auto Place", "Round " .. roundsCompleted .. " done", 2)
        end)
    end
end)

-- ========================================================================== --
--                         NEW FEATURES MODULES                               --
-- ========================================================================== --

-- NOCLIP MODULE
local NoclipModule = (function()
    local enabled = false
    local connection = nil
    
    local function toggleNoclip(state)
        enabled = state
        
        if enabled then
            if connection then
                pcall(function() connection:Disconnect() end)
            end
            
            connection = RunService.Stepped:Connect(function()
                local character = player.Character
                if character then
                    for _, part in pairs(character:GetDescendants()) do
                        if part:IsA("BasePart") and part.CanCollide then
                            pcall(function() part.CanCollide = false end)
                        end
                    end
                end
            end)
        else
            if connection then
                pcall(function() connection:Disconnect() end)
                connection = nil
            end
            
            local character = player.Character
            if character then
                for _, part in pairs(character:GetDescendants()) do
                    if part:IsA("BasePart") then
                        pcall(function() part.CanCollide = true end)
                    end
                end
            end
        end
    end
    
    return {
        Start = function() toggleNoclip(true) end,
        Stop = function() toggleNoclip(false) end,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(0.5)
                toggleNoclip(false)
                task.wait(0.1)
                toggleNoclip(true)
            end
        end
    }
end)()

-- BUG EMOTE MODULE
local BugEmoteModule = (function()
    local enabled = false
    local connection = nil
    
    local function updateSit()
        if not enabled then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        
        if not humanoid then
            local gamePlayers = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players")
            if gamePlayers then
                local playerModel = gamePlayers:FindFirstChild(player.Name)
                if playerModel then
                    humanoid = playerModel:FindFirstChild("Humanoid")
                end
            end
        end
        
        if humanoid then
            pcall(function() humanoid.Sit = true end)
        end
    end
    
    local function start()
        if enabled then return end
        enabled = true
        
        if connection then
            pcall(function() connection:Disconnect() end)
        end
        
        connection = RunService.Heartbeat:Connect(updateSit)
        updateSit()
        Success("Bug Emote", "Force sit enabled", 2)
    end
    
    local function stop()
        if not enabled then return end
        enabled = false
        
        if connection then
            pcall(function() connection:Disconnect() end)
            connection = nil
        end
        
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if not humanoid then
                local gamePlayers = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players")
                if gamePlayers then
                    local playerModel = gamePlayers:FindFirstChild(player.Name)
                    if playerModel then
                        humanoid = playerModel:FindFirstChild("Humanoid")
                    end
                end
            end
            if humanoid then
                pcall(function() humanoid.Sit = false end)
            end
        end
        
        Info("Bug Emote", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(1)
                updateSit()
            end
        end
    }
end)()

-- REMOVE BARRIERS MODULE
local RemoveBarriersModule = (function()
    local enabled = false
    
    local function toggleBarriers(state)
        local success, invisParts = pcall(function()
            return workspace:FindFirstChild("Game") and 
                   workspace.Game:FindFirstChild("Map") and 
                   workspace.Game.Map:FindFirstChild("InvisParts")
        end)
        
        if not success or not invisParts then
            return
        end
        
        local objectsChanged = 0
        
        for _, obj in ipairs(invisParts:GetDescendants()) do
            if obj:IsA("BasePart") then
                pcall(function()
                    obj.CanCollide = not state
                    obj.CanQuery = not state
                end)
                objectsChanged = objectsChanged + 1
            end
        end
        
        if state then
            Success("Remove Barriers", "Barriers removed for " .. objectsChanged .. " objects", 2)
        else
            Info("Remove Barriers", "Barriers restored for " .. objectsChanged .. " objects", 2)
        end
    end
    
    return {
        Start = function()
            enabled = true
            toggleBarriers(true)
        end,
        Stop = function()
            enabled = false
            toggleBarriers(false)
        end,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(1)
                toggleBarriers(true)
            end
        end
    }
end)()

-- BARRIERS VISIBLE MODULE
local BarriersVisibleModule = (function()
    local enabled = false
    local descendantConnection = nil
    local barrierColor = Color3.fromRGB(255, 0, 0)
    local barrierTransparency = 0
    
    local function setTransparency(transparent)
        local success, invisParts = pcall(function()
            return workspace:FindFirstChild("Game") and 
                   workspace.Game:FindFirstChild("Map") and 
                   workspace.Game.Map:FindFirstChild("InvisParts")
        end)
        
        if not success or not invisParts then
            return 0
        end
        
        local changed = 0
        
        if transparent then
            for _, obj in ipairs(invisParts:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") then
                        obj.Transparency = barrierTransparency
                        obj.Color = barrierColor
                        obj.Material = Enum.Material.Neon
                        changed = changed + 1
                    elseif obj:IsA("Decal") then
                        obj.Transparency = barrierTransparency
                        changed = changed + 1
                    end
                end)
            end
            Success("Barriers Visible", "Made " .. changed .. " barriers visible (" .. math.floor(barrierTransparency * 100) .. "% transparency)", 2)
        else
            for _, obj in ipairs(invisParts:GetDescendants()) do
                pcall(function()
                    if obj:IsA("BasePart") or obj:IsA("Decal") then
                        obj.Transparency = 1
                        if obj:IsA("BasePart") then
                            obj.Color = Color3.fromRGB(255, 255, 255)
                            obj.Material = Enum.Material.Plastic
                        end
                        changed = changed + 1
                    end
                end)
            end
            Info("Barriers Visible", "Made " .. changed .. " barriers invisible", 2)
        end
        
        return changed
    end
    
    local function setupDescendantListener()
        if descendantConnection then
            pcall(function() descendantConnection:Disconnect() end)
        end
        
        local success, invisParts = pcall(function()
            return workspace:FindFirstChild("Game") and 
                   workspace.Game:FindFirstChild("Map") and 
                   workspace.Game.Map:FindFirstChild("InvisParts")
        end)
        
        if success and invisParts and enabled then
            descendantConnection = invisParts.DescendantAdded:Connect(function(obj)
                if enabled then
                    task.wait(0.05)
                    pcall(function()
                        if obj:IsA("BasePart") then
                            obj.Transparency = barrierTransparency
                            obj.Color = barrierColor
                            obj.Material = Enum.Material.Neon
                        elseif obj:IsA("Decal") then
                            obj.Transparency = barrierTransparency
                        end
                    end)
                end
            end)
        end
    end
    
    local function setColor(color)
        barrierColor = color
        if enabled then
            setTransparency(true)
        end
    end
    
    local function setTransparencyLevel(level)
        local transparencyMap = {
            [1] = 0,     [2] = 0.2,   [3] = 0.4,   [4] = 0.5,   [5] = 0.6,
            [6] = 0.7,   [7] = 0.8,   [8] = 0.85,  [9] = 0.9,   [10] = 0.95,
        }
        
        barrierTransparency = transparencyMap[level] or 0
        if enabled then
            setTransparency(true)
        end
        return barrierTransparency
    end
    
    return {
        Start = function()
            enabled = true
            setTransparency(true)
            setupDescendantListener()
        end,
        Stop = function()
            enabled = false
            setTransparency(false)
            if descendantConnection then
                pcall(function() descendantConnection:Disconnect() end)
                descendantConnection = nil
            end
        end,
        SetColor = setColor,
        SetTransparencyLevel = setTransparencyLevel,
        IsEnabled = function() return enabled end,
        OnCharacterAdded = function()
            if enabled then
                task.wait(1)
                setTransparency(true)
            end
        end
    }
end)()

-- GRAPPLEHOOK MODULE
local GrapplehookModule = (function()
    local function enhanceGrappleHook()
        local success, result = pcall(function()
            local GrappleHook = require(ReplicatedStorage.Tools["GrappleHook"])
            
            if not GrappleHook then
                error("GrappleHook module not found")
            end
            
            local grappleTask = GrappleHook.Tasks[2]
            if not grappleTask then
                error("GrappleTask not found")
            end
            
            local shootMethod = grappleTask.Functions[1].Activations[1].Methods[1]
            if not shootMethod then
                error("Shoot method not found")
            end

            shootMethod.Info.Speed = 10000
            shootMethod.Info.Lifetime = 10.0
            shootMethod.Info.Gravity = Vector3.new(0, 0, 0)
            shootMethod.Info.SpreadIncrease = 0
            shootMethod.Info.Cooldown = 0.2

            grappleTask.MethodReferences.Projectile.Info.SpreadInfo.MaxSpread = 0
            grappleTask.MethodReferences.Projectile.Info.SpreadInfo.MinSpread = 0
            grappleTask.MethodReferences.Projectile.Info.SpreadInfo.ReductionRate = 100

            local checkMethod = grappleTask.AutomaticFunctions[1].Methods[1]
            if checkMethod then
                checkMethod.Info.Cooldown = 0.2
                checkMethod.CooldownInfo.TestCooldown = 0.2
            end

            grappleTask.ResourceInfo.Cap = 200
            grappleTask.ResourceInfo.Reserve = 200

            return true
        end)
        
        if success then
            Success("Grapplehook", "Enhanced successfully!", 2)
            return true
        else
            Error("Grapplehook", "Failed to enhance: " .. tostring(result), 3)
            warn("Grapplehook error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceGrappleHook()
        end
    }
end)()

-- BREACHER MODULE
local BreacherModule = (function()
    local function enhanceBreacher()
        local success, result = pcall(function()
            local Breacher = require(ReplicatedStorage.Tools.Breacher)
            
            if not Breacher then
                error("Breacher module not found")
            end

            local portalTask
            for i, task in ipairs(Breacher.Tasks) do
                if task.ResourceInfo and task.ResourceInfo.Type == "Clip" then
                    portalTask = task
                    break
                end
            end

            if not portalTask then
                portalTask = Breacher.Tasks[2]
            end

            portalTask.ResourceInfo.Cap = 400

            local blueShoot = portalTask.Functions[1].Activations[1].Methods[1]
            local yellowShoot = portalTask.Functions[2].Activations[1].Methods[1]

            blueShoot.Info.Range = 99999999
            yellowShoot.Info.Range = 99999999

            blueShoot.Info.SpreadIncrease = 0
            yellowShoot.Info.SpreadIncrease = 0

            portalTask.MethodReferences.Portal.Info.SpreadInfo.MaxSpread = 0
            portalTask.MethodReferences.Portal.Info.SpreadInfo.MinSpread = 0
            portalTask.MethodReferences.Portal.Info.SpreadInfo.ReductionRate = 100

            blueShoot.Info.Cooldown = 0.4
            yellowShoot.Info.Cooldown = 0.4

            blueShoot.CooldownInfo = {}
            yellowShoot.CooldownInfo = {}
            blueShoot.Requirements = {}
            yellowShoot.Requirements = {}

            Breacher.Actions.ADS.Enabled = false

            portalTask.Functions[1].Activations[1].CanHoldDown = true
            portalTask.Functions[2].Activations[1].CanHoldDown = true

            return true
        end)
        
        if success then
            Success("Breacher", "Portal Gun enhanced successfully!", 2)
            return true
        else
            Error("Breacher", "Failed to enhance: " .. tostring(result), 3)
            warn("Breacher error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceBreacher()
        end
    }
end)()

-- SMOKE GRENADE MODULE
local SmokeGrenadeModule = (function()
    local function enhanceSmokeGrenade()
        local success, result = pcall(function()
            local SmokeGrenade = require(ReplicatedStorage.Tools["SmokeGrenade"])
            
            if not SmokeGrenade then
                error("SmokeGrenade module not found")
            end

            SmokeGrenade.RequiresOwnedItem = false

            local throwMethod = SmokeGrenade.Tasks[1].Functions[1].Activations[1].Methods[1]

            throwMethod.ItemUseIncrement = {"SmokeGrenade", 0}
            throwMethod.Info.Cooldown = 0.5
            throwMethod.Info.ThrowVelocity = 200

            SmokeGrenade.Tasks[1].Functions[1].Activations[1].CanHoldDown = true

            throwMethod.Info.SmokeDuration = 999
            throwMethod.Info.SmokeRadius = 100
            throwMethod.Info.FadeTime = 60

            local equipMethod = SmokeGrenade.Tasks[1].AutomaticFunctions[1].Methods[1]
            local unequipMethod = SmokeGrenade.Tasks[1].AutomaticFunctions[2].Methods[1]
            equipMethod.Info.Cooldown = 0.5
            unequipMethod.Info.Cooldown = 0.5

            throwMethod.CooldownInfo = {}

            return true
        end)
        
        if success then
            Success("Smoke Grenade", "Enhanced successfully!", 2)
            return true
        else
            Error("Smoke Grenade", "Failed to enhance: " .. tostring(result), 3)
            warn("Smoke Grenade error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceSmokeGrenade()
        end
    }
end)()

-- STUN BATON MODULE
local StunBatonModule = (function()
    local function enhanceStunBaton()
        local success, result = pcall(function()
            local StunBaton = require(ReplicatedStorage.Tools["StunBaton"])
            
            local task = StunBaton.Tasks[1]
            
            task.Functions[1].Activations[1].CanHoldDown = true
            task.Functions[1].Activations[2].CanHoldDown = true
            
            task.Functions[1].Activations[1].Methods[1].Info.LungeRange = 0
            task.Functions[1].Activations[2].Methods[1].Info.LungeRange = 0
            
            task.AutomaticFunctions[1].Methods[1].Info.Range = 999
            task.AutomaticFunctions[2].Methods[1].Info.Range = 999
            
            if task.Functions[1].Activations[2].Methods[1].Requirements then
                if task.Functions[1].Activations[2].Methods[1].Requirements.MeleeSuccess then
                    task.Functions[1].Activations[2].Methods[1].Requirements.MeleeSuccess = nil
                end
            end
            
            task.AutomaticFunctions[1].Methods[1].Info.Cooldown = 0.1
            task.AutomaticFunctions[2].Methods[1].Info.Cooldown = 0.1
            task.Functions[1].Activations[1].Methods[1].Info.Cooldown = 0.1
            task.Functions[1].Activations[2].Methods[1].Info.Cooldown = 0.1
            
            task.Functions[1].Activations[1].Methods[1].Requirements = {}
            task.Functions[1].Activations[2].Methods[1].Requirements = {}
            task.Functions[1].Activations[1].Methods[1].CooldownInfo = {}
            task.Functions[1].Activations[2].Methods[1].CooldownInfo = {}
            
            task.AutomaticFunctions[1].Methods[1].Info.SelfDamage = 0
            
            task.AutomaticFunctions[2].Methods[1].Info.SuccessStunLength = 15
            task.Functions[1].Activations[1].Methods[1].Info.SuccessStunLength = 15
            task.Functions[1].Activations[2].Methods[1].Info.SuccessStunLength = 15
            
            task.AutomaticFunctions[2].Methods[1].Info.SuccessImmortalLength = 10
            task.Functions[1].Activations[1].Methods[1].Info.SuccessImmortalLength = 10
            task.Functions[1].Activations[2].Methods[1].Info.SuccessImmortalLength = 10
            task.Functions[1].Activations[1].Methods[1].Info.ImmortalLength = 10
            task.Functions[1].Activations[2].Methods[1].Info.ImmortalLength = 10
            
            task.AutomaticFunctions[2].Methods[1].Info.Damage = 110
            
            StunBaton.Actions.ADS.Enabled = false
            
            return true
        end)
        
        if success then
            Success("Stun Baton", "No Auto-Aim mode! Hold click to spam (30 studs range)", 2)
            return true
        else
            Error("Stun Baton", "Failed to enhance: " .. tostring(result), 3)
            warn("Stun Baton error details:", result)
            return false
        end
    end
    
    return {
        Execute = function()
            return enhanceStunBaton()
        end
    }
end)()

-- ========================================================================== --
--                         AUTO JUMP / BHOP SYSTEM                            --
-- ========================================================================== --

local AutoJumpModule = (function()
    local enabled = false
    local holdEnabled = false
    local autoJumpType = "Bounce"
    local bhopMode = "Acceleration"
    local bhopAccelValue = -0.5
    local jumpCooldown = 0.7
    local rotationEnabled = false
    local rotationSpeed = 100000
    
    local bhopConnection = nil
    local rotationConnection = nil
    local characterConnection = nil
    local frictionTables = {}
    
    local Character = nil
    local Humanoid = nil
    local HumanoidRootPart = nil
    local LastJump = 0
    
    local GROUND_CHECK_OFFSET = 3.5
    local GROUND_CHECK_RAY_LENGTH = 4
    local MAX_SLOPE_ANGLE = 45
    
    local bhopHoldActive = false
    
    -- ==================== ROTATION 360° ====================
    local function startRotation()
        if rotationConnection then
            rotationConnection:Disconnect()
            rotationConnection = nil
        end
        
        if not rotationEnabled or not HumanoidRootPart then return end
        
        rotationConnection = RunService.Heartbeat:Connect(function(deltaTime)
            if HumanoidRootPart and HumanoidRootPart.Parent then
                local currentRotation = HumanoidRootPart.Orientation
                local newRotation = Vector3.new(
                    currentRotation.X,
                    currentRotation.Y + (rotationSpeed * deltaTime),
                    currentRotation.Z
                )
                HumanoidRootPart.Orientation = newRotation
            else
                if rotationConnection then
                    rotationConnection:Disconnect()
                    rotationConnection = nil
                end
            end
        end)
    end
    
    local function stopRotation()
        if rotationConnection then
            rotationConnection:Disconnect()
            rotationConnection = nil
        end
    end
    
    -- ==================== GROUND CHECK ====================
    local function IsOnGround()
        if not Character or not HumanoidRootPart or not Humanoid then 
            return false 
        end
        
        local state = Humanoid:GetState()
        if state == Enum.HumanoidStateType.Jumping or 
           state == Enum.HumanoidStateType.Freefall or
           state == Enum.HumanoidStateType.Swimming then
            return false
        end
        
        if Humanoid:GetState() == Enum.HumanoidStateType.Running then
            return true
        end
        
        local rayOrigin = HumanoidRootPart.Position
        local rayDirection = Vector3.new(0, -GROUND_CHECK_RAY_LENGTH, 0)
        
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {Character}
        raycastParams.IgnoreWater = true
        
        local raycastResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        
        if raycastResult then
            local surfaceNormal = raycastResult.Normal
            local angle = math.deg(math.acos(surfaceNormal:Dot(Vector3.new(0, 1, 0))))
            
            if angle <= MAX_SLOPE_ANGLE then
                local heightDiff = math.abs(rayOrigin.Y - raycastResult.Position.Y)
                return heightDiff <= GROUND_CHECK_OFFSET
            end
        end
        
        if HumanoidRootPart.Velocity.Y > -1 and HumanoidRootPart.Velocity.Y < 1 then
            return true
        end
        
        return false
    end
    
    -- ==================== FRICTION TABLES ====================
    local function findFrictionTables()
        frictionTables = {}
        
        for _, obj in pairs(getgc(true)) do
            if type(obj) == "table" and rawget(obj, "Friction") then
                table.insert(frictionTables, {
                    obj = obj,
                    original = obj.Friction
                })
            end
        end
    end
    
    local function applyBhopFriction()
        local isActive = enabled or bhopHoldActive
        
        if isActive and bhopMode == "Acceleration" then
            if #frictionTables == 0 then
                findFrictionTables()
            end
            
            for _, tableData in ipairs(frictionTables) do
                if tableData.obj and type(tableData.obj) == "table" then
                    pcall(function()
                        tableData.obj.Friction = bhopAccelValue
                    end)
                end
            end
        else
            for _, tableData in ipairs(frictionTables) do
                if tableData.obj and type(tableData.obj) == "table" and tableData.original then
                    pcall(function()
                        tableData.obj.Friction = tableData.original
                    end)
                end
            end
        end
    end
    
    -- ==================== BHOP UPDATE ====================
    local function updateBhop()
        local isActive = enabled or bhopHoldActive
        
        if not isActive then return end
        
        if not Character or not Humanoid or not HumanoidRootPart then
            Character = player.Character
            if Character then
                Humanoid = Character:FindFirstChildOfClass("Humanoid")
                HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            end
            if not Humanoid or not HumanoidRootPart then return end
        end
        
        if Humanoid:GetState() == Enum.HumanoidStateType.Dead then
            return
        end
        
        local now = tick()
        
        if autoJumpType == "Realistic" then
            pcall(function()
                player.PlayerScripts.Events.temporary_events.JumpReact:Fire()
                player.PlayerScripts.Events.temporary_events.EndJump:Fire()
            end)
        else  -- BOUNCE
            if IsOnGround() and (now - LastJump) > 0.25 then
                Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                LastJump = now
            end
        end
    end
    
    -- ==================== LOAD/UNLOAD ====================
    local function loadBhop()
        findFrictionTables()
        applyBhopFriction()
        
        if bhopConnection then
            bhopConnection:Disconnect()
        end
        
        bhopConnection = RunService.Heartbeat:Connect(function(deltaTime)
            updateBhop()
        end)
    end
    
    local function unloadBhop()
        if bhopConnection then
            bhopConnection:Disconnect()
            bhopConnection = nil
        end
        
        bhopHoldActive = false
        applyBhopFriction()
    end
    
    local function checkBhopState()
        local shouldLoad = enabled or bhopHoldActive
        
        if shouldLoad then
            loadBhop()
            if rotationEnabled and enabled then
                startRotation()
            else
                stopRotation()
            end
        else
            unloadBhop()
            stopRotation()
        end
    end
    
    -- ==================== CHARACTER UPDATES ====================
    RunService.Heartbeat:Connect(function()
        if not Character or not Character:IsDescendantOf(workspace) then
            Character = player.Character
            if Character then
                Humanoid = Character:FindFirstChildOfClass("Humanoid")
                HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                if rotationEnabled and enabled then
                    startRotation()
                end
            else
                Humanoid = nil
                HumanoidRootPart = nil
                stopRotation()
            end
        end
    end)
    
    characterConnection = player.CharacterAdded:Connect(function(character)
        Character = character
        task.wait(0.5)
        Humanoid = character:WaitForChild("Humanoid")
        HumanoidRootPart = character:WaitForChild("HumanoidRootPart")
        
        if enabled or bhopHoldActive then
            task.wait(1)
            findFrictionTables()
            checkBhopState()
        end
        
        if rotationEnabled and enabled then
            startRotation()
        end
    end)
    
    -- ==================== INPUT HANDLERS ====================
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if gameProcessedEvent then return end
        
        if input.KeyCode == Enum.KeyCode.Space and holdEnabled then
            bhopHoldActive = true
            checkBhopState()
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.Space then
            bhopHoldActive = false
            checkBhopState()
        end
    end)
    
    -- ==================== PUBLIC FUNCTIONS ====================
    local function start()
        if enabled then return end
        enabled = true
        checkBhopState()
        Success("Auto Jump", "Activated (" .. autoJumpType .. " mode)", 2)
    end
    
    local function stop()
        if not enabled then return end
        enabled = false
        checkBhopState()
        Info("Auto Jump", "Disabled", 2)
    end
    
    local function toggleRotation(state)
        rotationEnabled = state
        if state and enabled then
            startRotation()
            Success("Rotation 360°", "Activated", 2)
        else
            stopRotation()
            Info("Rotation 360°", "Disabled", 2)
        end
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        
        SetAutoJumpType = function(type)
            autoJumpType = type
            Info("Auto Jump", "Type: " .. type, 1)
        end,
        
        SetBhopMode = function(mode)
            bhopMode = mode
            checkBhopState()
            Info("Bhop Mode", mode, 1)
        end,
        
        SetBhopAccel = function(accel)
            local num = tonumber(accel)
            if num and num < 0 then
                bhopAccelValue = num
                if enabled or bhopHoldActive then
                    applyBhopFriction()
                end
                Success("Bhop Accel", "Set to: " .. num, 1)
            end
        end,
        
        SetJumpCooldown = function(cooldown)
            local num = tonumber(cooldown)
            if num and num > 0 then
                jumpCooldown = num
                Success("Jump Cooldown", "Set to: " .. num .. "s", 1)
            end
        end,
        
        ToggleRotation = toggleRotation,
        IsRotationEnabled = function() return rotationEnabled end,
        
        SetHoldEnabled = function(state)
            holdEnabled = state
        end
    }
end)()

-- ========================================================================== --
--                         BOUNCE MODIFICATION MODULE                         --
-- ========================================================================== --

local BounceModule = (function()
    local enabled = false
    local bounceSpeed = 110
    local bounceConnection = nil
    
    local function updateBounce()
        if not enabled then return end
        
        local gamePlayers = workspace:FindFirstChild("Game") 
            and workspace.Game:FindFirstChild("Players")
        if not gamePlayers then return end
        
        local playerModel = gamePlayers:FindFirstChild(player.Name)
        if not playerModel then return end
        
        local humanoid = playerModel:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        humanoid.WalkSpeed = bounceSpeed
    end
    
    local function start()
        if bounceConnection then return end
        enabled = true
        
        bounceConnection = RunService.Heartbeat:Connect(updateBounce)
        
        Success("Bounce Mod", "Activated (Speed: " .. bounceSpeed .. ")", 2)
    end
    
    local function stop()
        enabled = false
        
        if bounceConnection then
            bounceConnection:Disconnect()
            bounceConnection = nil
        end
        
        -- Reset speed
        local gamePlayers = workspace:FindFirstChild("Game") 
            and workspace.Game:FindFirstChild("Players")
        if gamePlayers then
            local playerModel = gamePlayers:FindFirstChild(player.Name)
            if playerModel then
                local humanoid = playerModel:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.WalkSpeed = 0
                end
            end
        end
        
        Info("Bounce Mod", "Disabled", 2)
    end
    
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if enabled then
            updateBounce()
        end
    end)
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        SetSpeed = function(speed)
            local num = tonumber(speed)
            if num and num > 0 and num <= 1000 then
                bounceSpeed = num
                if enabled then
                    updateBounce()
                    Success("Bounce Speed", "Set to: " .. num, 1)
                end
            end
        end
    }
end)()

-- ========================================================================== --
--                         GRAVITY SYSTEM MODULE                              --
-- ========================================================================== --

local GravityModule = (function()
    local enabled = false
    local originalGravity = workspace.Gravity
    local gravityValue = 10
    
    local function start()
        if enabled then return end
        enabled = true
        
        workspace.Gravity = gravityValue
        
        Success("Gravity", "Activated (Value: " .. gravityValue .. ")", 2)
    end
    
    local function stop()
        if not enabled then return end
        enabled = false
        
        workspace.Gravity = originalGravity
        
        Info("Gravity", "Disabled (Reset to: " .. originalGravity .. ")", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        SetGravity = function(gravity)
            local num = tonumber(gravity)
            if num and num > 0 then
                gravityValue = num
                if enabled then
                    workspace.Gravity = num
                    Success("Gravity", "Set to: " .. num, 1)
                end
            end
        end,
        GetOriginalGravity = function() return originalGravity end
    }
end)()

-- ========================================================================== --
--                         INFINITE SLIDE MODULE (KEEP)                       --
-- ========================================================================== --

local InfiniteSlideModule = (function()
    local enabled = false
    local slideFrictionValue = -8
    local movementTables = {}
    local slideConnection = nil
    local charConnection = nil
    
    local requiredKeys = {
        "Friction", "AirStrafeAcceleration", "JumpHeight", "RunDeaccel",
        "JumpSpeedMultiplier", "JumpCap", "SprintCap", "WalkSpeedMultiplier",
        "BhopEnabled", "Speed", "AirAcceleration", "RunAccel", "SprintAcceleration"
    }
    
    local function hasRequiredFields(tbl)
        if typeof(tbl) ~= "table" then return false end
        for _, key in ipairs(requiredKeys) do
            if rawget(tbl, key) == nil then return false end
        end
        return true
    end
    
    local function findMovementTables()
        movementTables = {}
        for _, obj in ipairs(getgc(true)) do
            if hasRequiredFields(obj) then
                table.insert(movementTables, obj)
            end
        end
        return #movementTables > 0
    end
    
    local function setSlideFriction(value)
        local appliedCount = 0
        for _, tbl in ipairs(movementTables) do
            pcall(function()
                tbl.Friction = value
                appliedCount = appliedCount + 1
            end)
        end
        return appliedCount
    end
    
    local function getPlayerModel()
        local gameFolder = workspace:FindFirstChild("Game")
        if not gameFolder then return nil end
        local playersFolder = gameFolder:FindFirstChild("Players")
        if not playersFolder then return nil end
        return playersFolder:FindFirstChild(player.Name)
    end
    
    local function slideUpdate()
        if not enabled then return end
        
        local playerModel = getPlayerModel()
        if not playerModel then return end
        
        local state = playerModel:GetAttribute("State")
        
        if state == "Slide" then
            pcall(function()
                playerModel:SetAttribute("State", "EmotingSlide")
            end)
        elseif state == "EmotingSlide" then
            setSlideFriction(slideFrictionValue)
        else
            setSlideFriction(5)
        end
    end
    
    local function onCharacterAdded(character)
        if not enabled then return end
        
        for i = 1, 5 do
            task.wait(0.5)
            if getPlayerModel() then break end
        end
        
        task.wait(0.5)
        findMovementTables()
    end
    
    local function start()
        if enabled then return end
        enabled = true
        
        findMovementTables()
        
        if player.Character then
            task.spawn(function() 
                onCharacterAdded(player.Character) 
            end)
        end
        
        charConnection = player.CharacterAdded:Connect(onCharacterAdded)
        slideConnection = RunService.Heartbeat:Connect(slideUpdate)
        
        Success("Infinite Slide", "Activated (Speed: " .. slideFrictionValue .. ")", 2)
    end
    
    local function stop()
        if not enabled then return end
        enabled = false
        
        if slideConnection then
            slideConnection:Disconnect()
            slideConnection = nil
        end
        
        if charConnection then
            charConnection:Disconnect()
            charConnection = nil
        end
        
        setSlideFriction(5)
        movementTables = {}
        
        Info("Infinite Slide", "Disabled", 2)
    end
    
    return {
        Start = start,
        Stop = stop,
        IsEnabled = function() return enabled end,
        SetSlideSpeed = function(speed)
            local num = tonumber(speed)
            if num then
                slideFrictionValue = num
                if enabled then
                    setSlideFriction(num)
                    Success("Slide Speed", "Set to: " .. num, 1)
                end
            end
        end
    }
end)()

-- FLY MODULE
local FlyModule = (function()
    local flying = false
    local bodyVelocity = nil
    local bodyGyro = nil
    local flyLoop = nil
    local characterAddedConnection = nil
    local flySpeed = 50
    
    local function startFlying()
        local character = player.Character
        if not character then 
            Error("Fly System", "No character found!", 2)
            return false 
        end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then 
            Error("Fly System", "Humanoid or RootPart not found!", 2)
            return false 
        end
        
        flying = true
        
        local success, err = pcall(function()
            bodyVelocity = Instance.new("BodyVelocity")
            bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            bodyVelocity.Parent = rootPart
            
            bodyGyro = Instance.new("BodyGyro")
            bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            bodyGyro.CFrame = rootPart.CFrame
            bodyGyro.Parent = rootPart
            
            humanoid.PlatformStand = true
        end)
        
        if success then
            Success("Fly System", "Flying activated! (Speed: " .. flySpeed .. ")", 2)
        else
            Error("Fly System", "Failed to start: " .. tostring(err), 2)
            return false
        end
        
        return true
    end
    
    local function stopFlying()
        flying = false
        
        if bodyVelocity then
            pcall(function() bodyVelocity:Destroy() end)
            bodyVelocity = nil
        end
        if bodyGyro then
            pcall(function() bodyGyro:Destroy() end)
            bodyGyro = nil
        end
        
        local character = player.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                pcall(function() humanoid.PlatformStand = false end)
            end
        end
        
        Info("Fly System", "Flying deactivated", 2)
    end
    
    local function updateFly()
        if not flying then return end
        if not bodyVelocity or not bodyGyro then return end
        
        local character = player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        local rootPart = character:FindFirstChild("HumanoidRootPart")
        
        if not humanoid or not rootPart then return end
        
        local camera = workspace.CurrentCamera
        if not camera then return end
        
        local cameraCFrame = camera.CFrame
        local direction = Vector3.new(0, 0, 0)
        local moveDirection = humanoid.MoveDirection
        
        if moveDirection.Magnitude > 0 then
            local forwardVector = cameraCFrame.LookVector
            local rightVector = cameraCFrame.RightVector
            local forwardComponent = moveDirection:Dot(forwardVector) * forwardVector
            local rightComponent = moveDirection:Dot(rightVector) * rightVector
            direction = direction + (forwardComponent + rightComponent).Unit * moveDirection.Magnitude
        end
        
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            direction = direction + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            direction = direction - Vector3.new(0, 1, 0)
        end
        
        pcall(function()
            if direction.Magnitude > 0 then
                bodyVelocity.Velocity = direction.Unit * (flySpeed * 2)
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
            end
            bodyGyro.CFrame = cameraCFrame
        end)
    end
    
    local function toggleFly(state)
        if state then
            if characterAddedConnection then
                pcall(function() characterAddedConnection:Disconnect() end)
            end
            
            characterAddedConnection = player.CharacterAdded:Connect(function(newChar)
                task.wait(0.5)
                if flying == false and state then
                    startFlying()
                end
            end)
            
            startFlying()
            
            if not flyLoop then
                flyLoop = RunService.RenderStepped:Connect(function()
                    if state then
                        updateFly()
                    end
                end)
            end
            
        else
            stopFlying()
            
            if flyLoop then
                pcall(function() flyLoop:Disconnect() end)
                flyLoop = nil
            end
            
            if characterAddedConnection then
                pcall(function() characterAddedConnection:Disconnect() end)
                characterAddedConnection = nil
            end
        end
    end
    
    local function setFlySpeed(speed)
        local num = tonumber(speed)
        if num and num > 0 then
            flySpeed = num
            if flying then
                Success("Fly System", "Speed set to: " .. flySpeed, 1)
            end
            return true
        end
        return false
    end
    
    player.CharacterRemoving:Connect(function()
        if flying then
            stopFlying()
            if flyLoop then
                pcall(function() flyLoop:Disconnect() end)
                flyLoop = nil
            end
        end
    end)
    
    return {
        Toggle = toggleFly,
        SetSpeed = setFlySpeed,
        GetSpeed = function() return flySpeed end,
        IsFlying = function() return flying end,
        Stop = function() 
            if flying then
                toggleFly(false)
            end
        end,
        OnCharacterAdded = function()
            if flying then
                task.wait(1)
                startFlying()
            end
        end
    }
end)()



-- ========================================================================== --
--                         VISUAL FEATURES MODULE                             --
-- ========================================================================== --

local VisualFeaturesModule = (function()
    local Lighting = game:GetService("Lighting")
    
    -- Store original values
    local originalValues = {
        FogEnd = Lighting.FogEnd,
        FogStart = Lighting.FogStart,
        FogColor = Lighting.FogColor,
        Brightness = Lighting.Brightness,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ColorShift_Bottom = Lighting.ColorShift_Bottom,
        ColorShift_Top = Lighting.ColorShift_Top,
        GlobalShadows = Lighting.GlobalShadows,
        Atmospheres = {}
    }
    
    -- Backup atmospheres
    for _, v in pairs(Lighting:GetChildren()) do
        if v:IsA("Atmosphere") then
            table.insert(originalValues.Atmospheres, v:Clone())
        end
    end
    
    -- ==================== FAKE STREAK ====================
    local function setFakeStreak(value)
        local num = tonumber(value)
        if num then
            local success, err = pcall(function()
                player:SetAttribute("Streak", num)
            end)
            if success then
                Success("Fake Streak", "Streak set to: " .. num, 1)
                return true
            else
                Error("Fake Streak", "Failed to set streak", 1)
                return false
            end
        end
        return false
    end
    
    local function resetStreak()
        local success, err = pcall(function()
            player:SetAttribute("Streak", nil)
        end)
        if success then
            Success("Fake Streak", "Streak has been reset", 1)
        else
            Error("Fake Streak", "Failed to reset streak", 1)
        end
    end
    
    -- ==================== CAMERA STRETCH ====================
    local cameraStretchConnection = nil
    local stretchHorizontal = 0.80
    local stretchVertical = 0.80
    local stretchEnabled = false
    
    local function applyCameraStretch()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CFrame = Camera.CFrame * CFrame.new(
                0, 0, 0,
                stretchHorizontal, 0, 0,
                0, stretchVertical, 0,
                0, 0, 1
            )
        end
    end
    
    local function setupCameraStretch()
        if cameraStretchConnection then
            pcall(function() cameraStretchConnection:Disconnect() end)
        end
        cameraStretchConnection = RunService.RenderStepped:Connect(applyCameraStretch)
    end
    
    local function toggleCameraStretch(state)
        stretchEnabled = state
        if state then
            setupCameraStretch()
            Success("Camera Stretch", "Activated (H: " .. stretchHorizontal .. ", V: " .. stretchVertical .. ")", 2)
        else
            if cameraStretchConnection then
                pcall(function() cameraStretchConnection:Disconnect() end)
                cameraStretchConnection = nil
            end
            Info("Camera Stretch", "Deactivated", 2)
        end
    end
    
    local function setStretchHorizontal(value)
        local num = tonumber(value)
        if num and num > 0 then
            stretchHorizontal = num
            if stretchEnabled then
                Success("Stretch H", "Set to: " .. stretchHorizontal, 1)
            end
            return true
        end
        return false
    end
    
    local function setStretchVertical(value)
        local num = tonumber(value)
        if num and num > 0 then
            stretchVertical = num
            if stretchEnabled then
                Success("Stretch V", "Set to: " .. stretchVertical, 1)
            end
            return true
        end
        return false
    end
    
    -- ==================== FULL BRIGHT ====================
    local fullBrightEnabled = false
    local fullBrightConnection = nil
    
    local function applyFullBright()
        pcall(function()
            if Lighting.Brightness ~= 2 then
                Lighting.Brightness = 2
            end
            if Lighting.Ambient ~= Color3.new(1, 1, 1) then
                Lighting.Ambient = Color3.new(1, 1, 1)
            end
            if Lighting.OutdoorAmbient ~= Color3.new(1, 1, 1) then
                Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
            end
            if Lighting.ColorShift_Bottom ~= Color3.new(1, 1, 1) then
                Lighting.ColorShift_Bottom = Color3.new(1, 1, 1)
            end
            if Lighting.ColorShift_Top ~= Color3.new(1, 1, 1) then
                Lighting.ColorShift_Top = Color3.new(1, 1, 1)
            end
            Lighting.GlobalShadows = false
            
            -- Remove atmospheres
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    v:Destroy()
                end
            end
        end)
    end
    
    local function restoreLighting()
        pcall(function()
            Lighting.Brightness = originalValues.Brightness
            Lighting.Ambient = originalValues.Ambient
            Lighting.OutdoorAmbient = originalValues.OutdoorAmbient
            Lighting.ColorShift_Bottom = originalValues.ColorShift_Bottom
            Lighting.ColorShift_Top = originalValues.ColorShift_Top
            Lighting.GlobalShadows = originalValues.GlobalShadows
            
            -- Restore atmospheres
            for _, atmosphere in ipairs(originalValues.Atmospheres) do
                local newAtmosphere = Instance.new("Atmosphere")
                for _, prop in pairs({"Density", "Offset", "Color", "Decay", "Glare", "Haze"}) do
                    if atmosphere[prop] then
                        newAtmosphere[prop] = atmosphere[prop]
                    end
                end
                newAtmosphere.Parent = Lighting
            end
        end)
    end
    
    local function toggleFullBright(state)
        fullBrightEnabled = state
        
        if state then
            applyFullBright()
            
            -- Keep full bright active via connection
            if fullBrightConnection then
                fullBrightConnection:Disconnect()
            end
            
            fullBrightConnection = RunService.Heartbeat:Connect(function()
                if fullBrightEnabled then
                    applyFullBright()
                end
            end)
            
            Success("Full Bright", "Activated", 2)
        else
            if fullBrightConnection then
                fullBrightConnection:Disconnect()
                fullBrightConnection = nil
            end
            
            restoreLighting()
            Info("Full Bright", "Deactivated", 2)
        end
    end
    
    -- ==================== ANTI LAG 1 (LIGHT) ====================
    local function antiLag1()
        task.spawn(function()
            pcall(function()
                Lighting.GlobalShadows = false
                Lighting.FogEnd = 1e10
                Lighting.Brightness = 1
                
                local Terrain = workspace:FindFirstChildOfClass("Terrain")
                if Terrain then
                    Terrain.WaterWaveSize = 0
                    Terrain.WaterWaveSpeed = 0
                    Terrain.WaterReflectance = 0
                    Terrain.WaterTransparency = 1
                end
                
                local partsChanged = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") then
                        obj.Material = Enum.Material.Plastic
                        obj.Reflectance = 0
                        partsChanged = partsChanged + 1
                    elseif obj:IsA("Decal") or obj:IsA("Texture") then
                        obj:Destroy()
                    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
                        obj:Destroy()
                    elseif obj:IsA("PointLight") or obj:IsA("SpotLight") or obj:IsA("SurfaceLight") then
                        obj:Destroy()
                    end
                end
                
                Success("Anti Lag 1", "Light optimization complete! (" .. partsChanged .. " parts)", 3)
            end)
        end)
    end
    
    -- ==================== ANTI LAG 2 (AGGRESSIVE) ====================
    local function antiLag2()
        task.spawn(function()
            pcall(function()
                local stats = {
                    parts = 0, particles = 0, effects = 0, textures = 0, sky = 0
                }
                
                for _, v in next, game:GetDescendants() do
                    if v:IsA("Part") or v:IsA("UnionOperation") or v:IsA("BasePart") then
                        v.Material = Enum.Material.SmoothPlastic
                        stats.parts = stats.parts + 1
                    end
                    
                    if v:IsA("ParticleEmitter") or v:IsA("Smoke") or v:IsA("Explosion") or v:IsA("Sparkles") or v:IsA("Fire") then
                        v.Enabled = false
                        stats.particles = stats.particles + 1
                    end
                    
                    if v:IsA("BloomEffect") or v:IsA("BlurEffect") or v:IsA("DepthOfFieldEffect") or v:IsA("SunRaysEffect") then
                        v.Enabled = false
                        stats.effects = stats.effects + 1
                    end
                    
                    if v:IsA("Decal") or v:IsA("Texture") then
                        v.Texture = ""
                        stats.textures = stats.textures + 1
                    end
                    
                    if v:IsA("Sky") then
                        v.Parent = nil
                        stats.sky = stats.sky + 1
                    end
                end
                
                Success("Anti Lag 2", "Aggressive optimization complete!", 3)
            end)
        end)
    end
    
    -- ==================== ANTI LAG 3 (TEXTURES) ====================
    local function antiLag3()
        task.spawn(function()
            pcall(function()
                local texturesRemoved = 0
                local decalsRemoved = 0
                
                for _, part in ipairs(workspace:GetDescendants()) do
                    if part:IsA("Part") or part:IsA("MeshPart") or part:IsA("UnionOperation") then
                        if part:IsA("Part") then
                            part.Material = Enum.Material.SmoothPlastic
                        end
                        
                        local texture = part:FindFirstChildWhichIsA("Texture")
                        if texture then
                            texture.Texture = "rbxassetid://0"
                            texturesRemoved = texturesRemoved + 1
                        end
                        
                        local decal = part:FindFirstChildWhichIsA("Decal")
                        if decal then
                            decal.Texture = "rbxassetid://0"
                            decalsRemoved = decalsRemoved + 1
                        end
                    end
                end
                
                Success("Anti Lag 3", "Textures: " .. texturesRemoved .. ", Decals: " .. decalsRemoved .. " cleared", 3)
            end)
        end)
    end
    
    -- ==================== REMOVE FOG ====================
    local removeFogEnabled = false
    
    local function applyRemoveFog()
        pcall(function()
            Lighting.FogEnd = 1000000
            for _, v in pairs(Lighting:GetChildren()) do
                if v:IsA("Atmosphere") then
                    v:Destroy()
                end
            end
        end)
    end
    
    local function restoreFog()
        pcall(function()
            Lighting.FogEnd = originalValues.FogEnd
            for _, atmosphere in ipairs(originalValues.Atmospheres) do
                local newAtmosphere = Instance.new("Atmosphere")
                for _, prop in pairs({"Density", "Offset", "Color", "Decay", "Glare", "Haze"}) do
                    if atmosphere[prop] then
                        newAtmosphere[prop] = atmosphere[prop]
                    end
                end
                newAtmosphere.Parent = Lighting
            end
        end)
    end
    
    local function toggleRemoveFog(state)
        removeFogEnabled = state
        
        if state then
            applyRemoveFog()
            Success("Remove Fog", "Activated", 2)
        else
            restoreFog()
            Info("Remove Fog", "Deactivated", 2)
        end
    end
    
    -- Character respawn handler
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if fullBrightEnabled then
            applyFullBright()
        end
        if removeFogEnabled then
            applyRemoveFog()
        end
    end)
    
    return {
        SetFakeStreak = setFakeStreak,
        ResetStreak = resetStreak,
        
        ToggleCameraStretch = toggleCameraStretch,
        SetStretchH = setStretchHorizontal,
        SetStretchV = setStretchVertical,
        IsStretchEnabled = function() return stretchEnabled end,
        
        ToggleFullBright = toggleFullBright,
        IsFullBright = function() return fullBrightEnabled end,
        
        AntiLag1 = antiLag1,
        AntiLag2 = antiLag2,
        AntiLag3 = antiLag3,
        
        ToggleRemoveFog = toggleRemoveFog,
        IsRemoveFog = function() return removeFogEnabled end,
    }
end)()

-- ========================================================================== --
--                         LAG SWITCH MODULE (ADVANCED)                       --
-- ========================================================================== --

local LagSwitchModule = (function()
    local enabled = false
    local lagMode = "Normal"
    local lagDelay = 0.1
    local lagIntensity = 1000000
    local demonHeight = 10
    local demonSpeed = 80
    local isLagActive = false
    
    -- ==================== NORMAL LAG (MATH) ====================
    local function performMathLag()
        local startTime = tick()
        local duration = lagDelay
        
        while tick() - startTime < duration do
            for i = 1, lagIntensity do
                local a = math.random(1, 1000000) * math.random(1, 1000000)
                a = a / math.random(1, 10000)
                local b = math.sqrt(math.random(1, 1000000))
                b = b * math.pi * math.exp(1)
                local c = math.sin(math.rad(math.random(1, 360))) * math.cos(math.rad(math.random(1, 360)))
            end
        end
    end
    
    -- ==================== DEMON MODE (LAG + RISE) ====================
    local function performDemonLag()
        local startTime = tick()
        local duration = lagDelay
        
        -- Part 1: Math lag in background
        task.spawn(function()
            local startLagTime = tick()
            while tick() - startLagTime < duration do
                for i = 1, math.floor(lagIntensity / 2) do
                    local a = math.random(1, 1000000) * math.random(1, 1000000)
                    a = a / math.random(1, 10000)
                    local b = math.sqrt(math.random(1, 1000000))
                    b = b * math.pi * math.exp(1)
                end
            end
        end)
        
        -- Part 2: Rise player
        local character = player.Character
        
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            local humanoid = character:FindFirstChild("Humanoid")
            
            if humanoidRootPart and humanoid then
                local startHeight = humanoidRootPart.Position.Y
                
                -- Create BodyThrust for upward force
                local bodyThrust = Instance.new("BodyThrust")
                bodyThrust.Name = "DemonRiseThrust"
                bodyThrust.Force = Vector3.new(0, demonSpeed * 500, 0)
                bodyThrust.Location = Vector3.new(0, 0, 0)
                bodyThrust.Parent = humanoidRootPart
                
                -- Create BodyVelocity for control
                local bodyVelocity = Instance.new("BodyVelocity")
                bodyVelocity.Name = "DemonRiseVelocity"
                bodyVelocity.MaxForce = Vector3.new(0, 500000, 0)
                bodyVelocity.Velocity = Vector3.new(0, demonSpeed, 0)
                bodyVelocity.Parent = humanoidRootPart
                
                -- Wait until reach target height
                local waitTime = 0
                local maxWaitTime = 5
                
                while waitTime < maxWaitTime do
                    local currentHeight = humanoidRootPart.Position.Y
                    local heightGained = currentHeight - startHeight
                    
                    if heightGained >= demonHeight then
                        break
                    end
                    
                    task.wait(0.1)
                    waitTime = waitTime + 0.1
                end
                
                -- Remove forces
                if bodyThrust then
                    bodyThrust:Destroy()
                end
                if bodyVelocity then
                    bodyVelocity:Destroy()
                end
                
                local finalHeight = humanoidRootPart.Position.Y
                local heightGained = finalHeight - startHeight
                
                Success("Demon Mode", string.format("Lifted %.1f meters (target: %.1fm)", heightGained, demonHeight), 3)
            end
        end
        
        isLagActive = false
    end
    
    -- ==================== TOGGLE LAG SWITCH ====================
    local function toggle()
        if not enabled then
            Warning("Lag Switch", "Enable the toggle first!", 2)
            return
        end
        
        if isLagActive then
            Warning("Lag Switch", "Already active, please wait!", 1)
            return
        end
        
        isLagActive = true
        
        if lagMode == "Normal" then
            task.spawn(function()
                performMathLag()
                isLagActive = false
            end)
            Success("Lag Switch", "Normal lag triggered (" .. lagDelay .. "s)", 1)
        elseif lagMode == "Demon" then
            task.spawn(function()
                performDemonLag()
                -- isLagActive = false (handled in performDemonLag)
            end)
            Info("Lag Switch", "Demon mode activated!", 1)
        end
    end
    
    -- ==================== PUBLIC FUNCTIONS ====================
    local function setEnabled(state)
        enabled = state
        if state then
            Info("Lag Switch", "Enabled (Mode: " .. lagMode .. ")", 1)
        else
            Info("Lag Switch", "Disabled", 1)
        end
    end
    
    local function setMode(mode)
        lagMode = mode
        Info("Lag Switch", "Mode changed to: " .. mode, 1)
    end
    
    local function setDelay(delay)
        local num = tonumber(delay)
        if num and num > 0 and num <= 5 then
            lagDelay = num
            Success("Lag Delay", "Set to: " .. num .. "s", 1)
            return true
        else
            Error("Lag Delay", "Value must be between 0.01 and 5", 2)
            return false
        end
    end
    
    local function setIntensity(intensity)
        local num = tonumber(intensity)
        if num and num >= 1000 and num <= 10000000 then
            lagIntensity = num
            Success("Lag Intensity", "Set to: " .. num, 1)
            return true
        else
            Error("Lag Intensity", "Value must be between 1000 and 10000000", 2)
            return false
        end
    end
    
    local function setDemonHeight(height)
        local num = tonumber(height)
        if num and num >= 10 and num <= 500 then
            demonHeight = num
            Success("Demon Height", "Set to: " .. num .. " meters", 1)
            return true
        else
            Error("Demon Height", "Value must be between 10 and 500", 2)
            return false
        end
    end
    
    local function setDemonSpeed(speed)
        local num = tonumber(speed)
        if num and num >= 20 and num <= 200 then
            demonSpeed = num
            Success("Demon Speed", "Set to: " .. num, 1)
            return true
        else
            Error("Demon Speed", "Value must be between 20 and 200", 2)
            return false
        end
    end
    
    return {
        Toggle = toggle,
        SetEnabled = setEnabled,
        SetMode = setMode,
        SetDelay = setDelay,
        SetIntensity = setIntensity,
        SetDemonHeight = setDemonHeight,
        SetDemonSpeed = setDemonSpeed,
        IsEnabled = function() return enabled end,
        GetMode = function() return lagMode end,
        GetStatus = function()
            return string.format(
                "Enabled: %s\nMode: %s\nDelay: %.2fs\nIntensity: %d\nDemon Height: %dm\nDemon Speed: %d",
                enabled and "✅" or "❌",
                lagMode,
                lagDelay,
                lagIntensity,
                demonHeight,
                demonSpeed
            )
        end
    }
end)()

-- UNLOCK LEADERBOARD MODULE
local UnlockLeaderboardModule = (function()
    local buttonGui = nil
    local player = game:GetService("Players").LocalPlayer
    local TweenService = game:GetService("TweenService")
    local StarterGui = game:GetService("StarterGui")
    
    local function createLeaderboardUI()
        if buttonGui and buttonGui.Parent then
            pcall(function() buttonGui:Destroy() end)
        end
        
        local playerGui = player:WaitForChild("PlayerGui")
        
        local existing = playerGui:FindFirstChild("CustomTopGui")
        if existing then
            existing:Destroy()
        end
        
        pcall(function()
            StarterGui:SetCore("TopbarEnabled", false)
        end)
        
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "CustomTopGui"
        screenGui.IgnoreGuiInset = false
        screenGui.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
        screenGui.DisplayOrder = 100
        screenGui.ResetOnSpawn = false
        screenGui.Parent = playerGui
        buttonGui = screenGui
        
        local container = Instance.new("Frame")
        container.Name = "ButtonContainer"
        container.Parent = screenGui
        container.BackgroundTransparency = 1
        container.Size = UDim2.new(1, -20, 1, 0)
        container.Position = UDim2.new(0, 10, 0, 10)
        
        local layout = Instance.new("UIListLayout")
        layout.Parent = container
        layout.FillDirection = Enum.FillDirection.Horizontal
        layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
        layout.VerticalAlignment = Enum.VerticalAlignment.Top
        layout.Padding = UDim.new(0, 8)
        
        local buttonsConfig = {
            {
                name = "FrontViewButton",
                icon = "rbxassetid://78648212535999",
                label = "Front View",
                keys = {"Reload", "FrontView", "View"},
                color = Color3.fromRGB(45, 45, 45)
            },
            {
                name = "LeaderboardButton",
                icon = "rbxassetid://5107166345",
                label = "Leaderboard",
                keys = {"Leaderboard", "Scoreboard"},
                color = Color3.fromRGB(45, 45, 45)
            }
        }
        
        local function triggerKey(key, state)
            pcall(function()
                local useKeybind = player.PlayerScripts.Events.temporary_events.UseKeybind
                if useKeybind then
                    useKeybind:Fire({Key = key, Down = state})
                end
            end)
        end
        
        for _, config in ipairs(buttonsConfig) do
            local btnFrame = Instance.new("Frame")
            btnFrame.Name = config.name
            btnFrame.Parent = container
            btnFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            btnFrame.BackgroundTransparency = 0.3
            btnFrame.BorderSizePixel = 0
            btnFrame.Size = UDim2.new(0, 44, 0, 44)
            btnFrame.ZIndex = 10
            
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(1, 0)
            corner.Parent = btnFrame
            
            local icon = Instance.new("ImageLabel")
            icon.Name = "Icon"
            icon.Parent = btnFrame
            icon.BackgroundTransparency = 1
            icon.Size = UDim2.new(0.7, 0, 0.7, 0)
            icon.Position = UDim2.new(0.15, 0, 0.15, 0)
            icon.Image = config.icon
            icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
            icon.ZIndex = 11
            
            local clickBtn = Instance.new("TextButton")
            clickBtn.Name = "ClickButton"
            clickBtn.Parent = btnFrame
            clickBtn.BackgroundTransparency = 1
            clickBtn.Size = UDim2.new(1, 0, 1, 0)
            clickBtn.ZIndex = 20
            clickBtn.Text = ""
            clickBtn.AutoButtonColor = false
            
            local label = Instance.new("TextLabel")
            label.Name = "Label"
            label.Parent = btnFrame
            label.BackgroundTransparency = 1
            label.Position = UDim2.new(0, 0, 1, 5)
            label.Size = UDim2.new(1, 0, 0, 16)
            label.Font = Enum.Font.GothamBold
            label.Text = config.label
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.TextSize = 12
            label.TextStrokeTransparency = 0.5
            label.ZIndex = 12
            label.Visible = false
            
            clickBtn.MouseEnter:Connect(function()
                btnFrame.BackgroundTransparency = 0
                label.Visible = true
            end)
            
            clickBtn.MouseLeave:Connect(function()
                btnFrame.BackgroundTransparency = 0.3
                label.Visible = false
            end)
            
            clickBtn.MouseButton1Down:Connect(function()
                btnFrame.BackgroundTransparency = 0.5
                for _, key in ipairs(config.keys) do
                    triggerKey(key, true)
                end
            end)
            
            clickBtn.MouseButton1Up:Connect(function()
                btnFrame.BackgroundTransparency = 0
                for _, key in ipairs(config.keys) do
                    triggerKey(key, false)
                end
            end)
            
            clickBtn.MouseLeave:Connect(function()
                btnFrame.BackgroundTransparency = 0.3
                label.Visible = false
                for _, key in ipairs(config.keys) do
                    triggerKey(key, false)
                end
            end)
        end
        
        return screenGui
    end
    
    local function destroyLeaderboardUI()
        if buttonGui and buttonGui.Parent then
            pcall(function() buttonGui:Destroy() end)
            buttonGui = nil
        end
        
        pcall(function()
            StarterGui:SetCore("TopbarEnabled", true)
        end)
    end
    
    return {
        Create = function()
            local success, err = pcall(createLeaderboardUI)
            if success then
                Success("Leaderboard", "Custom UI created!", 2)
                return true
            else
                Error("Leaderboard", "Failed: " .. tostring(err), 3)
                return false
            end
        end,
        Destroy = destroyLeaderboardUI,
        Toggle = function()
            if buttonGui and buttonGui.Parent then
                destroyLeaderboardUI()
                Info("Leaderboard", "Custom UI destroyed", 2)
            else
                createLeaderboardUI()
                Success("Leaderboard", "Custom UI created!", 2)
            end
        end
    }
end)()

-- ESP SYSTEM MODULE
local ESP_System = {}
local ESP_Players = game:GetService("Players")
local ESP_RunService = game:GetService("RunService")
local ESP_ReplicatedStorage = game:GetService("ReplicatedStorage")
local ESP_LocalPlayer = ESP_Players.LocalPlayer

ESP_System.PlayersESP = {}
ESP_System.TicketsESP = {}
ESP_System.NextbotsESP = {}
ESP_System.NextbotNames = {}
ESP_System.Connections = {}
ESP_System.Running = false
ESP_System.ChamsPlayers = {}
ESP_System.TracerDrawings = {}
ESP_System.TracerAllDrawings = {}

ESP_System.Settings = {
    Players = {
        Enabled = false,
        Color = Color3.fromRGB(255, 255, 255)
    },
    Tickets = {
        Enabled = false,
        Color = Color3.fromRGB(255, 165, 0)
    },
    Nextbots = {
        Enabled = false,
        Color = Color3.fromRGB(255, 0, 0)
    },
    ChamsPlayers = {
        Enabled = false,
        FillColor = Color3.fromRGB(255, 0, 0),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineTransparency = 0,
    },
    TracerDowned = {
        Enabled = false,
        Color = Color3.fromRGB(255, 50, 50),
        Thickness = 2,
    },
    TracerAll = {
        Enabled = false,
        ColorNormal = Color3.fromRGB(255, 255, 255),
        ColorDowned = Color3.fromRGB(255, 50, 50),
        Thickness = 2,
    }
}

function ESP_System:GetNextbotNames()
    if ESP_ReplicatedStorage:FindFirstChild("NPCs") then
        for _, npc in ipairs(ESP_ReplicatedStorage.NPCs:GetChildren()) do
            table.insert(self.NextbotNames, npc.Name)
        end
    end
    return self.NextbotNames
end

function ESP_System:IsNextbot(model)
    if not model or not model.Name then return false end
    for _, name in ipairs(self.NextbotNames) do
        if model.Name == name then return true end
    end
    local lowerName = model.Name:lower()
    if lowerName:find("nextbot") or lowerName:find("scp%-") or
       lowerName:find("^monster") or lowerName:find("^creep") or
       lowerName:find("^enemy") then return true end
    if ESP_Players:FindFirstChild(model.Name) then return false end
    if model:GetAttribute("IsNPC") or model:GetAttribute("Nextbot") then return true end
    return false
end

function ESP_System:GetDistanceFromPlayer(position)
    if not ESP_LocalPlayer.Character or not ESP_LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        return 0
    end
    return (position - ESP_LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
end

function ESP_System:CreatePlayerESP(player)
    if not self.Settings.Players.Enabled or player == ESP_LocalPlayer then return end
    local character = player.Character
    if not character then return end
    local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
    if not head then return end
    if self.PlayersESP[player] and self.PlayersESP[player].Parent then
        self.PlayersESP[player]:Destroy()
    end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "IRUZPlayerESP"
    billboard.Adornee = head
    billboard.Size = UDim2.new(0, 120, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3.5, 0)
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 1500
    billboard.Active = true
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Parent = head
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = player.Name
    textLabel.TextColor3 = self.Settings.Players.Color
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.RobotoMono
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    textLabel.Parent = billboard
    self.PlayersESP[player] = billboard
    return billboard
end

function ESP_System:UpdatePlayersESP()
    if not self.Settings.Players.Enabled then self:ClearPlayersESP() return end
    for player, esp in pairs(self.PlayersESP) do
        if player and player.Character and esp and esp.Parent then
            local character = player.Character
            local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
            local textLabel = esp:FindFirstChildOfClass("TextLabel")
            if head and textLabel and ESP_LocalPlayer.Character and ESP_LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local distance = self:GetDistanceFromPlayer(head.Position)
                local textColor = self.Settings.Players.Color
                local extraText = ""
                if character:FindFirstChild("Revives") then
                    textColor = Color3.fromRGB(255, 255, 0)
                    extraText = "] [Revives"
                elseif character:GetAttribute("Downed") then
                    textColor = Color3.fromRGB(255, 0, 0)
                    extraText = "] [Downed"
                end
                textLabel.Text = string.format("%s [%dm%s]", player.Name, math.floor(distance), extraText)
                textLabel.TextColor3 = textColor
            end
        else
            if esp then pcall(function() esp:Destroy() end) end
            self.PlayersESP[player] = nil
        end
    end
    for _, player in ipairs(ESP_Players:GetPlayers()) do
        if player ~= ESP_LocalPlayer and not self.PlayersESP[player] and player.Character then
            self:CreatePlayerESP(player)
        end
    end
end

function ESP_System:ClearPlayersESP()
    for _, esp in pairs(self.PlayersESP) do pcall(function() esp:Destroy() end) end
    self.PlayersESP = {}
end

function ESP_System:UpdateTicketsESP()
    if not self.Settings.Tickets.Enabled then self:ClearTicketsESP() return end
    local ticketsFound = {}
    local gameFolder = workspace:FindFirstChild("Game")
    if gameFolder then
        local effects = gameFolder:FindFirstChild("Effects")
        if effects then
            local tickets = effects:FindFirstChild("Tickets")
            if tickets then
                for _, ticket in pairs(tickets:GetChildren()) do
                    if ticket:IsA("BasePart") or ticket:IsA("Model") then
                        local part = ticket:IsA("Model") and
                            (ticket:FindFirstChild("HumanoidRootPart") or
                             ticket:FindFirstChild("Head") or
                             ticket.PrimaryPart or
                             ticket:FindFirstChildWhichIsA("BasePart")) or
                            ticket:IsA("BasePart") and ticket
                        if part then ticketsFound[ticket] = part end
                    end
                end
            end
        end
    end
    for ticket, esp in pairs(self.TicketsESP) do
        if not ticketsFound[ticket] or not ticket.Parent then
            pcall(function() esp:Destroy() end)
            self.TicketsESP[ticket] = nil
        end
    end
    for ticket, part in pairs(ticketsFound) do
        if not self.TicketsESP[ticket] then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "IRUZTicketESP"
            billboard.Adornee = part
            billboard.Size = UDim2.new(0, 100, 0, 30)
            billboard.StudsOffset = Vector3.new(0, 2, 0)
            billboard.AlwaysOnTop = true
            billboard.MaxDistance = 1000
            billboard.Parent = part
            local textLabel = Instance.new("TextLabel")
            textLabel.Size = UDim2.new(1, 0, 1, 0)
            textLabel.BackgroundTransparency = 1
            textLabel.TextColor3 = self.Settings.Tickets.Color
            textLabel.TextSize = 12
            textLabel.Font = Enum.Font.RobotoMono
            textLabel.Parent = billboard
            local stroke = Instance.new("UIStroke")
            stroke.Color = Color3.new(0, 0, 0)
            stroke.Thickness = 0.5
            stroke.Parent = textLabel
            self.TicketsESP[ticket] = billboard
        end
        local esp = self.TicketsESP[ticket]
        if esp and esp.Parent and esp:FindFirstChildOfClass("TextLabel") then
            local textLabel = esp:FindFirstChildOfClass("TextLabel")
            local distance = self:GetDistanceFromPlayer(part.Position)
            textLabel.Text = string.format("Ticket [%d m]", math.floor(distance))
        end
    end
end

function ESP_System:ClearTicketsESP()
    for _, esp in pairs(self.TicketsESP) do pcall(function() esp:Destroy() end) end
    self.TicketsESP = {}
end

function ESP_System:CreateFakePartForModel(model)
    if not model or not model:IsA("Model") then return nil end
    local fakePart = Instance.new("Part")
    fakePart.Name = "IRUZESP_Anchor"
    fakePart.Size = Vector3.new(0.1, 0.1, 0.1)
    fakePart.Transparency = 1
    fakePart.CanCollide = false
    fakePart.Anchored = true
    fakePart.Parent = model
    if model.PrimaryPart then
        fakePart.CFrame = model.PrimaryPart.CFrame
    else
        local success, center = pcall(function() return model:GetBoundingBox() end)
        if success and center then
            fakePart.CFrame = center
        else
            local firstPart = model:FindFirstChildWhichIsA("BasePart")
            if firstPart then fakePart.CFrame = firstPart.CFrame end
        end
    end
    return fakePart
end

function ESP_System:CreateNextbotESP(model, part)
    if not part then return nil end
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "IRUZNextbotESP"
    billboard.Parent = part
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.AlwaysOnTop = true
    billboard.LightInfluence = 1
    billboard.Size = UDim2.new(0, 200, 0, 50)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.MaxDistance = 1000
    local textLabel = Instance.new("TextLabel")
    textLabel.Parent = billboard
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.TextScaled = false
    textLabel.Font = Enum.Font.RobotoMono
    textLabel.TextStrokeTransparency = 0.5
    textLabel.TextSize = 16
    textLabel.TextColor3 = self.Settings.Nextbots.Color
    return billboard
end

function ESP_System:UpdateNextbotESP(model, part)
    if not part then return false end
    local esp = part:FindFirstChild("IRUZNextbotESP")
    if esp and esp:FindFirstChildOfClass("TextLabel") then
        local label = esp:FindFirstChildOfClass("TextLabel")
        local distance = self:GetDistanceFromPlayer(part.Position)
        label.Text = string.format("%s [%d m]", model.Name, math.floor(distance))
        return true
    end
    return false
end

function ESP_System:ScanNextbots()
    if not self.Settings.Nextbots.Enabled then self:ClearNextbotsESP() return end
    local nextbots = {}
    local playersFolder = workspace:FindFirstChild("Game") and workspace.Game:FindFirstChild("Players")
    if playersFolder then
        for _, model in ipairs(playersFolder:GetChildren()) do
            if model:IsA("Model") and self:IsNextbot(model) then nextbots[model] = model end
        end
    end
    local npcsFolder = workspace:FindFirstChild("NPCs")
    if npcsFolder then
        for _, model in ipairs(npcsFolder:GetChildren()) do
            if model:IsA("Model") and self:IsNextbot(model) then nextbots[model] = model end
        end
    end
    for model in pairs(nextbots) do
        if not self.NextbotsESP[model] then
            local fakePart = model:FindFirstChild("IRUZESP_Anchor") or self:CreateFakePartForModel(model)
            if fakePart then
                local esp = self:CreateNextbotESP(model, fakePart)
                if esp then
                    self:UpdateNextbotESP(model, fakePart)
                    self.NextbotsESP[model] = { esp = esp, part = fakePart, lastUpdate = tick() }
                end
            end
        else
            local data = self.NextbotsESP[model]
            if data.part and data.part.Parent == model then
                if model.PrimaryPart then
                    data.part.CFrame = model.PrimaryPart.CFrame
                else
                    local success, center = pcall(function() return model:GetBoundingBox() end)
                    if success and center then data.part.CFrame = center end
                end
                self:UpdateNextbotESP(model, data.part)
                data.lastUpdate = tick()
            else
                local fakePart = self:CreateFakePartForModel(model)
                if fakePart then
                    data.part = fakePart
                    local esp = self:CreateNextbotESP(model, fakePart)
                    if esp then
                        self:UpdateNextbotESP(model, fakePart)
                        data.esp = esp
                        data.lastUpdate = tick()
                    end
                end
            end
        end
    end
    for model, data in pairs(self.NextbotsESP) do
        if not nextbots[model] or not model.Parent then
            pcall(function()
                if data.esp then data.esp:Destroy() end
                if data.part and data.part.Name == "IRUZESP_Anchor" then data.part:Destroy() end
            end)
            self.NextbotsESP[model] = nil
        end
    end
end

function ESP_System:ClearNextbotsESP()
    for _, data in pairs(self.NextbotsESP) do
        pcall(function()
            if data.esp then data.esp:Destroy() end
            if data.part and data.part.Name == "IRUZESP_Anchor" then data.part:Destroy() end
        end)
    end
    self.NextbotsESP = {}
end

function ESP_System:CreatePlayerChams(player)
    if not self.Settings.ChamsPlayers.Enabled or player == ESP_LocalPlayer then return end
    local character = player.Character
    if not character then return end

    if self.ChamsPlayers[player] then
        pcall(function() self.ChamsPlayers[player]:Destroy() end)
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "IRUZPlayerChams"
    highlight.FillColor = self.Settings.ChamsPlayers.FillColor
    highlight.OutlineColor = self.Settings.ChamsPlayers.OutlineColor
    highlight.FillTransparency = self.Settings.ChamsPlayers.FillTransparency
    highlight.OutlineTransparency = self.Settings.ChamsPlayers.OutlineTransparency
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = character

    self.ChamsPlayers[player] = highlight
    return highlight
end

function ESP_System:UpdatePlayerChams()
    if not self.Settings.ChamsPlayers.Enabled then
        self:ClearPlayerChams()
        return
    end

    for player, highlight in pairs(self.ChamsPlayers) do
        if not player or not player.Character or not highlight.Parent then
            pcall(function() if highlight then highlight:Destroy() end end)
            self.ChamsPlayers[player] = nil
        else
            if player.Character:GetAttribute("Downed") then
                highlight.FillColor = Color3.fromRGB(255, 0, 0)
                highlight.OutlineColor = Color3.fromRGB(255, 255, 0)
            else
                highlight.FillColor = self.Settings.ChamsPlayers.FillColor
                highlight.OutlineColor = self.Settings.ChamsPlayers.OutlineColor
            end
        end
    end

    for _, player in ipairs(ESP_Players:GetPlayers()) do
        if player ~= ESP_LocalPlayer and not self.ChamsPlayers[player] and player.Character then
            self:CreatePlayerChams(player)
        end
    end
end

function ESP_System:ClearPlayerChams()
    for _, highlight in pairs(self.ChamsPlayers) do
        pcall(function() highlight:Destroy() end)
    end
    self.ChamsPlayers = {}
end

function ESP_System:UpdateTracerDowned()
    if not self.Settings.TracerDowned.Enabled then
        self:ClearTracerDowned()
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then return end
    if not ESP_LocalPlayer.Character then return end

    local screenSize = camera.ViewportSize
    local startPos = Vector2.new(screenSize.X / 2, screenSize.Y)

    local activePlayers = {}

    for _, player in ipairs(ESP_Players:GetPlayers()) do
        if player ~= ESP_LocalPlayer and player.Character then
            if player.Character:GetAttribute("Downed") then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    or player.Character:FindFirstChild("Head")
                if hrp then
                    activePlayers[player] = hrp
                end
            end
        end
    end

    for player, line in pairs(self.TracerDrawings) do
        if not activePlayers[player] then
            pcall(function() line:Remove() end)
            self.TracerDrawings[player] = nil
        end
    end

    for player, hrp in pairs(activePlayers) do
        local success, screenPos, onScreen = pcall(function()
            return camera:WorldToViewportPoint(hrp.Position)
        end)

        if success and onScreen then
            if not self.TracerDrawings[player] then
                local line = Drawing.new("Line")
                line.Visible = true
                line.Color = self.Settings.TracerDowned.Color
                line.Thickness = self.Settings.TracerDowned.Thickness
                line.Transparency = 1
                self.TracerDrawings[player] = line
            end

            local line = self.TracerDrawings[player]
            line.From = startPos
            line.To = Vector2.new(screenPos.X, screenPos.Y)
            line.Color = self.Settings.TracerDowned.Color
            line.Thickness = self.Settings.TracerDowned.Thickness
            line.Visible = true
        else
            if self.TracerDrawings[player] then
                self.TracerDrawings[player].Visible = false
            end
        end
    end
end

function ESP_System:ClearTracerDowned()
    for _, line in pairs(self.TracerDrawings) do
        pcall(function() line:Remove() end)
    end
    self.TracerDrawings = {}
end

function ESP_System:UpdateTracerAll()
    if not self.Settings.TracerAll.Enabled then
        self:ClearTracerAll()
        return
    end

    local camera = workspace.CurrentCamera
    if not camera then return end
    if not ESP_LocalPlayer.Character then return end

    local screenSize = camera.ViewportSize
    local startPos = Vector2.new(screenSize.X / 2, screenSize.Y)

    local activePlayers = {}

    for _, player in ipairs(ESP_Players:GetPlayers()) do
        if player ~= ESP_LocalPlayer and player.Character then
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                or player.Character:FindFirstChild("Head")
            if hrp then
                activePlayers[player] = {
                    hrp = hrp,
                    downed = player.Character:GetAttribute("Downed") == true
                }
            end
        end
    end

    for player, line in pairs(self.TracerAllDrawings) do
        if not activePlayers[player] then
            pcall(function() line:Remove() end)
            self.TracerAllDrawings[player] = nil
        end
    end

    for player, data in pairs(activePlayers) do
        local success, screenPos, onScreen = pcall(function()
            return camera:WorldToViewportPoint(data.hrp.Position)
        end)

        if success and onScreen then
            if not self.TracerAllDrawings[player] then
                local line = Drawing.new("Line")
                line.Visible = true
                line.Thickness = self.Settings.TracerAll.Thickness
                line.Transparency = 1
                self.TracerAllDrawings[player] = line
            end

            local line = self.TracerAllDrawings[player]
            line.From = startPos
            line.To = Vector2.new(screenPos.X, screenPos.Y)
            line.Thickness = self.Settings.TracerAll.Thickness
            line.Visible = true

            if data.downed then
                line.Color = self.Settings.TracerAll.ColorDowned
            else
                line.Color = self.Settings.TracerAll.ColorNormal
            end
        else
            if self.TracerAllDrawings[player] then
                self.TracerAllDrawings[player].Visible = false
            end
        end
    end
end

function ESP_System:ClearTracerAll()
    for _, line in pairs(self.TracerAllDrawings) do
        pcall(function() line:Remove() end)
    end
    self.TracerAllDrawings = {}
end

function ESP_System:Start()
    if self.Running then return end
    self.Running = true
    self:GetNextbotNames()
    for _, p in ipairs(ESP_Players:GetPlayers()) do
        if p ~= ESP_LocalPlayer then
            if p.Character then self:CreatePlayerESP(p) end
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                if self.Settings.Players.Enabled then self:CreatePlayerESP(p) end
            end)
        end
    end
    ESP_Players.PlayerAdded:Connect(function(p)
        if p ~= ESP_LocalPlayer then
            p.CharacterAdded:Connect(function()
                task.wait(0.5)
                if self.Settings.Players.Enabled then self:CreatePlayerESP(p) end
            end)
        end
    end)
    ESP_Players.PlayerRemoving:Connect(function(p)
        if self.PlayersESP[p] then
            pcall(function() self.PlayersESP[p]:Destroy() end)
            self.PlayersESP[p] = nil
        end
    end)
    ESP_LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if self.Running then
            self:ClearPlayersESP()
            self:ClearNextbotsESP()
            for _, p in ipairs(ESP_Players:GetPlayers()) do
                if p ~= ESP_LocalPlayer and p.Character then self:CreatePlayerESP(p) end
            end
        end
    end)
    self.Connections.Main = ESP_RunService.Heartbeat:Connect(function()
        if not self.Running then return end
        pcall(function()
            self:UpdatePlayersESP()
            self:UpdateTicketsESP()
            self:ScanNextbots()
            self:UpdatePlayerChams()
            self:UpdateTracerDowned()
            self:UpdateTracerAll()
        end)
    end)
end

function ESP_System:Stop()
    self.Running = false
    if self.Connections.Main then
        self.Connections.Main:Disconnect()
        self.Connections.Main = nil
    end
    self:ClearPlayersESP()
    self:ClearTicketsESP()
    self:ClearNextbotsESP()
    self:ClearPlayerChams()
    self:ClearTracerDowned()
    self:ClearTracerAll()
end

-- ========================================================================== --
--                            CHARACTER CONNECTIONS                            --
-- ========================================================================== --

player.CharacterAdded:Connect(function(character)
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then return end
    task.wait(0.5)
    NoclipModule.OnCharacterAdded()
    BugEmoteModule.OnCharacterAdded()
    RemoveBarriersModule.OnCharacterAdded()
    BarriersVisibleModule.OnCharacterAdded()
    FlyModule.OnCharacterAdded()
end)

-- ========================================================================== --
--                            CREATE WINDOW                                    --
-- ========================================================================== --

local Window = Library:CreateWindow({
    Title = "rzprivate - Evade",
    Footer = "by iruz | version 3.0",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Combat = Window:AddTab("Combat", "swords"),
    Teleport = Window:AddTab("Teleport", "navigation"),
    ESP = Window:AddTab("ESP", "scan-eye"),
    Movement = Window:AddTab("Movement", "activity"),
    Visual = Window:AddTab("Visual", "eye"),
    AutoFarm = Window:AddTab("Auto Farm", "zap"),
    PlayerSettings = Window:AddTab("Player Settings", "user"),
    Server = Window:AddTab("Server", "server"),
    ["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}


-- ========================================================================== --
--                            COMBAT TAB                                       --
-- ========================================================================== --

local CombatLeft = Tabs.Combat:AddLeftGroupbox("Auto Revive", "heart")
local CombatRight = Tabs.Combat:AddRightGroupbox("Weapon Enhancements", "sword")

-- AUTO REVIVE SECTION
CombatLeft:AddButton({
    Text = "Revive Yourself (Manual)",
    Tooltip = "Revive yourself manually when downed",
    Func = function()
        local char = player.Character
        if char then
            local isDowned = pcall(function() return char:GetAttribute("Downed") end)
            if isDowned then
                pcall(function()
                    ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
                end)
                Success("Revive Yourself", "Revive attempt sent!", 2)
            else
                Warning("Revive Yourself", "You are not downed!", 2)
            end
        end
    end
})

CombatLeft:AddDivider()

CombatLeft:AddDropdown("SelfReviveMethod", {
    Values = { "Spawnpoint", "Fake Revive" },
    Default = "Spawnpoint",
    Text = "Self Revive Method",
    Tooltip = "Choose auto self revive method",
    Callback = function(Value)
        AutoSelfReviveModule.SetMethod(Value)
    end
})

CombatLeft:AddToggle("AutoSelfRevive", {
    Text = "Auto Self Revive",
    Tooltip = "Automatically revive yourself when downed",
    Default = false,
})

Toggles.AutoSelfRevive:OnChanged(function()
    if Toggles.AutoSelfRevive.Value then
        AutoSelfReviveModule.Start()
    else
        AutoSelfReviveModule.Stop()
    end
end)

CombatLeft:AddDivider()

-- INSTANT REVIVE TOGGLE
CombatLeft:AddToggle("InstantRevive", {
    Text = "Instant Revive",
    Tooltip = "Automatically revive downed players in range",
    Default = false,
})

Toggles.InstantRevive:OnChanged(function()
    if Toggles.InstantRevive.Value then
        InstantReviveModule.Start()
    else
        InstantReviveModule.Stop()
    end
end)

-- REVIVE WHILE EMOTING
CombatLeft:AddToggle("ReviveWhileEmoting", {
    Text = "Revive While Emoting",
    Tooltip = "Continue reviving even when emoting",
    Default = false,
})

Toggles.ReviveWhileEmoting:OnChanged(function()
    InstantReviveModule.SetReviveWhileEmoting(Toggles.ReviveWhileEmoting.Value)
end)

-- REVIVE DELAY
CombatLeft:AddInput("ReviveDelay", {
    Default = "0.15",
    Numeric = true,
    Text = "Revive Delay (seconds)",
    Tooltip = "Lower = faster revive, but may cause lag",
    Placeholder = "0.15",
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 and num <= 1 then
            InstantReviveModule.SetDelay(num)
        else
            Error("Revive Delay", "Value must be between 0.01 and 1", 2)
        end
    end
})

-- REVIVE RANGE
CombatLeft:AddInput("ReviveRange", {
    Default = "10",
    Numeric = true,
    Text = "Revive Range (studs)",
    Tooltip = "Distance to auto-revive players",
    Placeholder = "10",
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 and num <= 100 then
            InstantReviveModule.SetRange(num)
        else
            Error("Revive Range", "Value must be between 1 and 100", 2)
        end
    end
})

-- AUTO WHISTLE SECTION
CombatLeft:AddDivider()

CombatLeft:AddToggle("AutoWhistle", {
    Text = "Auto Whistle",
    Tooltip = "Automatically whistle every 1 second",
    Default = false,
})

Toggles.AutoWhistle:OnChanged(function()
    if Toggles.AutoWhistle.Value then
        AutoWhistleModule.Start()
    else
        AutoWhistleModule.Stop()
    end
end)

CombatLeft:AddInput("AutoWhistleDelay", {
    Default = "1",
    Numeric = true,
    Text = "Whistle Delay (seconds)",
    Tooltip = "Set delay between whistles",
    Placeholder = "Enter seconds",
    Callback = function(Value)
        local num = tonumber(Value)
        if num and num > 0 then
            AutoWhistleModule.SetDelay(num)
        end
    end
})

-- WEAPON ENHANCEMENTS SECTION
CombatRight:AddButton({
    Text = "Grapplehook",
    Tooltip = "Enhance Grapplehook (infinite ammo, speed)",
    Func = function()
        GrapplehookModule.Execute()
    end
})

CombatRight:AddButton({
    Text = "Breacher (Portal Gun)",
    Tooltip = "Enhance Breacher (infinite range, no cooldown)",
    Func = function()
        BreacherModule.Execute()
    end
})

CombatRight:AddButton({
    Text = "Smoke Grenade",
    Tooltip = "Enhance Smoke Grenade (bigger cloud, faster)",
    Func = function()
        SmokeGrenadeModule.Execute()
    end
})

CombatRight:AddButton({
    Text = "Stun Baton",
    Tooltip = "Enhance Stun Baton (infinite range, no cooldown, super stun)",
    Func = function()
        StunBatonModule.Execute()
    end
})

CombatRight:AddDivider()

CombatRight:AddLabel("Status: All weapons ready to enhance", true)

-- ========================================================================== --
--                            TELEPORT TAB                                     --
-- ========================================================================== --

local TeleportLeft = Tabs.Teleport:AddLeftGroupbox("Teleport Module", "database")
local TeleportLeft2 = Tabs.Teleport:AddLeftGroupbox("Quick Teleports", "zap")
local TeleportRight = Tabs.Teleport:AddRightGroupbox("Objective Teleports", "target")
local TeleportRight2 = Tabs.Teleport:AddRightGroupbox("Player Teleports", "users")

-- MODULE STATUS
local moduleStatusLabel = TeleportLeft:AddLabel("Loading module info...", true)

local function updateModuleStatus()
    local mapName = TeleportModule.GetCurrentMap()
    local isLoaded = TeleportModule.IsLoaded()
    local hasMap = isLoaded and TeleportModule.HasMapData(mapName)
    local mapCount = TeleportModule.GetMapCount()
    local lastUpdate = TeleportModule.GetLastUpdate()
    
    local statusText = string.format(
        "Current Map: %s %s\nDatabase: %d maps | Last: %s %s",
        mapName,
        mapName == "Unknown" and "(not detected)" or (hasMap and "(✅ in database)" or "(❌ not in database)"),
        mapCount,
        lastUpdate,
        isLoaded and "| ✅ Loaded" or "| ❌ Not Loaded"
    )
    
    if moduleStatusLabel and moduleStatusLabel.SetText then
        pcall(function() moduleStatusLabel:SetText(statusText) end)
    end
end

task.spawn(function()
    while true do
        pcall(updateModuleStatus)
        task.wait(2)
    end
end)

TeleportLeft:AddButton({
    Text = "Refresh Teleport Module",
    Tooltip = "Update map database dari GitHub",
    Func = function()
        local success = TeleportModule.Refresh()
        if success then
            updateModuleStatus()
            Success("Teleport Module", "Database berhasil diupdate!", 2)
        end
    end
})

TeleportLeft:AddDivider()

TeleportLeft:AddToggle("AutoPlaceTeleporter", {
    Text = "Auto Place Every Round",
    Tooltip = "Otomatis place teleporter setiap ronde mulai",
    Default = false,
})

Toggles.AutoPlaceTeleporter:OnChanged(function()
    autoPlaceTeleporterEnabled = Toggles.AutoPlaceTeleporter.Value
    if autoPlaceTeleporterEnabled then
        Success("Auto Place", "Akan place " .. autoPlaceTeleporterType .. " teleporter setiap ronde", 3)
    end
end)

TeleportLeft:AddDropdown("TeleporterType", {
    Values = { "Far", "Sky" },
    Default = "Far",
    Text = "Teleporter Type",
    Tooltip = "Pilih tipe teleporter (Far / Sky)",
    Callback = function(Value)
        autoPlaceTeleporterType = Value
        Library:Notify({
            Title = "Type Changed",
            Description = "Auto place akan menggunakan " .. Value .. " spot",
            Time = 2
        })
    end
})

-- QUICK TELEPORTS
TeleportLeft2:AddButton({
    Text = "Teleport to Sky",
    Tooltip = "Teleport player ke spot Sky",
    Func = function()
        TeleportModule.TeleportPlayer("Sky")
    end
})

TeleportLeft2:AddButton({
    Text = "Teleport to Far",
    Tooltip = "Teleport player ke spot Far",
    Func = function()
        TeleportModule.TeleportPlayer("Far")
    end
})

TeleportLeft2:AddDivider()

TeleportLeft2:AddButton({
    Text = "Place Teleporter (Far)",
    Tooltip = "Place di spot Far untuk map saat ini",
    Func = function()
        TeleportModule.PlaceTeleporter("Far")
    end
})

TeleportLeft2:AddButton({
    Text = "Place Teleporter (Sky)",
    Tooltip = "Place di spot Sky untuk map saat ini",
    Func = function()
        TeleportModule.PlaceTeleporter("Sky")
    end
})

-- OBJECTIVE TELEPORTS
TeleportRight:AddButton({
    Text = "Teleport to Objective",
    Tooltip = "Teleport ke objective random",
    Func = function()
        TeleportFeaturesModule.TeleportToRandomObjective()
    end
})

TeleportRight:AddButton({
    Text = "Teleport to Nearest Ticket",
    Tooltip = "Teleport ke ticket terdekat",
    Func = function()
        TeleportFeaturesModule.TeleportToNearestTicket()
    end
})

-- PLAYER TELEPORTS
local selectedPlayerName = nil

local function refreshPlayerList()
    local playerList = TeleportFeaturesModule.GetPlayerList()
    if Options.PlayerDropdown then
        Options.PlayerDropdown:SetValues(playerList)
        if #playerList > 0 and playerList[1] ~= "No players available" then
            if not selectedPlayerName or not table.find(playerList, selectedPlayerName) then
                selectedPlayerName = playerList[1]
                Options.PlayerDropdown:SetValue(selectedPlayerName)
            end
        else
            selectedPlayerName = nil
        end
    end
end

TeleportRight2:AddDropdown("PlayerDropdown", {
    Values = { "Loading..." },
    Default = "Loading...",
    Multi = false,
    Text = "Select Player",
    Tooltip = "Pilih player untuk teleport",
    Searchable = true,
    Callback = function(Value)
        if Value and Value ~= "No players available" and Value ~= "Loading..." then
            selectedPlayerName = Value
        end
    end
})

task.spawn(function()
    task.wait(1)
    refreshPlayerList()
end)

Players.PlayerAdded:Connect(function()
    task.wait(1)
    refreshPlayerList()
end)

Players.PlayerRemoving:Connect(function()
    task.wait(0.5)
    refreshPlayerList()
end)

TeleportRight2:AddButton({
    Text = "Teleport to Selected Player",
    Tooltip = "Teleport ke player yang dipilih",
    Func = function()
        if selectedPlayerName and selectedPlayerName ~= "No players available" then
            TeleportFeaturesModule.TeleportToPlayer(selectedPlayerName)
        else
            Error("Teleport", "Pilih player terlebih dahulu!", 2)
        end
    end
})

TeleportRight2:AddButton({
    Text = "Refresh Player List",
    Tooltip = "Update daftar player manual",
    Func = function()
        refreshPlayerList()
        Info("Player List", "Daftar player diupdate!", 2)
    end
})

TeleportRight2:AddButton({
    Text = "Teleport to Random Player",
    Tooltip = "Teleport ke player random",
    Func = function()
        TeleportFeaturesModule.TeleportToRandomPlayer()
    end
})

TeleportRight2:AddDivider()

TeleportRight2:AddButton({
    Text = "Teleport to Nearest Downed",
    Tooltip = "Teleport ke player downed terdekat",
    Func = function()
        TeleportFeaturesModule.TeleportToNearestDowned()
    end
})

-- ========================================================================== --
--                            ESP TAB                                          --
-- ========================================================================== --

local ESPLeft = Tabs.ESP:AddLeftGroupbox("Players ESP", "users")
local ESPLeft2 = Tabs.ESP:AddLeftGroupbox("Tickets ESP", "ticket")
local ESPLeft3 = Tabs.ESP:AddLeftGroupbox("Nextbots ESP", "skull")
local ESPRight = Tabs.ESP:AddRightGroupbox("Chams - Players", "eye")
local ESPRight2 = Tabs.ESP:AddRightGroupbox("Tracers", "git-branch")
local ESPRight3 = Tabs.ESP:AddRightGroupbox("Master Control", "settings")

-- PLAYERS ESP
ESPLeft:AddToggle("PlayersESP", {
    Text = "Players ESP",
    Tooltip = "Tampilkan nama + jarak + status player lain",
    Default = false,
})

Toggles.PlayersESP:OnChanged(function()
    ESP_System.Settings.Players.Enabled = Toggles.PlayersESP.Value
    if Toggles.PlayersESP.Value then
        if not ESP_System.Running then ESP_System:Start() end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character then
                ESP_System:CreatePlayerESP(p)
            end
        end
        Success("Players ESP", "Aktif", 2)
    else
        ESP_System:ClearPlayersESP()
        if not ESP_System.Settings.Tickets.Enabled and not ESP_System.Settings.Nextbots.Enabled then
            ESP_System:Stop()
        end
        Info("Players ESP", "Dimatikan", 2)
    end
end)

ESPLeft:AddDropdown("PlayersESPColor", {
    Values = { "Putih", "Merah", "Hijau", "Biru", "Kuning", "Pink", "Cyan" },
    Default = "Putih",
    Text = "ESP Color",
    Tooltip = "Pilih warna label player",
    Callback = function(Value)
        local colors = {
            Putih  = Color3.fromRGB(255, 255, 255),
            Merah  = Color3.fromRGB(255, 50,  50),
            Hijau  = Color3.fromRGB(50,  255, 50),
            Biru   = Color3.fromRGB(50,  150, 255),
            Kuning = Color3.fromRGB(255, 255, 0),
            Pink   = Color3.fromRGB(255, 100, 255),
            Cyan   = Color3.fromRGB(0,   255, 255),
        }
        ESP_System.Settings.Players.Color = colors[Value] or Color3.fromRGB(255,255,255)
        Success("ESP Color", "Players: " .. Value, 1)
    end
})

ESPLeft:AddLabel("Info: Putih = normal\nMerah = downed\nKuning = reviving", true)

-- TICKETS ESP
ESPLeft2:AddToggle("TicketsESP", {
    Text = "Tickets ESP",
    Tooltip = "Tampilkan lokasi + jarak ticket di map",
    Default = false,
})

Toggles.TicketsESP:OnChanged(function()
    ESP_System.Settings.Tickets.Enabled = Toggles.TicketsESP.Value
    if Toggles.TicketsESP.Value then
        if not ESP_System.Running then ESP_System:Start() end
        Success("Tickets ESP", "Aktif", 2)
    else
        ESP_System:ClearTicketsESP()
        if not ESP_System.Settings.Players.Enabled and not ESP_System.Settings.Nextbots.Enabled then
            ESP_System:Stop()
        end
        Info("Tickets ESP", "Dimatikan", 2)
    end
end)

ESPLeft2:AddDropdown("TicketsESPColor", {
    Values = { "Oranye", "Putih", "Kuning", "Hijau", "Pink" },
    Default = "Oranye",
    Text = "Ticket Color",
    Tooltip = "Pilih warna label ticket",
    Callback = function(Value)
        local colors = {
            Oranye = Color3.fromRGB(255, 165, 0),
            Putih  = Color3.fromRGB(255, 255, 255),
            Kuning = Color3.fromRGB(255, 255, 0),
            Hijau  = Color3.fromRGB(50,  255, 50),
            Pink   = Color3.fromRGB(255, 100, 255),
        }
        ESP_System.Settings.Tickets.Color = colors[Value] or Color3.fromRGB(255,165,0)
        Success("ESP Color", "Tickets: " .. Value, 1)
    end
})

-- NEXTBOTS ESP
ESPLeft3:AddToggle("NextbotsESP", {
    Text = "Nextbots ESP",
    Tooltip = "Tampilkan lokasi + jarak nextbot/monster",
    Default = false,
})

Toggles.NextbotsESP:OnChanged(function()
    ESP_System.Settings.Nextbots.Enabled = Toggles.NextbotsESP.Value
    if Toggles.NextbotsESP.Value then
        if not ESP_System.Running then ESP_System:Start() end
        Success("Nextbots ESP", "Aktif", 2)
    else
        ESP_System:ClearNextbotsESP()
        if not ESP_System.Settings.Players.Enabled and not ESP_System.Settings.Tickets.Enabled then
            ESP_System:Stop()
        end
        Info("Nextbots ESP", "Dimatikan", 2)
    end
end)

ESPLeft3:AddDropdown("NextbotsESPColor", {
    Values = { "Merah", "Oranye", "Putih", "Kuning", "Pink" },
    Default = "Merah",
    Text = "Nextbot Color",
    Tooltip = "Pilih warna label nextbot",
    Callback = function(Value)
        local colors = {
            Merah  = Color3.fromRGB(255, 50,  50),
            Oranye = Color3.fromRGB(255, 165, 0),
            Putih  = Color3.fromRGB(255, 255, 255),
            Kuning = Color3.fromRGB(255, 255, 0),
            Pink   = Color3.fromRGB(255, 100, 255),
        }
        ESP_System.Settings.Nextbots.Color = colors[Value] or Color3.fromRGB(255,50,50)
        Success("ESP Color", "Nextbots: " .. Value, 1)
    end
})

-- CHAMS
ESPRight:AddToggle("ChamsPlayers", {
    Text = "Chams Players",
    Tooltip = "Highlight player terlihat melalui tembok",
    Default = false,
})

Toggles.ChamsPlayers:OnChanged(function()
    ESP_System.Settings.ChamsPlayers.Enabled = Toggles.ChamsPlayers.Value
    if Toggles.ChamsPlayers.Value then
        if not ESP_System.Running then ESP_System:Start() end
        Success("Chams", "Players Chams aktif", 2)
    else
        ESP_System:ClearPlayerChams()
        Info("Chams", "Players Chams dimatikan", 2)
    end
end)

ESPRight:AddDropdown("ChamsFillColor", {
    Values = { "Merah", "Biru", "Hijau", "Kuning", "Pink", "Cyan", "Putih", "Oranye" },
    Default = "Merah",
    Text = "Fill Color",
    Tooltip = "Warna isi body player",
    Callback = function(Value)
        local colors = {
            Merah  = Color3.fromRGB(255, 0,   0),
            Biru   = Color3.fromRGB(0,   100, 255),
            Hijau  = Color3.fromRGB(0,   255, 0),
            Kuning = Color3.fromRGB(255, 255, 0),
            Pink   = Color3.fromRGB(255, 0,   255),
            Cyan   = Color3.fromRGB(0,   255, 255),
            Putih  = Color3.fromRGB(255, 255, 255),
            Oranye = Color3.fromRGB(255, 165, 0),
        }
        ESP_System.Settings.ChamsPlayers.FillColor = colors[Value] or Color3.fromRGB(255,0,0)
        Success("Chams", "Fill color: " .. Value, 1)
    end
})

ESPRight:AddDropdown("ChamsOutlineColor", {
    Values = { "Putih", "Kuning", "Merah", "Cyan", "Hijau" },
    Default = "Putih",
    Text = "Outline Color",
    Tooltip = "Warna garis tepi body player",
    Callback = function(Value)
        local colors = {
            Putih  = Color3.fromRGB(255, 255, 255),
            Kuning = Color3.fromRGB(255, 255, 0),
            Merah  = Color3.fromRGB(255, 0,   0),
            Cyan   = Color3.fromRGB(0,   255, 255),
            Hijau  = Color3.fromRGB(0,   255, 0),
        }
        ESP_System.Settings.ChamsPlayers.OutlineColor = colors[Value] or Color3.fromRGB(255,255,255)
        Success("Chams", "Outline color: " .. Value, 1)
    end
})

ESPRight:AddDropdown("ChamsTransparency", {
    Values = { "Solid (0%)", "Tipis (30%)", "Setengah (50%)", "Transparan (70%)" },
    Default = "Setengah (50%)",
    Text = "Transparency",
    Tooltip = "Transparansi isi chams",
    Callback = function(Value)
        local levels = {
            ["Solid (0%)"]       = 0,
            ["Tipis (30%)"]      = 0.3,
            ["Setengah (50%)"]   = 0.5,
            ["Transparan (70%)"] = 0.7,
        }
        ESP_System.Settings.ChamsPlayers.FillTransparency = levels[Value] or 0.5
        Success("Chams", "Transparency: " .. Value, 1)
    end
})

-- TRACERS
ESPRight2:AddToggle("TracerDowned", {
    Text = "Tracer Downed",
    Tooltip = "Garis ke player yang SEDANG downed saja",
    Default = false,
})

Toggles.TracerDowned:OnChanged(function()
    ESP_System.Settings.TracerDowned.Enabled = Toggles.TracerDowned.Value
    if Toggles.TracerDowned.Value then
        if not ESP_System.Running then ESP_System:Start() end
        Success("Tracer", "Downed Tracer aktif", 2)
    else
        ESP_System:ClearTracerDowned()
        Info("Tracer", "Downed Tracer dimatikan", 2)
    end
end)

ESPRight2:AddDropdown("TracerDownedColor", {
    Values = { "Merah", "Kuning", "Putih", "Cyan", "Hijau", "Pink", "Oranye" },
    Default = "Merah",
    Text = "Downed Color",
    Tooltip = "Warna garis tracer downed",
    Callback = function(Value)
        local colors = {
            Merah  = Color3.fromRGB(255, 50,  50),
            Kuning = Color3.fromRGB(255, 255, 0),
            Putih  = Color3.fromRGB(255, 255, 255),
            Cyan   = Color3.fromRGB(0,   255, 255),
            Hijau  = Color3.fromRGB(50,  255, 50),
            Pink   = Color3.fromRGB(255, 100, 255),
            Oranye = Color3.fromRGB(255, 165, 0),
        }
        ESP_System.Settings.TracerDowned.Color = colors[Value] or Color3.fromRGB(255,50,50)
        Success("Tracer", "Warna: " .. Value, 1)
    end
})

ESPRight2:AddDropdown("TracerDownedThickness", {
    Values = { "Tipis (1)", "Normal (2)", "Tebal (3)", "Sangat Tebal (5)" },
    Default = "Normal (2)",
    Text = "Downed Thickness",
    Tooltip = "Ketebalan garis tracer downed",
    Callback = function(Value)
        local thickness = {
            ["Tipis (1)"]        = 1,
            ["Normal (2)"]       = 2,
            ["Tebal (3)"]        = 3,
            ["Sangat Tebal (5)"] = 5,
        }
        ESP_System.Settings.TracerDowned.Thickness = thickness[Value] or 2
        Success("Tracer", "Thickness: " .. Value, 1)
    end
})

ESPRight2:AddDivider()

ESPRight2:AddToggle("TracerAll", {
    Text = "Tracer All Players",
    Tooltip = "Garis ke SEMUA player (warna berubah saat downed)",
    Default = false,
})

Toggles.TracerAll:OnChanged(function()
    ESP_System.Settings.TracerAll.Enabled = Toggles.TracerAll.Value
    if Toggles.TracerAll.Value then
        if not ESP_System.Running then ESP_System:Start() end
        Success("Tracer", "All Players Tracer aktif", 2)
    else
        ESP_System:ClearTracerAll()
        Info("Tracer", "All Players Tracer dimatikan", 2)
    end
end)

ESPRight2:AddDropdown("TracerNormalColor", {
    Values = { "Putih", "Cyan", "Hijau", "Biru", "Kuning", "Pink", "Oranye" },
    Default = "Putih",
    Text = "Normal Color",
    Tooltip = "Warna garis saat player normal",
    Callback = function(Value)
        local colors = {
            Putih  = Color3.fromRGB(255, 255, 255),
            Cyan   = Color3.fromRGB(0,   255, 255),
            Hijau  = Color3.fromRGB(50,  255, 50),
            Biru   = Color3.fromRGB(50,  150, 255),
            Kuning = Color3.fromRGB(255, 255, 0),
            Pink   = Color3.fromRGB(255, 100, 255),
            Oranye = Color3.fromRGB(255, 165, 0),
        }
        ESP_System.Settings.TracerAll.ColorNormal = colors[Value] or Color3.fromRGB(255,255,255)
        Success("Tracer", "Normal color: " .. Value, 1)
    end
})

ESPRight2:AddDropdown("TracerAllDownedColor", {
    Values = { "Merah", "Kuning", "Oranye", "Pink", "Cyan" },
    Default = "Merah",
    Text = "All Downed Color",
    Tooltip = "Warna garis saat player downed",
    Callback = function(Value)
        local colors = {
            Merah  = Color3.fromRGB(255, 50,  50),
            Kuning = Color3.fromRGB(255, 255, 0),
            Oranye = Color3.fromRGB(255, 165, 0),
            Pink   = Color3.fromRGB(255, 100, 255),
            Cyan   = Color3.fromRGB(0,   255, 255),
        }
        ESP_System.Settings.TracerAll.ColorDowned = colors[Value] or Color3.fromRGB(255,50,50)
        Success("Tracer", "Downed color: " .. Value, 1)
    end
})

ESPRight2:AddDropdown("TracerAllThickness", {
    Values = { "Tipis (1)", "Normal (2)", "Tebal (3)", "Sangat Tebal (5)" },
    Default = "Normal (2)",
    Text = "All Thickness",
    Tooltip = "Ketebalan garis tracer",
    Callback = function(Value)
        local thickness = {
            ["Tipis (1)"]        = 1,
            ["Normal (2)"]       = 2,
            ["Tebal (3)"]        = 3,
            ["Sangat Tebal (5)"] = 5,
        }
        ESP_System.Settings.TracerAll.Thickness = thickness[Value] or 2
        Success("Tracer", "Thickness: " .. Value, 1)
    end
})

-- MASTER CONTROL
ESPRight3:AddButton({
    Text = "Enable All ESP",
    Tooltip = "Aktifkan semua ESP sekaligus",
    Func = function()
        Toggles.PlayersESP:SetValue(true)
        Toggles.TicketsESP:SetValue(true)
        Toggles.NextbotsESP:SetValue(true)
        Success("ESP", "Semua ESP diaktifkan!", 2)
    end
})

ESPRight3:AddButton({
    Text = "Disable All ESP",
    Tooltip = "Matikan semua ESP sekaligus",
    Func = function()
        Toggles.PlayersESP:SetValue(false)
        Toggles.TicketsESP:SetValue(false)
        Toggles.NextbotsESP:SetValue(false)
        Info("ESP", "Semua ESP dimatikan!", 2)
    end
})

-- ========================================================================== --
--                            AUTO FARM TAB                                    --
-- ========================================================================== --

local AutoFarmLeft = Tabs.AutoFarm:AddLeftGroupbox("Money & Tickets", "coins")
local AutoFarmRight = Tabs.AutoFarm:AddRightGroupbox("AFK Farm", "moon")

-- AUTO FARM MONEY
AutoFarmLeft:AddToggle("AutoFarmMoney", {
    Text = "Auto Farm Money",
    Tooltip = "Auto revive players to earn money (stay alive + revive = $$$)",
    Default = false,
})

Toggles.AutoFarmMoney:OnChanged(function()
    if Toggles.AutoFarmMoney.Value then
        AutoFarmMoneyModule.Start()
    else
        AutoFarmMoneyModule.Stop()
    end
end)

AutoFarmLeft:AddLabel("⚠️ Requires SecurityPart in workspace\nWill auto-revive downed players for money", true)

AutoFarmLeft:AddDivider()

-- AUTO FARM TICKETS
AutoFarmLeft:AddToggle("AutoFarmTickets", {
    Text = "Auto Farm Tickets",
    Tooltip = "Automatically collect tickets from the map",
    Default = false,
})

Toggles.AutoFarmTickets:OnChanged(function()
    if Toggles.AutoFarmTickets.Value then
        AutoFarmTicketsModule.Start()
    else
        AutoFarmTicketsModule.Stop()
    end
end)

AutoFarmLeft:AddLabel("⚠️ Will teleport to tickets automatically\nCollects all tickets on map", true)

-- AFK FARM
AutoFarmRight:AddToggle("AFKFarm", {
    Text = "AFK Farm",
    Tooltip = "Stay at safe spot (SecurityPart) to avoid death",
    Default = false,
})

Toggles.AFKFarm:OnChanged(function()
    if Toggles.AFKFarm.Value then
        AFKFarmModule.Start()
    else
        AFKFarmModule.Stop()
    end
end)

AutoFarmRight:AddLabel("💡 Info:\n• Stays at SecurityPart\n• Prevents death while AFK\n• Perfect for idle farming", true)

-- ========================================================================== --
--                            PLAYER SETTINGS TAB                              --
-- ========================================================================== --

local PlayerLeft = Tabs.PlayerSettings:AddLeftGroupbox("Movement Settings", "activity")
local PlayerRight = Tabs.PlayerSettings:AddRightGroupbox("View Settings", "eye")

-- PLAYER SPEED
PlayerLeft:AddInput("PlayerSpeed", {
    Default = "1500",
    Numeric = true,
    Text = "Player Speed",
    Tooltip = "Adjust player movement speed (1450-100000000)",
    Placeholder = "Default: 1500",
    Callback = function(Value)
        PlayerAdjustmentsModule.SetSpeed(Value)
    end
})

-- PLAYER JUMP POWER
PlayerLeft:AddInput("PlayerJumpPower", {
    Default = "3.5",
    Numeric = true,
    Text = "Jump Power",
    Tooltip = "Adjust jump height (0.1-1000)",
    Placeholder = "Default: 3.5",
    Callback = function(Value)
        JumpPowerModule.SetJumpPower(Value)
    end
})

-- PLAYER JUMP CAP
PlayerLeft:AddInput("PlayerJumpCap", {
    Default = "1",
    Numeric = true,
    Text = "Jump Cap",
    Tooltip = "Maximum jump velocity (0.1-5000000)",
    Placeholder = "Default: 1",
    Callback = function(Value)
        PlayerAdjustmentsModule.SetJumpCap(Value)
    end
})

-- PLAYER STRAFE ACCELERATION
PlayerLeft:AddInput("PlayerStrafe", {
    Default = "187",
    Numeric = true,
    Text = "Air Strafe Acceleration",
    Tooltip = "Control movement speed in air (1-1000000000)",
    Placeholder = "Default: 187",
    Callback = function(Value)
        PlayerAdjustmentsModule.SetStrafeAccel(Value)
    end
})

PlayerLeft:AddDivider()

-- APPLY METHOD
PlayerLeft:AddDropdown("ApplyMethod", {
    Values = { "Not Optimized", "Optimized" },
    Default = "Not Optimized",
    Text = "Apply Method",
    Tooltip = "Not Optimized = instant apply | Optimized = batched apply (less lag)",
    Callback = function(Value)
        PlayerAdjustmentsModule.SetApplyMode(Value)
    end
})

PlayerLeft:AddLabel("💡 Info:\n• Not Optimized = Instant changes\n• Optimized = Batched (prevents lag)", true)

-- FOV ADJUSTMENT
PlayerRight:AddInput("PlayerFOV", {
    Default = "150",
    Numeric = true,
    Text = "Field of View (FOV)",
    Tooltip = "Adjust camera FOV (1-1000)",
    Placeholder = "Default: 150",
    Callback = function(Value)
        FOVModule.SetFOV(Value)
    end
})

PlayerRight:AddLabel("⚠️ FOV Changes:\n• Only applies when you change it\n• Rejoin to reset to default\n• Higher = wider view", true)

PlayerRight:AddDivider()

-- FOV PRESETS
PlayerRight:AddDropdown("FOVPresets", {
    Values = { "100 FOV (150)", "110 FOV (200)", "120 FOV (250)", "130 FOV (300)", "140 FOV (350)", "150 FOV (400)" },
    Default = "100 FOV (150)",
    Text = "FOV Presets",
    Tooltip = "Quick FOV presets",
    Callback = function(Value)
        local fovMap = {
            ["100 FOV (150)"] = 150,
            ["110 FOV (200)"] = 200,
            ["120 FOV (250)"] = 250,
            ["130 FOV (300)"] = 300,
            ["140 FOV (350)"] = 350,
            ["150 FOV (400)"] = 400
        }
        
        local fovValue = fovMap[Value]
        if fovValue then
            FOVModule.SetFOV(fovValue)
        end
    end
})

PlayerRight:AddLabel("Quick presets for common FOV values", true)

-- ========================================================================== --
--                            MOVEMENT TAB                                     --
-- ========================================================================== --

local MovementLeft = Tabs.Movement:AddLeftGroupbox("Basic Movement", "activity")
local MovementLeft2 = Tabs.Movement:AddLeftGroupbox("Advanced Jump", "rabbit")
local MovementRight = Tabs.Movement:AddRightGroupbox("Infinite Slide", "zap")
local MovementRight2 = Tabs.Movement:AddRightGroupbox("Modifications", "settings")

-- NOCLIP
MovementLeft:AddToggle("Noclip", {
    Text = "Noclip",
    Tooltip = "Walk through walls and objects",
    Default = false,
})

Toggles.Noclip:OnChanged(function()
    if Toggles.Noclip.Value then
        NoclipModule.Start()
    else
        NoclipModule.Stop()
    end
end)

-- BUG EMOTE
MovementLeft:AddToggle("BugEmote", {
    Text = "Bug Emote (Force Sit)",
    Tooltip = "Force your character to sit",
    Default = false,
})

Toggles.BugEmote:OnChanged(function()
    if Toggles.BugEmote.Value then
        BugEmoteModule.Start()
    else
        BugEmoteModule.Stop()
    end
end)

MovementLeft:AddDivider()

-- FLY SYSTEM
MovementLeft:AddToggle("FlyActivate", {
    Text = "Activate Fly",
    Tooltip = "Enable/disable flying mode (WASD + Space/Shift)",
    Default = false,
})

Toggles.FlyActivate:OnChanged(function()
    FlyModule.Toggle(Toggles.FlyActivate.Value)
end)

MovementLeft:AddInput("FlySpeed", {
    Default = "50",
    Numeric = true,
    Text = "Fly Speed",
    Tooltip = "Set flying speed (10-500)",
    Placeholder = "Enter speed",
    Callback = function(Value)
        local success = FlyModule.SetSpeed(Value)
        if not success then
            Error("Fly System", "Invalid speed value!", 1)
        end
    end
})

MovementLeft:AddButton({
    Text = "Reset Fly",
    Tooltip = "Force stop fly if stuck",
    Func = function()
        FlyModule.Stop()
        Success("Fly System", "Fly has been reset", 2)
    end
})

MovementLeft:AddLabel("Controls:\nWASD = Move\nSpace = Up\nShift = Down\nCamera = Direction", true)

-- AUTO JUMP TYPE
MovementLeft2:AddDropdown("AutoJumpType", {
    Values = { "Bounce", "Realistic" },
    Default = "Bounce",
    Text = "Auto Jump Type",
    Tooltip = "Bounce = fast jump | Realistic = realistic jump",
    Callback = function(Value)
        AutoJumpModule.SetAutoJumpType(Value)
    end
})

-- ROTATION 360°
MovementLeft2:AddToggle("Rotation360", {
    Text = "Rotation 360°",
    Tooltip = "Rotate character 360° continuously (DO NOT use with emotes!)",
    Default = false,
})

Toggles.Rotation360:OnChanged(function()
    AutoJumpModule.ToggleRotation(Toggles.Rotation360.Value)
end)

-- BUNNY HOP TOGGLE
MovementLeft2:AddToggle("BunnyHop", {
    Text = "Bunny Hop",
    Tooltip = "Auto jump continuously",
    Default = false,
})

Toggles.BunnyHop:OnChanged(function()
    if Toggles.BunnyHop.Value then
        AutoJumpModule.Start()
    else
        AutoJumpModule.Stop()
    end
end)

-- BHOP HOLD
MovementLeft2:AddToggle("BhopHold", {
    Text = "Bhop Hold (Hold Space)",
    Tooltip = "Enable bhop only when holding Space",
    Default = false,
})

Toggles.BhopHold:OnChanged(function()
    AutoJumpModule.SetHoldEnabled(Toggles.BhopHold.Value)
end)

-- BHOP MODE
MovementLeft2:AddDropdown("BhopMode", {
    Values = { "Acceleration", "No Acceleration" },
    Default = "Acceleration",
    Text = "Bhop Mode",
    Tooltip = "Acceleration = slide effect | No Acceleration = normal",
    Callback = function(Value)
        AutoJumpModule.SetBhopMode(Value)
    end
})

-- BHOP ACCELERATION
MovementLeft2:AddInput("BhopAccel", {
    Default = "-0.5",
    Numeric = true,
    Text = "Bhop Acceleration",
    Tooltip = "Negative value for slide effect (e.g., -0.5)",
    Placeholder = "-0.5",
    Callback = function(Value)
        AutoJumpModule.SetBhopAccel(Value)
    end
})

-- JUMP COOLDOWN
MovementLeft2:AddInput("JumpCooldown", {
    Default = "0.7",
    Numeric = true,
    Text = "Jump Cooldown (seconds)",
    Tooltip = "Delay between jumps",
    Placeholder = "0.7",
    Callback = function(Value)
        AutoJumpModule.SetJumpCooldown(Value)
    end
})

-- INFINITE SLIDE
MovementRight:AddToggle("InfiniteSlide", {
    Text = "Infinite Slide",
    Tooltip = "Slide infinitely (hold Shift while running)",
    Default = false,
})

Toggles.InfiniteSlide:OnChanged(function()
    if Toggles.InfiniteSlide.Value then
        InfiniteSlideModule.Start()
    else
        InfiniteSlideModule.Stop()
    end
end)

MovementRight:AddInput("SlideSpeed", {
    Default = "-8",
    Numeric = true,
    Text = "Slide Speed",
    Tooltip = "Negative value = acceleration (e.g., -8)",
    Placeholder = "-8",
    Callback = function(Value)
        InfiniteSlideModule.SetSlideSpeed(Value)
    end
})

MovementRight:AddLabel("How to use:\n• Run (hold Shift)\n• Slide will continue infinitely\n• Adjust speed for acceleration", true)

-- BOUNCE MODIFICATION
MovementRight2:AddToggle("BounceModify", {
    Text = "Modify Bounce",
    Tooltip = "Modify player bounce speed",
    Default = false,
})

Toggles.BounceModify:OnChanged(function()
    if Toggles.BounceModify.Value then
        BounceModule.Start()
    else
        BounceModule.Stop()
    end
end)

MovementRight2:AddInput("BounceSpeed", {
    Default = "110",
    Numeric = true,
    Text = "Bounce Speed",
    Tooltip = "Player bounce walk speed (0-1000)",
    Placeholder = "110",
    Callback = function(Value)
        BounceModule.SetSpeed(Value)
    end
})

MovementRight2:AddDivider()

-- GRAVITY SYSTEM
MovementRight2:AddToggle("Gravity", {
    Text = "Gravity",
    Tooltip = "Modify workspace gravity",
    Default = false,
})

Toggles.Gravity:OnChanged(function()
    if Toggles.Gravity.Value then
        GravityModule.Start()
    else
        GravityModule.Stop()
    end
end)

MovementRight2:AddInput("GravityValue", {
    Default = "10",
    Numeric = true,
    Text = "Gravity Value",
    Tooltip = "Lower = slower fall (1-200)",
    Placeholder = "10",
    Callback = function(Value)
        GravityModule.SetGravity(Value)
    end
})

MovementRight2:AddLabel("💡 Lower gravity = slower fall\nDefault gravity: " .. GravityModule.GetOriginalGravity(), true)

-- ========================================================================== --
--                            VISUAL TAB                                       --
-- ========================================================================== --

local VisualLeft = Tabs.Visual:AddLeftGroupbox("Barriers", "shield")
local VisualLeft2 = Tabs.Visual:AddLeftGroupbox("Lighting & Atmosphere", "sun")
local VisualRight = Tabs.Visual:AddRightGroupbox("Camera & Effects", "camera")
local VisualRight2 = Tabs.Visual:AddRightGroupbox("Optimization", "zap")

-- ==================== BARRIERS ====================
VisualLeft:AddToggle("RemoveBarriers", {
    Text = "Remove Barriers",
    Tooltip = "Disable collision on invisible barriers",
    Default = false,
})

Toggles.RemoveBarriers:OnChanged(function()
    if Toggles.RemoveBarriers.Value then
        RemoveBarriersModule.Start()
    else
        RemoveBarriersModule.Stop()
    end
end)

VisualLeft:AddLabel("Remove Barriers Keybind"):AddKeyPicker("RemoveBarriersKey", {
    Default = "F",
    Text = "Remove Barriers Keybind",
    Mode = "Toggle",
    Callback = function()
        if RemoveBarriersModule.IsEnabled() then
            RemoveBarriersModule.Stop()
        else
            RemoveBarriersModule.Start()
        end
    end
})

VisualLeft:AddDivider()

VisualLeft:AddToggle("BarriersVisible", {
    Text = "Barriers Visible",
    Tooltip = "Make invisible barriers visible with color",
    Default = false,
})

Toggles.BarriersVisible:OnChanged(function()
    if Toggles.BarriersVisible.Value then
        BarriersVisibleModule.Start()
    else
        BarriersVisibleModule.Stop()
    end
end)

VisualLeft:AddLabel("Barriers Visible Keybind"):AddKeyPicker("BarriersVisibleKey", {
    Default = "G",
    Text = "Barriers Visible Keybind",
    Mode = "Toggle",
    Callback = function()
        if BarriersVisibleModule.IsEnabled() then
            BarriersVisibleModule.Stop()
        else
            BarriersVisibleModule.Start()
        end
    end
})

VisualLeft:AddDropdown("BarriersColor", {
    Values = { "Merah", "Biru", "Hijau", "Kuning", "Ungu", "Pink", "Cyan", "Oranye", "Putih", "Hitam" },
    Default = "Merah",
    Text = "Barriers Color",
    Tooltip = "Choose color for barriers",
    Callback = function(Value)
        local colors = {
            Merah  = Color3.fromRGB(255, 0,   0),
            Biru   = Color3.fromRGB(0,   100, 255),
            Hijau  = Color3.fromRGB(0,   255, 0),
            Kuning = Color3.fromRGB(255, 255, 0),
            Ungu   = Color3.fromRGB(150, 0,   255),
            Pink   = Color3.fromRGB(255, 0,   255),
            Cyan   = Color3.fromRGB(0,   255, 255),
            Oranye = Color3.fromRGB(255, 128, 0),
            Putih  = Color3.fromRGB(255, 255, 255),
            Hitam  = Color3.fromRGB(0,   0,   0),
        }
        BarriersVisibleModule.SetColor(colors[Value] or Color3.fromRGB(255,0,0))
        Success("Color Changed", "Barriers color: " .. Value, 1)
    end
})

VisualLeft:AddDropdown("BarriersTransparency", {
    Values = { 
        "1 - Solid (0%)", 
        "2 - Sedikit Transparan (20%)", 
        "3 - Transparan (40%)", 
        "4 - Setengah (50%)", 
        "5 - Agak Transparan (60%)",
        "6 - Transparan (70%)", 
        "7 - Sangat Transparan (80%)", 
        "8 - Hampir Tak Terlihat (85%)", 
        "9 - Nyaris Invisible (90%)", 
        "10 - Super Transparan (95%)" 
    },
    Default = "1 - Solid (0%)",
    Text = "Transparency",
    Tooltip = "Choose transparency level",
    Callback = function(Value)
        local level = tonumber(Value:match("%d+"))
        if level then
            BarriersVisibleModule.SetTransparencyLevel(level)
            if BarriersVisibleModule.IsEnabled() then
                local percent = Value:match("%((%d+)%%%)")
                Success("Transparency", "Barriers: " .. percent .. "% transparent", 1)
            end
        end
    end
})

-- ==================== LIGHTING ====================
VisualLeft2:AddToggle("FullBright", {
    Text = "Full Bright",
    Tooltip = "Maximize game lighting",
    Default = false,
})

Toggles.FullBright:OnChanged(function()
    VisualFeaturesModule.ToggleFullBright(Toggles.FullBright.Value)
end)

VisualLeft2:AddToggle("RemoveFog", {
    Text = "Remove Fog",
    Tooltip = "Remove fog/atmosphere effects",
    Default = false,
})

Toggles.RemoveFog:OnChanged(function()
    VisualFeaturesModule.ToggleRemoveFog(Toggles.RemoveFog.Value)
end)

VisualLeft2:AddLabel("💡 Full Bright = Maximum brightness\nRemove Fog = Clear visibility", true)

-- ==================== CAMERA & EFFECTS ====================
VisualRight:AddToggle("CameraStretch", {
    Text = "Camera Stretch",
    Tooltip = "Stretch camera view",
    Default = false,
})

Toggles.CameraStretch:OnChanged(function()
    VisualFeaturesModule.ToggleCameraStretch(Toggles.CameraStretch.Value)
end)

VisualRight:AddInput("StretchH", {
    Default = "0.8",
    Numeric = true,
    Text = "Stretch Horizontal",
    Tooltip = "Horizontal stretch value (0.1 - 2.0)",
    Placeholder = "0.8",
    Callback = function(Value)
        VisualFeaturesModule.SetStretchH(Value)
    end
})

VisualRight:AddInput("StretchV", {
    Default = "0.8",
    Numeric = true,
    Text = "Stretch Vertical",
    Tooltip = "Vertical stretch value (0.1 - 2.0)",
    Placeholder = "0.8",
    Callback = function(Value)
        VisualFeaturesModule.SetStretchV(Value)
    end
})

VisualRight:AddDivider()

-- FAKE STREAK
VisualRight:AddInput("FakeStreak", {
    Default = "",
    Numeric = true,
    Text = "Fake Streak",
    Tooltip = "Fake your streak value (visual only)",
    Placeholder = "Enter streak number",
    Callback = function(Value)
        VisualFeaturesModule.SetFakeStreak(Value)
    end
})

VisualRight:AddButton({
    Text = "Reset Streak",
    Tooltip = "Remove fake streak and return to normal",
    Func = function()
        VisualFeaturesModule.ResetStreak()
    end
})

VisualRight:AddLabel("⚠️ Fake streak is visual only\nDoes not affect actual gameplay", true)

-- ==================== OPTIMIZATION ====================
VisualRight2:AddButton({
    Text = "Anti Lag 1 - Light",
    Tooltip = "Light optimization (shadows, fog, materials)",
    Func = function()
        VisualFeaturesModule.AntiLag1()
    end
})

VisualRight2:AddButton({
    Text = "Anti Lag 2 - Aggressive",
    Tooltip = "Aggressive optimization (textures, effects, particles)",
    Func = function()
        VisualFeaturesModule.AntiLag2()
    end
})

VisualRight2:AddButton({
    Text = "Anti Lag 3 - Textures",
    Tooltip = "Focus on removing textures and decals",
    Func = function()
        VisualFeaturesModule.AntiLag3()
    end
})

VisualRight2:AddLabel("💡 Anti Lag Info:\n• Level 1 = Light (safe)\n• Level 2 = Aggressive (max FPS)\n• Level 3 = Textures only", true)

VisualRight2:AddLabel("⚠️ Warning:\nAnti Lag cannot be undone!\nYou must rejoin to restore visuals", true)

-- ========================================================================== --
--                            SERVER TAB                                       --
-- ========================================================================== --

local ServerLeft = Tabs.Server:AddLeftGroupbox("Server Info", "info")
local ServerLeft2 = Tabs.Server:AddLeftGroupbox("Quick Actions", "zap")
local ServerRight = Tabs.Server:AddRightGroupbox("Join Modes", "server")
local ServerRight2 = Tabs.Server:AddRightGroupbox("Misc Features", "package")

-- SERVER INFO
local gameModeName = "Loading..."
local gameModeLabel = ServerLeft:AddLabel("Game Mode: " .. gameModeName, false)

task.spawn(function()
    local success, productInfo = pcall(function()
        return MarketplaceService:GetProductInfo(placeId)
    end)
    if success and productInfo then
        local fullName = productInfo.Name
        if fullName:find("Evade %- ") then
            gameModeName = fullName:match("Evade %- (.+)") or fullName
        else
            gameModeName = fullName
        end
        if gameModeLabel and gameModeLabel.SetText then
            pcall(function() gameModeLabel:SetText("Game Mode: " .. gameModeName) end)
        end
    else
        gameModeName = "Unknown"
        if gameModeLabel and gameModeLabel.SetText then
            pcall(function() gameModeLabel:SetText("Game Mode: " .. gameModeName) end)
        end
    end
end)

ServerLeft:AddLabel("Current Players: " .. #Players:GetPlayers() .. " / " .. Players.MaxPlayers, false)
ServerLeft:AddLabel("Server ID: " .. jobId, true)
ServerLeft:AddLabel("Place ID: " .. tostring(placeId), false)

ServerLeft:AddButton({
    Text = "Copy Server Link",
    Tooltip = "Copy the current server's join link",
    Func = function()
        local serverLink = ServerUtils.GetServerLink()
        local success, errorMsg = pcall(function()
            setclipboard(serverLink)
        end)

        if success then
            Info("Link Copied", "Server invite link copied to clipboard!", 3)
        else
            Error("Copy Failed", "Your executor doesn't support setclipboard", 3)
            warn("Failed to copy link:", errorMsg)
        end
    end
})

-- QUICK ACTIONS
ServerLeft2:AddButton({
    Text = "Rejoin Server",
    Tooltip = "Rejoin the current server",
    Func = function()
        pcall(function()
            TeleportService:Teleport(game.PlaceId, player)
        end)
    end
})

ServerLeft2:AddButton({
    Text = "Server Hop",
    Tooltip = "Join a random server with 5+ players",
    Func = function()
        local success = ServerUtils.ServerHop(5)
        if not success then
            Library:Notify({
                Title = "Server Hop Failed",
                Description = "No servers with 5+ players found!",
                Time = 3
            })
        end
    end
})

ServerLeft2:AddButton({
    Text = "Hop to Small Server",
    Tooltip = "Hop to the emptiest available server",
    Func = function()
        local success = ServerUtils.HopToSmallestServer()
        if not success then
            Library:Notify({
                Title = "Server Hop Failed",
                Description = "Could not fetch servers!",
                Time = 3
            })
        end
    end
})

-- JOIN MODES
ServerRight:AddButton({
    Text = "Join Big Team",
    Tooltip = "Join the most populated Big Team server",
    Func = function()
        ServerUtils.JoinServerByPlaceId(10324346056, "Big Team")
    end
})

ServerRight:AddButton({
    Text = "Join Casual",
    Tooltip = "Join the most populated Casual server",
    Func = function()
        ServerUtils.JoinServerByPlaceId(10662542523, "Casual")
    end
})

ServerRight:AddButton({
    Text = "Join Social Space",
    Tooltip = "Join the most populated Social Space server",
    Func = function()
        ServerUtils.JoinServerByPlaceId(10324347967, "Social Space")
    end
})

ServerRight:AddButton({
    Text = "Join Player Nextbots",
    Tooltip = "Join the most populated Player Nextbots server",
    Func = function()
        ServerUtils.JoinServerByPlaceId(121271605799901, "Player Nextbots")
    end
})

ServerRight:AddButton({
    Text = "Join VC Only",
    Tooltip = "Join the most populated VC Only server",
    Func = function()
        ServerUtils.JoinServerByPlaceId(10808838353, "VC Only")
    end
})

ServerRight:AddButton({
    Text = "Join Pro",
    Tooltip = "Join the most populated Pro server",
    Func = function()
        ServerUtils.JoinServerByPlaceId(11353528705, "Pro")
    end
})

ServerRight:AddButton({
    Text = "Join Pro (Low Players)",
    Tooltip = "Join the emptiest Pro server",
    Func = function()
        ServerUtils.JoinLowestServer(11353528705, "Pro Low")
    end
})

ServerRight:AddDivider()

local customServerCode = ""

ServerRight:AddInput("CustomServerCode", {
    Default = "",
    Numeric = false,
    Finished = false,
    Text = "Custom Server Code",
    Tooltip = "Enter custom server passcode",
    Placeholder = "Enter custom server passcode",
    Callback = function(Value)
        customServerCode = Value
    end
})

ServerRight:AddButton({
    Text = "Join Custom Server",
    Tooltip = "Join custom server with the code above",
    Func = function()
        if customServerCode == "" then
            Library:Notify({
                Title = "Join Failed",
                Description = "Please enter a custom server code!",
                Time = 3
            })
            return
        end

        local success, result = pcall(function()
            return game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("CustomServers")
                :WaitForChild("JoinPasscode"):InvokeServer(customServerCode)
        end)

        if success then
            Library:Notify({
                Title = "Joining Custom Server",
                Description = "Attempting to join with code: " .. customServerCode,
                Time = 3
            })
        else
            Library:Notify({
                Title = "Join Failed",
                Description = "Invalid code or server unavailable!",
                Time = 3
            })
        end
    end
})

-- ==================== LAG SWITCH ====================
ServerRight2:AddToggle("LagSwitchEnable", {
    Text = "Enable Lag Switch",
    Tooltip = "Enable lag switch system",
    Default = false,
})

Toggles.LagSwitchEnable:OnChanged(function()
    LagSwitchModule.SetEnabled(Toggles.LagSwitchEnable.Value)
end)

ServerRight2:AddDropdown("LagSwitchMode", {
    Values = { "Normal", "Demon" },
    Default = "Normal",
    Text = "Lag Switch Mode",
    Tooltip = "Normal = lag only | Demon = lag + rise to sky",
    Callback = function(Value)
        LagSwitchModule.SetMode(Value)
    end
})

ServerRight2:AddInput("LagDelay", {
    Default = "0.1",
    Numeric = true,
    Text = "Lag Delay (seconds)",
    Tooltip = "Duration of lag (0.01-5 seconds)",
    Placeholder = "0.1",
    Callback = function(Value)
        LagSwitchModule.SetDelay(Value)
    end
})

ServerRight2:AddInput("LagIntensity", {
    Default = "1000000",
    Numeric = true,
    Text = "Lag Intensity",
    Tooltip = "Calculation intensity (1000-10000000)",
    Placeholder = "1000000",
    Callback = function(Value)
        LagSwitchModule.SetIntensity(Value)
    end
})

ServerRight2:AddDivider()

ServerRight2:AddInput("DemonHeight", {
    Default = "10",
    Numeric = true,
    Text = "Demon Rise Height (meters)",
    Tooltip = "How high to rise in Demon mode (10-500m)",
    Placeholder = "10",
    Callback = function(Value)
        LagSwitchModule.SetDemonHeight(Value)
    end
})

ServerRight2:AddInput("DemonSpeed", {
    Default = "80",
    Numeric = true,
    Text = "Demon Rise Speed",
    Tooltip = "Speed of rising in Demon mode (20-200)",
    Placeholder = "80",
    Callback = function(Value)
        LagSwitchModule.SetDemonSpeed(Value)
    end
})

ServerRight2:AddLabel("Lag Switch Trigger"):AddKeyPicker("LagSwitchKey", {
    Default = "F12",
    Text = "Trigger Key",
    Mode = "Press",
    Callback = function()
        if LagSwitchModule.IsEnabled() then
            LagSwitchModule.Toggle()
        else
            Warning("Lag Switch", "Enable the toggle first!", 2)
        end
    end
})

ServerRight2:AddLabel("💡 Normal Mode:\n• Creates lag via math calculations\n• Good for quick lag spikes", true)

ServerRight2:AddLabel("💡 Demon Mode:\n• Creates lag + rises to sky\n• Adjustable height & speed\n• Perfect for escaping", true)

ServerRight2:AddLabel("⚠️ Warning:\n• Don't spam (may crash)\n• Use responsibly", true)

ServerRight2:AddDivider()

ServerRight2:AddToggle("UnlockLeaderboard", {
    Text = "Unlock Leaderboard UI",
    Tooltip = "Buat custom button untuk Zoom, Front View, dan Leaderboard",
    Default = false,
})

Toggles.UnlockLeaderboard:OnChanged(function()
    if Toggles.UnlockLeaderboard.Value then
        UnlockLeaderboardModule.Create()
    else
        UnlockLeaderboardModule.Destroy()
    end
end)

ServerRight2:AddButton({
    Text = "Remove Leaderboard UI",
    Tooltip = "Hapus custom button dan kembalikan topbar normal",
    Func = function()
        UnlockLeaderboardModule.Destroy()
    end
})

-- ========================================================================== --
--                            UI SETTINGS TAB                                  --
-- ========================================================================== --

local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")

MenuGroup:AddToggle("KeybindMenuOpen", {
    Default = Library.KeybindFrame.Visible,
    Text = "Open Keybind Menu",
    Callback = function(value)
        Library.KeybindFrame.Visible = value
    end,
})

MenuGroup:AddToggle("ShowCustomCursor", {
    Text = "Custom Cursor",
    Default = true,
    Callback = function(Value)
        Library.ShowCustomCursor = Value
    end,
})

MenuGroup:AddDropdown("NotificationSide", {
    Values = { "Left", "Right" },
    Default = "Right",
    Text = "Notification Side",
    Callback = function(Value)
        Library:SetNotifySide(Value)
    end,
})

MenuGroup:AddDropdown("DPIDropdown", {
    Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
    Default = "100%",
    Text = "DPI Scale",
    Callback = function(Value)
        Value = Value:gsub("%%", "")
        local DPI = tonumber(Value)
        Library:SetDPIScale(DPI)
    end,
})

MenuGroup:AddDivider()

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { 
    Default = "RightShift", 
    NoUI = true, 
    Text = "Menu keybind" 
})

MenuGroup:AddButton("Unload", function()
    Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- ========================================================================== --
--                            THEME & SAVE MANAGER                            --
-- ========================================================================== --

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })

ThemeManager:SetFolder("rzprivate")
SaveManager:SetFolder("rzprivate/evade")

SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])

-- ========================================================================== --
--                            SIMPLE INFO DISPLAY                             --
-- ========================================================================== --

pcall(function()
    StarterGui:SetCore("TopbarEnabled", false)
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SimpleInfoDisplay"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 1000
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Parent = screenGui
mainFrame.BackgroundTransparency = 1
mainFrame.Size = UDim2.new(0, 200, 0, 80)
mainFrame.Position = UDim2.new(1, -210, 0, 10)
mainFrame.ZIndex = 10

local infoLabel = Instance.new("TextLabel")
infoLabel.Name = "InfoLabel"
infoLabel.Parent = mainFrame
infoLabel.Size = UDim2.new(1, 0, 1, 0)
infoLabel.BackgroundTransparency = 1
infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
infoLabel.TextStrokeTransparency = 0.5
infoLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
infoLabel.Font = Enum.Font.GothamBold
infoLabel.TextSize = 14
infoLabel.TextXAlignment = Enum.TextXAlignment.Right
infoLabel.TextYAlignment = Enum.TextYAlignment.Bottom
infoLabel.Text = ""
infoLabel.ZIndex = 11

local frameCount = 0
local lastFPSUpdate = tick()
local currentFPS = 0
local fpsUpdateInterval = 0.5

RunService.RenderStepped:Connect(function()
    frameCount = frameCount + 1
    
    local currentTime = tick()
    if currentTime - lastFPSUpdate >= fpsUpdateInterval then
        currentFPS = math.floor(frameCount / (currentTime - lastFPSUpdate))
        frameCount = 0
        lastFPSUpdate = currentTime
    end
    
    local timerText = "0:00"
    local gameStats = workspace:FindFirstChild("Game")
    if gameStats then
        gameStats = gameStats:FindFirstChild("Stats")
        if gameStats then
            local timerValue = gameStats:GetAttribute("Timer")
            if timerValue then
                local mins = math.floor(timerValue / 60)
                local secs = timerValue % 60
                timerText = string.format("%d:%02d", mins, secs)
            end
        end
    end
    
    infoLabel.Text = string.format("FPS: %d\nTimer: %s", currentFPS, timerText)
end)

player.CharacterAdded:Connect(function()
    task.wait(0.5)
    screenGui.Parent = player:WaitForChild("PlayerGui")
end)

-- ========================================================================== --
--                            FINAL SETUP & LOAD                              --
-- ========================================================================== -- 
task.delay(2, function()                                          
    isScriptLoading = false                                       
    Library:Notify({                                              
        Title = "✅ rzprivate - Evade",                           
        Description = "Script loaded successfully! All features ready.", 
        Time = 5,                                                 
    })                                                            
end)                                                              

Library:OnUnload(function()
    print("rzprivate - Evade unloaded!")
    
    -- ==================== COMBAT MODULES ====================
    if AutoSelfReviveModule.IsEnabled() then 
        AutoSelfReviveModule.Stop() 
    end
    
    if InstantReviveModule.IsEnabled() then 
        InstantReviveModule.Stop() 
    end
    
    if AutoWhistleModule and AutoWhistleModule.IsEnabled() then 
        AutoWhistleModule.Stop() 
    end
    
    -- ==================== MOVEMENT MODULES ====================
    if NoclipModule.IsEnabled() then 
        NoclipModule.Stop() 
    end
    
    if BugEmoteModule.IsEnabled() then 
        BugEmoteModule.Stop() 
    end
    
    if FlyModule.IsFlying() then 
        FlyModule.Stop() 
    end
    
    if AutoJumpModule and AutoJumpModule.IsEnabled() then 
        AutoJumpModule.Stop() 
    end
    
    if InfiniteSlideModule and InfiniteSlideModule.IsEnabled() then 
        InfiniteSlideModule.Stop() 
    end
    
    if BounceModule and BounceModule.IsEnabled() then 
        BounceModule.Stop() 
    end
    
    if GravityModule and GravityModule.IsEnabled() then 
        GravityModule.Stop() 
    end
    
    -- ==================== VISUAL MODULES ====================
    if RemoveBarriersModule.IsEnabled() then 
        RemoveBarriersModule.Stop() 
    end
    
    if BarriersVisibleModule.IsEnabled() then 
        BarriersVisibleModule.Stop() 
    end
    
    if VisualFeaturesModule then
        if VisualFeaturesModule.IsStretchEnabled() then
            VisualFeaturesModule.ToggleCameraStretch(false)
        end
        
        if VisualFeaturesModule.IsFullBright() then
            VisualFeaturesModule.ToggleFullBright(false)
        end
        
        if VisualFeaturesModule.IsRemoveFog() then
            VisualFeaturesModule.ToggleRemoveFog(false)
        end
    end
    
    -- ==================== AUTO FARM MODULES ====================
    if AutoFarmMoneyModule and AutoFarmMoneyModule.IsEnabled() then 
        AutoFarmMoneyModule.Stop() 
    end
    
    if AutoFarmTicketsModule and AutoFarmTicketsModule.IsEnabled() then 
        AutoFarmTicketsModule.Stop() 
    end
    
    if AFKFarmModule and AFKFarmModule.IsEnabled() then 
        AFKFarmModule.Stop() 
    end
    
    -- ==================== PLAYER SETTINGS ====================
    if JumpPowerModule and JumpPowerModule.Cleanup then
        JumpPowerModule.Cleanup()
    end
    
    -- ==================== ESP SYSTEM ====================
    if ESP_System and ESP_System.Running then 
        ESP_System:Stop() 
    end
    
    -- ==================== UI CLEANUP ====================
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
    
    pcall(function()
        StarterGui:SetCore("TopbarEnabled", true)
    end)
    
    -- ==================== FINAL MESSAGE ====================
    print("✅ All modules stopped successfully!")
    print("✅ UI cleaned up!")
    print("✅ Script unloaded!")
end)

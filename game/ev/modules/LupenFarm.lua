-- ========================================================================== --
--                      LUPEN FARM MODULE (EXTERNAL)                         --
--                    Compatible with rzprivate - Evade                      --
-- ========================================================================== --

local LupenFarm = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Module state
local moduleState = {
    Enabled = false,
    Connection = nil,
    RespawnConnection = nil,
    CurrentTarget = nil,
    Settings = {
        TeleportOffset = Vector3.new(0, 5, 0),
        PlatformOffset = Vector3.new(0, 3, 0),
        AutoRespawn = true,
        PlayerName = "Lupen"
    }
}

-- Notification system (compatible with Obsidian)
local function Notify(title, message, duration)
    if _G.RZPrivateLibrary then
        pcall(function()
            _G.RZPrivateLibrary:Notify({
                Title = title,
                Description = message,
                Time = duration or 2,
            })
        end)
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = title,
                Text = message,
                Duration = duration or 2
            })
        end)
    end
end

local function Success(title, message, duration)
    Notify(title, message, duration)
end

local function Info(title, message, duration)
    Notify("ℹ️ " .. title, message, duration)
end

local function Warning(title, message, duration)
    Notify("⚠️ " .. title, message, duration)
end

-- Safe function to find or create platform
local function findOrCreatePlatform()
    local platform = Workspace:FindFirstChild("SecurityPart")
    
    if not platform then
        local success, result = pcall(function()
            local newPlatform = Instance.new("Part")
            newPlatform.Name = "SecurityPart"
            newPlatform.Size = Vector3.new(10, 1, 10)
            newPlatform.Position = Vector3.new(5000, 5000, 5000)
            newPlatform.Anchored = true
            newPlatform.CanCollide = true
            newPlatform.Material = Enum.Material.Neon
            newPlatform.BrickColor = BrickColor.new("Bright red")
            newPlatform.Parent = Workspace
            return newPlatform
        end)
        
        if success then
            platform = result
        end
    end
    
    return platform
end

-- Safe teleport to platform
local function teleportToPlatform()
    local success, result = pcall(function()
        local character = LocalPlayer.Character
        if not character then return false end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return false end
        
        local platform = findOrCreatePlatform()
        if platform then
            humanoidRootPart.CFrame = platform.CFrame + moduleState.Settings.PlatformOffset
            return true
        end
        return false
    end)
    
    return success and result or false
end

-- Safe function to find Lupen
local function findLupen()
    local success, result = pcall(function()
        -- Search in Game.Players
        local gamePlayers = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Players")
        if gamePlayers then
            for _, obj in ipairs(gamePlayers:GetChildren()) do
                if obj:IsA("Model") then
                    local name = obj.Name:lower()
                    if name:find(moduleState.Settings.PlayerName:lower()) then
                        return obj
                    end
                end
            end
        end
        
        -- Search in NPCs
        local npcs = Workspace:FindFirstChild("NPCs")
        if npcs then
            for _, obj in ipairs(npcs:GetChildren()) do
                if obj:IsA("Model") then
                    local name = obj.Name:lower()
                    if name:find(moduleState.Settings.PlayerName:lower()) then
                        return obj
                    end
                end
            end
        end
        
        return nil
    end)
    
    return success and result or nil
end

-- Safe get root part
local function safeGetRootPart(model)
    if not model then return nil end
    
    local success, result = pcall(function()
        return model:FindFirstChild("HumanoidRootPart") or
               model:FindFirstChild("Head") or
               model:FindFirstChild("Torso") or
               model:FindFirstChild("UpperTorso") or
               model.PrimaryPart or
               model:FindFirstChildWhichIsA("BasePart")
    end)
    
    return success and result or nil
end

-- Safe teleport to Lupen
local function teleportToLupen(lupen)
    local success, result = pcall(function()
        local character = LocalPlayer.Character
        if not character then return false end
        
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return false end
        
        local lupenRoot = safeGetRootPart(lupen)
        if not lupenRoot then return false end
        
        humanoidRootPart.CFrame = lupenRoot.CFrame + moduleState.Settings.TeleportOffset
        return true
    end)
    
    return success and result or false
end

-- Check if player is downed
local function isPlayerDowned()
    local success, result = pcall(function()
        local character = LocalPlayer.Character
        if not character then return true end
        
        if character:GetAttribute("Downed") then
            return true
        end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            return humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead
        end
        
        return false
    end)
    
    return success and result or false
end

-- Safe respawn player
local function respawnPlayer()
    if not moduleState.Settings.AutoRespawn then return false end
    
    local success = pcall(function()
        if ReplicatedStorage and 
           ReplicatedStorage:FindFirstChild("Events") and
           ReplicatedStorage.Events:FindFirstChild("Player") and
           ReplicatedStorage.Events.Player:FindFirstChild("ChangePlayerMode") then
            ReplicatedStorage.Events.Player.ChangePlayerMode:FireServer(true)
        end
    end)
    
    return success
end

-- Main update loop
local function updateFarm()
    if not moduleState.Enabled then return end
    
    pcall(function()
        if isPlayerDowned() then
            respawnPlayer()
            task.wait(1)
            teleportToPlatform()
            return
        end
        
        local lupen = findLupen()
        
        if lupen then
            if not moduleState.CurrentTarget or moduleState.CurrentTarget ~= lupen then
                moduleState.CurrentTarget = lupen
            end
            teleportToLupen(lupen)
        else
            if moduleState.CurrentTarget then
                moduleState.CurrentTarget = nil
                teleportToPlatform()
            end
        end
    end)
end

-- Public methods
function LupenFarm:Start()
    if moduleState.Enabled then return true end
    
    moduleState.Enabled = true
    moduleState.CurrentTarget = nil
    
    -- Teleport to platform
    teleportToPlatform()
    
    -- Clear old connections
    if moduleState.Connection then
        pcall(function() moduleState.Connection:Disconnect() end)
        moduleState.Connection = nil
    end
    
    if moduleState.RespawnConnection then
        pcall(function() moduleState.RespawnConnection:Disconnect() end)
        moduleState.RespawnConnection = nil
    end
    
    -- New connections
    moduleState.Connection = RunService.Heartbeat:Connect(function()
        updateFarm()
    end)
    
    moduleState.RespawnConnection = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(1)
        if moduleState.Enabled then
            teleportToPlatform()
        end
    end)
    
    Success("Auto Farm Lupen", "Enabled - Will teleport to " .. moduleState.Settings.PlayerName, 3)
    
    return true
end

function LupenFarm:Stop()
    if not moduleState.Enabled then return true end
    
    moduleState.Enabled = false
    moduleState.CurrentTarget = nil
    
    -- Disconnect connections
    if moduleState.Connection then
        pcall(function() moduleState.Connection:Disconnect() end)
        moduleState.Connection = nil
    end
    
    if moduleState.RespawnConnection then
        pcall(function() moduleState.RespawnConnection:Disconnect() end)
        moduleState.RespawnConnection = nil
    end
    
    -- Return to platform
    teleportToPlatform()
    
    Info("Auto Farm Lupen", "Disabled", 2)
    
    return true
end

function LupenFarm:IsEnabled()
    return moduleState.Enabled
end

function LupenFarm:GetCurrentTarget()
    return moduleState.CurrentTarget
end

function LupenFarm:SetPlayerName(name)
    moduleState.Settings.PlayerName = name
    Info("Auto Farm Lupen", "Target player set to: " .. name, 2)
end

function LupenFarm:SetAutoRespawn(enabled)
    moduleState.Settings.AutoRespawn = enabled
end

function LupenFarm:RefreshPlatform()
    return teleportToPlatform()
end

return LupenFarm

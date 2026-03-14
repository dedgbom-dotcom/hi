-- ========================================================================== --
--                      LUPEN ESP MODULE (EXTERNAL)                          --
--                    Compatible with rzprivate - Evade                      --
-- ========================================================================== --

local LupenESP = {}

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Internal state
local moduleState = {
    Enabled = false,
    Highlight = nil,
    Billboard = nil,
    Tracer = nil,
    Connection = nil,
    MonitorConnection = nil,
    ChildAddedConnection = nil,
    ChildRemovedConnection = nil,
    PlayerName = "Lupen"
}

-- Notification system (compatible with Obsidian)
local function Notify(title, message, duration)
    -- Try Library notification first (Obsidian)
    if _G.RZPrivateLibrary then
        pcall(function()
            _G.RZPrivateLibrary:Notify({
                Title = title,
                Description = message,
                Time = duration or 2,
            })
        end)
    else
        -- Fallback to StarterGui
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

-- Function to create green ESP for Lupen
local function createLupenESP()
    -- Clear previous objects
    if moduleState.Highlight then
        pcall(function() moduleState.Highlight:Destroy() end)
        moduleState.Highlight = nil
    end
    
    if moduleState.Billboard then
        pcall(function() moduleState.Billboard:Destroy() end)
        moduleState.Billboard = nil
    end
    
    if moduleState.Tracer then
        pcall(function() moduleState.Tracer:Remove() end)
        moduleState.Tracer = nil
    end
    
    -- Find Lupen in workspace.Game.Players
    local gamePlayers = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Players")
    if not gamePlayers then return false end
    
    local lupenModel = gamePlayers:FindFirstChild(moduleState.PlayerName)
    if not lupenModel then return false end
    
    -- Find HumanoidRootPart for positioning
    local hrp = lupenModel:FindFirstChild("HumanoidRootPart") or 
                lupenModel:FindFirstChild("Torso") or 
                lupenModel:FindFirstChild("UpperTorso") or
                lupenModel:FindFirstChild("Head")
    
    if not hrp then return false end
    
    -- ===== 1. CREATE HIGHLIGHT (GREEN GLOW) =====
    local highlight = Instance.new("Highlight")
    highlight.Name = "LupenHighlight"
    highlight.Adornee = lupenModel
    highlight.FillColor = Color3.fromRGB(0, 255, 0)  -- Green
    highlight.FillTransparency = 0.3
    highlight.OutlineColor = Color3.fromRGB(0, 200, 0)
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Parent = lupenModel
    
    moduleState.Highlight = highlight
    
    -- ===== 2. CREATE BILLBOARD GUI (TEXT ABOVE HEAD) =====
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "LupenESP"
    billboard.Adornee = hrp
    billboard.Size = UDim2.new(0, 200, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.ClipsDescendants = false
    
    local mainLabel = Instance.new("TextLabel")
    mainLabel.Name = "MainLabel"
    mainLabel.Size = UDim2.new(1, 0, 1, 0)
    mainLabel.BackgroundTransparency = 1
    mainLabel.Text = "Lupen"
    mainLabel.TextColor3 = Color3.fromRGB(0, 255, 0)  -- Green
    mainLabel.TextStrokeColor3 = Color3.fromRGB(0, 100, 0)
    mainLabel.TextStrokeTransparency = 0
    mainLabel.TextSize = 16
    mainLabel.Font = Enum.Font.RobotoMono
    mainLabel.TextXAlignment = Enum.TextXAlignment.Center
    mainLabel.TextYAlignment = Enum.TextYAlignment.Center
    mainLabel.Parent = billboard
    
    billboard.Parent = lupenModel
    
    moduleState.Billboard = billboard
    
    -- ===== 3. CREATE TRACER (GREEN LINE) =====
    local tracer = Drawing.new("Line")
    tracer.Visible = false
    tracer.Thickness = 2
    tracer.Color = Color3.fromRGB(0, 255, 0)  -- Green
    tracer.Transparency = 1
    tracer.ZIndex = 2
    
    moduleState.Tracer = tracer
    
    -- Function to update distance and Tracer
    local function updateDistanceAndTracer()
        if not moduleState.Enabled or not billboard or not billboard.Parent then return end
        
        local character = LocalPlayer.Character
        if not character then return end
        
        local playerHRP = character:FindFirstChild("HumanoidRootPart")
        local camera = Workspace.CurrentCamera
        if not camera then return end
        
        -- Update HRP reference if needed
        if not hrp or not hrp.Parent then
            hrp = lupenModel:FindFirstChild("HumanoidRootPart") or 
                  lupenModel:FindFirstChild("Torso") or 
                  lupenModel:FindFirstChild("UpperTorso") or
                  lupenModel:FindFirstChild("Head")
            if hrp then
                billboard.Adornee = hrp
            else
                return
            end
        end
        
        -- Update distance in text
        if hrp and playerHRP then
            local distance = (playerHRP.Position - hrp.Position).Magnitude
            mainLabel.Text = string.format("Lupen - [%.0fm]", distance)
        end
        
        -- Update Tracer
        if tracer and hrp and playerHRP and camera then
            local screenBottomCenter = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
            local vector, onScreen = camera:WorldToViewportPoint(hrp.Position)
            
            if onScreen then
                tracer.Visible = true
                tracer.From = screenBottomCenter
                tracer.To = Vector2.new(vector.X, vector.Y)
            else
                tracer.Visible = false
            end
        end
    end
    
    -- Start update loop
    if moduleState.Connection then
        moduleState.Connection:Disconnect()
    end
    
    moduleState.Connection = RunService.RenderStepped:Connect(function()
        if moduleState.Enabled and billboard and billboard.Parent then
            updateDistanceAndTracer()
        end
    end)
    
    return true
end

-- Function to remove Lupen ESP
local function removeLupenESP()
    if moduleState.Highlight then
        pcall(function() moduleState.Highlight:Destroy() end)
        moduleState.Highlight = nil
    end
    
    if moduleState.Billboard then
        pcall(function() moduleState.Billboard:Destroy() end)
        moduleState.Billboard = nil
    end
    
    if moduleState.Tracer then
        pcall(function() moduleState.Tracer:Remove() end)
        moduleState.Tracer = nil
    end
    
    if moduleState.Connection then
        moduleState.Connection:Disconnect()
        moduleState.Connection = nil
    end
end

-- Function to check for Lupen and apply ESP
local function checkForLupen()
    if not moduleState.Enabled then return end
    
    local gamePlayers = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Players")
    if not gamePlayers then return end
    
    local lupenModel = gamePlayers:FindFirstChild(moduleState.PlayerName)
    
    if lupenModel and not (moduleState.Highlight and moduleState.Highlight.Parent) then
        -- Lupen appeared and ESP not created yet
        createLupenESP()
    elseif not lupenModel and (moduleState.Highlight or moduleState.Billboard or moduleState.Tracer) then
        -- Lupen disappeared, remove ESP
        removeLupenESP()
    end
end

-- Public methods
function LupenESP:Start()
    if moduleState.Enabled then return end
    
    moduleState.Enabled = true
    
    -- Check immediately
    checkForLupen()
    
    -- Monitor for Lupen appearance
    local gamePlayers = Workspace:FindFirstChild("Game") and Workspace.Game:FindFirstChild("Players")
    if gamePlayers then
        -- Track new players being added
        moduleState.ChildAddedConnection = gamePlayers.ChildAdded:Connect(function(child)
            if moduleState.Enabled and child.Name == moduleState.PlayerName then
                task.wait(0.5) -- Give time to load
                checkForLupen()
            end
        end)
        
        -- Track players being removed
        moduleState.ChildRemovedConnection = gamePlayers.ChildRemoved:Connect(function(child)
            if moduleState.Enabled and child.Name == moduleState.PlayerName then
                removeLupenESP()
            end
        end)
    end
    
    -- Also check every 2 seconds for reliability
    moduleState.MonitorConnection = RunService.Heartbeat:Connect(function()
        if moduleState.Enabled then
            checkForLupen()
        end
    end)
    
    Success("Lupen ESP", "Enabled - Green highlight for Lupen", 2)
end

function LupenESP:Stop()
    if not moduleState.Enabled then return end
    
    moduleState.Enabled = false
    
    -- Remove ESP
    removeLupenESP()
    
    -- Disconnect all connections
    if moduleState.MonitorConnection then
        moduleState.MonitorConnection:Disconnect()
        moduleState.MonitorConnection = nil
    end
    
    if moduleState.ChildAddedConnection then
        moduleState.ChildAddedConnection:Disconnect()
        moduleState.ChildAddedConnection = nil
    end
    
    if moduleState.ChildRemovedConnection then
        moduleState.ChildRemovedConnection:Disconnect()
        moduleState.ChildRemovedConnection = nil
    end
    
    Info("Lupen ESP", "Disabled", 2)
end

function LupenESP:Refresh()
    if moduleState.Enabled then
        removeLupenESP()
        task.wait(0.2)
        checkForLupen()
    end
end

function LupenESP:IsEnabled()
    return moduleState.Enabled
end

function LupenESP:SetPlayerName(name)
    moduleState.PlayerName = name
    if moduleState.Enabled then
        self:Refresh()
    end
end

-- Auto-refresh on player respawn
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(2)
    if moduleState.Enabled then
        checkForLupen()
    end
end)

return LupenESP

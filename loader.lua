local GITHUB_BASE = "https://raw.githubusercontent.com/Bagah-Project/bagah-hub-public/main"


local SUPPORTED_GAMES = {
    ["Evade"] = {
        script = "/games/evade/main.lua",
        placeIds = {
            10324346056,     -- Big Team
            9872472334,      -- Evade
            10662542523,     -- Casual
            10324347967,     -- Social Space
            121271605799901, -- Player Nextbots
            10808838353,     -- VC Only
            11353528705,     -- Pro
            99214917572799,  -- Custom Servers
        }
    },
    ["Evade Legacy"] = {
        script = "/games/evadelegacy/main.lua",
        placeIds = { 96537472072550 }
    },
}

local UNIVERSAL_SCRIPT = "/universal/main.lua"


local function createLoadingUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "BagahLoader"
    ScreenGui.DisplayOrder = 999
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = game:GetService("CoreGui")
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 320, 0, 140)
    Frame.Position = UDim2.new(0.5, -160, 0.5, -70)
    Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    Frame.BorderSizePixel = 0

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 8)
    Corner.Parent = Frame

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, -20, 0, 30)
    Title.Position = UDim2.new(0, 10, 0, 10)
    Title.BackgroundTransparency = 1
    Title.Text = "BagahHub Loader"
    Title.TextColor3 = Color3.fromRGB(255, 255, 255)
    Title.TextSize = 18
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left
    Title.Parent = Frame

    local Status = Instance.new("TextLabel")
    Status.Size = UDim2.new(1, -20, 0, 20)
    Status.Position = UDim2.new(0, 10, 0, 50)
    Status.BackgroundTransparency = 1
    Status.Text = "Initializing..."
    Status.TextColor3 = Color3.fromRGB(200, 200, 200)
    Status.TextSize = 14
    Status.Font = Enum.Font.Gotham
    Status.TextXAlignment = Enum.TextXAlignment.Left
    Status.Parent = Frame

    local GameName = Instance.new("TextLabel")
    GameName.Size = UDim2.new(1, -20, 0, 16)
    GameName.Position = UDim2.new(0, 10, 0, 75)
    GameName.BackgroundTransparency = 1
    GameName.Text = "Detecting game..."
    GameName.TextColor3 = Color3.fromRGB(150, 150, 150)
    GameName.TextSize = 12
    GameName.Font = Enum.Font.Gotham
    GameName.TextXAlignment = Enum.TextXAlignment.Left
    GameName.Parent = Frame

    local ProgressBG = Instance.new("Frame")
    ProgressBG.Size = UDim2.new(1, -20, 0, 4)
    ProgressBG.Position = UDim2.new(0, 10, 0, 110)
    ProgressBG.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    ProgressBG.BorderSizePixel = 0

    local ProgressCorner = Instance.new("UICorner")
    ProgressCorner.CornerRadius = UDim.new(0, 2)
    ProgressCorner.Parent = ProgressBG

    local Progress = Instance.new("Frame")
    Progress.Size = UDim2.new(0, 0, 1, 0)
    Progress.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    Progress.BorderSizePixel = 0

    local FillCorner = Instance.new("UICorner")
    FillCorner.CornerRadius = UDim.new(0, 2)
    FillCorner.Parent = Progress

    Progress.Parent = ProgressBG
    ProgressBG.Parent = Frame
    Frame.Parent = ScreenGui

    local function updateStatus(text)
        Status.Text = text
    end

    local function updateGame(text)
        GameName.Text = text
    end

    local function updateProgress(percent)
        Progress:TweenSize(
            UDim2.new(percent, 0, 1, 0),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Quad,
            0.3,
            true
        )
    end

    local function close()
        ScreenGui:Destroy()
    end

    return {
        updateStatus = updateStatus,
        updateGame = updateGame,
        updateProgress = updateProgress,
        close = close
    }
end

local function fetchScript(url)
    local cacheBuster = string.format("?v=%d&r=%d&t=%d",
        tick() * 1000,
        math.random(100000, 999999),
        os.time()
    )

    local success, result = pcall(function()
        return game:HttpGet(url .. cacheBuster, true)
    end)
    return success and result or nil
end


local function main()
    local ui = createLoadingUI()
    ui.updateStatus("Detecting game...")
    ui.updateProgress(0.2)
    task.wait(0.3)

    local currentPlaceId = game.PlaceId
    local selectedGame = nil
    local scriptPath = nil

    for gameName, gameData in pairs(SUPPORTED_GAMES) do
        for _, placeId in ipairs(gameData.placeIds) do
            if currentPlaceId == placeId then
                selectedGame = gameName
                scriptPath = gameData.script
                ui.updateGame("Game: " .. gameName)
                break
            end
        end
        if selectedGame then break end
    end

    if not selectedGame then
        selectedGame = "Universal"
        scriptPath = UNIVERSAL_SCRIPT
        ui.updateGame("Game: Universal Script")
    end

    ui.updateStatus("Fetching script...")
    ui.updateProgress(0.4)
    task.wait(0.2)

    local scriptUrl = GITHUB_BASE .. scriptPath
    local scriptContent = fetchScript(scriptUrl)

    if not scriptContent then
        ui.updateStatus("❌ Failed to fetch script")
        ui.updateGame("Check your connection")
        task.wait(3)
        ui.close()
        return
    end

    ui.updateStatus("Loading " .. selectedGame .. "...")
    ui.updateProgress(0.7)
    task.wait(0.2)

    local success, err = pcall(function()
        loadstring(scriptContent)()
    end)

    if success then
        ui.updateStatus("✅ " .. selectedGame .. " loaded!")
        ui.updateProgress(1)

        -- Setup auto-reexecute (DISABLED - causes bugs)
        --[[
        local queueTeleport = syn and syn.queue_on_teleport or queue_on_teleport
        if queueTeleport then
            queueTeleport("loadstring(game:HttpGet('" .. GITHUB_BASE .. "/mainloader.lua', true))()")
        end
        ]]

        task.wait(2)
        ui.close()

        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "rzprivate",
            Text = selectedGame .. " loaded successfully!",
            Duration = 3
        })
    else
        ui.updateStatus("❌ Failed to load")
        ui.updateGame("Error: " .. tostring(err))
        task.wait(5)
        ui.close()
    end
end


main()

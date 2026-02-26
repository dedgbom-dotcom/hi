-- =========================================================
-- SMART LOADER WITH GAME DETECTION
-- =========================================================

-- Konfigurasi Game
local supportedGames = {
    -- Evade Games
    evade = {
        name = "Evade",
        ids = {
            9872472334,        -- Evade
            10324346056,       -- Big Team
            10662542523,       -- Casual
            99214917572799,    -- Custom Server
            96537472072550,    -- Legacy
            121271605799901,   -- Player-Nextbots
            11353528705,       -- Pro
            10324347967,       -- Social-Space
            10808838353        -- VC-Only
        },
        script = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/main/AutoKataV2.lua" -- Ganti dengan URL script Evade
    },
    
    -- Sambung Kata Game
    sambungKata = {
        name = "Sambung-Kata",
        ids = {
            130342654546662    -- Sambung-Kata
        },
        script = "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/main/AutoKataV2.lua" -- Ganti dengan URL script Sambung Kata
    }
}

-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local StarterGui = game:GetService("StarterGui")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- UI Library (Rayfield)
local Rayfield = nil

-- Variables
local currentGame = nil
local gameDetected = false
local loaderGui = nil

-- =========================================================
-- FUNGSI NOTIFIKASI
-- =========================================================
local function showNotification(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title or "Loader",
            Text = text or "",
            Duration = duration or 5
        })
    end)
end

-- =========================================================
-- FUNGSI DETEKSI GAME
-- =========================================================
local function detectCurrentGame()
    local placeId = game.PlaceId
    local gameId = tostring(placeId)
    
    print("🔍 Mendeteksi game...")
    print("📍 Place ID: " .. gameId)
    
    -- Cek di semua game yang didukung
    for gameKey, gameData in pairs(supportedGames) do
        for _, id in ipairs(gameData.ids) do
            if tostring(id) == gameId then
                currentGame = {
                    key = gameKey,
                    name = gameData.name,
                    script = gameData.script,
                    placeId = placeId
                }
                gameDetected = true
                
                print("✅ Game terdeteksi: " .. gameData.name)
                return true
            end
        end
    end
    
    print("❌ Game tidak terdeteksi dalam daftar supported")
    return false
end

-- =========================================================
-- FUNGSI LOADING GUI
-- =========================================================
local function createLoadingGUI()
    -- Hapus GUI lama jika ada
    if loaderGui and loaderGui.Parent then
        loaderGui:Destroy()
    end
    
    loaderGui = Instance.new("ScreenGui")
    loaderGui.Name = "LoaderGUI"
    loaderGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    loaderGui.ResetOnSpawn = false
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 400, 0, 200)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -100)
    mainFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.15)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = loaderGui
    
    -- Rounded Corners
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Stroke/Outline
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.new(0.3, 0.6, 1)
    stroke.Transparency = 0.5
    stroke.Parent = mainFrame
    
    -- Title
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0.25, 0)
    title.Position = UDim2.new(0, 0, 0.1, 0)
    title.BackgroundTransparency = 1
    title.Text = "🎮 GAME DETECTOR"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.TextScaled = true
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    -- Game Status
    local gameStatus = Instance.new("TextLabel")
    gameStatus.Name = "GameStatus"
    gameStatus.Size = UDim2.new(0.9, 0, 0.2, 0)
    gameStatus.Position = UDim2.new(0.05, 0, 0.35, 0)
    gameStatus.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
    gameStatus.BackgroundTransparency = 0.3
    gameStatus.Text = "🔍 Mendeteksi game..."
    gameStatus.TextColor3 = Color3.new(1, 1, 0)
    gameStatus.TextScaled = true
    gameStatus.Font = Enum.Font.Gotham
    gameStatus.Parent = mainFrame
    
    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = gameStatus
    
    -- Place ID Info
    local placeIdLabel = Instance.new("TextLabel")
    placeIdLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
    placeIdLabel.Position = UDim2.new(0.05, 0, 0.6, 0)
    placeIdLabel.BackgroundTransparency = 1
    placeIdLabel.Text = "Place ID: " .. game.PlaceId
    placeIdLabel.TextColor3 = Color3.new(0.8, 0.8, 0.8)
    placeIdLabel.TextScaled = true
    placeIdLabel.Font = Enum.Font.Gotham
    placeIdLabel.Parent = mainFrame
    
    -- Progress Bar Background
    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(0.9, 0, 0.1, 0)
    progressBg.Position = UDim2.new(0.05, 0, 0.8, 0)
    progressBg.BackgroundColor3 = Color3.new(0.3, 0.3, 0.3)
    progressBg.Parent = mainFrame
    
    local progressCorner = Instance.new("UICorner")
    progressCorner.CornerRadius = UDim.new(0, 4)
    progressCorner.Parent = progressBg
    
    -- Progress Bar Fill
    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = Color3.new(0.2, 0.8, 0.2)
    progressFill.Parent = progressBg
    
    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(0, 4)
    fillCorner.Parent = progressFill
    
    return {
        MainFrame = mainFrame,
        GameStatus = gameStatus,
        ProgressFill = progressFill,
        PlaceIdLabel = placeIdLabel
    }
end

-- =========================================================
-- FUNGSI UPDATE LOADING
-- =========================================================
local function updateLoading(guiElements, status, progress, color)
    if not guiElements then return end
    
    pcall(function()
        guiElements.GameStatus.Text = status or "Loading..."
        guiElements.GameStatus.TextColor3 = color or Color3.new(1, 1, 0)
        
        if progress then
            local tweenService = game:GetService("TweenService")
            local tween = tweenService:Create(
                guiElements.ProgressFill,
                TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
                {Size = UDim2.new(progress, 0, 1, 0)}
            )
            tween:Play()
        end
    end)
end

-- =========================================================
-- FUNGSI LOAD SCRIPT
-- =========================================================
local function loadGameScript(gameData)
    local gui = createLoadingGUI()
    
    -- Deteksi game
    updateLoading(gui, "📋 Game: " .. gameData.name, 0.2, Color3.new(0.2, 0.8, 1))
    task.wait(1)
    
    updateLoading(gui, "⬇️ Mendownload script...", 0.4, Color3.new(1, 1, 0))
    
    -- Download script
    local success, scriptSource = pcall(function()
        return game:HttpGet(gameData.script)
    end)
    
    if not success or not scriptSource then
        updateLoading(gui, "❌ Gagal download script!", 0, Color3.new(1, 0, 0))
        task.wait(2)
        gui.MainFrame.Parent:Destroy()
        showNotification("Loader Error", "Gagal mendownload script!", 5)
        return false
    end
    
    updateLoading(gui, "🔧 Menyiapkan script...", 0.7, Color3.new(1, 1, 0))
    task.wait(0.5)
    
    -- Compile script
    local loadFunction, compileError = loadstring(scriptSource)
    
    if not loadFunction then
        updateLoading(gui, "❌ Error kompilasi!", 0, Color3.new(1, 0, 0))
        task.wait(2)
        gui.MainFrame.Parent:Destroy()
        showNotification("Loader Error", "Error: " .. tostring(compileError), 8)
        return false
    end
    
    updateLoading(gui, "✅ Berhasil! Menjalankan...", 1, Color3.new(0.2, 1, 0.2))
    task.wait(1)
    
    -- Hapus GUI
    gui.MainFrame.Parent:Destroy()
    
    -- Jalankan script
    local execSuccess, execError = pcall(loadFunction)
    
    if execSuccess then
        showNotification("✅ Success", "Script " .. gameData.name .. " dimuat!", 3)
        return true
    else
        showNotification("❌ Error", tostring(execError), 8)
        return false
    end
end

-- =========================================================
-- FUNGSI TAMPILAN GAME TIDAK DIDETEKSI
-- =========================================================
local function showGameNotSupported()
    local gui = createLoadingGUI()
    
    updateLoading(gui, "❌ GAME TIDAK DIDETEKSI", 0, Color3.new(1, 0, 0))
    task.wait(1)
    
    -- Update dengan daftar game yang didukung
    local gameList = "Game tidak didukung!\n\n"
    gameList = gameList .. "📋 Daftar Game yang Didukung:\n"
    
    for _, gameData in pairs(supportedGames) do
        gameList = gameList .. "• " .. gameData.name .. "\n"
    end
    
    -- Buat frame untuk daftar game
    local listFrame = Instance.new("ScrollingFrame")
    listFrame.Size = UDim2.new(0.9, 0, 0.4, 0)
    listFrame.Position = UDim2.new(0.05, 0, 0.4, 0)
    listFrame.BackgroundColor3 = Color3.new(0.15, 0.15, 0.2)
    listFrame.BackgroundTransparency = 0.3
    listFrame.BorderSizePixel = 0
    listFrame.CanvasSize = UDim2.new(0, 0, 1.5, 0)
    listFrame.Parent = gui.MainFrame
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 8)
    listCorner.Parent = listFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 5)
    listLayout.Parent = listFrame
    
    -- Tambah daftar game ke scrolling frame
    for gameKey, gameData in pairs(supportedGames) do
        for _, id in ipairs(gameData.ids) do
            local gameButton = Instance.new("TextButton")
            gameButton.Size = UDim2.new(0.95, 0, 0, 25)
            gameButton.Position = UDim2.new(0.025, 0, 0, 0)
            gameButton.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
            gameButton.Text = gameData.name .. " (ID: " .. id .. ")"
            gameButton.TextColor3 = Color3.new(1, 1, 1)
            gameButton.TextScaled = true
            gameButton.Font = Enum.Font.Gotham
            gameButton.Parent = listFrame
            
            local btnCorner = Instance.new("UICorner")
            btnCorner.CornerRadius = UDim.new(0, 4)
            btnCorner.Parent = gameButton
        end
    end
    
    -- Tunggu beberapa detik lalu hapus GUI
    task.wait(5)
    gui.MainFrame.Parent:Destroy()
end

-- =========================================================
-- MAIN EXECUTION
-- =========================================================
local function main()
    print("=" .. string.rep("=", 50) .. "=")
    print("🚀 LOADER GAME DETECTOR v1.0")
    print("=" .. string.rep("=", 50) .. "=")
    
    -- Tunggu player dan game siap
    if not LocalPlayer then
        Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
        LocalPlayer = Players.LocalPlayer
    end
    
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- Beri sedikit delay untuk stabilisasi
    task.wait(1)
    
    -- Deteksi game
    local detected = detectCurrentGame()
    
    if detected and currentGame then
        print("✅ Game terdeteksi: " .. currentGame.name)
        print("📦 Loading script...")
        
        -- Load script untuk game yang terdeteksi
        loadGameScript(currentGame)
    else
        print("❌ Game tidak didukung!")
        print("📋 Place ID: " .. game.PlaceId)
        
        -- Tampilkan pesan game tidak didukung
        showGameNotSupported()
        
        showNotification(
            "❌ Game Tidak Didukung",
            "Place ID: " .. game.PlaceId .. "\nTidak ada dalam daftar supported games!",
            8
        )
    end
end

-- Jalankan main function dengan pcall untuk safety
local success, err = pcall(main)
if not success then
    warn("Error dalam loader: " .. tostring(err))
    showNotification("Loader Error", "Terjadi error: " .. tostring(err), 8)
end

-- Return functions for manual use
return {
    detectGame = detectCurrentGame,
    loadCurrent = main,
    getSupportedGames = function() return supportedGames end
}

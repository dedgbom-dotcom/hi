-- =========================================================
-- ULTRA SMART AUTO KATA (ANTI LUAOBFUSCATOR V2 - ANTI DOUBLE)
-- =========================================================

if game:IsLoaded() == false then
    game.Loaded:Wait()
end

-- =========================
-- SAFE RAYFIELD LOAD
-- =========================
local httpget = game.HttpGet
local loadstr = loadstring

local RayfieldSource = httpget(game, "https://sirius.menu/rayfield")
if RayfieldSource == nil then
    warn("Gagal ambil Rayfield source")
    return
end

local RayfieldFunction = loadstr(RayfieldSource)
if RayfieldFunction == nil then
    warn("Gagal compile Rayfield")
    return
end

local Rayfield = RayfieldFunction()
if Rayfield == nil or type(Rayfield) ~= "table" then
    warn("Rayfield return nil or invalid")
    return
end
print("Rayfield loaded successfully")

-- Small delay to ensure Rayfield initializes
task.wait(0.5)

-- =========================
-- SERVICES
-- =========================
local GetService = game.GetService
local ReplicatedStorage = GetService(game, "ReplicatedStorage")
local Players = GetService(game, "Players")
local LocalPlayer = Players.LocalPlayer

-- =========================
-- LOAD WORDLIST + ANTI DOUBLE
-- =========================
local kataModule = {}
local kataSet = {} -- Untuk cek duplikat cepat

local function downloadWordlist()
    local success, response = pcall(function()
        return httpget(game, "https://raw.githubusercontent.com/danzzy1we/roblox-script-dump/refs/heads/main/WordListDump/withallcombination2.lua")
    end)
    
    if not success or not response then
        warn("Failed to download wordlist")
        return false
    end

    local content = string.match(response, "return%s*(.+)")
    if not content then
        return false
    end

    content = string.gsub(content, "^%s*{", "")
    content = string.gsub(content, "}%s*$", "")

    local duplicateCount = 0
    local totalProcessed = 0

    for word in string.gmatch(content, '"([^"]+)"') do
        totalProcessed = totalProcessed + 1
        local w = string.lower(word)
        
        -- CEK DOUBLE KATA
        if string.len(w) > 1 then
            if kataSet[w] == nil then
                -- Kata baru (unik)
                kataSet[w] = true
                table.insert(kataModule, w)
            else
                -- Kata double ditemukan!
                duplicateCount = duplicateCount + 1
            end
        end
    end

    print(string.format("Wordlist loaded: %d total, %d unique, %d duplicates removed", 
        totalProcessed, #kataModule, duplicateCount))

    return true
end

local wordOk = downloadWordlist()
if not wordOk or #kataModule == 0 then
    warn("Wordlist gagal dimuat!")
    return
end

print("Wordlist Loaded (Unique):", #kataModule)

-- =========================
-- REMOTES
-- =========================
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local MatchUI = remotes:WaitForChild("MatchUI")
local SubmitWord = remotes:WaitForChild("SubmitWord")
local BillboardUpdate = remotes:WaitForChild("BillboardUpdate")
local BillboardEnd = remotes:WaitForChild("BillboardEnd")
local TypeSound = remotes:WaitForChild("TypeSound")
local UsedWordWarn = remotes:WaitForChild("UsedWordWarn")

-- =========================
-- STATE
-- =========================
local matchActive = false
local isMyTurn = false
local serverLetter = ""

local usedWords = {}      -- Kata yang udah dipakai di match ini
local usedWordsSet = {}   -- Set buat cek cepat
local usedWordsList = {}
local opponentStreamWord = ""

local autoEnabled = false
local autoRunning = false

local config = {
    minDelay = 350,
    maxDelay = 650,
    aggression = 20,
    minLength = 2,
    maxLength = 12
}

-- =========================
-- LOGIC FUNCTIONS (DENGAN ANTI DOUBLE)
-- =========================
local function isUsed(word)
    return usedWordsSet[string.lower(word)] == true
end

local usedWordsDropdown = nil

local function addUsedWord(word)
    local w = string.lower(word)
    if usedWordsSet[w] == nil then
        usedWordsSet[w] = true
        usedWords[w] = true
        table.insert(usedWordsList, word)
        if usedWordsDropdown ~= nil then
            -- Safe update with pcall
            local success, err = pcall(function()
                usedWordsDropdown:Set(usedWordsList)
            end)
            if not success then
                warn("Failed to update dropdown:", err)
            end
        end
    end
end

local function resetUsedWords()
    usedWords = {}
    usedWordsSet = {}
    usedWordsList = {}
    if usedWordsDropdown ~= nil then
        -- Safe update with empty table
        local success, err = pcall(function()
            usedWordsDropdown:Set({})
        end)
        if not success then
            warn("Failed to reset dropdown:", err)
        end
    end
end

local function getSmartWords(prefix)
    local results = {}
    local lowerPrefix = string.lower(prefix)

    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix then
            -- CEK APAKAH SUDAH DIPAKAI
            if not isUsed(word) then
                local len = string.len(word)
                if len >= config.minLength and len <= config.maxLength then
                    table.insert(results, word)
                end
            end
        end
    end

    table.sort(results, function(a,b)
        return string.len(a) > string.len(b)
    end)

    return results
end

local function humanDelay()
    local min = config.minDelay
    local max = config.maxDelay
    if min > max then
        min = max
    end
    task.wait(math.random(min, max) / 1000)
end

-- =========================
-- AUTO ENGINE
-- =========================
local function startUltraAI()
    if autoRunning then return end
    if not autoEnabled then return end
    if not matchActive then return end
    if not isMyTurn then return end
    if serverLetter == "" then return end

    autoRunning = true

    humanDelay()

    local words = getSmartWords(serverLetter)
    if #words == 0 then
        autoRunning = false
        return
    end

    local selectedWord = words[1]

    if config.aggression < 100 then
        local topN = math.floor(#words * (config.aggression/100))
        if topN < 1 then topN = 1 end
        if topN > #words then topN = #words end
        selectedWord = words[math.random(1, topN)]
    end

    local currentWord = serverLetter
    local remain = string.sub(selectedWord, #serverLetter + 1)

    for i = 1, string.len(remain) do
        if not matchActive or not isMyTurn then
            autoRunning = false
            return
        end

        currentWord = currentWord .. string.sub(remain, i, i)

        local success, err = pcall(function()
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentWord)
        end)
        if not success then
            warn("Failed to send update:", err)
        end

        humanDelay()
    end

    humanDelay()

    local success, err = pcall(function()
        SubmitWord:FireServer(selectedWord)
    end)
    if success then
        addUsedWord(selectedWord)
    else
        warn("Failed to submit word:", err)
    end

    humanDelay()
    
    pcall(function()
        BillboardEnd:FireServer()
    end)

    autoRunning = false
end

-- =========================
-- UI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "Sambung-kata (Anti Double)",
    LoadingTitle = "Loading Gui...",
    LoadingSubtitle = "automate by sazaraaax",
    ConfigurationSaving = {Enabled = false}
})

local MainTab = Window:CreateTab("Main")

-- Info Wordlist
local wordlistInfo = string.format("Wordlist: %d kata unik", #kataModule)
MainTab:CreateParagraph({Title = "📚 Wordlist Info", Content = wordlistInfo})

MainTab:CreateToggle({
    Name = "Aktifkan Auto",
    CurrentValue = false,
    Callback = function(Value)
        autoEnabled = Value
        if Value then
            task.spawn(startUltraAI)
        end
    end
})

MainTab:CreateSlider({
    Name = "Aggression",
    Range = {0,100},
    Increment = 5,
    CurrentValue = config.aggression,
    Callback = function(Value)
        config.aggression = Value
    end
})

MainTab:CreateSlider({
    Name = "Min Delay (ms)",
    Range = {10, 500},
    Increment = 5,
    CurrentValue = config.minDelay,
    Callback = function(Value)
        config.minDelay = Value
    end
})

MainTab:CreateSlider({
    Name = "Max Delay (ms)",
    Range = {100, 1000},
    Increment = 5,
    CurrentValue = config.maxDelay,
    Callback = function(Value)
        config.maxDelay = Value
    end
})

MainTab:CreateSlider({
    Name = "Min Word Length",
    Range = {1, 3},
    Increment = 1,
    CurrentValue = config.minLength,
    Callback = function(Value)
        config.minLength = Value
    end
})

MainTab:CreateSlider({
    Name = "Max Word Length",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = config.maxLength,
    Callback = function(Value)
        config.maxLength = Value
    end
})

-- Create dropdown with empty initial options
usedWordsDropdown = MainTab:CreateDropdown({
    Name = "Used Words",
    Options = {},
    CurrentOption = "",
    Callback = function() end
})

-- ==============================
-- PARAGRAPH OBJECTS
-- ==============================
local opponentParagraph = MainTab:CreateParagraph({
    Title = "Status Opponent",
    Content = "Menunggu..."
})

local startLetterParagraph = MainTab:CreateParagraph({
    Title = "Kata Start",
    Content = "-"
})

-- ==============================
-- UPDATE FUNCTIONS
-- ==============================
local function updateOpponentStatus()
    local content = ""

    if matchActive == true then
        if isMyTurn == true then
            content = "Giliran Anda"
        else
            if opponentStreamWord ~= nil and opponentStreamWord ~= "" then
                content = "Opponent mengetik: " .. tostring(opponentStreamWord)
            else
                content = "Giliran Opponent"
            end
        end
    else
        content = "Match tidak aktif"
    end

    local success, err = pcall(function()
        opponentParagraph:Set({
            Title = "Status Opponent",
            Content = tostring(content)
        })
    end)
    if not success then
        warn("Failed to update opponent status:", err)
    end
end

local function updateStartLetter()
    local content = ""

    if serverLetter ~= nil and serverLetter ~= "" then
        content = "Kata Start: " .. tostring(serverLetter)
    else
        content = "Kata Start: -"
    end

    local success, err = pcall(function()
        startLetterParagraph:Set({
            Title = "Kata Start",
            Content = tostring(content)
        })
    end)
    if not success then
        warn("Failed to update start letter:", err)
    end
end

-- ==============================
-- TAB ABOUT
-- ==============================
local AboutTab = Window:CreateTab("About")

AboutTab:CreateParagraph({
    Title = "Informasi Script",
    Content = "Auto Kata\nVersi: 2.0 (Anti Double)\nby sazaraaax\nFitur: Auto play dengan wordlist Indonesia + ANTI DUPLICATE KATA\n\nthanks to danzzy1we for the indonesian dictionary"
})

AboutTab:CreateParagraph({
    Title = "Informasi Update",
    Content = "> Anti Double Word System\n> Wordlist unik (" .. #kataModule .. " kata)\n> Deteksi otomatis kata dobel\n> Performa lebih cepat"
})

AboutTab:CreateParagraph({
    Title = "Cara Penggunaan",
    Content = "1. Aktifkan toggle Auto\n2. Atur delay dan agresivitas\n3. Mulai permainan\n4. Script akan otomatis menjawab\n5. Kata dobel di wordlist sudah dihapus"
})

-- =========================
-- REMOTE EVENTS
-- =========================
local function onMatchUI(cmd, value)
    if cmd == "ShowMatchUI" then
        matchActive = true
        isMyTurn = false
        resetUsedWords()

    elseif cmd == "HideMatchUI" then
        matchActive = false
        isMyTurn = false
        serverLetter = ""
        resetUsedWords()

    elseif cmd == "StartTurn" then
        isMyTurn = true
        if autoEnabled then
            task.spawn(startUltraAI)
        end

    elseif cmd == "EndTurn" then
        isMyTurn = false

    elseif cmd == "UpdateServerLetter" then
        serverLetter = value or ""
    end

    updateOpponentStatus()
    updateStartLetter()
end

local function onBillboard(word)
    if matchActive and not isMyTurn then
        opponentStreamWord = word or ""
        updateOpponentStatus()
    end
end

local function onUsedWarn(word)
    if word then
        addUsedWord(word)
        if autoEnabled and matchActive and isMyTurn then
            humanDelay()
            task.spawn(startUltraAI)
        end
    end
end

-- Connect events with pcall for safety
pcall(function()
    MatchUI.OnClientEvent:Connect(onMatchUI)
    BillboardUpdate.OnClientEvent:Connect(onBillboard)
    UsedWordWarn.OnClientEvent:Connect(onUsedWarn)
end)

print("ANTI LUAOBFUSCATOR BUILD V2 LOADED - ANTI DOUBLE WORD ACTIVE")

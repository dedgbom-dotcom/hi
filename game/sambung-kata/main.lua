-- =========================================================
-- ULTRA SMART AUTO KATA V3 - FULL FEATURE
-- Features: Anti Double, Auto Claim, Score Counter, Auto Join, Win/Lose Notif
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
if RayfieldSource == nil then warn("Gagal ambil Rayfield source") return end

local RayfieldFunction = loadstr(RayfieldSource)
if RayfieldFunction == nil then warn("Gagal compile Rayfield") return end

local Rayfield = RayfieldFunction()
if Rayfield == nil or type(Rayfield) ~= "table" then warn("Rayfield return nil or invalid") return end
print("Rayfield loaded successfully")

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
local kataSet = {}

local function downloadWordlist()
    local success, response = pcall(function()
        return httpget(game, "https://raw.githubusercontent.com/dedgbom-dotcom/hi/refs/heads/main/game/sambung-kata/modules/listkata.lua")
    end)
    if not success or not response then warn("Failed to download wordlist") return false end

    local content = string.match(response, "return%s*(.+)")
    if not content then return false end

    content = string.gsub(content, "^%s*{", "")
    content = string.gsub(content, "}%s*$", "")

    local duplicateCount = 0
    local totalProcessed = 0

    for word in string.gmatch(content, '"([^"]+)"') do
        totalProcessed = totalProcessed + 1
        local w = string.lower(word)
        if string.len(w) > 1 then
            if kataSet[w] == nil then
                kataSet[w] = true
                table.insert(kataModule, w)
            else
                duplicateCount = duplicateCount + 1
            end
        end
    end

    print(string.format("Wordlist loaded: %d total, %d unique, %d duplicates removed",
        totalProcessed, #kataModule, duplicateCount))
    return true
end

local wordOk = downloadWordlist()
if not wordOk or #kataModule == 0 then warn("Wordlist gagal dimuat!") return end
print("Wordlist Loaded (Unique):", #kataModule)

-- =========================
-- REMOTES
-- =========================
local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
if not remotes then warn("Remotes tidak ditemukan!") return end

local MatchUI             = remotes:WaitForChild("MatchUI", 10)
local SubmitWord          = remotes:WaitForChild("SubmitWord", 10)
local BillboardUpdate     = remotes:WaitForChild("BillboardUpdate", 10)
local BillboardEnd        = remotes:WaitForChild("UpdateBillboard", 10)
local TypeSound           = remotes:WaitForChild("TypeSound", 10)
local UsedWordWarn        = remotes:WaitForChild("UsedWordWarn", 10)
local PlayerCorrect       = remotes:WaitForChild("PlayerCorrect", 10)
local PlayerHit           = remotes:WaitForChild("PlayerHit", 10)
local ResultUI            = remotes:WaitForChild("ResultUI", 10)
local JoinTable           = remotes:WaitForChild("JoinTable", 10)
local LeaveTable          = remotes:WaitForChild("LeaveTable", 10)
local ClaimIndexReward    = remotes:WaitForChild("ClaimIndexReward", 10)
local WordUpdate          = remotes:WaitForChild("WordUpdate", 10)

if not (MatchUI and SubmitWord and BillboardUpdate and BillboardEnd and TypeSound and UsedWordWarn) then
    warn("Remote utama tidak ditemukan! Cek ulang nama remote.")
    return
end

-- =========================
-- STATE
-- =========================
local matchActive = false
local isMyTurn = false
local serverLetter = ""

local usedWords = {}
local usedWordsSet = {}
local usedWordsList = {}
local opponentStreamWord = ""

local autoEnabled = false
local autoRunning = false
local autoJoinEnabled = false
local autoClaimEnabled = false

-- Score counter
local totalWins = 0
local totalLosses = 0
local totalCorrect = 0

local config = {
    minDelay = 350,
    maxDelay = 650,
    aggression = 20,
    minLength = 2,
    maxLength = 12,
    autoJoinDelay = 2  -- detik sebelum auto join meja baru
}

-- =========================
-- LOGIC FUNCTIONS
-- =========================
local function isUsed(word)
    return usedWordsSet[string.lower(word)] == true
end

local usedWordsDropdown = nil
local scoreParagraph = nil
local statusParagraph = nil
local startLetterParagraph = nil
local opponentParagraph = nil

local function addUsedWord(word)
    local w = string.lower(word)
    if usedWordsSet[w] == nil then
        usedWordsSet[w] = true
        usedWords[w] = true
        table.insert(usedWordsList, word)
        if usedWordsDropdown ~= nil then
            pcall(function() usedWordsDropdown:Set(usedWordsList) end)
        end
    end
end

local function resetUsedWords()
    usedWords = {}
    usedWordsSet = {}
    usedWordsList = {}
    if usedWordsDropdown ~= nil then
        pcall(function() usedWordsDropdown:Set({}) end)
    end
end

local function getSmartWords(prefix)
    local results = {}
    local lowerPrefix = string.lower(prefix)
    for i = 1, #kataModule do
        local word = kataModule[i]
        if string.sub(word, 1, #lowerPrefix) == lowerPrefix then
            if not isUsed(word) then
                local len = string.len(word)
                if len >= config.minLength and len <= config.maxLength then
                    table.insert(results, word)
                end
            end
        end
    end
    table.sort(results, function(a,b) return string.len(a) > string.len(b) end)
    return results
end

local function humanDelay()
    local min = config.minDelay
    local max = config.maxDelay
    if min > max then min = max end
    task.wait(math.random(min, max) / 1000)
end

-- =========================
-- UPDATE UI
-- =========================
local function updateScoreDisplay()
    if scoreParagraph == nil then return end
    pcall(function()
        scoreParagraph:Set({
            Title = "📊 Score",
            Content = string.format("Menang: %d  |  Kalah: %d  |  Kata Benar: %d", totalWins, totalLosses, totalCorrect)
        })
    end)
end

local function updateOpponentStatus()
    if opponentParagraph == nil then return end
    local content = ""
    if matchActive then
        if isMyTurn then
            content = "🟢 Giliran Anda"
        else
            if opponentStreamWord ~= nil and opponentStreamWord ~= "" then
                content = "⌨️ Opponent mengetik: " .. tostring(opponentStreamWord)
            else
                content = "🔴 Giliran Opponent"
            end
        end
    else
        content = "⏸️ Match tidak aktif"
    end
    pcall(function()
        opponentParagraph:Set({Title = "Status Opponent", Content = tostring(content)})
    end)
end

local function updateStartLetter()
    if startLetterParagraph == nil then return end
    local content = serverLetter ~= "" and ("Kata Start: " .. tostring(serverLetter)) or "Kata Start: -"
    pcall(function()
        startLetterParagraph:Set({Title = "Kata Start", Content = tostring(content)})
    end)
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
        if not matchActive or not isMyTurn then autoRunning = false return end
        currentWord = currentWord .. string.sub(remain, i, i)
        pcall(function()
            TypeSound:FireServer()
            BillboardUpdate:FireServer(currentWord)
        end)
        humanDelay()
    end

    humanDelay()

    local success = pcall(function()
        SubmitWord:FireServer(selectedWord)
    end)
    if success then
        addUsedWord(selectedWord)
    end

    humanDelay()
    pcall(function() BillboardEnd:FireServer() end)

    autoRunning = false
end

-- =========================
-- AUTO JOIN
-- =========================
local function tryAutoJoin()
    if not autoJoinEnabled then return end
    task.wait(config.autoJoinDelay)
    if matchActive then return end -- udah di match, skip
    pcall(function()
        JoinTable:FireServer()
        print("Auto join meja dijalankan")
    end)
end

-- =========================
-- AUTO CLAIM REWARD
-- =========================
local function tryAutoClaim()
    if not autoClaimEnabled then return end
    task.wait(1)
    pcall(function()
        ClaimIndexReward:FireServer()
        print("Auto claim reward dijalankan")
        Rayfield:Notify({
            Title = "Auto Claim",
            Content = "Reward berhasil diklaim!",
            Duration = 3,
            Image = 4483362458
        })
    end)
end

-- =========================
-- UI
-- =========================
local Window = Rayfield:CreateWindow({
    Name = "Sambung-kata V3 - Full Feature",
    LoadingTitle = "Loading Gui...",
    LoadingSubtitle = "automate by sazaraaax",
    ConfigurationSaving = {Enabled = false}
})

-- ======= MAIN TAB =======
local MainTab = Window:CreateTab("Main")

MainTab:CreateParagraph({Title = "📚 Wordlist Info", Content = string.format("Wordlist: %d kata unik", #kataModule)})

-- Score display (assigned to variable)
scoreParagraph = MainTab:CreateParagraph({
    Title = "📊 Score",
    Content = "Menang: 0  |  Kalah: 0  |  Kata Benar: 0"
})

MainTab:CreateButton({
    Name = "Reset Score",
    Callback = function()
        totalWins = 0
        totalLosses = 0
        totalCorrect = 0
        updateScoreDisplay()
        Rayfield:Notify({Title = "Score Reset", Content = "Score berhasil direset!", Duration = 2})
    end
})

opponentParagraph = MainTab:CreateParagraph({Title = "Status Opponent", Content = "Menunggu..."})
startLetterParagraph = MainTab:CreateParagraph({Title = "Kata Start", Content = "-"})

MainTab:CreateToggle({
    Name = "Aktifkan Auto",
    CurrentValue = false,
    Callback = function(Value)
        autoEnabled = Value
        if Value then task.spawn(startUltraAI) end
    end
})

MainTab:CreateSlider({
    Name = "Aggression",
    Range = {0,100},
    Increment = 5,
    CurrentValue = config.aggression,
    Callback = function(Value) config.aggression = Value end
})

MainTab:CreateSlider({
    Name = "Min Delay (ms)",
    Range = {10, 500},
    Increment = 5,
    CurrentValue = config.minDelay,
    Callback = function(Value) config.minDelay = Value end
})

MainTab:CreateSlider({
    Name = "Max Delay (ms)",
    Range = {100, 1000},
    Increment = 5,
    CurrentValue = config.maxDelay,
    Callback = function(Value) config.maxDelay = Value end
})

MainTab:CreateSlider({
    Name = "Min Word Length",
    Range = {1, 3},
    Increment = 1,
    CurrentValue = config.minLength,
    Callback = function(Value) config.minLength = Value end
})

MainTab:CreateSlider({
    Name = "Max Word Length",
    Range = {5, 20},
    Increment = 1,
    CurrentValue = config.maxLength,
    Callback = function(Value) config.maxLength = Value end
})

usedWordsDropdown = MainTab:CreateDropdown({
    Name = "Used Words",
    Options = {},
    CurrentOption = "",
    Callback = function() end
})

-- ======= AUTO TAB =======
local AutoTab = Window:CreateTab("Auto Features")

AutoTab:CreateToggle({
    Name = "Auto Join Meja",
    CurrentValue = false,
    Callback = function(Value)
        autoJoinEnabled = Value
        if Value then
            Rayfield:Notify({Title = "Auto Join", Content = "Auto join meja aktif!", Duration = 3})
            task.spawn(tryAutoJoin)
        end
    end
})

AutoTab:CreateSlider({
    Name = "Delay Auto Join (detik)",
    Range = {1, 10},
    Increment = 1,
    CurrentValue = config.autoJoinDelay,
    Callback = function(Value) config.autoJoinDelay = Value end
})

AutoTab:CreateButton({
    Name = "Manual Join Meja",
    Callback = function()
        pcall(function() JoinTable:FireServer() end)
        Rayfield:Notify({Title = "Join Meja", Content = "Mencoba join meja...", Duration = 2})
    end
})

AutoTab:CreateButton({
    Name = "Leave Meja",
    Callback = function()
        pcall(function() LeaveTable:FireServer() end)
        Rayfield:Notify({Title = "Leave Meja", Content = "Keluar dari meja!", Duration = 2})
    end
})

AutoTab:CreateDivider()

AutoTab:CreateToggle({
    Name = "Auto Claim Reward",
    CurrentValue = false,
    Callback = function(Value)
        autoClaimEnabled = Value
        if Value then
            Rayfield:Notify({Title = "Auto Claim", Content = "Auto claim reward aktif!", Duration = 3})
            task.spawn(tryAutoClaim)
        end
    end
})

AutoTab:CreateButton({
    Name = "Manual Claim Reward",
    Callback = function()
        pcall(function() ClaimIndexReward:FireServer() end)
        Rayfield:Notify({Title = "Claim Reward", Content = "Mencoba klaim reward...", Duration = 2})
    end
})

-- ======= ABOUT TAB =======
local AboutTab = Window:CreateTab("About")

AboutTab:CreateParagraph({
    Title = "Informasi Script",
    Content = "Auto Kata\nVersi: 3.0 (Full Feature)\nby sazaraaax\n\nFitur:\n- Auto play anti duplicate\n- Score counter (menang/kalah/kata benar)\n- Auto join meja otomatis\n- Notifikasi menang/kalah\n- Auto claim reward\n\nthanks to danzzy1we for the indonesian dictionary"
})

AboutTab:CreateParagraph({
    Title = "Changelog V3",
    Content = "> [NEW] Score counter (win/loss/correct)\n> [NEW] Auto join meja + manual join/leave\n> [NEW] Auto claim reward\n> [NEW] Notifikasi menang/kalah\n> [FIX] BillboardEnd -> UpdateBillboard\n> [KEEP] Anti double word system"
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
        -- Trigger auto join setelah match selesai
        task.spawn(tryAutoJoin)

    elseif cmd == "StartTurn" then
        isMyTurn = true
        if autoEnabled then task.spawn(startUltraAI) end

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

-- Score: kata benar
local function onPlayerCorrect()
    totalCorrect = totalCorrect + 1
    updateScoreDisplay()
end

-- Kena hit / salah
local function onPlayerHit()
    Rayfield:Notify({
        Title = "⚠️ Player Hit!",
        Content = "Kamu kena hukuman!",
        Duration = 3,
        Image = 4483362458
    })
end

-- Hasil match
local function onResultUI(result)
    if result == "Win" or result == true or result == 1 then
        totalWins = totalWins + 1
        updateScoreDisplay()
        Rayfield:Notify({
            Title = "🏆 Menang!",
            Content = string.format("GG! Total menang: %d", totalWins),
            Duration = 4,
            Image = 4483362458
        })
    else
        totalLosses = totalLosses + 1
        updateScoreDisplay()
        Rayfield:Notify({
            Title = "💀 Kalah!",
            Content = string.format("Lebih beruntung next round! Total kalah: %d", totalLosses),
            Duration = 4,
            Image = 4483362458
        })
    end

    -- Auto claim setelah match
    task.spawn(tryAutoClaim)
    -- Auto join meja baru
    task.spawn(tryAutoJoin)
end

-- Connect semua events
pcall(function()
    MatchUI.OnClientEvent:Connect(onMatchUI)
    BillboardUpdate.OnClientEvent:Connect(onBillboard)
    UsedWordWarn.OnClientEvent:Connect(onUsedWarn)
    PlayerCorrect.OnClientEvent:Connect(onPlayerCorrect)
    PlayerHit.OnClientEvent:Connect(onPlayerHit)
    ResultUI.OnClientEvent:Connect(onResultUI)
end)

print("SAMBUNG KATA V3 - FULL FEATURE LOADED")

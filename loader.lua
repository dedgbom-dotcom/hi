-- ========================================================================== --
--                      RZPRIVATE - EVADE LOADER                              --
--                            by iruz | version 3.0                           --
-- ========================================================================== --

-- ========================================================================== --
--                            LOAD OBSIDIAN LIBRARY                           --
-- ========================================================================== --

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()

-- ========================================================================== --
--                            CONFIGURATION                                    --
-- ========================================================================== --

local CORRECT_KEY = "iruzruz"
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/dedgbom-dotcom/hi/main/game/ev/main.lua"

-- ========================================================================== --
--                            CREATE LOADER WINDOW                            --
-- ========================================================================== --

local Window = Library:CreateWindow({
    Title = "rzprivate - Evade (Key System)",
    Footer = "by iruz | version 3.0",
    Icon = 95816097006870,
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Key = Window:AddTab("Key System", "key"),
}

-- ========================================================================== --
--                            KEY SYSTEM TAB                                   --
-- ========================================================================== --

Tabs.Key:AddLabel({
    Text = "Welcome to rzprivate - Evade!",
    DoesWrap = true,
    Size = 18,
})

Tabs.Key:AddDivider()

Tabs.Key:AddLabel({
    Text = "Enter the key to access the script.\nKey: iruzruz",
    DoesWrap = true,
    Size = 14,
})

Tabs.Key:AddDivider()

local keyStatusLabel = Tabs.Key:AddLabel({
    Text = "Status: Waiting for key...",
    DoesWrap = true,
    Size = 14,
})

Tabs.Key:AddKeyBox(function(ReceivedKey)
    local Success = ReceivedKey == CORRECT_KEY
    
    if Success then
        -- Update status
        if keyStatusLabel and keyStatusLabel.SetText then
            pcall(function() 
                keyStatusLabel:SetText("✅ Key Accepted! Loading script...")
            end)
        end
        
        Library:Notify({
            Title = "✅ Key Accepted",
            Description = "Loading main script...",
            Time = 3,
        })
        
        -- Wait a moment for notification
        task.wait(1)
        
        -- Load main script with detailed error handling
        local loadSuccess, loadError = pcall(function()
            print("📡 Downloading main script from:", MAIN_SCRIPT_URL)
            
            local scriptContent = game:HttpGet(MAIN_SCRIPT_URL)
            
            if not scriptContent or scriptContent == "" then
                error("Failed to download script (empty response)")
            end
            
            print("✅ Downloaded " .. #scriptContent .. " characters")
            print("🔄 Compiling script...")
            
            local compiledScript, compileError = loadstring(scriptContent)
            
            if not compiledScript then
                error("Script compilation failed: " .. tostring(compileError))
            end
            
            print("✅ Script compiled successfully")
            print("🚀 Executing script...")
            
            compiledScript()
            
            print("✅ Script executed successfully")
        end)
        
        if loadSuccess then
            Library:Notify({
                Title = "✅ Script Loaded",
                Description = "rzprivate - Evade is now running!",
                Time = 3,
            })
            
            -- Wait for notification then unload loader
            task.wait(2)
            Library:Unload()
        else
            -- Show detailed error
            local errorMsg = tostring(loadError)
            
            Library:Notify({
                Title = "❌ Load Failed",
                Description = "Error: " .. errorMsg,
                Time = 10,
            })
            
            if keyStatusLabel and keyStatusLabel.SetText then
                pcall(function() 
                    keyStatusLabel:SetText("❌ Failed to load script!\nError: " .. errorMsg)
                end)
            end
            
            warn("================== LOADER ERROR ==================")
            warn("Main Script URL:", MAIN_SCRIPT_URL)
            warn("Error Details:", errorMsg)
            warn("==================================================")
        end
    else
        Library:Notify({
            Title = "❌ Wrong Key",
            Description = "Received: " .. ReceivedKey .. "\nExpected: " .. CORRECT_KEY,
            Time = 4,
        })
        
        if keyStatusLabel and keyStatusLabel.SetText then
            pcall(function() 
                keyStatusLabel:SetText("❌ Wrong key! Try again.")
            end)
        end
    end
end)

Tabs.Key:AddDivider()

Tabs.Key:AddLabel({
    Text = "Features:\n• Combat (Auto Revive, Fast Revive, Weapon Enhancements)\n• Teleport (Map Spots, Players, Objectives)\n• ESP (Players, Tickets, Nextbots, Chams, Tracers)\n• Movement (Noclip, Fly, Infinite Slide, Bhop)\n• Visual (Barriers, Lighting, Camera, Anti-Lag)\n• Server (Server Hop, Join Modes, Lag Switch)",
    DoesWrap = true,
    Size = 12,
})

Tabs.Key:AddDivider()

-- Debug button
Tabs.Key:AddButton({
    Text = "🔍 Test Main Script URL",
    Tooltip = "Check if main script URL is accessible",
    Func = function()
        Library:Notify({
            Title = "Testing URL",
            Description = "Checking main script URL...",
            Time = 2,
        })
        
        local testSuccess, testResult = pcall(function()
            local content = game:HttpGet(MAIN_SCRIPT_URL)
            return #content
        end)
        
        if testSuccess then
            Library:Notify({
                Title = "✅ URL OK",
                Description = "Downloaded " .. testResult .. " characters",
                Time = 5,
            })
        else
            Library:Notify({
                Title = "❌ URL Failed",
                Description = "Error: " .. tostring(testResult),
                Time = 5,
            })
        end
    end
})

-- ========================================================================== --
--                            THEME MANAGER                                    --
-- ========================================================================== --

ThemeManager:SetLibrary(Library)
ThemeManager:SetFolder("rzprivate")
ThemeManager:ApplyToTab(Tabs.Key)

-- ========================================================================== --
--                            MENU KEYBIND                                     --
-- ========================================================================== --

local MenuGroup = Tabs.Key:AddRightGroupbox("Menu Settings", "settings")

MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { 
    Default = "RightShift", 
    NoUI = true, 
    Text = "Menu keybind" 
})

Library.ToggleKeybind = Library.Options.MenuKeybind

-- ========================================================================== --
--                            FINAL                                            --
-- ========================================================================== --

print(string.rep("=", 70))
print("rzprivate - Evade Loader v3.0")
print("by iruz | Key: iruzruz")
print("Main Script URL:", MAIN_SCRIPT_URL)
print(string.rep("=", 70))

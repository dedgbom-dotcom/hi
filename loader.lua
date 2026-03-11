-- ========================================================================== --
--                      RZPRIVATE - EVADE LOADER                              --
--                            by iruz | version 3.0                           --
-- ========================================================================== --

local CORRECT_KEY = "iruzruz"
local MAIN_SCRIPT_URL = "https://raw.githubusercontent.com/dedgbom-dotcom/hi/main/game/ev/main.lua"

-- ========================================================================== --
--                            LOAD OBSIDIAN LIBRARY                           --
-- ========================================================================== --

local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()

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
    if ReceivedKey == CORRECT_KEY then
        -- Update status
        pcall(function() 
            keyStatusLabel:SetText("✅ Key Accepted! Loading script...")
        end)
        
        Library:Notify({
            Title = "✅ Key Accepted",
            Description = "Loading main script...",
            Time = 2,
        })
        
        task.wait(0.5)
        
        -- Close loader UI first
        Library:Unload()
        
        task.wait(0.5)
        
        -- Load main script (simple approach)
        loadstring(game:HttpGet(MAIN_SCRIPT_URL))()
        
    else
        Library:Notify({
            Title = "❌ Wrong Key",
            Description = "Received: " .. ReceivedKey .. "\nExpected: " .. CORRECT_KEY,
            Time = 4,
        })
        
        pcall(function() 
            keyStatusLabel:SetText("❌ Wrong key! Try again.")
        end)
    end
end)

Tabs.Key:AddDivider()

Tabs.Key:AddLabel({
    Text = "Features:\n• Combat (Auto Revive, Fast Revive, Weapon Enhancements)\n• Teleport (Map Spots, Players, Objectives)\n• ESP (Players, Tickets, Nextbots, Chams, Tracers)\n• Movement (Noclip, Fly, Infinite Slide, Bhop)\n• Visual (Barriers, Lighting, Camera, Anti-Lag)\n• Server (Server Hop, Join Modes, Lag Switch)",
    DoesWrap = true,
    Size = 12,
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

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
        
        -- Load main script
        local success, err = pcall(function()
            loadstring(game:HttpGet(MAIN_SCRIPT_URL))()
        end)
        
        if success then
            Library:Notify({
                Title = "✅ Script Loaded",
                Description = "rzprivate - Evade is now running!",
                Time = 3,
            })
            
            -- Wait for notification then unload loader
            task.wait(2)
            Library:Unload()
        else
            Library:Notify({
                Title = "❌ Load Failed",
                Description = "Error: " .. tostring(err),
                Time = 5,
            })
            
            if keyStatusLabel and keyStatusLabel.SetText then
                pcall(function() 
                    keyStatusLabel:SetText("❌ Failed to load script! Check console for errors.")
                end)
            end
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

print("=".rep(70))
print("rzprivate - Evade Loader v3.0")
print("by iruz | Key: iruzruz")
print("=".rep(70))

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
                Duration = dur

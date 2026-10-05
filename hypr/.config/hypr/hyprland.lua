-- ========================
-- MOD KEY
-- ========================
local mod = "ALT"

-- Keyboard backlight device (Apple touch bar), used by the XF86KbdBrightness* binds.
-- Controlled via brightnessctl: the sysfs brightness file is root-owned, so writing
-- to it directly (as the old hyprland.conf binds did) does not work.
local kb_dev = "appletb_backlight"

-- ========================
-- MONITORS (laptop + external)
-- ========================
-- Adjust names via: hyprctl monitors
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto-left",  scale = 1.5 })
hl.monitor({ output = "eDP-2", disabled = true })
hl.monitor({ output = "DP-1",  mode = "preferred", position = "auto",        scale = 2.0 })
hl.monitor({ output = "DP-5",  mode = "preferred", position = "auto-right", scale = 1.5 })
hl.monitor({ output = "DP-6",  mode = "preferred", position = "auto-left",  scale = 1.0 })
hl.monitor({ output = "DP-3",  mode = "preferred", position = "auto-left",  scale = 1.0 })
hl.monitor({ output = "DP-2",  mode = "preferred", position = "auto-right", scale = 1.0 })

-- Workspaces mapped
local ws_monitor = {
    [1]  = "DP-2",  [2]  = "DP-2",  [3]  = "DP-2",  [4]  = "DP-2",  [5]  = "DP-2",
    [6]  = "eDP-1", [7]  = "eDP-1", [8]  = "eDP-1", [9]  = "eDP-1", [10] = "eDP-1",
}
for ws, mon in pairs(ws_monitor) do
    hl.workspace_rule({ workspace = tostring(ws), monitor = mon })
end

-- ========================
-- AUTOSTART
-- ========================
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd("dex --autostart --environment Hyprland")

    -- Wallpaper
    hl.exec_cmd("hyprpaper")

    -- Idle manager
    hl.exec_cmd("hypridle")
end)

-- ========================
-- INPUT
-- ========================
hl.config({
    input = {
        kb_layout  = "us",
        kb_options = "ctrl:nocaps",

        follow_mouse   = 1,
        natural_scroll = true, -- mice

        touchpad = {
            natural_scroll = true,
        },
    },
})

-- ========================
-- GENERAL LOOK
-- ========================
hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 12,
        border_size = 2,

        col = {
            active_border   = "rgba(88c0d0ff)",
            inactive_border = "rgba(4c566a88)",
        },
    },
})

-- ========================
-- DECORATION (BLUR + TRANSPARENCY)
-- ========================
hl.config({
    decoration = {
        rounding = 10,

        blur = {
            enabled          = true,
            size             = 8,
            passes           = 2,
            new_optimizations = true,
        },

        -- shadow = {
        --     enabled      = true,
        --     range        = 20,
        --     render_power = 3,
        -- },
    },
})

-- https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    misc = {
        force_default_wallpaper = -1, -- Set to 0 or 1 to disable the anime mascot wallpapers
        focus_on_activate       = true,
        disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
    },
})

-- ========================
-- ANIMATIONS
-- ========================
hl.config({
    animations = {
        enabled = false,
    },
})

hl.curve("easeOut", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 }    } })
hl.curve("easeIn",  { type = "bezier", points = { { 0.5, 0 },  { 1, 0.75 }  } })

hl.animation({ leaf = "windows",    enabled = true, speed = 6, bezier = "easeOut" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 5, bezier = "easeIn"  })
hl.animation({ leaf = "fade",       enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "border",     enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "easeOut" })

-- ========================
-- LAYOUT
-- ========================
-- hl.config({
--     dwindle = {
--         pseudotile     = true,
--         preserve_split = true,
--     },
-- })

-- ========================
-- KEYBINDS
-- ========================

hl.bind(mod .. " + RETURN", hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + D", hl.dsp.exec_cmd("rofi -show drun"))

hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mod .. " + SHIFT + SPACE", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprshot -m region"))

-- Focus
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left"  }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down"  }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up"    }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Move windows
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left"  }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down"  }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up"    }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Resize mode
hl.bind(mod .. " + R", hl.dsp.submap("resize"))

hl.define_submap("resize", function()
    hl.bind("H", hl.dsp.window.resize({ x = -30, y = 0,  relative = true }))
    hl.bind("L", hl.dsp.window.resize({ x = 30,  y = 0,  relative = true }))
    hl.bind("K", hl.dsp.window.resize({ x = 0,   y = -30, relative = true }))
    hl.bind("J", hl.dsp.window.resize({ x = 0,   y = 30,  relative = true }))
    hl.bind("escape", hl.dsp.submap("reset"))
end)

-- Workspaces (workspace 10 maps to key 0)
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +10%"))
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -10%"))
hl.bind("XF86AudioMute",    hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"))
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"))

-- Brightness
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl set +10%"))
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 10%-"))

-- Requires playerctl
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd("playerctl next"),       { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd("playerctl previous"),   { locked = true })

-- Keyboard backlight (up/down in steps of 1, toggle = off)
hl.bind("XF86KbdBrightnessUp",     hl.dsp.exec_cmd("brightnessctl --device=" .. kb_dev .. " set +1"))
hl.bind("XF86KbdBrightnessDown",   hl.dsp.exec_cmd("brightnessctl --device=" .. kb_dev .. " set 1-"))
hl.bind("XF86KbdLightOnOff",       hl.dsp.exec_cmd("brightnessctl --device=" .. kb_dev .. " set 0"))

-- Lock screen
hl.bind("SUPER + L", hl.dsp.exec_cmd("hyprlock"))

-- Reload / exit
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

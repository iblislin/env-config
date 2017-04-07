-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")

-- Widget and layout library
local wibox = require("wibox")

-- Theme handling library
local beautiful = require("beautiful")

-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup").widget

-- Third party library
local vicious = require("vicious")
local lain = require("lain")
local markup = lain.util.markup
local separators = lain.util.separators

-- Enable VIM help for hotkeys widget when client with matching name is opened:
require("awful.hotkeys_popup.keys.vim")

-- {{{ Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
                         title = "Oops, an error happened!",
                         text = tostring(err) })
        in_error = false
    end)
end

function os.capture(cmd, raw)
    local f = assert(io.popen(cmd, 'r'))
    local s = assert(f:read('*a'))
    f:close()

    if raw then
        return s
    end

    s = string.gsub(s, '^%s+', '')
    s = string.gsub(s, '%s+$', '')
    s = string.gsub(s, '[\n\r]+', ' ')
    return s
end
-- }}}

-- {{{ Variable definitions
local home_dir = os.getenv("HOME") .. "/"
local awesome_dir = home_dir .. ".config/awesome/"
local platform = os.capture('uname -s')

-- Themes define colours, icons, font and wallpapers.
beautiful.init(awesome_dir .. "themes/iblis/theme.lua")
local theme = beautiful.get()

-- This is used later as the default terminal and editor to run.
terminal = "urxvt"
editor = os.getenv("EDITOR") or "vi"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Table of layouts to cover with awful.layout.inc, order matters.
awful.layout.layouts = {
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    -- awful.layout.suit.tile.bottom,
    -- awful.layout.suit.tile.top,
    -- awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    -- awful.layout.suit.spiral,
    -- awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    -- awful.layout.suit.max.fullscreen,
    -- awful.layout.suit.magnifier,
    awful.layout.suit.corner.nw,
    -- awful.layout.suit.corner.ne,
    -- awful.layout.suit.corner.sw,
    -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Helper functions
local function client_menu_toggle_fn()
    local instance = nil

    return function ()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({ theme = { width = 250 } })
        end
    end
end
-- }}}

-- {{{ Menu
-- Create a launcher widget and a main menu
myawesomemenu = {
   { "hotkeys", function() return false, hotkeys_popup.show_help end},
   { "manual", terminal .. " -e man awesome" },
   { "edit config", editor_cmd .. " " .. awesome.conffile },
   { "restart", awesome.restart },
   { "suspend", function() awful.spawn.with_shell('sudo pm-suspend') end },
   { "quit", function() awesome.quit() end}
}

mymainmenu = awful.menu({
    items = {
        { "awesome", myawesomemenu, beautiful.awesome_icon },
        { "open terminal", terminal }
    }
})

mylauncher = awful.widget.launcher({ image = beautiful.awesome_icon,
                                     menu = mymainmenu })

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- Keyboard map indicator and switcher
mykeyboardlayout = awful.widget.keyboardlayout()

-- {{{ Wibar

-- Clock
local clock = wibox.widget.textclock()
vicious.register(clock, vicious.widgets.date, " %Y/%m/%d %p %I:%M:%S", 1)
clock = wibox.container.background(clock, theme.bg_noalpha)

-- Calendar
local cal_cmd

if platform == 'Linux' then
    cal_cmd = "cal --color=always"
else -- in case of FreeBSD
    cal_cmd = "cal"
end

local cal_widget = lain.widget.calendar({
    cal = cal_cmd,
    attach_to = { clock },
    notification_preset = {
        font = "Droid Sans Mono 16",
        fg   = theme.fg_normal,
        bg   = theme.bg_normal
    }
})

-- Memory
local mem_icon = wibox.widget.imagebox(theme.widget_mem)
local mem_widget = lain.widget.mem({
    settings = function()
        widget:set_markup(mem_now.used .. "M ")
    end
})
local mem_line = wibox.container.background(
    wibox.container.margin(
        wibox.widget({
            mem_icon,
            mem_widget,
            layout = wibox.layout.align.horizontal
        }),
        2, 3),
    "#777E76"
)

-- CPU
local cpu_icon = wibox.widget.imagebox(theme.widget_cpu)
local cpu_widget = lain.widget.cpu({
    settings = function()
        widget:set_markup(cpu_now.usage .. '% ')
    end
})
local cpu_line = wibox.container.background(
    wibox.container.margin(
        wibox.widget({
            cpu_icon,
            cpu_widget,
            layout = wibox.layout.align.horizontal
        }),
        3, 4),
    "#4B696D"
)

--  Temp
local temp_icon = wibox.widget.imagebox(theme.widget_temp)
local temp_widget = lain.widget.temp({
    tempfile = "/sys/class/thermal/thermal_zone2/temp",
    settings = function()
        widget:set_markup(coretemp_now .. "°C ")
    end
})
local temp_line = wibox.container.background(
    wibox.container.margin(
        wibox.widget({
            temp_icon,
            temp_widget,
            layout = wibox.layout.align.horizontal
        }),
        4, 4),
    "#4B3B51"
)

-- FS
local df_option

if platform == 'Linux' then
    df_option = '--type=ext2 --type=ext3 --type=ext4'
else  -- in case of FreeBSD
    df_option = '--type=ufs --type=zfs'
end

local fs_icon = wibox.widget.imagebox(theme.widget_hdd)
local fs_widget = lain.widget.fs({
    options = df_option,
    notification_preset = {
        fg = theme.fg_normal,
        bg = theme.bg_normal,
        -- font = "xos4 Terminus 10"
    },
    settings = function()
        widget:set_markup(fs_now.available_gb .. 'GB ')
    end
})
local fs_line = wibox.container.background(
    wibox.container.margin(
        wibox.widget({
            fs_icon,
            fs_widget,
            layout = wibox.layout.align.horizontal
        }),
        3, 3),
    "#B63B3B"
)

-- Battery
local bat_icon = wibox.widget.imagebox(theme.widget_battery)
local bat_widget = lain.widget.bat({
    settings = function()
        if bat_now.status ~= "N/A" then
            if bat_now.ac_status == 1 then
                widget:set_markup(" AC ")
                bat_icon:set_image(theme.widget_ac)
                return
            elseif not bat_now.perc and tonumber(bat_now.perc) <= 5 then
                bat_icon:set_image(theme.widget_battery_empty)
            elseif not bat_now.perc and tonumber(bat_now.perc) <= 15 then
                bat_icon:set_image(theme.widget_battery_low)
            else
                bat_icon:set_image(theme.widget_battery)
            end
            widget:set_markup(bat_now.perc .. "% ")
        else
            widget:set_markup()
            bat_icon:set_image(theme.widget_ac)
        end
    end
})
local bat_line = wibox.container.background(
    wibox.container.margin(
        wibox.widget({
            bat_icon,
            bat_widget,
            layout = wibox.layout.align.horizontal
        }),
        3, 3),
    "#A36530"
)

-- Net
local net_icon = wibox.widget.imagebox(theme.widget_net)
local net_widget = lain.widget.net({
    settings = function()
        widget:set_markup(
            markup("#FEFEFE",
                   net_now.received .. "↓↑" .. net_now.sent .. " ")
        )
    end
})
local net_line = wibox.container.background(
    wibox.container.margin(
        wibox.widget({
            net_icon,
            net_widget,
            layout = wibox.layout.align.horizontal
        }),
        3, 3),
    "#7B8F1B"
)

-- Volume
local vol_icon = wibox.widget.imagebox(theme.widget_vol)
local vol_widget = lain.widget.alsabar({
    -- --togglechannel = "IEC958,3",
    ticks = true,
    width = 67,
})
local vol_bar = wibox.container.margin(
    vol_widget.bar,
    -5, 7, 5, 5
)
vol_bar:buttons(awful.util.table.join(
    awful.button({}, 1, function()
        awful.spawn(string.format("%s set %s toggle", vol_widget.cmd, vol_widget.togglechannel or vol_widget.channel))
        vol_widget.update()
    end),
    awful.button({}, 2, function()
        awful.spawn(string.format("%s set %s 100%%", vol_widget.cmd, vol_widget.channel))
        vol_widget.update()
    end),
    awful.button({}, 3, function()
        awful.spawn.with_shell(string.format("%s -e alsamixer", terminal))
    end),
    awful.button({}, 4, function()
        awful.spawn(string.format("%s set %s 3%%+", vol_widget.cmd, vol_widget.channel))
        vol_widget.update()
    end),
    awful.button({}, 5, function()
        awful.spawn(string.format("%s set %s 3%%-", vol_widget.cmd, vol_widget.channel))
        vol_widget.update()
    end)
))
local vol_line = wibox.container.background(
    wibox.widget({
        vol_icon,
        vol_bar,
        layout = wibox.layout.align.horizontal
    }),
    "#7493D2"
)

-- Separator widget
local spr = wibox.container.background(wibox.widget.textbox(' '), theme.bg_noalpha)
local arrow = separators.arrow_left

-- Create a wibox for each screen and add it
local taglist_buttons = gears.table.join(
    awful.button({ }, 1, function(t) t:view_only() end),
    awful.button({ modkey }, 1, function(t)
                                    if client.focus then
                                        client.focus:move_to_tag(t)
                                    end
                                end),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ modkey }, 3, function(t)
                                    if client.focus then
                                        client.focus:toggle_tag(t)
                                    end
                                end),
    awful.button({ }, 4, function(t) awful.tag.viewprev(t.screen) end),
    awful.button({ }, 5, function(t) awful.tag.viewnext(t.screen) end)
)

local tasklist_buttons = gears.table.join(
    awful.button({ }, 1, function (c)
                            if c == client.focus then
                                c.minimized = true
                            else
                                -- Without this, the following
                                -- :isvisible() makes no sense
                                c.minimized = false
                                if not c:isvisible() and c.first_tag then
                                    c.first_tag:view_only()
                                end
                                -- This will also un-minimize
                                -- the client, if needed
                                client.focus = c
                                c:raise()
                            end
                         end),
    awful.button({ }, 3, client_menu_toggle_fn()),
    awful.button({ }, 4, function ()
                            awful.client.focus.byidx(1)
                         end),
    awful.button({ }, 5, function ()
                            awful.client.focus.byidx(-1)
                         end)
)

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

tag_names = {
    'α', 'β', 'γ', 'δ', 'ε', 'ζ', 'η', 'θ', 'ι', 'κ',
    'λ', 'μ', 'ν', 'ξ', 'ο', 'π', 'ρ', 'ς', 'σ', 'τ',
    'υ', 'φ', 'χ', 'ψ', 'ω'
}
tag_number = 25

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    awful.tag(tag_names, s, awful.layout.layouts[2])

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create an imagebox widget which will contains an icon indicating which layout we're using.
    -- We need one layoutbox per screen.
    s.mylayoutbox = awful.widget.layoutbox(s)
    s.mylayoutbox:buttons(
        gears.table.join(
            awful.button({ }, 1, function () awful.layout.inc( 1) end),
            awful.button({ }, 3, function () awful.layout.inc(-1) end),
            awful.button({ }, 4, function () awful.layout.inc( 1) end),
            awful.button({ }, 5, function () awful.layout.inc(-1) end)
        )
    )
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)

    -- Create a tasklist widget
    s.mytasklist = awful.widget.tasklist(s, awful.widget.tasklist.filter.currenttags, tasklist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            mylauncher,
            s.mytaglist,
            s.mypromptbox,
        },
        s.mytasklist, -- Middle widget
        { -- Right widgets
            layout = wibox.layout.fixed.horizontal,
            mykeyboardlayout,
            wibox.widget.systray(),
            arrow(theme.bg_noalpha, "#777E76"),
            mem_line,
            arrow("#777E76", "#4B696D"),
            cpu_line,
            arrow("#4B696D", "#4B3B51"),
            temp_line,
            arrow("#4B3B51", "#B63B3B"),
            fs_line,
            arrow("#B63B3B", "#A36530"),
            bat_line,
            arrow("#A36530", "#7B8F1B"),
            net_line,
            arrow("#7B8F1B", "#7493D2"),
            vol_line,
            arrow("#7493D2", theme.bg_noalpha),
            clock,
            s.mylayoutbox,
        },
    }
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(gears.table.join(
    awful.button({ }, 3, function () mymainmenu:toggle() end),
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = gears.table.join(
    -- Tage movement
    awful.key({ modkey,           }, "a",      awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "s",      awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev,
              {description = "view previous", group = "tag"}),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext,
              {description = "view next", group = "tag"}),
    -- Tag larger movement
    awful.key({ modkey, "Mod1"    }, "Left",   function() awful.tag.viewidx(-3) end ),
    awful.key({ modkey, "Mod1"    }, "Right",  function() awful.tag.viewidx( 3) end ),
    -- Screen movement
    awful.key({ modkey,           }, "Up",   function ()
                                                awful.screen.focus_relative( 1)
                                             end),
    awful.key({ modkey,           }, "Down", function ()
                                                awful.screen.focus_relative(-1)
                                              end),
    -- Tag restore
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore,
              {description = "go back", group = "tag"}),
    awful.key({ modkey,           }, "`",      awful.tag.history.restore,
              {description = "go back", group = "tag"}),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),
    awful.key({ modkey,           }, "w", function () mymainmenu:show() end,
              {description = "show main menu", group = "awesome"}),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end,
              {description = "swap with next client by index", group = "client"}),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end,
              {description = "swap with previous client by index", group = "client"}),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end,
              {description = "focus the next screen", group = "screen"}),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end,
              {description = "focus the previous screen", group = "screen"}),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto,
              {description = "jump to urgent client", group = "client"}),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end,
        {description = "go back", group = "client"}),

    -- Standard program
    awful.key({ modkey,           }, "Return", function () awful.spawn(terminal) end,
              {description = "open a terminal", group = "launcher"}),
    awful.key({ modkey, "Control" }, "r", awesome.restart,
              {description = "reload awesome", group = "awesome"}),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit,
              {description = "quit awesome", group = "awesome"}),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)          end,
              {description = "increase master width factor", group = "layout"}),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)          end,
              {description = "decrease master width factor", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1, nil, true) end,
              {description = "increase the number of master clients", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1, nil, true) end,
              {description = "decrease the number of master clients", group = "layout"}),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1, nil, true)    end,
              {description = "increase the number of columns", group = "layout"}),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1, nil, true)    end,
              {description = "decrease the number of columns", group = "layout"}),
    awful.key({ modkey,           }, "space", function () awful.layout.inc( 1)                end,
              {description = "select next", group = "layout"}),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(-1)                end,
              {description = "select previous", group = "layout"}),

    awful.key({ modkey, "Control" }, "n",
              function ()
                  local c = awful.client.restore()
                  -- Focus restored client
                  if c then
                      client.focus = c
                      c:raise()
                  end
              end,
              {description = "restore minimized", group = "client"}),

    -- Prompt
    awful.key({ modkey },            "r",     function () awful.screen.focused().mypromptbox:run() end,
              {description = "run prompt", group = "launcher"}),

    awful.key({ modkey }, "x",
              function ()
                  awful.prompt.run {
                    prompt       = "Run Lua code: ",
                    textbox      = awful.screen.focused().mypromptbox.widget,
                    exe_callback = awful.util.eval,
                    history_path = awful.util.get_cache_dir() .. "/history_eval"
                  }
              end,
              {description = "lua execute prompt", group = "awesome"})
    -- Menubar
    -- awful.key({ modkey }, "p", function() menubar.show() end,
    --           {description = "show the menubar", group = "launcher"})

    -- custom shortcut
	awful.key({ modkey }, "e", function() awful.spawn.with_shell('thunar') end),
	awful.key({ modkey }, "l", function() awful.spawn.with_shell('/home/iblis/bin/lock.sh') end),
	awful.key({ modkey }, "Print", function() awful.spawn.with_shell('gnome-screenshot') end),
    awful.key({ modkey }, "p", function() awful.util.spawn_with_shell('pkill --signal USR1 feh') end)
)

clientkeys = gears.table.join(
    awful.key({ modkey,           }, "f",
        function (c)
            c.fullscreen = not c.fullscreen
            c:raise()
        end,
        {description = "toggle fullscreen", group = "client"}),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill() end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "c",      function (c) c:kill() end,
              {description = "close", group = "client"}),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle,
              {description = "toggle floating", group = "client"}),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end,
              {description = "move to master", group = "client"}),
    awful.key({ modkey,           }, "o",      function (c) c:move_to_screen() end,
              {description = "move to screen", group = "client"}),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop end,
              {description = "toggle keep on top", group = "client"}),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized = not c.maximized
            c:raise()
        end ,
        {description = "(un)maximize", group = "client"}),
    awful.key({ modkey, "Control" }, "m",
        function (c)
            c.maximized_vertical = not c.maximized_vertical
            c:raise()
        end ,
        {description = "(un)maximize vertically", group = "client"}),
    awful.key({ modkey, "Shift"   }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c:raise()
        end ,
        {description = "(un)maximize horizontally", group = "client"}),

	-- client movement between tag
	awful.key({ modkey, "Control" }, "Left",
		function (c)
            if not client.focus then
                return
            end

            local curidx = awful.tag.getidx()
            local tags = awful.screen.focused().tags

			client.focus:move_to_tag(tags[((curidx - 2) % tag_number) + 1])
			awful.tag.viewprev()
		end),
	awful.key({ modkey, "Control" }, "Right",
		function (c)
            if not client.focus then
                return
            end

            local curidx = awful.tag.getidx()
            local tags = awful.screen.focused().tags

			client.focus:move_to_tag(tags[((curidx) % tag_number) + 1])
			awful.tag.viewnext()
		end)
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it work on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = gears.table.join(globalkeys,
        -- View tag only.
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = awful.screen.focused()
                        local tag = screen.tags[i]
                        if tag then
                           tag:view_only()
                        end
                  end,
                  {description = "view tag #"..i, group = "tag"}),
        -- Toggle tag display.
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = awful.screen.focused()
                      local tag = screen.tags[i]
                      if tag then
                         awful.tag.viewtoggle(tag)
                      end
                  end,
                  {description = "toggle tag #" .. i, group = "tag"}),
        -- Move client to tag.
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:move_to_tag(tag)
                          end
                     end
                  end,
                  {description = "move focused client to tag #"..i, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus then
                          local tag = client.focus.screen.tags[i]
                          if tag then
                              client.focus:toggle_tag(tag)
                          end
                      end
                  end,
                  {description = "toggle focused client on tag #" .. i, group = "tag"})
    )
end

clientbuttons = gears.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     focus = awful.client.focus.filter,
                     raise = true,
                     keys = clientkeys,
                     buttons = clientbuttons,
                     screen = awful.screen.preferred,
                     placement = awful.placement.no_overlap+awful.placement.no_offscreen,
                     size_hints_honor = false
     }
    },

    -- Floating clients.
    { rule_any = {
        instance = {
          "DTA",  -- Firefox addon DownThemAll.
          "copyq",  -- Includes session name in class.
        },
        class = {
          "Arandr",
          "Gpick",
          "Kruler",
          "MessageWin",  -- kalarm.
          "Sxiv",
          "Wpa_gui",
          "pinentry",
          "veromix",
          "xtightvncviewer"},

        name = {
          "Event Tester",  -- xev.
        },
        role = {
          "AlarmWindow",  -- Thunderbird's calendar.
          "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
        }
      }, properties = { floating = true }},

    -- Add titlebars to normal clients and dialogs
    { rule_any = { type = { "dialog" }
      }, properties = { titlebars_enabled = true }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    -- { rule = { class = "Firefox" },
    --   properties = { screen = 1, tag = "2" } },

    -- urxvt
    {
        rule = { class = "urxvt" },
        properties = {
            size_hints_honor = false,
        },
    },
    -- feh
    {
        rule = { name = "feh" },
        properties = {
            maximized_vertical = false,
            maximized_horizontal = false,
            floating = true,
            focus = false,
            width = 1366,
            height = 742,
            x = 1610,
            y = 150,
            below = true,
            sticky = true,
            focusable = false,
            skip_taskbar = true,
            type = "dock",
            border_width = 0,
            raise = false,
            buttons = photoframebutton,
        },
    },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup and
      not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = gears.table.join(
        awful.button({ }, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
-- }}}

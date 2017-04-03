-------------------------------
--  "Zenburn" awesome theme  --
--    By Adrian C. (anrxc)   --
-------------------------------

local themes_path = os.getenv("HOME") .. "/.config/awesome/themes/iblis"

-- {{{ Main
local theme = {}
theme.wallpaper = "/home/iblis/picture/desk.jpg"
-- }}}

-- {{{ Styles
theme.font      = "Droid Sans Mono 11"

-- {{{ Colors
theme.fg_normal  = "#DCDCCC"
theme.fg_focus   = "#F0DFAF"
theme.fg_urgent  = theme.fg_normal
theme.bg_normal  = "#3F3F3F55"
theme.bg_noalpha = "#1F1F1F"
theme.bg_focus   = "#1E232099"
theme.bg_urgent  = "#E14646"
theme.bg_systray = theme.bg_noalpha
-- }}}

-- {{{ Borders
theme.useless_gap   = 0
theme.border_width  = 0
theme.border_normal = "#3F3F3F"
theme.border_focus  = "#6F6F6F"
theme.border_marked = "#CC9393"
-- }}}

-- {{{ Titlebars
theme.titlebar_bg_focus  = "#3F3F3F"
theme.titlebar_bg_normal = "#3F3F3F"
-- }}}

-- {{{ Tag
theme.taglist_bg_focus = "#7EA13799"
-- }}}

-- {{{ Tasklist
theme.tasklist_bg_focus = "#7EA13799"
-- }}}

-- {{{ Tooltip
theme.tooltip_bg_color = "#2E417299"
-- }}}

-- There are other variable sets
-- overriding the default one when
-- defined, the sets are:
-- [taglist|tasklist]_[bg|fg]_[focus|urgent|occupied|empty|volatile]
-- titlebar_[normal|focus]
-- tooltip_[font|opacity|fg_color|bg_color|border_width|border_color]
-- Example:
--theme.taglist_bg_focus = "#CC9393"
-- }}}

-- {{{ Widgets
-- You can add as many variables as
-- you wish and access them by using
-- beautiful.variable in your rc.lua
--theme.fg_widget        = "#AECF96"
--theme.fg_center_widget = "#88A175"
--theme.fg_end_widget    = "#FF5656"
--theme.bg_widget        = "#494B4F"
--theme.border_widget    = "#3F3F3F"
-- }}}

-- {{{ Mouse finder
theme.mouse_finder_color = "#CC9393"
-- mouse_finder_[timeout|animate_timeout|radius|factor]
-- }}}

-- {{{ Menu
-- Variables set for theming the menu:
-- menu_[bg|fg]_[normal|focus]
-- menu_[border_color|border_width]
theme.menu_height = 25
theme.menu_width  = 150
-- }}}

-- {{{ Icons

-- {{{ Widgets
theme.widget_ac             = themes_path .. "/icons/ac.png"
theme.widget_battery        = themes_path .. "/icons/battery.png"
theme.widget_battery_low    = themes_path .. "/icons/battery_low.png"
theme.widget_battery_empty  = themes_path .. "/icons/battery_empty.png"
theme.widget_mem            = themes_path .. "/icons/mem.png"
theme.widget_cpu            = themes_path .. "/icons/cpu.png"
theme.widget_temp           = themes_path .. "/icons/temp.png"
theme.widget_net            = themes_path .. "/icons/net.png"
theme.widget_hdd            = themes_path .. "/icons/hdd.png"
theme.widget_music          = themes_path .. "/icons/note.png"
theme.widget_music_on       = themes_path .. "/icons/note_on.png"
theme.widget_vol            = themes_path .. "/icons/vol.png"
theme.widget_vol_low        = themes_path .. "/icons/vol_low.png"
theme.widget_vol_no         = themes_path .. "/icons/vol_no.png"
theme.widget_vol_mute       = themes_path .. "/icons/vol_mute.png"
theme.widget_mail           = themes_path .. "/icons/mail.png"
theme.widget_mail_on        = themes_path .. "/icons/mail_on.png"
-- }}}

-- {{{ Taglist
theme.taglist_squares_sel   = themes_path .. "/taglist/squarefz.png"
theme.taglist_squares_unsel = themes_path .. "/taglist/squarez.png"
--theme.taglist_squares_resize = "false"
-- }}}

-- {{{ Misc
-- theme.awesome_icon           = themes_path .. "/awesome-icon.png"
theme.menu_submenu_icon      = themes_path .. "default/submenu.png"
-- }}}

-- {{{ Layout
theme.layout_tile       = themes_path .. "/layouts/tile.png"
theme.layout_tileleft   = themes_path .. "/layouts/tileleft.png"
theme.layout_tilebottom = themes_path .. "/layouts/tilebottom.png"
theme.layout_tiletop    = themes_path .. "/layouts/tiletop.png"
theme.layout_fairv      = themes_path .. "/layouts/fairv.png"
theme.layout_fairh      = themes_path .. "/layouts/fairh.png"
theme.layout_spiral     = themes_path .. "/layouts/spiral.png"
theme.layout_dwindle    = themes_path .. "/layouts/dwindle.png"
theme.layout_max        = themes_path .. "/layouts/max.png"
theme.layout_fullscreen = themes_path .. "/layouts/fullscreen.png"
theme.layout_magnifier  = themes_path .. "/layouts/magnifier.png"
theme.layout_floating   = themes_path .. "/layouts/floating.png"
theme.layout_cornernw   = themes_path .. "/layouts/cornernw.png"
theme.layout_cornerne   = themes_path .. "/layouts/cornerne.png"
theme.layout_cornersw   = themes_path .. "/layouts/cornersw.png"
theme.layout_cornerse   = themes_path .. "/layouts/cornerse.png"
-- }}}

-- {{{ Titlebar
theme.titlebar_close_button_focus  = themes_path .. "/titlebar/close_focus.png"
theme.titlebar_close_button_normal = themes_path .. "/titlebar/close_normal.png"

theme.titlebar_minimize_button_normal = themes_path .. "/titlebar/minimize_normal.png"
theme.titlebar_minimize_button_focus  = themes_path .. "/titlebar/minimize_focus.png"

theme.titlebar_ontop_button_focus_active  = themes_path .. "/titlebar/ontop_focus_active.png"
theme.titlebar_ontop_button_normal_active = themes_path .. "/titlebar/ontop_normal_active.png"
theme.titlebar_ontop_button_focus_inactive  = themes_path .. "/titlebar/ontop_focus_inactive.png"
theme.titlebar_ontop_button_normal_inactive = themes_path .. "/titlebar/ontop_normal_inactive.png"

theme.titlebar_sticky_button_focus_active  = themes_path .. "/titlebar/sticky_focus_active.png"
theme.titlebar_sticky_button_normal_active = themes_path .. "/titlebar/sticky_normal_active.png"
theme.titlebar_sticky_button_focus_inactive  = themes_path .. "/titlebar/sticky_focus_inactive.png"
theme.titlebar_sticky_button_normal_inactive = themes_path .. "/titlebar/sticky_normal_inactive.png"

theme.titlebar_floating_button_focus_active  = themes_path .. "/titlebar/floating_focus_active.png"
theme.titlebar_floating_button_normal_active = themes_path .. "/titlebar/floating_normal_active.png"
theme.titlebar_floating_button_focus_inactive  = themes_path .. "/titlebar/floating_focus_inactive.png"
theme.titlebar_floating_button_normal_inactive = themes_path .. "/titlebar/floating_normal_inactive.png"

theme.titlebar_maximized_button_focus_active  = themes_path .. "/titlebar/maximized_focus_active.png"
theme.titlebar_maximized_button_normal_active = themes_path .. "/titlebar/maximized_normal_active.png"
theme.titlebar_maximized_button_focus_inactive  = themes_path .. "/titlebar/maximized_focus_inactive.png"
theme.titlebar_maximized_button_normal_inactive = themes_path .. "/titlebar/maximized_normal_inactive.png"
-- }}}
-- }}}

return theme

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80

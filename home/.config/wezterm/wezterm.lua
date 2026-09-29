-- Pull in WezTerm API
local wezterm = require("wezterm")

-- Load Rosé Pine theme plugin (all variants available)
local rose_pine = wezterm.plugin.require("https://github.com/neapsix/wezterm")
local themes = {
	main = rose_pine.main,
	moon = rose_pine.moon,
	dawn = rose_pine.dawn,
}

-- Set default theme variant (change this to switch: main, moon, or dawn)
local current_theme = themes.dawn
local current_theme_name = "Rosé Pine Dawn (Gogh)" -- for tabline.wez theme matching

-- Initialize actual config
local config = {}
if wezterm.config_builder then
	config = wezterm.config_builder()
end

-- Appearance
config.font_size = 18.0
config.font = wezterm.font("Maple Mono NF", { weight = "Bold", italic = false })

config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = false
config.enable_tab_bar = true
config.native_macos_fullscreen_mode = true
-- Transparent window background
config.window_background_opacity = 1.0
config.macos_window_background_blur = 70

-- Keybindings
config.keys = {
	-- Default QuickSelect keybind (CTRL-SHIFT-Space) gets captured by something
	-- else on my system
	{
		key = "A",
		mods = "CTRL|SHIFT",
		action = wezterm.action.QuickSelect,
	},
	-- Quickly open config file with common macOS keybind
	{
		key = ",",
		mods = "SUPER",
		action = wezterm.action.SpawnCommandInNewWindow({
			cwd = os.getenv("WEZTERM_CONFIG_DIR"),
			args = { os.getenv("SHELL"), "-c", "$VISUAL $WEZTERM_CONFIG_FILE" },
		}),
	},
	-- Toggle fullscreen with Cmd+Enter
	{
		key = "Enter",
		mods = "SUPER",
		action = wezterm.action.ToggleFullScreen,
	},

	-- Split horizontally with Ctrl+Shift+\
	{
		key = "H",
		mods = "CTRL",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	-- Split vertically with Ctrl+\
	{
		key = "V",
		mods = "CTRL",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
}

config.window_frame = current_theme.window_frame()

config.colors = current_theme.colors()

local act = wezterm.action

config.mouse_bindings = {
	-- Right click sends "woot" to the terminal
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = act.SendString("woot"),
	},

	-- Change the default click behavior so that it only selects
	-- text and doesn't open hyperlinks
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "NONE",
		action = act.CompleteSelection("ClipboardAndPrimarySelection"),
	},

	-- and make CTRL-Click open hyperlinks
	{
		event = { Up = { streak = 1, button = "Left" } },
		mods = "CTRL",
		action = act.OpenLinkAtMouseCursor,
	},
	-- NOTE that binding only the 'Up' event can give unexpected behaviors.
	-- Read more below on the gotcha of binding an 'Up' event only.
}

-- Tab bar

--

local tabline = wezterm.plugin.require("https://github.com/michaelbrusegard/tabline.wez")
tabline.setup({
	options = {
		icons_enabled = true,
		theme = current_theme_name,
		tabs_enabled = true,
		theme_overrides = {},
		section_separators = {
			left = wezterm.nerdfonts.pl_left_hard_divider,
			right = wezterm.nerdfonts.pl_right_hard_divider,
		},
		component_separators = {
			left = wezterm.nerdfonts.pl_left_soft_divider,
			right = wezterm.nerdfonts.pl_right_soft_divider,
		},
		tab_separators = {
			left = wezterm.nerdfonts.pl_left_hard_divider,
			right = wezterm.nerdfonts.pl_right_hard_divider,
		},
	},
	sections = {
		tabline_a = { "mode" },
		tabline_b = { "workspace" },
		tabline_c = { " " },
		tab_active = {
			"index",
			{ "parent", padding = 0 },
			"/",
			{ "cwd", padding = { left = 0, right = 1 } },
			{ "zoomed", padding = 0 },
		},
		tab_inactive = { "index", { "process", padding = { left = 0, right = 1 } } },
		tabline_x = { "ram", "cpu" },
		tabline_y = { "datetime", "battery" },
		tabline_z = { "domain" },
	},
	extensions = {},
})
tabline.apply_to_config(config)
-- Return config to WezTerm
return config

-------------------
---- COLORS -------
-------------------

-- Gruvbox palette for the Lua side of the Hyprland config, on the Catppuccin
-- slot names the rest of the config uses.
-- The hyprlang equivalent (used by hyprlock) lives in ../colors/.
--
-- Values are bare hex without a leading '#', so they compose into Hyprland's
-- rgba() literals: "rgba(" .. colors.blue .. "ff)"

local flavors = {
	dark = {
		rosewater = "d65d0e",
		flamingo = "b16286",
		pink = "d3869b",
		mauve = "d3869b",
		red = "fb4934",
		maroon = "cc241d",
		peach = "fe8019",
		yellow = "fabd2f",
		green = "b8bb26",
		teal = "8ec07c",
		sky = "689d6a",
		sapphire = "458588",
		blue = "83a598",
		lavender = "83a598",
		text = "ebdbb2",
		subtext1 = "d5c4a1",
		subtext0 = "bdae93",
		overlay2 = "a89984",
		overlay1 = "928374",
		overlay0 = "7c6f64",
		surface2 = "665c54",
		surface1 = "504945",
		surface0 = "3c3836",
		base = "282828",
		mantle = "1d2021",
		crust = "1d2021",
	},

	light = {
		rosewater = "d65d0e",
		flamingo = "b16286",
		pink = "8f3f71",
		mauve = "8f3f71",
		red = "9d0006",
		maroon = "cc241d",
		peach = "af3a03",
		yellow = "b57614",
		green = "79740e",
		teal = "427b58",
		sky = "689d6a",
		sapphire = "458588",
		blue = "076678",
		lavender = "076678",
		text = "3c3836",
		subtext1 = "504945",
		subtext0 = "665c54",
		overlay2 = "7c6f64",
		overlay1 = "928374",
		overlay0 = "a89984",
		surface2 = "bdae93",
		surface1 = "d5c4a1",
		surface0 = "ebdbb2",
		base = "fbf1c7",
		mantle = "f2e5bc",
		crust = "ebdbb2",
	},
}

-- This line is rewritten by `scripts/theme.sh`.
local active = "dark"

return flavors[active]

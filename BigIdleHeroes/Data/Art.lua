-- Interface pictures of this add-on (Media/Art, cut from the icon sheet by
-- tools/cut_icons.py): white icons drawn tinted. The menu screens' icons
-- (icon_<screen>), the forge's functions (forge_<function>), settings, the
-- 대장간 (icon_forge, tools/cut_icon.py from tools/art/forge_house.png), the
-- lock (icon_lock, tools/cut_icon.py) on everything locked, the
-- recommendation star and the boss skull (icon_star, icon_skull: painted,
-- never tinted), and the scroll bar pieces (sb_*).
-- UI.ArtIcon / UI.SetArtOrIcon use one when it is listed here, else the
-- game icon given with it.
local _, ns = ...

ns.ART = { icons = {}, ui = {} }
for _, id in ipairs({
	"icon_hero", "icon_bag", "icon_forge", "icon_party", "icon_runes", "icon_map", "icon_pets", "icon_settings",
	"forge_fuse", "forge_craft", "forge_gem", "forge_ench", "forge_insc", "forge_up", "forge_smelt", "forge_mats",
	"icon_lock", "icon_star", "icon_skull", "icon_crown",
	-- item slots (tools/cut_marks.py, painted): the better-gear arrow
	"icon_upgrade",
	-- 강화's strikes (tools/cut_anvil.py): the anvil, and the hammer swung
	-- about its handle's end
	"fx_anvil", "fx_hammer",
	-- scroll bars (tools/cut_scrollbar.py): bars, grips, page arrows
	"sb_bar_v", "sb_bar_h", "sb_bend", "sb_grip_v", "sb_grip_v_hot", "sb_arrow_left", "sb_arrow_right", "sb_arrow_up", "sb_arrow_down",
}) do
	ns.ART.icons[id] = { file = id .. ".tga" }
end

-- Interface pictures of this add-on (Media/Art, cut from the icon sheet by
-- tools/cut_icons.py): white icons drawn tinted. The menu screens' icons
-- (icon_<screen>), the forge's functions (forge_<function>) and settings.
-- UI.ArtIcon / UI.SetArtOrIcon use one when it is listed here, else the
-- game icon given with it.
local _, ns = ...

ns.ART = { icons = {}, ui = {} }
for _, id in ipairs({
	"icon_hero", "icon_bag", "icon_forge", "icon_party", "icon_runes", "icon_map", "icon_pets", "icon_settings",
	"forge_fuse", "forge_craft", "forge_gem", "forge_ench", "forge_insc", "forge_up", "forge_smelt", "forge_mats",
}) do
	ns.ART.icons[id] = { file = id .. ".tga" }
end

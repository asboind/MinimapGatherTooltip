# Third-party notices

## GatherMate2_Data (spawn coordinates)

- **Project:** [GatherMate2_Data (Retail & Forever)](https://www.curseforge.com/wow/addons/gathermate2_data)
- **Authors / maintenance:** moonfann, Nevcairiel (see CurseForge and GitHub `Nevcairiel/GatherMate2_Data`)
- **Use in this addon:** When GatherMate2 and GatherMate2_Data are installed, MinimapGatherTooltip reads the Forever herbalism and mining tables at runtime and caches item coordinates in its own saved variables. `Spawns.lua` is a compressed fallback extract of that forever set (snapshot noted in the file header), used only when the data addon is missing or disabled.
- **CurseForge license field:** **All Rights Reserved** (not an open-source license).
- **This addon does not ship** GatherMate2 or GatherMate2_Data. Both are optional; without them the embedded fallback is used.

You may contact the GatherMate2_Data maintainers if you redistribute coordinate data derived from their project.

## Auctionator

- **Project:** [Auctionator](https://www.curseforge.com/wow/addons/auctionator)
- **Use:** Runtime dependency only. MinimapGatherTooltip calls Auctionator APIs when that addon is loaded. No Auctionator code or price database is included.

## Blizzard Entertainment

- World of Warcraft, WoW Forever, and related assets are trademarks of Blizzard Entertainment.
- This is a fan-made UI mod. It must remain **free**, with **readable** Lua source, and must follow [Blizzard’s UI Add-On Development Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642).
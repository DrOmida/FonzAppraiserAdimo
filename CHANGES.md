# Changelog

## [Unreleased]

## [3.4] - 2026-03-26

### Changed
- `core.lua` `CHAT_MSG_LOOT()` — added early `session.isCurrent()` guard at top of handler; skips all string parsing, item lookup, and `guiUpdate()` calls when no session is active.
- `core.lua` `CHAT_MSG_MONEY()` — added early `session.isCurrent()` guard after `isInGroup()` check; skips all string parsing and `guiUpdate()` calls when no session is active.
- `mods/gui/gph.lua` `update()` — moved `updateData()` call inside the `if db.show then` block; data is no longer recalculated when the HUD is hidden.

### Removed
- `mods/slashcmd.lua` — removed duplicate `A.options.args["Move"]` slash command option (was identical to `"HudMove"`, same function, same description).
- `mods/gui/sessions/core.lua` — removed dead `updateGphValue()` and `lazyUpdateGphValue()` functions (body was fully commented out; neither did anything). Removed orphaned `lazyUpdateGphValue()` call from `durationAnimation_OnUpdate()`.

### Fixed
- Critical bug in `savedvar.lua` `setCharConfigDefaults()` — `if not namespace[k]` treated saved `false` values as missing, overwriting them with defaults on every login. Changed to `if namespace[k] == nil`. This caused the GPH HUD `show = false` setting to be reset to `true` every login.
- GPH HUD frame in `mods/gui/gph.lua` was visible during construction before `applySettings()` ran on `ADDON_LOADED`, causing a brief flash and unnecessary OnUpdate ticks.

### Changed
- GPH HUD default `show` changed from `true` to `false` in `mods/gui/gph.lua` `defaults` table — new characters start with HUD hidden; users opt-in via Config checkbox.
- GPH HUD `OnUpdate` handler in `mods/gui/gph.lua` now checks `frame:IsVisible()` before running `updateData()` to avoid wasted CPU cycles when the HUD is hidden.

---

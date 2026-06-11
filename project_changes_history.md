# Project Changes History

## 2026-06-11

### feat: add build-all.sh and improve run-simulator.sh
- Added `build-all.sh` to build PRGs for all devices in manifests in one run
- `run-simulator.sh`: track whether the script started the simulator and kill it on exit
- `run-simulator.sh`: prompt PASS/FAIL after `monkeydo` finishes or Ctrl+C
- `run-simulator.sh`: on FAIL, append target name to `failed_target.txt`
- `run-simulator.sh`: filter out failed targets from the interactive menu
- `run-simulator.sh`: two-step menu (type → device name) to reduce 144-item list
- `run-simulator.sh`: Ctrl+C during simulation returns to PASS/FAIL prompt instead of exiting
- `build-all.sh`: exclude targets listed in `failed_target.txt`
- `build-all.sh`: skip all widget builds (watchface only)

---

## 2026-06-09

### v1.2.0 Release
- Bumped version to 1.2.0
- Renamed widget for clarity
- Localized glance strings

### feat: Bible Verse widget
- Implemented Bible Verse widget (`VerseWidgetView.mc`)
- Renamed resource directories to `resources_kor` / `resources_kor-vivoactive4s`
- Added more Korean Bible verses
- Used `FONT_SMALL` for bottom reference text in widget

---

## 2026-06-07

### feat: reference text color and size
- Made book name red and chapter:verse in accent color
- Made both book name and chapter:verse red
- Increased reference font size: 9→10 (4S), 14→15 (standard)
- Increased reference font size again: 10→12 (4S), 15→17 (standard)

### feat: custom fonts for verse and reference
- Resized standard custom verse font to size 20, reference font to size 14 (matches time font)
- Implemented separate smaller custom font for bottom reference

### feat: Korean book name abbreviations
- Applied Korean abbreviations to book names
- Implemented length-conditioned abbreviation logic (shorter names for long titles)
- Rebuilt English font glyphs alongside Korean

### fix: stability and rendering
- Reverted bottom reference font to custom `_font` to prevent broken Korean glyphs on non-APAC devices
- Fixed `substring` call parameter count for backward compatibility
- Resolved `IQ!` crash and book reference splitting on bottom arc

---

## 2026-06-05

### feat: verse font scaling
- Increased verse font: `FONT_SMALL` → `FONT_MEDIUM` for readability
- Increased verse font: `FONT_MEDIUM` → `FONT_LARGE`

### feat: pagination
- Added verse-to-reference collision detection with pagination
- Fixed watchface input handling for tap-to-paginate
- Added build and sideload documentation for pagination release

---

## 2026-06-03

### Initial development
- Initial commit: verses watchface for Garmin vivoactive4 / vivoactive4s
- Loaded 241 Korean Bible verses, improved watchface display layout
- Removed metrics display and rebuilt custom fonts at 72pt
- Switched to system font and implemented conditional character wrapping

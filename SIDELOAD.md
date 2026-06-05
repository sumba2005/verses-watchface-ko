# Sideloading Verses Watchface to vivoactive4/4s

## Prerequisites

- **Garmin Connect IQ SDK** installed
- **vivoactive4 or vivoactive4s** watch with USB connection
- **Git** for version control (optional)

## Step 1: Install Connect IQ SDK

Download from: https://developer.garmin.com/downloads/connect-iq/

Extract and add to PATH. Test:
```bash
monkeyc --version
```

## Step 2: Build the Watchface

With the pagination changes, rebuild the .prg files:

```bash
# English version
monkeyc -f eng.jungle -o bin/verses-face-4s.prg -l

# Or Korean version
monkeyc -f monkey.jungle -o bin/verses-kor-4s.prg -l
```

If the build succeeds, you'll see: `SUCCESS` and have a fresh .prg in `bin/`

## Step 3: Sideload to Watch

### Option A: Using Garmin BaseCamp (Easiest)

1. Connect watch via USB to computer
2. Open Garmin BaseCamp
3. File → Import → select `bin/verses-face-4s.prg`
4. Select your watch as the destination
5. Wait for transfer to complete

### Option B: Manual USB Copy (Advanced)

1. Connect watch via USB (it mounts as a drive)
2. Navigate to: `GARMIN/APPS/`
3. Create a folder named with the app ID from manifest:
   ```
   mkdir GARMIN/APPS/3f4362d960df42419ab01640cdf6788c
   ```
4. Copy `bin/verses-face-4s.prg` into that folder
5. Safely eject and disconnect
6. Watch will auto-detect the new app

### Option C: Using Garmin Connect Mobile

1. Build with `-l` flag for debug symbols
2. Use "Developer Tools" in Garmin Connect mobile app
3. Select the .prg file to install to paired watch

## Step 4: Verify Installation

1. On watch, hold UP to access watch faces
2. Swipe to find "Verses" (or "구절" for Korean)
3. Tap to activate

## Testing Pagination

With your updated code:
1. **Tap verse text** → enters FONT_MEDIUM pagination mode
2. **Tap again** → cycles to next page
3. **Wait 10 seconds** → auto-exits to normal mode
4. **Check top center** → dots appear only if verse needs multiple pages

## Troubleshooting

### Build fails: "monkeyc not found"
→ Ensure SDK is installed and in PATH. Try full path: `/path/to/connectiq/bin/monkeyc`

### "Resource not found"
→ Rebuild resources first:
```bash
cd tools/
python3 build_resources.py eng  # for English
python3 build_resources.py kor  # for Korean
```

### Watch doesn't show new app after sideload
→ Hard restart watch: Settings → System → Reboot

## File Locations

| File | Purpose |
|------|---------|
| `manifest-eng.xml` | App metadata (English) |
| `source/VersesFaceView.mc` | Main watchface + pagination logic |
| `source/VersesFaceApp.mc` | App entry point |
| `resources-eng/data/verses.json` | English verses data |
| `bin/verses-face-4s.prg` | Compiled app (ready to sideload) |

## Build Output Files

After successful build, you'll have:
- `verses-face-4s.prg` — the watchface app
- `verses-face-4s.prg.debug.xml` — debug symbols
- `verses-face-4s-settings.json` — settings metadata

Only the `.prg` file is needed for sideloading.

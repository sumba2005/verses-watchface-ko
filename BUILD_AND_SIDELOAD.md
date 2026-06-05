# Build & Sideload Verses Watchface with Pagination

## What's New
✨ **Pagination system** with verse-to-reference collision detection
- Tap verse text → FONT_MEDIUM pagination mode
- Tap again → cycle through pages
- Auto-timeout after 10 seconds
- Dot indicators at top center (only on multi-page)

## Prerequisites

- **Connect IQ SDK 9.x** installed on your machine
- **vivoactive4 or vivoactive4s** watch (USB connection)
- **Developer key** (free from Garmin)

## Step 1: Get Developer Key (One-Time)

### Option A: Use Garmin Developer Portal
1. Go to: https://developer.garmin.com/
2. Sign in (create account if needed)
3. Download your developer certificate/key
4. Save as: `~/garmin-dev-key.p12` (or similar)

### Option B: Generate via SDK Key Manager
1. Open Connect IQ application (if installed)
2. Settings → Developer Certificate
3. Create New Certificate → Follow wizard
4. Key saves to: `~/.Garmin/ConnectIQ/Certificates/` (or similar)

## Step 2: Clone/Update Code

```bash
# Get the latest pagination implementation
cd ~/path/to/verses-watchface3
git pull origin master

# Should see commit: "Add verse-to-reference collision detection with pagination"
git log --oneline -1
```

## Step 3: Build with Your Key

```bash
# Set your key path (replace with your actual key location)
export MY_KEY="$HOME/garmin-dev-key.p12"
# OR
# export MY_KEY="$HOME/.Garmin/ConnectIQ/Certificates/your-key.p12"

# Build English version
monkeyc -f eng.jungle -o bin/verses-face-4s.prg -y $MY_KEY

# Build Korean version (optional)
monkeyc -f monkey.jungle -o bin/verses-kor-4s.prg -y $MY_KEY
```

**Expected output:**
```
SUCCESS
```

If you get an error about the key format, try these alternatives:
- `.keystore` file (Java keystore format)
- `.pfx` file (PKCS#12 format)
- Ask Garmin support which format they provide

## Step 4: Verify Build

```bash
ls -lh bin/verses-face-4s.prg
# Should be ~130-150 KB and recently modified
```

## Step 5: Connect Watch & Sideload

### Option A: Garmin BaseCamp (Easiest)
1. Plug watch into computer via USB
2. Open Garmin BaseCamp
3. File → Import
4. Select: `bin/verses-face-4s.prg`
5. Choose watch as destination
6. Click Import/Transfer
7. Wait for completion (usually 10-30 seconds)

### Option B: Manual USB Copy
1. Connect watch via USB (it mounts as a drive)
2. Navigate to: `GARMIN/APPS/`
3. Create folder: `3f4362d960df42419ab01640cdf6788c` (app ID from manifest)
4. Copy `bin/verses-face-4s.prg` into that folder
5. Eject/unmount safely
6. Watch auto-detects new app on next boot

### Option C: Garmin Connect Mobile
1. In app: Settings → Developer Mode (enable)
2. Build with: `monkeyc ... -d vivoactive4`
3. Use "Install via Connect Mobile" option
4. Select your watch from the app

## Step 6: Test on Watch

1. On watch: Hold **UP** to access watch faces
2. Swipe to find **"Verses"**
3. Tap to make it your active watch face
4. View the verse that's currently active
5. **Tap on the verse text** (in the middle)
   - Should enter pagination mode (FONT_MEDIUM, larger text)
   - Dots appear at top if verse spans multiple pages
6. **Tap again** → next page (dots cycle)
7. **Wait 10 seconds** → auto-exits to normal mode
8. **Swipe to different verse** (hour changes) → pagination resets

## Troubleshooting

### Build fails: "Unable to load private key"
- Verify your key file exists: `ls -l /path/to/your/key.p12`
- Try specifying absolute path: `monkeyc ... -y /absolute/path/to/key.p12`
- If using `.keystore`, try: `-y /path/to/keystore.jks`
- Contact Garmin if unsure about key format

### Build fails: "The private key was not specified"
- Make sure `-y` flag is provided
- Double-check the `-y` value is a valid file path

### Watch doesn't show new app
- Disconnect watch from USB
- Hard restart watch: Settings → System → Reboot
- Reconnect and try sideload again
- Check that `GARMIN/APPS/3f4362d960df42419ab01640cdf6788c/` folder exists

### Pagination not working
- Verify you're tapping the **verse text** (middle of screen)
- Not the time (top) or reference (bottom)
- Try tapping multiple times
- If verse is very short (1 line), pagination might not show (by design—no dots needed for single page)

## Build Output Files

After successful build:
```
bin/verses-face-4s.prg              ← Sideload this file
bin/verses-face-4s.prg.debug.xml    ← Debug symbols (optional)
bin/verses-face-4s-settings.json    ← Settings metadata (optional)
```

Only the `.prg` file is needed for sideloading.

## Feature Summary

**Normal Mode (default):**
- Time curved at top
- Verse in middle (auto-wrapped)
- Reference text curved at bottom
- Battery/pedometer on sides (optional)

**Pagination Mode (after tap):**
- Same layout but verse in FONT_MEDIUM (larger, more readable)
- Verse split into pages
- Dots at top center show current page
- Tap to cycle pages
- Auto-exit after 10 seconds (or new verse loads)

**Collision Detection (automatic):**
- If verse too long, reduces reference arc radius
- If still too long, shrinks verse display region
- If still too long, truncates to 4 lines with "..."
- All fallbacks are invisible to user—display just adapts

## Need Help?

- **Garmin SDK docs:** https://developer.garmin.com/downloads/connect-iq/
- **Connect IQ forum:** https://forums.garmin.com/developer/connect-iq/
- **This project:** Check git log for implementation details

## Success!

Once sideloaded and tested, you're done! The pagination system is production-ready. Enjoy reading Bible verses on your watch! 📖⌚

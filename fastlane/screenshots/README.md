# App Store screenshots (frameit)

Wraps raw simulator captures in a device frame + calm background + caption,
producing App Store–ready images.

## One-time setup (done)
- `bundle install` — fastlane lives in the project Gemfile (run everything via
  `bundle exec`, NOT the broken Homebrew `fastlane` wrapper).
- `bundle exec fastlane frameit download_frames` — device frames cached in
  `~/.fastlane/frameit/` (includes iPhone 16/17 Pro Max = 6.9").

## Capture the raw screens (6.9", iPhone 16/17 Pro Max sim → 1320×2868)
1. Boot a 6.9" sim and install a Release-ish build with realistic data.
2. Clean the status bar:
   ```
   xcrun simctl status_bar booted override --time 9:41 --batteryLevel 100 \
     --batteryState charged --cellularBars 4 --wifiBars 3
   ```
3. Navigate to each screen and capture into `en-US/` with these exact names
   (they key into `title.strings`):
   | File | Screen |
   |------|--------|
   | `01_muscle_map.png` | post-session muscle map |
   | `02_logging.png` | active workout / set logging |
   | `03_readiness.png` | Today readiness glance |
   | `04_ai.png` | AI routine wizard / quick-log |
   | `05_progress.png` | progress chart + weekly map |
   | `06_privacy.png` | export / privacy |
   | `07_pricing.png` | paywall / price |
   ```
   xcrun simctl io booted screenshot fastlane/screenshots/en-US/01_muscle_map.png
   ```

## Frame them
```
cd fastlane/screenshots && bundle exec fastlane frameit
```
Output: `*_framed.png` beside each source. Upload those to App Store Connect.

## Editing captions / look
- Caption text → `en-US/title.strings` (key = filename without extension).
- Background, padding, font, colors → `Framefile.json`.
- Other locales → add a sibling folder (`de-DE/`, etc.) with its own `title.strings`.

## Notes
- Slot 1 (muscle map) is the hook — consider hand-designing that one in Figma
  for max polish and using frameit for the rest.
- If you ship iPhone-only, you only need this 6.9" set (ASC scales down).
  Keeping iPad support means also producing a 13" iPad set.

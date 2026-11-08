# Lunar

- Native macOS SwiftUI app with a bundled Moonlight 6.2.0 streaming engine. The installed Moonlight app is optional.
- Use the bundled helper for list, pair, and stream commands. Never call an executable in /Applications/Moonlight.app.
- The engine owns com.balaji.lunar.engine QSettings. The UI owns dev.balaji.lunar preferences. Keep their fallback domains separate.
- On first engine start, import legacy Moonlight settings once under a lock, before any settings reader can create a new identity. Preserve certificate, key, unique ID, hosts, and saved options. Never write to legacy settings.
- Read saved paired computers through UserDefaults, not the plist file on disk.
- Native SwiftUI owns setup, PIN display, progress, cancellation, errors, and retry. Use the upstream pairing launcher; do not implement another pairing protocol.
- Run one list, pair, or stream command at a time. Wait for pairing to exit and flush hosts before reloading them.
- Use LUNAR_NATIVE_UI=1 for pair and stream. Do not load Qt connection or setup screens.
- Keep upstream protocol, video, audio, and input code unchanged. The renderer belongs to the bundled engine.
- Keep patches/lunarui.h and patches/lunarsettings.h in sync with the vendored headers, and patches/native-ui.patch in sync with entry-point changes.
- Build the engine with zsh scripts/build-engine.sh, then run zsh scripts/build.sh.
- This build requires macOS 26 on Apple Silicon due to its bundled Qt libraries.
- Keep patches/lunarmenu.mm in sync with the vendored native menu source. Command-Q quits Lunar; Command-W and the stream close button disconnect only the stream.
- The application delegate waits for list, pairing, and stream helpers before quitting. Keep setup-sheet quit handling in the native Quit command.
- Package a local disk image with zsh scripts/package.sh. This build has an ad hoc signature, not Developer ID notarization.
- See DESIGN.md and reviews/claude-design-review.md for the independence design.

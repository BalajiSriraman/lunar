# Lunar

A native macOS remote desktop app. Requires macOS 26 on Apple Silicon. The installed Moonlight app is optional.

- Use **Disconnect** or **Command-W** to end a stream. **Command-Q** quits Lunar and its helpers.
- **Command-N** adds a computer. Enter the address and enter the shown PIN in Sunshine.
- **Command-comma** opens Settings; **Command-R** refreshes applications.
- Lunar imports Moonlight pairings once, then owns its settings. Existing credentials and Moonlight data are preserved.
- Native controls have accessibility names and headings. The PIN is read one digit at a time. Card hover effects respect Reduce Motion.

## Build

Install the Xcode Command Line Tools, Homebrew, and Python 3. Then run:

```sh
brew install qtbase qtdeclarative qtsvg
zsh scripts/build-engine.sh  # Downloads upstream engine libraries on first build
zsh scripts/build.sh
open build/Lunar.app
zsh scripts/package.sh      # Optional: build/Lunar-0.3.0-arm64.dmg
```

All engine source and source dependencies are included. The build uses Homebrew at `/opt/homebrew`. The app has an ad hoc signature and is not notarized. No prebuilt release is included in this repository.

## Status

Lunar is experimental. Native connection progress, cancel, and host-error handling have been checked in actual windows. The application list was verified in native mode on 8 November 2026. A complete desktop stream has not been verified.

For the UI and engine boundaries, see [DESIGN.md](DESIGN.md).

## License

Lunar is distributed under [GNU GPL v3](LICENSE). The bundled engine uses [Moonlight 6.2.0](https://github.com/moonlight-stream/moonlight-qt/tree/v6.2.0). Its source is in `vendor/moonlight-qt-6.2.0`, and the native adapters are in `patches/`. Upstream streaming and pairing protocols, video, audio, and input code retain their original implementation and attribution. See [NOTICE.md](NOTICE.md) for dependency details.

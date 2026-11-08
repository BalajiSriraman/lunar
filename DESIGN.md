# Independent Lunar

## Goal

Lunar must list computers and applications, pair a new computer, and stream after the installed Moonlight app and its preferences are removed. Keep the bundled upstream streaming engine and its protocol, video, audio, and input code.

## Ownership

- Use the bundled engine for list, pair, and stream commands. Resolve it from the Lunar bundle.
- Give the engine a separate QSettings domain: com.balaji.lunar.engine. The Swift UI keeps its existing dev.balaji.lunar settings.
- On first engine start only, hold an import lock and copy all existing Moonlight QSettings values into the empty Lunar engine domain. This includes the client certificate, private key, identity, hosts, cached applications, and stream settings. Do not log values. Never overwrite an existing Lunar identity. Never write to Moonlight settings. Sync the copied values before the completion marker. Mark the import complete even when no old settings exist. The Qt organization fallback is com.balaji.lunar, separate from the Swift UI.
- Read paired computers from the Lunar engine domain through UserDefaults. The engine syncs settings before it reports successful pairing.

## Native setup

- Plus opens a native sheet with a host address field. Generate a four-digit PIN for a pairing attempt. Show the PIN and tell the user to enter it in Sunshine on that computer.
- Run the existing upstream pair launcher with the supplied PIN. A small engine UI adapter emits JSON progress, success, and error events. No Qt setup window.
- Run only one engine command at a time in the UI. Disable refresh, selection, and stream actions during pairing. Cancel stops the child process and waits for it to exit before the sheet closes. Show an error with Retry. Refresh the computer list on success. Do not implement a new pairing protocol.

## Settings and packaging

- Label inherited values as saved settings. They refer to Lunar-owned imported settings or upstream defaults on a new install. Remove links that open Moonlight.
- Keep upstream attribution and licenses. The bundled helper has a separate Lunar bundle identifier and display name. No runtime path may refer to the installed Moonlight app.

## Checks

- Build the engine and Swift app. Check bundle libraries for external Moonlight paths.
- Test preference import with temporary QSettings files: preserve identity and hosts, import once, do not overwrite existing Lunar settings, and work with no source preferences.
- Test listing and live streaming with the installed Moonlight app temporarily moved aside. Do not remove the user’s Moonlight preferences; verify the new domain owns the same identity and all runtime reads use it. A fresh macOS account test remains a separate check. Test pairing failures and cancellation without changing the existing server identity.
- Review actual UI images. Keep the installed Moonlight app and its data until the checks pass.

## Implementation

Use the separate fallback domain, locked import before settings users, command exclusion, preferences API reads, paired-host filtering, delayed pairing flush, and child-exit handling. Keep meaningful validation limits in README.md. No new pairing protocol or server change is required.

Lunar list commands do not request box art. The native library uses application names, and an unused box-art download can block command shutdown. The upstream default behavior stays available outside native mode.
